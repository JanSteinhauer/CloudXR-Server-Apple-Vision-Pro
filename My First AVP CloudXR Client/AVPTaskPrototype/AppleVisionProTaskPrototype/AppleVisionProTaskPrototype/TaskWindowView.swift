//
//  TaskWindowView.swift
//  AppleVisionProTaskPrototype
//
//  Dispatcher view for the task WindowGroup. Receives a TaskID
//  and renders the matching task view, pulling agentType from
//  the shared AppModel so it stays in sync with the master window.
//

import SwiftUI

struct TaskWindowView: View {
    let taskID: TaskID
    @Environment(AppModel.self) private var model

    var body: some View {
        let agent = model.agentType
        switch taskID {
        case .preflight1A:
            PreflightTaskView(round: .a)
        case .preflight1B:
            PreflightTaskView(round: .b)
        case .task1A:
            TaskInformationSharingView(round: .a, agent: agent)
        case .task1B:
            TaskInformationSharingView(round: .b, agent: agent)
        case .task2A:
            TaskPerformanceFeedbackView(round: .a, agent: agent)
        case .task2B:
            TaskPerformanceFeedbackView(round: .b, agent: agent)
        case .task3A:
            TaskAdvisoryView(round: .a, agent: agent)
        case .task3B:
            TaskAdvisoryView(round: .b, agent: agent)
        }
    }
}

#Preview(windowStyle: .automatic) {
    TaskWindowView(taskID: .task1A)
        .environment(AppModel())
}
