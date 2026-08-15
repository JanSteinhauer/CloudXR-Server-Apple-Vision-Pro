//
//  ExperimentConditionService.swift
//  My First AVP CloudXR Client
//
//  Keeps the client's idea of the experimental condition in sync with the Unity
//  server, by polling the same Firestore document the server watches.
//
//  Before this existed the client had its own local `AppModel.agentType`, set by
//  hand in the master window, while Unity decided the condition from Firestore.
//  Nothing tied the two together, so the headset could show the manager clone
//  while every logged event claimed "generic" — and nothing recorded the
//  mismatch. Firestore is now the single source of truth for both halves.
//

import SwiftUI
import Combine

/// Which clone the participant is facing. Mirrors `MasterThesis.ExperimentCondition`
/// in the Unity project — keep the two in step.
enum ExperimentCondition: String, CaseIterable, Identifiable {
    case none
    case manager
    case generic

    var id: String { rawValue }

    /// The agent type the task views render for this condition.
    /// `nil` while no clone is present.
    var agentType: AgentType? {
        switch self {
        case .none: return nil
        case .manager: return .managerClone
        case .generic: return .genericAgent
        }
    }

    /// Label for the experimenter console. Never shown to the participant.
    var operatorLabel: String {
        switch self {
        case .none: return "No clone"
        case .manager: return "Manager clone"
        case .generic: return "Generic clone"
        }
    }
}

/// Polls `experiment_control/condition` — the document the Unity
/// `ExperimentConditionController` both resets on startup and obeys — and can
/// write it, so the condition can be driven from either side.
@MainActor
final class ExperimentConditionService: ObservableObject {

    @Published private(set) var condition: ExperimentCondition = .none

    /// True once at least one poll has come back, so the UI can tell
    /// "no clone" apart from "haven't heard from Firestore yet".
    @Published private(set) var hasSynced = false

    /// Set when the document contains an impossible state (both flags true).
    @Published private(set) var conflictDetected = false

    let rest: FirestoreREST
    private var pollTask: Task<Void, Never>?
    private let pollInterval: TimeInterval = 2.0

    // Field names must match ExperimentConditionController in the Unity project.
    private let managerField = "managerActive"
    private let genericField = "genericActive"

    init(projectId: String, apiKey: String) {
        self.rest = FirestoreREST(
            projectId: projectId,
            apiKey: apiKey,
            documentPath: "experiment_control/condition"
        )

        startPolling()
    }

    deinit {
        pollTask?.cancel()
    }

    #if DEBUG
    /// Non-polling instance for Xcode previews.
    static func preview(_ condition: ExperimentCondition = .manager) -> ExperimentConditionService {
        ExperimentConditionService(previewCondition: condition)
    }

    private init(previewCondition: ExperimentCondition) {
        self.rest = FirestoreREST(projectId: "preview", apiKey: "preview",
                                  documentPath: "experiment_control/condition")
        self.condition = previewCondition
        self.hasSynced = true
    }
    #endif

    // MARK: - Polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }

            try? await self.fetchCondition()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
                try? await self.fetchCondition()
            }
        }
    }

    func fetchCondition() async throws {
        let (json, _) = try await rest.getDocument()
        let fields = json["fields"] as? [String: Any] ?? [:]

        let manager = boolField(fields, managerField)
        let generic = boolField(fields, genericField)

        // Same rule the Unity controller applies: both true is invalid and is
        // treated as "nobody", so the two conditions can never overlap.
        let resolved: ExperimentCondition
        if manager && generic {
            resolved = .none
            if !conflictDetected {
                print("⚠️ [ExperimentConditionService] Both \(managerField) and \(genericField) are true. Treating as no clone.")
            }
            conflictDetected = true
        } else {
            conflictDetected = false
            resolved = manager ? .manager : (generic ? .generic : .none)
        }

        hasSynced = true

        if resolved != condition {
            print("🎭 [ExperimentConditionService] Condition: \(condition.rawValue) → \(resolved.rawValue)")
            condition = resolved
        }
    }

    private func boolField(_ fields: [String: Any], _ key: String) -> Bool {
        guard let field = fields[key] as? [String: Any],
              let value = field["booleanValue"] as? Bool else { return false }
        return value
    }

    // MARK: - Writing

    /// Drives the condition from the headset. Unity picks the change up through
    /// its own listener, so the two stay in agreement whichever side sets it.
    func setCondition(_ newValue: ExperimentCondition) async {
        let fields: [String: FirestoreREST.FirestoreValue] = [
            managerField: .boolean(newValue == .manager),
            genericField: .boolean(newValue == .generic),
        ]

        do {
            try await rest.patchDocument(fields: fields, updateMask: Array(fields.keys))
            // Optimistic local update; the next poll confirms it.
            condition = newValue
            conflictDetected = false
        } catch {
            print("❌ [ExperimentConditionService] Failed to set condition: \(error.localizedDescription)")
        }
    }
}
