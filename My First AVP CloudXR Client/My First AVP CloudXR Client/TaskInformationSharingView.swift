//
//  TaskInformationSharingView.swift
//  AppleVisionProTaskPrototype
//
//  Task 1A / 1B — Information Sharing (Low stakes).
//  Regions: Header · Context card · Status panel · Confirmation footer.
//  (Live-caption transcript pane intentionally omitted.)
//

import SwiftUI

struct TaskInformationSharingView: View {
    let round: TaskRound
    let agent: AgentType

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var eventLog: SessionEventLog
    @EnvironmentObject private var syncService: PrototypeSyncService

    /// Off lets the experimenter pace the session by hand from Firestore instead.
    @AppStorage("autoAdvanceTasks") private var autoAdvanceTasks = true

    @State private var highlightedContextIndex: Int? = nil
    @State private var statusPanelVisible: Bool = false
    @State private var confirmed: Bool = false

    private var taskID: TaskID { round == .a ? .task1A : .task1B }

    /// Always on screen, so a participant who misses the spoken brief — bad
    /// audio, a dropped stream, or simply not catching it — still knows what to
    /// do instead of freezing.
    private let instruction = "Listen to the update, then confirm below when you have it."

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    contextCard
                    statusPanel
                }
                .padding(24)
            }
            footer
        }
        .background(.regularMaterial)
        .onAppear { animateHighlights() }
        .onChange(of: round) { _, _ in
            confirmed = false
            statusPanelVisible = false
            highlightedContextIndex = nil
            animateHighlights()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
                .font(.title2)
            VStack(alignment: .leading) {
                Text(headerTitle)
                    .font(.title2.weight(.semibold))
                Text(instruction)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            badge(text: round.badge, color: .blue)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.thinMaterial)
    }

    private var headerTitle: String {
        switch round {
        case .a: return "SAP Joule · Ticket Update"
        case .b: return "SAP Joule · Meeting Summary Update"
        }
    }

    // MARK: - Context card

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle(round == .a ? "Routed tickets" : "Processed summaries",
                             systemImage: round == .a ? "tray.and.arrow.up" : "doc.text")
                Spacer()
                Button {
                    openWindow(id: "task", value: round == .a ? TaskID.preflight1A : TaskID.preflight1B)
                } label: {
                    Label("Preflight Task", systemImage: "laptopcomputer")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ForEach(Array(contextItems.enumerated()), id: \.offset) { index, item in
                contextRow(item: item, highlighted: highlightedContextIndex == index)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18).fill(.background.secondary))
    }

    private func contextRow(item: ContextItem, highlighted: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.icon)
                .frame(width: 32, height: 32)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline)
                Text(item.detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.outcome)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(.tint.opacity(0.18)))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(highlighted ? Color.blue.opacity(0.18) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(highlighted ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.4), value: highlighted)
    }

    // MARK: - Status panel

    private var statusPanel: some View {
        HStack(spacing: 14) {
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle).font(.headline)
                Text(statusBody).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.orange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.orange.opacity(0.4), lineWidth: 1)
        )
        .opacity(statusPanelVisible ? 1 : 0)
        .offset(y: statusPanelVisible ? 0 : 12)
        .animation(.easeOut(duration: 0.5), value: statusPanelVisible)
    }

    private var statusIcon: String { round == .a ? "wrench.and.screwdriver" : "checkmark.shield" }
    private var statusTitle: String {
        round == .a ? "IT Service Desk — system update in progress" : "Compliance — early audit archival"
    }
    private var statusBody: String {
        round == .a
            ? "Ticket resolution times +24 h today."
            : "All summaries lock at 16:00 today."
    }



    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 16) {
            Button {
                confirmed = true
                eventLog.record("information_confirmed", task: taskID)
                advance(from: taskID, autoAdvance: autoAdvanceTasks,
                        syncService: syncService, openWindow: openWindow, dismiss: dismiss)
            } label: {
                Label(confirmed ? "Confirmed" : "Confirm — I've got it on my radar",
                      systemImage: confirmed ? "checkmark.circle.fill" : "checkmark.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(confirmed)

            Button {
                // open mic affordance (stub)
                // Logged even though the affordance is a stub: whether participants
                // reach for a follow-up at all differs by condition and is worth having.
                eventLog.record("followup_requested", task: taskID)
            } label: {
                Label("Ask follow-up question", systemImage: "mic.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(20)
        .background(.thinMaterial)
    }

    // MARK: - Animation

    private func animateHighlights() {
        Task {
            for index in contextItems.indices {
                try? await Task.sleep(nanoseconds: 700_000_000)
                await MainActor.run { highlightedContextIndex = index }
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                highlightedContextIndex = nil
                statusPanelVisible = true
            }
        }
    }

    // MARK: - Items

    private struct ContextItem {
        let title: String
        let detail: String
        let outcome: String
        let icon: String
    }

    private var contextItems: [ContextItem] {
        switch round {
        case .a:
            return [
                .init(title: "Dashboard speed ticket",
                      detail: "User reports slow load on Joule dashboard.",
                      outcome: "Routed to IT", icon: "speedometer"),
                .init(title: "HR access ticket",
                      detail: "New hire missing Workzone permissions.",
                      outcome: "Routed to HR", icon: "person.badge.key"),
                .init(title: "Joule plug-in bug",
                      detail: "Plug-in returns 500 on summarisation call.",
                      outcome: "Routed to Dev", icon: "ladybug")
            ]
        case .b:
            return [
                .init(title: "Vendor sync — Acme Corp",
                      detail: "Weekly check-in with external partner.",
                      outcome: "Approved", icon: "person.2"),
                .init(title: "Q2 roadmap review",
                      detail: "Internal planning sync, 8 attendees.",
                      outcome: "Edited", icon: "map"),
                .init(title: "Sprint retrospective",
                      detail: "Team retro covering blockers and wins.",
                      outcome: "Rejected", icon: "arrow.uturn.backward")
            ]
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.secondary)
    }

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
    TaskInformationSharingView(round: .a, agent: .managerClone)
        .environmentObject(SessionEventLog.preview)
        .environmentObject(PrototypeSyncService.preview)
}
