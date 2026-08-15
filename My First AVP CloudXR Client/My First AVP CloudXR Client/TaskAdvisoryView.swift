//
//  TaskAdvisoryView.swift
//  AppleVisionProTaskPrototype
//
//  Task 3A / 3B — Advisory / Problem Solving (Mixed stakes, contains error).
//  Regions: Header · Queue panel + Action toolbar | Script panel · Decision footer.
//  (Live-caption transcript pane intentionally omitted.)
//

import SwiftUI

struct TaskAdvisoryView: View {
    let round: TaskRound
    let agent: AgentType

    @EnvironmentObject private var eventLog: SessionEventLog

    @State private var items: [QueueItem]
    @State private var decision: Decision? = nil
    @State private var declineReason: String = ""
    @State private var loggedReason: String = ""

    /// This view is opened as either task3A or task3B; the round tells us which.
    private var taskID: TaskID { round == .a ? .task3A : .task3B }

    init(round: TaskRound, agent: AgentType) {
        self.round = round
        self.agent = agent
        _items = State(initialValue: Self.makeItems(for: round))
    }

    enum Decision { case followed, declined }

    var body: some View {
        VStack(spacing: 0) {
            header
            queueColumn
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(24)
            footer
        }
        .background(.regularMaterial)
        .onChange(of: round) { _, newValue in
            flushDeclineReason()
            items = Self.makeItems(for: newValue)
            decision = nil
            declineReason = ""
            loggedReason = ""
        }
        // The reason is free text with no submit affordance, so it is captured
        // when the window goes away rather than on a keystroke.
        .onDisappear { flushDeclineReason() }
    }

    private func flushDeclineReason() {
        let trimmed = declineReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != loggedReason else { return }
        loggedReason = trimmed
        eventLog.record("advisory_decline_reason", task: taskID, value: trimmed)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: round == .a ? "list.bullet.rectangle" : "doc.on.doc")
                .font(.title2)
            VStack(alignment: .leading) {
                Text(headerTitle).font(.title2.weight(.semibold))
                Text(agent.rawValue).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            badge(text: round.badge, color: .blue)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.thinMaterial)
    }

    private var headerTitle: String {
        round == .a
            ? "SAP Joule · Ticket Queue — Loading-Speed Backlog"
            : "SAP Joule · Summary Approval Queue — Pre-Audit"
    }

    // MARK: - Queue column

    private var queueColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            actionToolbar

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button {
                        let allSelected = items.allSatisfy(\.selected)
                        for i in items.indices { items[i].selected = !allSelected }
                    } label: {
                        Label(items.allSatisfy(\.selected) ? "Deselect all" : "Select all",
                              systemImage: "checkmark.square")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
                    Text("\(items.filter(\.selected).count) of \(items.count) selected")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(12)

                Divider()

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach($items) { $item in
                            queueRow(item: $item)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 360)
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(.background.secondary))
        }
    }

    private var actionToolbar: some View {
        HStack(spacing: 10) {
            actionButton(title: dangerTitle, systemImage: "trash", tint: .red, isPrimary: true)
            actionButton(title: safeTitle, systemImage: "checklist", tint: .blue, isPrimary: false)
            actionButton(title: escalateTitle, systemImage: "person.badge.shield.checkmark",
                         tint: .gray, isPrimary: false)
        }
    }

    private func actionButton(title: String, systemImage: String, tint: Color, isPrimary: Bool) -> some View {
        Button {
            // toolbar buttons are illustrative only; binding decision happens in footer
        } label: {
            Label(title, systemImage: systemImage)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .controlSize(.regular)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isPrimary ? tint.opacity(0.6) : .clear,
                        style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                .opacity(isPrimary ? 0.8 : 0)
        )
    }

    private func queueRow(item: Binding<QueueItem>) -> some View {
        HStack(spacing: 12) {
            Toggle(isOn: item.selected) { EmptyView() }
                .labelsHidden()
            Image(systemName: item.wrappedValue.icon)
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.wrappedValue.title).font(.subheadline.weight(.medium))
                Text(item.wrappedValue.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.wrappedValue.meta).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }



    // MARK: - Footer (decision)

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button {
                    decision = .followed
                    // The compliance measure for Task 3.
                    eventLog.record("advisory_decision", task: taskID, value: "followed",
                                    detail: ["selectedItems": String(items.filter(\.selected).count),
                                             "totalItems": String(items.count),
                                             "action": dangerTitle])
                } label: {
                    Label("Follow the recommendation", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .disabled(decision != nil)

                Button {
                    decision = .declined
                    eventLog.record("advisory_decision", task: taskID, value: "declined",
                                    detail: ["selectedItems": String(items.filter(\.selected).count),
                                             "totalItems": String(items.count),
                                             "action": dangerTitle])
                } label: {
                    Label("Decline / Choose differently", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(decision != nil)
            }

            if let decision {
                decisionFeedback(decision)
            }
        }
        .padding(20)
        .background(.thinMaterial)
    }

    @ViewBuilder
    private func decisionFeedback(_ decision: Decision) -> some View {
        switch decision {
        case .followed:
            HStack {
                Image(systemName: "exclamationmark.octagon.fill").foregroundStyle(.red)
                Text("Compliance event logged: \(dangerTitle.lowercased()) executed.")
                    .font(.subheadline)
                Spacer()
            }
        case .declined:
            VStack(alignment: .leading, spacing: 6) {
                Label("Why are you declining?", systemImage: "mic.fill")
                    .font(.subheadline).foregroundStyle(.secondary)
                TextField("Speak or type your reason…", text: $declineReason, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
        }
    }

    // MARK: - Action titles

    private var dangerTitle: String {
        round == .a ? "Bulk-Delete Selected" : "Auto-Approve Selected"
    }
    private var safeTitle: String {
        round == .a ? "Route Individually" : "Review Each"
    }
    private var escalateTitle: String {
        round == .a ? "Escalate to IT Lead" : "Defer to Manager Review"
    }

    // MARK: - Items

    struct QueueItem: Identifiable {
        let id = UUID()
        var title: String
        var detail: String
        var meta: String
        var icon: String
        var selected: Bool = false
    }

    static func makeItems(for round: TaskRound) -> [QueueItem] {
        switch round {
        case .a:
            return (1...12).map { i in
                QueueItem(
                    title: "Loading-speed ticket #\(4400 + i)",
                    detail: "User reports slow Joule dashboard render.",
                    meta: "Opened \(i)h ago",
                    icon: "speedometer"
                )
            }
        case .b:
            let titles = [
                "Vendor sync — Globex", "Sprint planning", "Design crit",
                "Finance close walkthrough", "Customer success QBR", "Security review",
                "Hiring debrief", "Roadmap alignment", "Partner onboarding",
                "Marketing standup"
            ]
            return titles.enumerated().map { idx, title in
                QueueItem(
                    title: title,
                    detail: "Meeting summary generated by Joule, pending approval.",
                    meta: "\(20 + idx) min read",
                    icon: "doc.text"
                )
            }
        }
    }

    // MARK: - Helpers

    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.2)))
            .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
            .foregroundStyle(color)
    }
}

#Preview(windowStyle: .automatic) {
    TaskAdvisoryView(round: .a, agent: .managerClone)
        .environmentObject(SessionEventLog.preview)
}
