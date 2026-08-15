//
//  AppModel.swift
//  AppleVisionProTaskPrototype
//
//  Shared observable state across the master window and any
//  task windows that have been opened. The agent-type picker in
//  the master window writes here; task windows read from here.
//

import SwiftUI

@Observable
final class AppModel {
    /// - Warning: No longer drives what the task windows render. The condition now
    ///   comes from `ExperimentConditionService`, i.e. from the same Firestore
    ///   document the Unity server obeys, so the headset and the server cannot
    ///   disagree. Kept only so existing call sites still compile; setting it has
    ///   no effect on the study. Safe to delete once nothing references it.
    var agentType: AgentType = .managerClone
}
