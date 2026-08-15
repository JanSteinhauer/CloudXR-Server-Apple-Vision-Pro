//
//  SessionEventLog.swift
//  My First AVP CloudXR Client
//
//  Records what the participant actually did, to Firestore `session_events`.
//
//  The task views previously kept every decision in local `@State`, so the
//  advisory follow/decline choice — the behavioural measure Task 3 exists to
//  produce — vanished when the window closed. Each interaction is now one
//  document, stamped with the participant, the session, and the condition that
//  was live at that moment.
//

import SwiftUI
import Combine

@MainActor
final class SessionEventLog: ObservableObject {

    /// Set by the experimenter in the master window before the session starts.
    /// Persisted so a crash or relaunch mid-session does not orphan the events.
    @Published var participantId: String {
        didSet { UserDefaults.standard.set(participantId, forKey: Self.participantKey) }
    }

    /// Number of events written this launch — shown in the console so the
    /// experimenter can see at a glance that logging is alive.
    @Published private(set) var writtenCount = 0
    @Published private(set) var lastError: String?

    /// One id per app launch, so events can be grouped even if the participant
    /// id was typed in late.
    let sessionId = UUID().uuidString

    /// Stamped onto every event. Wired to the condition service at startup.
    weak var conditionService: ExperimentConditionService?

    private static let participantKey = "SessionEventLog.participantId"
    private let collection = "session_events"
    private let rest: FirestoreREST
    private var index = 0

    init(projectId: String, apiKey: String) {
        self.participantId = UserDefaults.standard.string(forKey: Self.participantKey) ?? ""
        self.rest = FirestoreREST(
            projectId: projectId,
            apiKey: apiKey,
            documentPath: collection
        )
    }

    #if DEBUG
    /// For Xcode previews. Writes go to a project that does not exist and fail quietly.
    static var preview: SessionEventLog {
        SessionEventLog(projectId: "preview", apiKey: "preview")
    }
    #endif

    // MARK: - Recording

    /// Fire-and-forget. Never blocks the UI and never throws into a view —
    /// a lost event must not interrupt a running session, so failures are
    /// surfaced in `lastError` and the console instead.
    func record(_ action: String,
                task: TaskID? = nil,
                value: String? = nil,
                detail: [String: String] = [:]) {

        let condition = conditionService?.condition ?? .none
        let position = index
        index += 1

        var fields: [String: FirestoreREST.FirestoreValue] = [
            "sessionId": .string(sessionId),
            "participantId": .string(participantId),
            "condition": .string(condition.rawValue),
            "action": .string(action),
            "index": .integer(Int64(position)),
            "clientTimeUtc": .string(ISO8601DateFormatter().string(from: Date())),
            "createdAt": .timestamp(ISO8601DateFormatter().string(from: Date())),
        ]

        if let task {
            fields["task"] = .string(task.rawValue)
            fields["taskLabel"] = .string(task.shortLabel)
            fields["round"] = .string(task.roundLabel)
        }

        if let value {
            fields["value"] = .string(value)
        }

        if !detail.isEmpty {
            fields["detail"] = .map(detail.mapValues { .string($0) })
        }

        if participantId.isEmpty {
            print("⚠️ [SessionEventLog] '\(action)' recorded with no participant id set.")
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.rest.createDocument(collection: self.collection, fields: fields)
                self.writtenCount += 1
                self.lastError = nil
                print("📝 [SessionEventLog] \(condition.rawValue) · \(action)\(value.map { " = \($0)" } ?? "")")
            } catch {
                self.lastError = error.localizedDescription
                print("❌ [SessionEventLog] Failed to write '\(action)': \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Round label

extension TaskID {
    /// "A" / "B" — the parallel task version, for the counterbalance.
    var roundLabel: String {
        switch self {
        case .preflight1A, .task1A, .task2A, .task3A: return "A"
        case .preflight1B, .task1B, .task2B, .task3B: return "B"
        }
    }
}
