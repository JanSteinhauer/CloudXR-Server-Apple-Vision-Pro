//
//  ParticipantVoiceService.swift
//  My First AVP CloudXR Client
//
//  Publishes the Vision Pro's microphone into the LiveKit room so the agent
//  hears the participant.
//
//  Why this exists
//  ---------------
//  Until now the only microphone in the pipeline was the Unity server's own
//  (`LiveKitMicrophone` publishes `Microphone.devices[...]`). That worked while
//  the server sat in the same room as the participant — the laptop mic simply
//  picked up the voice. It cannot work once the server is a Google Cloud VM:
//  there is no microphone in the datacentre, and nobody is talking near it.
//
//  Rather than tunnelling audio up through CloudXR and hoping it lands in a
//  virtual input device Unity's `Microphone` API can enumerate, the headset
//  joins the same LiveKit room directly and publishes its own microphone. The
//  agent is already in that room, so it hears the participant with no extra
//  moving parts, and it behaves identically whether the server is a laptop next
//  door or a VM in another country.
//
//  Audio only goes *up*. The agent's voice deliberately stays on the CloudXR
//  path so it arrives already in sync with the avatar's SALSA lip-sync; if the
//  headset also subscribed to the agent's audio track the two would drift apart
//  and you would hear the voice before the mouth moved.
//
//  Requires the LiveKit Swift SDK:
//    Xcode ▸ File ▸ Add Package Dependencies… ▸ https://github.com/livekit/client-sdk-swift
//    (add the `LiveKit` product to the "My First AVP CloudXR Client" target)
//

import SwiftUI
import Combine
import AVFoundation
import LiveKit

@MainActor
final class ParticipantVoiceService: ObservableObject {

    enum State: Equatable {
        case idle
        case requestingPermission
        case fetchingToken
        case connecting
        case publishing
        case failed(String)

        var label: String {
            switch self {
            case .idle: return "Microphone not connected"
            case .requestingPermission: return "Asking for microphone permission…"
            case .fetchingToken: return "Requesting LiveKit token…"
            case .connecting: return "Joining the room…"
            case .publishing: return "Participant microphone live"
            case .failed(let reason): return "Microphone failed: \(reason)"
            }
        }

        var isHealthy: Bool {
            if case .publishing = self { return true }
            return false
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var isMuted = false

    private var room: Room?

    // MARK: - Connecting

    func start() async {
        guard case .publishing = state else {
            await connect()
            return
        }
    }

    private func connect() async {
        let config = EnvironmentConfig.liveKit

        guard !config.room.isEmpty else {
            fail("LIVEKIT_ROOM is not set in .env — it must match `room` in the Unity project's 03_LiveKitSession.asset.")
            return
        }
        guard !config.user.isEmpty, !config.apiKey.isEmpty else {
            fail("LIVEKIT_CONTROL_USER / LIVEKIT_CONTROL_API_KEY are not set in .env.")
            return
        }

        // visionOS will not hand over the microphone without this, and the
        // failure is silent otherwise.
        state = .requestingPermission
        guard await requestMicrophonePermission() else {
            fail("Microphone permission denied. Grant it in Settings ▸ Privacy ▸ Microphone.")
            return
        }

        state = .fetchingToken
        let token: String
        do {
            token = try await fetchToken(config: config)
        } catch {
            fail("Could not get a token: \(error.localizedDescription)")
            return
        }

        state = .connecting
        let room = Room()
        self.room = room

        do {
            // Audio only goes up: publish the mic, do not auto-subscribe to the
            // agent's audio (that arrives via CloudXR, lip-synced).
            try await room.connect(
                url: config.serverURL,
                token: token,
                connectOptions: ConnectOptions(autoSubscribe: false)
            )
            try await room.localParticipant.setMicrophone(enabled: true)

            state = .publishing
            print("🎤 [ParticipantVoiceService] Publishing headset microphone as '\(config.identity)' in room '\(config.room)'.")
        } catch {
            fail(error.localizedDescription)
        }
    }

    func stop() async {
        guard let room else { return }
        await room.disconnect()
        self.room = nil
        state = .idle
        print("🎤 [ParticipantVoiceService] Disconnected.")
    }

    /// Mute without leaving the room — for the between-task stretches where the
    /// participant is filling in questionnaires and should not be transcribed.
    func setMuted(_ muted: Bool) async {
        guard let room else { return }
        do {
            try await room.localParticipant.setMicrophone(enabled: !muted)
            isMuted = muted
        } catch {
            print("❌ [ParticipantVoiceService] Could not \(muted ? "mute" : "unmute"): \(error.localizedDescription)")
        }
    }

    // MARK: - Token

    /// Mirrors `LiveKitControlClient.GetToken` in the Unity package:
    /// GET {controlURL}/token/create with user / apikey / room / participant headers,
    /// responding `{ "status": 200, "message": "<jwt>" }`.
    private func fetchToken(config: (serverURL: String, controlURL: String, user: String,
                                     apiKey: String, room: String, identity: String)) async throws -> String {
        guard let url = URL(string: "\(config.controlURL)/token/create") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.user, forHTTPHeaderField: "user")
        request.setValue(config.apiKey, forHTTPHeaderField: "apikey")
        request.setValue(config.room, forHTTPHeaderField: "room")
        request.setValue(config.identity, forHTTPHeaderField: "participant")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "ParticipantVoiceService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Token endpoint returned \(body)"])
        }

        struct TokenResponse: Decodable {
            let status: Int
            let message: String
        }

        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard decoded.status == 200, !decoded.message.isEmpty else {
            throw NSError(domain: "ParticipantVoiceService", code: decoded.status,
                          userInfo: [NSLocalizedDescriptionKey: "Token response status \(decoded.status)"])
        }
        return decoded.message
    }

    // MARK: - Permission

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func fail(_ reason: String) {
        state = .failed(reason)
        print("❌ [ParticipantVoiceService] \(reason)")
    }
}
