//
//  TaskMasterView.swift
//  AppleVisionProTaskPrototype
//
//  Master window: agent-type picker on top, task list below.
//  Tapping a task opens a new task window via openWindow(value:).
//

import SwiftUI

struct TaskMasterView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var conditionService: ExperimentConditionService
    @EnvironmentObject private var eventLog: SessionEventLog
    @EnvironmentObject private var work: SessionWork

    /// On, each task advances itself when the participant completes it. Off, the
    /// experimenter paces the session by flipping triggers in Firestore.
    @AppStorage("autoAdvanceTasks") private var autoAdvanceTasks = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            participantSection
                .padding(.horizontal, 20)
                .padding(.top, 16)

            conditionSection
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            roundSection
                .padding(.horizontal, 20)
                .padding(.top, 16)

            Divider().padding(.vertical, 8)

            tasksHeader
                .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 10) {
                    taskGroup(title: "Round A · Joule Tickets",
                              tasks: [.brief1A, .work1A, .review1A])
                    taskGroup(title: "Round B · Meeting Summaries",
                              tasks: [.brief1B, .work1B, .review1B])
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .frame(minWidth: 420)
        .background(.regularMaterial)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "visionpro")
                .font(.title)
            VStack(alignment: .leading, spacing: 2) {
                Text("Task Prototype").font(.title2.weight(.semibold))
                Text("Master Window").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.thinMaterial)
    }

    // MARK: - Participant

    private var participantSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Participant", systemImage: "person.text.rectangle")
                .font(.headline)

            HStack(spacing: 12) {
                TextField("Participant ID (e.g. P07)", text: Binding(
                    get: { eventLog.participantId },
                    set: { eventLog.participantId = $0 }
                ))
                .textFieldStyle(.roundedBorder)

                Label("\(eventLog.writtenCount)", systemImage: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundStyle(eventLog.lastError == nil ? .secondary : .red)
                    .help("Events written this session")
            }

            if eventLog.participantId.isEmpty {
                Text("Set this before the session starts — events are logged without it otherwise.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Toggle("Tasks advance themselves", isOn: $autoAdvanceTasks)
                .font(.caption)

            if let error = eventLog.lastError {
                Text("Last write failed: \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Condition section

    // Drives `experiment_control/condition` in Firestore, which the Unity server
    // also obeys — so setting it here switches the avatar on the headset too, and
    // there is no second local copy that can drift out of step.
    private var conditionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Condition (counterbalanced)", systemImage: "person.crop.square.badge.camera")
                    .font(.headline)
                Spacer()
                if !conditionService.hasSynced {
                    ProgressView().controlSize(.small)
                }
            }

            Picker("Condition", selection: Binding(
                get: { conditionService.condition },
                set: { newValue in
                    Task {
                        await conditionService.setCondition(newValue)
                        eventLog.record("condition_set", value: newValue.rawValue)
                    }
                }
            )) {
                ForEach(ExperimentCondition.allCases) { condition in
                    Text(condition.operatorLabel).tag(condition)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(conditionService.hasSynced
                 ? "Synced with the Unity server via Firestore."
                 : "Waiting for the first read of experiment_control/condition…")
                .font(.caption)
                .foregroundStyle(.secondary)

            if conditionService.conflictDetected {
                Text("Both flags are true in Firestore — treated as no clone.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Round in progress

    /// What the participant has done so far, and which critique the review will
    /// deliver as a result. Worth having in front of the experimenter: the review
    /// branch is chosen by behaviour, so it cannot be known in advance, and it is
    /// the thing to note down if the spoken line has to be corrected by hand.
    private var roundSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Round in progress", systemImage: "figure.walk.motion")
                .font(.headline)

            if work.accepted.isEmpty {
                Text("Nothing taken yet. Open a brief to start a round.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 10) {
                    pill(work.round.badge, tint: .blue)
                    pill("\(work.handling.count)/\(work.accepted.count) handled", tint: .secondary)
                    pill("\(work.opened.intersection(Set(work.accepted)).count) opened", tint: .secondary)
                    if work.consultCount > 0 { pill("\(work.consultCount) asked", tint: .secondary) }
                    Spacer()
                }

                HStack(spacing: 8) {
                    Text("Review will land on")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    pill(branchLabel, tint: branchTint)
                }
            }
        }
    }

    private var branchLabel: String {
        switch work.branch {
        case .shortcut: return "the shortcut"
        case .missed:   return "the missed detail"
        case .thorough: return "pace"
        }
    }

    private var branchTint: Color {
        switch work.branch {
        case .shortcut: return .red
        case .missed:   return .orange
        case .thorough: return .green
        }
    }

    private func pill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.14)))
    }

    // MARK: - Tasks list

    private var tasksHeader: some View {
        HStack {
            Label("Tasks", systemImage: "rectangle.stack")
                .font(.headline)
            Spacer()
            Text("Tap to open in a new window")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func taskGroup(title: String, tasks: [TaskID]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            ForEach(tasks) { task in
                taskRow(task)
            }
        }
    }

    private func taskRow(_ task: TaskID) -> some View {
        Button {
            openWindow(id: "task", value: task)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: task.systemImage)
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.tint.opacity(0.18)))
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.headline)
                    Text(task.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(.background.secondary))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview(windowStyle: .automatic) {
    TaskMasterView()
        .environment(AppModel())
        .environmentObject(ExperimentConditionService.preview())
        .environmentObject(SessionEventLog.preview)
        .environmentObject(SessionWork.preview)
}
