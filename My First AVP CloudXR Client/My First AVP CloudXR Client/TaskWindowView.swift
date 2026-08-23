//
//  TaskWindowView.swift
//  My First AVP CloudXR Client
//
//  Dispatcher view for the task WindowGroup. Receives a TaskID
//  and renders the matching move.
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
    @EnvironmentObject private var syncService: PrototypeSyncService
    @EnvironmentObject private var work: SessionWork

    var body: some View {
        // While no clone is present the views still need something to render;
        // the *logged* condition is always the real one from Firestore.
        let agent = conditionService.condition.agentType ?? .managerClone

        Group {
            switch taskID {
            case .brief1A:  TaskBriefView(round: .a, agent: agent)
            case .brief1B:  TaskBriefView(round: .b, agent: agent)
            case .work1A:   TaskWorkView(round: .a, agent: agent)
            case .work1B:   TaskWorkView(round: .b, agent: agent)
            case .review1A: TaskReviewView(round: .a, agent: agent)
            case .review1B: TaskReviewView(round: .b, agent: agent)
            }
        }
        // Window open/close gives the per-move dwell time for free.
        .onAppear {
            eventLog.record("task_opened", task: taskID)
            Task { await syncService.taskDidAppear(taskID) }
        }
        .onDisappear {
            eventLog.record("task_closed", task: taskID)
            Task { await syncService.taskDidDisappear(taskID) }
        }
    }
}
