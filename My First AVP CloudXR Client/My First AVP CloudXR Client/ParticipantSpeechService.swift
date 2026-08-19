//
//  ParticipantSpeechService.swift
//  My First AVP CloudXR Client
//
//  Transcribes the participant on-device and sends each finished sentence to the
//  agent through Firestore.
//
//  Why on-device transcription rather than streaming the microphone
//  ---------------------------------------------------------------
//  There is no way to get the Vision Pro's microphone to the server. CloudXR
//  Runtime 6.0.5 streams audio server-to-client only — its own effective-settings
//  dump lists exactly one audio flag, `audioStreaming`, and no upstream stream is
//  ever created. The LiveKit Swift SDK, which would have let the headset publish
//  into the room directly, does not support visionOS at all: neither it nor its
//  WebRTC XCFramework declares the platform.
//
//  So the audio never leaves the headset. Speech is recognised locally, and only
//  *text* is sent. That is also the better answer for data protection: no voice
//  recording in transit or at rest, which keeps participant audio out of the
//  data-management plan entirely.
//
//  Flow
//  ----
//    mic -> on-device recogniser -> partial text
//        -> silence for `endpointSilence` seconds = sentence finished
//        -> append to `participant_utterances`      (the research record)
//        -> patch `experiment_control/participant_speech`  (the agent trigger)
//    Unity's AgentSpeechController sees the trigger and calls SendGenerateReply,
//    the avatar answers, and the reply comes back as CloudXR audio.
//
//  Echo
//  ----
//  The avatar's voice plays out of the Vision Pro speakers, and the recogniser
//  will happily transcribe it back as if the participant had said it — the agent
//  ends up talking to itself. Echo cancellation cannot help, because that audio
//  arrives over CloudXR rather than through this app's audio session, so there is
//  no reference signal to subtract. Instead Unity publishes whether the agent is
//  speaking, and recognition is suspended while it is. In-ear playback (AirPods
//  paired to the headset) removes most of what remains.
//

import SwiftUI
import Combine
import AVFoundation
import Speech

@MainActor
final class ParticipantSpeechService: ObservableObject {

    enum State: Equatable {
        case idle
        case requestingPermission
        case unavailable(String)
        case listening
        case gated              // agent is speaking; deliberately not transcribing
        case failed(String)

        var label: String {
            switch self {
            case .idle: return "Speech recognition off"
            case .requestingPermission: return "Asking for permission…"
            case .unavailable(let why): return "Unavailable: \(why)"
            case .listening: return "Listening"
            case .gated: return "Paused — avatar speaking"
            case .failed(let why): return "Failed: \(why)"
            }
        }

        var isRunning: Bool {
            switch self {
            case .listening, .gated: return true
            default: return false
            }
        }
    }

    // MARK: - Tuning

    /// Locale used for recognition. Change to "de-DE" to run the study in German —
    /// this is the only place the language is decided on the client.
    @AppStorage("speechLocale") var localeIdentifier: String = "en-US"

    /// How long the transcript must stop changing before the sentence counts as
    /// finished. Shorter feels snappier but chops people off mid-thought.
    @AppStorage("speechEndpointSilence") var endpointSilence: Double = 1.0

    /// Commit regardless after this long, so a monologue still reaches the agent.
    @AppStorage("speechMaxUtterance") var maxUtterance: Double = 20.0

    /// Send `interrupt` when the participant starts talking over the avatar.
    @AppStorage("speechBargeIn") var bargeInEnabled: Bool = true

    // MARK: - Published state

    @Published private(set) var state: State = .idle
    @Published private(set) var partialText: String = ""
    @Published private(set) var lastCommitted: String = ""
    @Published private(set) var committedCount = 0
    @Published private(set) var agentSpeaking = false

    // MARK: - Dependencies

    private let utterances: FirestoreREST      // append-only research log
    private let trigger: FirestoreREST         // document Unity watches
    private let agentState: FirestoreREST      // document Unity publishes to
    private weak var eventLog: SessionEventLog?
    private weak var conditionService: ExperimentConditionService?

    // MARK: - Speech plumbing

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    private var utteranceStartedAt: Date?
    private var lastChangeAt: Date?
    private var endpointTimer: Timer?
    private var gatePollTask: Task<Void, Never>?
    private var requestCounter = 0

    private let collection = "participant_utterances"

    init(projectId: String,
         apiKey: String,
         eventLog: SessionEventLog?,
         conditionService: ExperimentConditionService?) {
        self.utterances = FirestoreREST(projectId: projectId, apiKey: apiKey,
                                        documentPath: collection)
        self.trigger = FirestoreREST(projectId: projectId, apiKey: apiKey,
                                     documentPath: "experiment_control/participant_speech")
        self.agentState = FirestoreREST(projectId: projectId, apiKey: apiKey,
                                        documentPath: "experiment_control/agent_state")
        self.eventLog = eventLog
        self.conditionService = conditionService
    }

    deinit {
        endpointTimer?.invalidate()
        gatePollTask?.cancel()
    }

    // MARK: - Start / stop

    func start() async {
        guard !state.isRunning else { return }

        state = .requestingPermission

        guard await requestSpeechPermission() else {
            state = .unavailable("speech recognition permission denied")
            return
        }
        guard await requestMicPermission() else {
            state = .unavailable("microphone permission denied")
            return
        }

        let locale = Locale(identifier: localeIdentifier)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            state = .unavailable("no recogniser for \(localeIdentifier)")
            return
        }
        guard recognizer.isAvailable else {
            state = .unavailable("recogniser not available right now")
            return
        }

        self.recognizer = recognizer
        startGatePolling()

        do {
            try startEngine()
            startRecognitionTask()
            state = .listening
            print("🗣️ [ParticipantSpeechService] Listening (\(localeIdentifier), endpoint \(endpointSilence)s).")
        } catch {
            state = .failed(error.localizedDescription)
            print("❌ [ParticipantSpeechService] \(error.localizedDescription)")
        }
    }

    func stop() {
        endpointTimer?.invalidate(); endpointTimer = nil
        gatePollTask?.cancel(); gatePollTask = nil
        endRecognition()
        state = .idle
        partialText = ""
    }

    // MARK: - Recognition
    //
    // The audio engine is started **once** and the microphone tap stays installed
    // for the whole session; only the recognition request is swapped between
    // utterances.
    //
    // Tearing the engine down after every sentence — stop, removeTap, re-read the
    // input format, installTap, start — is what made the first sentence work and
    // every later one silently fail: after `engine.stop()` the input node often
    // reports a zero-sample-rate format, and a tap installed with that format
    // delivers no audio at all, with no error anywhere.

    /// Holds whichever request is current so the audio tap, which runs on a
    /// realtime audio thread, can feed it without touching main-actor state.
    private final class RequestBox: @unchecked Sendable {
        private let lock = NSLock()
        private var request: SFSpeechAudioBufferRecognitionRequest?

        func set(_ next: SFSpeechAudioBufferRecognitionRequest?) {
            lock.lock(); defer { lock.unlock() }
            request = next
        }

        func append(_ buffer: AVAudioPCMBuffer) {
            lock.lock(); let current = request; lock.unlock()
            current?.append(buffer)
        }

        func endAudio() {
            lock.lock(); let current = request; lock.unlock()
            current?.endAudio()
        }
    }

    private let requestBox = RequestBox()

    /// Starts the engine and installs the tap. Called once per session.
    private func startEngine() throws {
        guard !engine.isRunning else { return }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        guard format.sampleRate > 0 else {
            throw NSError(domain: "ParticipantSpeechService", code: -2, userInfo: [
                NSLocalizedDescriptionKey:
                    "The microphone reported a zero sample rate. Another app may hold the audio input.",
            ])
        }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [requestBox] buffer, _ in
            requestBox.append(buffer)
        }

        engine.prepare()
        try engine.start()

        print("🎤 [ParticipantSpeechService] Audio engine running at \(Int(format.sampleRate)) Hz.")
    }

    /// Swaps in a fresh recognition request. The engine keeps running throughout,
    /// so no audio is lost and no format has to be renegotiated.
    private func startRecognitionTask() {
        task?.cancel()
        task = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        // Keep audio on the device. Also means recognition keeps working if the
        // network is busy carrying the CloudXR stream.
        if recognizer?.supportsOnDeviceRecognition == true {
            request.requiresOnDeviceRecognition = true
        } else {
            print("⚠️ [ParticipantSpeechService] On-device recognition unavailable for \(localeIdentifier); " +
                  "audio would be sent to Apple for transcription. Check this before running participants.")
        }

        self.request = request
        requestBox.set(request)

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.handlePartial(result.bestTranscription.formattedString)

                    // The recogniser decided the utterance was over. Its task is now
                    // finished and will never report again, so a new one is needed
                    // whether or not the silence timer has fired yet.
                    if result.isFinal {
                        self.rotateRecognitionTask()
                        return
                    }
                }

                if error != nil, self.state.isRunning {
                    // A task that has simply ended reports an error too, so this is
                    // not necessarily a fault — rotate rather than surfacing it.
                    self.rotateRecognitionTask()
                }
            }
        }
    }

    /// Ends the current utterance and immediately begins the next one.
    private func rotateRecognitionTask() {
        guard state.isRunning else { return }

        requestBox.endAudio()
        requestBox.set(nil)
        task?.cancel()
        task = nil
        request = nil

        startRecognitionTask()
    }

    private func endRecognition() {
        task?.cancel(); task = nil
        requestBox.endAudio()
        requestBox.set(nil)
        request = nil

        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
    }

    // MARK: - Endpointing

    private func handlePartial(_ text: String) {
        // While the avatar talks, anything the recogniser hears is most likely the
        // avatar itself. Drop it rather than send the agent its own words back.
        if agentSpeaking {
            if bargeInEnabled && !text.isEmpty && text != partialText {
                sendInterrupt()
            }
            partialText = ""
            return
        }

        guard text != partialText else { return }

        if utteranceStartedAt == nil { utteranceStartedAt = Date() }
        partialText = text
        lastChangeAt = Date()
        armEndpointTimer()
    }

    private func armEndpointTimer() {
        endpointTimer?.invalidate()
        endpointTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkEndpoint() }
        }
    }

    private func checkEndpoint() {
        guard !partialText.isEmpty, let lastChange = lastChangeAt else { return }

        let silent = Date().timeIntervalSince(lastChange) >= endpointSilence
        let tooLong = utteranceStartedAt.map { Date().timeIntervalSince($0) >= maxUtterance } ?? false

        guard silent || tooLong else { return }

        commit(partialText, reason: tooLong ? "max_length" : "silence")
    }

    /// Commit the current partial immediately — for a push-to-talk style override
    /// when endpointing misfires.
    func commitNow() {
        guard !partialText.isEmpty else { return }
        commit(partialText, reason: "manual")
    }

    private func commit(_ text: String, reason: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        endpointTimer?.invalidate(); endpointTimer = nil
        let startedAt = utteranceStartedAt ?? Date()
        utteranceStartedAt = nil
        lastChangeAt = nil
        partialText = ""

        guard !trimmed.isEmpty else { return }

        requestCounter += 1
        committedCount += 1
        lastCommitted = trimmed

        print("🗣️ [ParticipantSpeechService] \(reason): \"\(trimmed)\"")

        logUtterance(trimmed, startedAt: startedAt, reason: reason, index: requestCounter)
        sendToAgent(trimmed, requestId: requestCounter)

        // A recognition task is finished once its utterance is committed, so the
        // next sentence needs a fresh one. The engine is untouched.
        rotateRecognitionTask()
    }

    // MARK: - Firestore

    private func logUtterance(_ text: String, startedAt: Date, reason: String, index: Int) {
        let condition = conditionService?.condition ?? .none
        let iso = ISO8601DateFormatter()

        let fields: [String: FirestoreREST.FirestoreValue] = [
            "sessionId": .string(eventLog?.sessionId ?? ""),
            "participantId": .string(eventLog?.participantId ?? ""),
            "condition": .string(condition.rawValue),
            "text": .string(text),
            "locale": .string(localeIdentifier),
            "utteranceIndex": .integer(Int64(index)),
            "endpointReason": .string(reason),
            "startedAt": .string(iso.string(from: startedAt)),
            "committedAt": .string(iso.string(from: Date())),
            "durationMs": .integer(Int64(Date().timeIntervalSince(startedAt) * 1000)),
            "createdAt": .timestamp(iso.string(from: Date())),
        ]

        Task { [weak self] in
            guard let self else { return }
            do { _ = try await self.utterances.createDocument(collection: self.collection, fields: fields) }
            catch { print("❌ [ParticipantSpeechService] utterance log failed: \(error.localizedDescription)") }
        }
    }

    private func sendToAgent(_ text: String, requestId: Int) {
        let fields: [String: FirestoreREST.FirestoreValue] = [
            "text": .string(text),
            "requestId": .integer(Int64(requestId)),
        ]

        Task { [weak self] in
            guard let self else { return }
            do { try await self.trigger.patchDocument(fields: fields, updateMask: Array(fields.keys)) }
            catch { print("❌ [ParticipantSpeechService] agent trigger failed: \(error.localizedDescription)") }
        }
    }

    private func sendInterrupt() {
        let fields: [String: FirestoreREST.FirestoreValue] = ["interrupt": .boolean(true)]
        Task { [weak self] in
            guard let self else { return }
            try? await self.trigger.patchDocument(fields: fields, updateMask: ["interrupt"])
        }
    }

    // MARK: - Echo gate

    /// Polls the state Unity publishes so recognition can pause while the avatar
    /// speaks. Two seconds would be far too slow, hence the short interval.
    private func startGatePolling() {
        gatePollTask?.cancel()
        gatePollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollAgentState()
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }

    private func pollAgentState() async {
        do {
            let (json, _) = try await agentState.getDocument()
            let fields = json["fields"] as? [String: Any] ?? [:]
            let speaking = (fields["speaking"] as? [String: Any])?["booleanValue"] as? Bool ?? false

            if speaking != agentSpeaking {
                agentSpeaking = speaking
                if state.isRunning { state = speaking ? .gated : .listening }
            }
        } catch {
            // Document may not exist until Unity writes it once; not an error.
        }
    }

    // MARK: - Permissions

    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
