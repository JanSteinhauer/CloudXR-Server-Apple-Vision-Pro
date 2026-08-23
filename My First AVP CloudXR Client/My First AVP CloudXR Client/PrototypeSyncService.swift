//
//  PrototypeSyncService.swift
//  My First AVP CloudXR Client
//
//  Created by CloudXR sync implementation
//

import SwiftUI
import Combine

struct TaskLaunchSignal: Equatable {
    let task: TaskID
    let requestId: String
}

/// Service that polls a specific Firestore document to trigger window openings from Firebase boolean toggles
@MainActor
final class PrototypeSyncService: ObservableObject {
    
    @Published var activeTasks = Set<TaskID>()
    @Published private(set) var launchSignal: TaskLaunchSignal?
    private var lastActiveTasks = Set<TaskID>()
    private var lastLaunchRequestId = ""

    let rest: FirestoreREST
    private var pollTask: Task<Void, Never>?
    private let pollInterval: TimeInterval = 2.0 // Poll every 2 seconds

    init(projectId: String, apiKey: String) {
        self.rest = FirestoreREST(
            projectId: projectId,
            apiKey: apiKey,
            documentPath: "prototype/triggers"
        )
        
        startPolling()
    }

    deinit {
        pollTask?.cancel()
    }

    #if DEBUG
    /// Non-polling instance for Xcode previews.
    static var preview: PrototypeSyncService { PrototypeSyncService(preview: true) }

    private init(preview: Bool) {
        self.rest = FirestoreREST(projectId: "preview", apiKey: "preview",
                                  documentPath: "prototype/triggers")
    }
    #endif
    
    // MARK: - Polling logic
    
    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }

            // Initial fetch
            try? await self.fetchTriggers()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
                try? await self.fetchTriggers()
            }
        }
    }
    
    // Attempt to read the fields of `prototype/triggers`
    func fetchTriggers() async throws {
        let (json, _) = try await rest.getDocument()
        guard let fields = json["fields"] as? [String: Any] else { return }
        
        var newlyActive = Set<TaskID>()
        
        for task in TaskID.allCases {
            // Firestore boolean fields wrap the value inside "booleanValue"
            if let field = fields[task.id] as? [String: Any],
               let isTrue = field["booleanValue"] as? Bool,
               isTrue {
                newlyActive.insert(task)
            }
        }

        // A launch request is edge-triggered independently of the booleans. This
        // makes "Launch again" reliable even when a stale task flag is still true,
        // and it cannot be missed if the initial fetch finishes before ContentView
        // attaches its activeTasks onChange handler.
        let requestId = scalarField(fields, key: "launchRequestId")
        let requestedTask = stringField(fields, key: "requestedTask")
        if !requestId.isEmpty, requestId != lastLaunchRequestId {
            lastLaunchRequestId = requestId
            if let task = TaskID(rawValue: requestedTask) {
                launchSignal = TaskLaunchSignal(task: task, requestId: requestId)
            }
        }
        
        // Publish strictly if changed
        if newlyActive != lastActiveTasks {
            self.activeTasks = newlyActive
            self.lastActiveTasks = newlyActive
        }
    }
    
    // MARK: - Write Operations

    /// Mirrors the real task-window lifecycle into Firestore. Windows opened by a
    /// Firebase trigger are already active, so this is a no-op for that path. A
    /// window opened locally from the master UI gets the same false-to-true event,
    /// allowing Unity to trigger its spoken task introduction consistently.
    func taskDidAppear(_ task: TaskID) async {
        guard !activeTasks.contains(task) else { return }

        activeTasks.insert(task)
        lastActiveTasks = activeTasks

        do {
            let requestId = UUID().uuidString
            try await rest.patchDocument(
                fields: [
                    task.id: .boolean(true),
                    "requestedTask": .string(task.id),
                    "launchRequestId": .string(requestId),
                ],
                updateMask: [task.id, "requestedTask", "launchRequestId"]
            )
        } catch {
            print("❌ [PrototypeSyncService] Failed to publish task appearance for \(task.id): \(error.localizedDescription)")
        }
    }

    private func stringField(_ fields: [String: Any], key: String) -> String {
        (fields[key] as? [String: Any])?["stringValue"] as? String ?? ""
    }

    private func scalarField(_ fields: [String: Any], key: String) -> String {
        guard let value = fields[key] as? [String: Any] else { return "" }
        if let string = value["stringValue"] as? String { return string }
        if let integer = value["integerValue"] as? String { return integer }
        if let integer = value["integerValue"] as? Int { return String(integer) }
        if let double = value["doubleValue"] as? Double { return String(double) }
        return ""
    }

    /// Clears a locally closed window so reopening it creates a fresh transition.
    /// This is idempotent when Firestore or `advance` already cleared the task.
    func taskDidDisappear(_ task: TaskID) async {
        guard activeTasks.contains(task) else { return }

        activeTasks.remove(task)
        lastActiveTasks = activeTasks

        do {
            try await rest.patchDocument(
                fields: [task.id: .boolean(false)],
                updateMask: [task.id]
            )
        } catch {
            print("❌ [PrototypeSyncService] Failed to clear task appearance for \(task.id): \(error.localizedDescription)")
        }
    }

    /// Moves the session on one step: clears the finished task's trigger and sets the
    /// next one.
    ///
    /// The windows are also opened and dismissed directly by the caller, because a
    /// task window may have been opened by a button rather than by a trigger (the
    /// pre-flight does this), in which case clearing a trigger alone would leave the
    /// old window on screen next to the new one. Writing the triggers as well keeps
    /// the experimenter's console showing where the participant actually is.
    func advance(from current: TaskID, to next: TaskID) async {
        let fields: [String: FirestoreREST.FirestoreValue] = [
            current.id: .boolean(false),
            next.id: .boolean(true),
        ]

        // Reflect it locally first; the poll is on a two-second interval and a button
        // press should not wait for it.
        activeTasks.remove(current)
        activeTasks.insert(next)
        lastActiveTasks = activeTasks

        do {
            try await rest.patchDocument(fields: fields, updateMask: Array(fields.keys))
        } catch {
            print("❌ [PrototypeSyncService] Failed to advance \(current.id) -> \(next.id): \(error.localizedDescription)")
        }
    }

    /// Tells the Unity server which of the three critiques the review should use.
    ///
    /// The branch is decided by what the participant did, so only the headset
    /// knows it. It rides on the same document as the triggers and must be
    /// written *before* the review trigger flips — otherwise the agent resolves
    /// its line against a stale value and criticises the wrong thing, which is
    /// the failure this whole rework exists to remove.
    func setReviewBranch(_ branch: String) async {
        do {
            try await rest.patchDocument(
                fields: ["reviewBranch": .string(branch)],
                updateMask: ["reviewBranch"]
            )
        } catch {
            print("❌ [PrototypeSyncService] Failed to publish review branch '\(branch)': \(error.localizedDescription)")
        }
    }

    /// Patches all task IDs in `prototype/triggers` to false
    func resetAllTriggers() async throws {
        var fields: [String: FirestoreREST.FirestoreValue] = [:]
        
        // Prepare to patch all enum cases to false
        for task in TaskID.allCases {
            fields[task.id] = .boolean(false)
        }
        
        let pathMask = Array(fields.keys)
        
        do {
            try await rest.patchDocument(fields: fields, updateMask: pathMask)
            
            // Update local state early
            activeTasks.removeAll()
            lastActiveTasks.removeAll()
        } catch {
            print("❌ [PrototypeSyncService] Failed to reset triggers: \(error.localizedDescription)")
            throw error
        }
    }
}
