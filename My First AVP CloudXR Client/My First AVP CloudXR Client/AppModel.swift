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
    var agentType: AgentType = .managerClone
}
