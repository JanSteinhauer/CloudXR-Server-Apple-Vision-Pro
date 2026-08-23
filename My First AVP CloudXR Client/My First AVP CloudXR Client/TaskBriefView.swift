//
//  TaskBriefView.swift
//  My First AVP CloudXR Client
//
//  Move 1 — Brief. The agent hands over a batch and the participant accepts it.
//
//  This replaced the old "Information Sharing" screen, which showed a fixed list
//  of work already done and asked for a single confirmation. Nothing on it was
//  a decision, and its list did not match what the participant had actually
//  routed. Here the batch is genuinely unhandled, the participant chooses which
//  of it to take, and that choice is the first thing the round carries forward.
//
//  The item the agent names in the brief starts selected and cannot be dropped.
//  It is the one the review will be about, and a review that has to cope with a
//  participant who never touched its subject is a review that goes back to
//  guessing.
//

import SwiftUI

struct TaskBriefView: View {
    let round: TaskRound
    let agent: AgentType

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var eventLog: SessionEventLog
    @EnvironmentObject private var syncService: PrototypeSyncService
    @EnvironmentObject private var work: SessionWork

    /// Off lets the experimenter pace the session by hand from Firestore instead.
    @AppStorage("autoAdvanceTasks") private var autoAdvanceTasks = true

    @State private var expanded: Set<String> = []
    @State private var committed = false

    private var taskID: TaskID { round == .a ? .brief1A : .brief1B }

    /// Always on screen, so a participant who misses the spoken brief — bad
    /// audio, a dropped stream, or simply not catching it — still knows what to
    /// do instead of freezing.
    private var instruction: String {
        round == .a
            ? "Choose three tickets to take this hour. The dashboard one is already assigned to you."
            : "Choose three summaries to clear before the archive locks. The vendor sync is already assigned to you."
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    constraintPanel
                    batchList
                }
                .padding(24)
            }
            footer
        }
        .background(.regularMaterial)
        .onAppear {
            if work.round != round || work.batch.isEmpty {
                work.beginRound(round)
            }
        }
        .onChange(of: round) { _, newValue in
            work.beginRound(newValue)
            expanded = []
            committed = false
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "person.wave.2")
                .font(.title2)
            VStack(alignment: .leading) {
                Text(round == .a ? "SAP Joule · Ticket Triage" : "SAP Joule · Summary Review")
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

    // MARK: - Constraint

    /// The thing the agent says out loud, kept on screen. It is also what the
    /// review refers back to, so it must not be something the participant can
    /// only have heard once.
    private var constraintPanel: some View {
        HStack(spacing: 14) {
            Image(systemName: round == .a ? "wrench.and.screwdriver" : "checkmark.shield")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(round == .a ? "IT Service Desk — system update in progress" : "Compliance — early audit archival")
                    .font(.headline)
                Text(round == .a
                     ? "Ticket resolution times +24 h today."
                     : "All summaries lock at 16:00 today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(.orange.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.orange.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Batch

    private var batchList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(round == .a ? "Unrouted tickets" : "Summaries pending review",
                      systemImage: round == .a ? "tray.and.arrow.down" : "doc.text")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(work.accepted.count) of \(WorkBatch.takeCount) selected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(work.selectionComplete ? .green : .secondary)
                    .monospacedDigit()
            }

            ForEach(work.batch) { item in
                row(for: item)
            }
        }
    }

    private func row(for item: WorkItem) -> some View {
        let isOn = work.isAccepted(item.id)
        let isOpen = expanded.contains(item.id)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Button {
                    work.toggleAccepted(item)
                } label: {
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .disabled(item.isAssigned || committed)
                .accessibilityLabel(isOn ? "Deselect \(item.id)" : "Select \(item.id)")

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(item.id)
                            .font(.caption.weight(.bold).monospaced())
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(.secondary.opacity(0.18)))
                        Text(item.title).font(.headline)
                        if item.isAssigned {
                            badge(text: "Assigned to you", color: .blue)
                        }
                    }
                    Text(item.meta)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    if isOpen { expanded.remove(item.id) } else { expanded.insert(item.id) }
                } label: {
                    Label(isOpen ? "Close" : "Preview", systemImage: isOpen ? "chevron.up" : "chevron.down")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel(isOpen ? "Collapse \(item.id)" : "Preview \(item.id)")
            }

            if isOpen {
                // Preview only. The detail that decides the right answer stays
                // behind the work window's own "open" action, so choosing a
                // batch here cannot accidentally do the looking for them.
                Text(item.body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.05)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isOn ? Color.accentColor.opacity(0.10) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isOn ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.18),
                        lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 16) {
            Button {
                work.recordConsult()
                eventLog.record("followup_requested", task: taskID)
            } label: {
                Label("Ask before I start", systemImage: "mic.fill")
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Speak to the agent. Whether the participant asks anything at all is itself a measure.")

            Spacer()

            Text(work.selectionComplete
                 ? "Ready."
                 : "Select \(WorkBatch.takeCount - work.accepted.count) more.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                committed = true
                work.commitSelection()
                advance(from: taskID, autoAdvance: autoAdvanceTasks,
                        syncService: syncService, openWindow: openWindow, dismiss: dismiss)
            } label: {
                Label(committed ? "Taken" : "Take these three",
                      systemImage: committed ? "checkmark.circle.fill" : "arrow.right.circle")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!work.selectionComplete || committed)
        }
        .padding(20)
        .background(.thinMaterial)
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
    TaskBriefView(round: .a, agent: .managerClone)
        .environmentObject(SessionEventLog.preview)
        .environmentObject(PrototypeSyncService.preview)
        .environmentObject(SessionWork.preview)
}
