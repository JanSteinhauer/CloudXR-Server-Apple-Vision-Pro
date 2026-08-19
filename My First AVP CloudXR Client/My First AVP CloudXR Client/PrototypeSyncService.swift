//
//  PrototypeSyncService.swift
//  My First AVP CloudXR Client
//
//  Created by CloudXR sync implementation
//

import SwiftUI
import Combine

/// Service that polls a specific Firestore document to trigger window openings from Firebase boolean toggles
@MainActor
final class PrototypeSyncService: ObservableObject {
    
    @Published var activeTasks = Set<TaskID>()
    private var lastActiveTasks = Set<TaskID>()

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
            try await rest.patchDocument(
                fields: [task.id: .boolean(true)],
                updateMask: [task.id]
            )
        } catch {
            print("❌ [PrototypeSyncService] Failed to publish task appearance for \(task.id): \(error.localizedDescription)")
        }
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
