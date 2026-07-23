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
