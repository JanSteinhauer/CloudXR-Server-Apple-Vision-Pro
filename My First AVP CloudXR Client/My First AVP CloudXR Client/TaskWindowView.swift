//
//  TaskWindowView.swift
//  My First AVP CloudXR Client
//
//  Dispatcher view for the task WindowGroup. Receives a TaskID
//  and renders the matching task view.
//
//  The agent shown comes from ExperimentConditionService — i.e. from the same
//  Firestore document the Unity server obeys — not from a picker held locally
//  on the headset, so client and server can no longer disagree about which
//  condition is running.
//

import SwiftUI

struct TaskWindowView: View {
    let taskID: TaskID
    @EnvironmentObject private var conditionService: ExperimentConditionService
    @EnvironmentObject private var eventLog: SessionEventLog

    var body: some View {
        // While no clone is present the views still need something to render;
        // the *logged* condition is always the real one from Firestore.
        let agent = conditionService.condition.agentType ?? .managerClone

        Group {
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
        // Window open/close gives the per-task dwell time for free.
        .onAppear { eventLog.record("task_opened", task: taskID) }
        .onDisappear { eventLog.record("task_closed", task: taskID) }
    }
}
