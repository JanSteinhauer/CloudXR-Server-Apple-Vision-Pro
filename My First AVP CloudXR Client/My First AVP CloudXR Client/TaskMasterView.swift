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

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 0) {
            header

            agentSection(agentType: $model.agentType)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider().padding(.vertical, 8)

            tasksHeader
                .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 10) {
                    taskGroup(title: "Round A · Joule Tickets",
                              tasks: [.preflight1A, .task1A, .task2A, .task3A])
                    taskGroup(title: "Round B · Meeting Summaries",
                              tasks: [.preflight1B, .task1B, .task2B, .task3B])
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

    // MARK: - Agent section

    private func agentSection(agentType: Binding<AgentType>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Agent (counterbalanced)", systemImage: "person.crop.square.badge.camera")
                .font(.headline)

            Picker("Agent type", selection: agentType) {
                ForEach(AgentType.allCases) { agent in
                    Text(agent.rawValue).tag(agent)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(agentType.wrappedValue.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
                    Text("Task \(task.shortLabel) · \(task.title)")
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
}
