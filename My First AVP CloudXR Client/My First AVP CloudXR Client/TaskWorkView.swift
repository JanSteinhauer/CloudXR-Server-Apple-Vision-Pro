//
//  TaskWorkView.swift
//  My First AVP CloudXR Client
//
//  Move 2 — Work. The participant handles the three items they took.
//
//  This is the move the old sequence did not have. Compliance with the agent's
//  advice used to be a button labelled "Follow the recommendation" on a queue of
//  twelve synthetic rows the participant had never seen. Here the shortcut is an
//  ordinary action in an ordinary action row — closing a ticket without routing
//  it, approving a summary without opening it — so taking it is something the
//  participant does rather than something they declare.
//
//  Nothing on this screen is labelled as correct, risky, or recommended. The
//  measure is what they do when nothing is labelled.
//
//  The agent stays in the room and can be consulted. That is deliberate: it
//  keeps the advisory register alive for H8, and whether someone consults a
//  clone more readily than a generic agent is the prediction under test.
//

import SwiftUI

struct TaskWorkView: View {
    let round: TaskRound
    let agent: AgentType

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var eventLog: SessionEventLog
    @EnvironmentObject private var syncService: PrototypeSyncService
    @EnvironmentObject private var work: SessionWork

    @AppStorage("autoAdvanceTasks") private var autoAdvanceTasks = true

    @State private var submitted = false

    private var taskID: TaskID { round == .a ? .work1A : .work1B }

    private var instruction: String {
        round == .a
            ? "Handle the three you took. Open anything you want a closer look at."
            : "Handle the three you took. Open anything you want to read in full."
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(work.acceptedItems) { item in
                        card(for: item)
                    }
                }
                .padding(24)
            }
            footer
        }
        .background(.regularMaterial)
        .onAppear { work.startWork() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "tray.full")
                .font(.title2)
            VStack(alignment: .leading) {
                Text(round == .a ? "SAP Joule · Your queue" : "SAP Joule · Your review list")
                    .font(.title2.weight(.semibold))
                Text(instruction)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(round.constraint)
                .font(.caption)
                .foregroundStyle(.orange)
                .frame(maxWidth: 260, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.thinMaterial)
    }

    // MARK: - Item card

    private func card(for item: WorkItem) -> some View {
        let isOpen = work.opened.contains(item.id)
        let decided = work.handling[item.id]

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Text(item.id)
                    .font(.caption.weight(.bold).monospaced())
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(.secondary.opacity(0.18)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.headline)
                    Text(item.meta).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                statusChip(for: item, decided: decided)
            }

            Text(item.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.caption).foregroundStyle(.purple)
                Text("Joule suggests · \(item.suggestion)").font(.caption)
            }

            Button {
                work.markOpened(item)
            } label: {
                Label(isOpen ? (round == .a ? "Full ticket and user profile" : "Full summary and coverage check")
                             : (round == .a ? "Open full ticket" : "Read full summary"),
                      systemImage: isOpen ? "doc.text.magnifyingglass" : "doc.text")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isOpen)

            if isOpen {
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.body)
                        .font(.callout)

                    if let detail = item.buriedDetail {
                        // Not highlighted, not coloured, not first. It reads like
                        // the rest of the record — which is the point.
                        Divider()
                        Text(detail)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.05)))
            }

            Divider()

            actionRow(for: item, decided: decided)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(decided == nil ? Color.clear : Color.accentColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(decided == nil ? Color.secondary.opacity(0.18) : Color.accentColor.opacity(0.35),
                        lineWidth: 1)
        )
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionRow(for item: WorkItem, decided: Handling?) -> some View {
        if round == .a {
            HStack(spacing: 10) {
                Text("Route to")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Queue", selection: queueBinding(for: item)) {
                    Text("— select queue —").tag("")
                    ForEach(WorkBatch.queues, id: \.self) { queue in
                        Text(queue).tag(queue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(submitted)

                Spacer()

                // The shortcut. Worded the way the agent worded it, sitting in the
                // same row as everything else, with no warning attached to it.
                Button {
                    work.apply(.cleared, to: item)
                } label: {
                    Text("Close — ask user to refresh")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(submitted)
            }
        } else {
            HStack(spacing: 10) {
                ForEach([Handling.approved, .edited, .rejected], id: \.self) { decision in
                    Button {
                        work.apply(decision, to: item)
                    } label: {
                        Text(decision.rawValue.capitalized)
                            .frame(minWidth: 78)
                    }
                    .buttonStyle(.bordered)
                    .tint(decided == decision ? Color.accentColor : Color.secondary)
                    .controlSize(.small)
                    .disabled(submitted)
                }
                Spacer()
            }
        }
    }

    private func queueBinding(for item: WorkItem) -> Binding<String> {
        Binding(
            get: { work.queue[item.id] ?? "" },
            set: { newValue in
                guard !newValue.isEmpty else { return }
                work.apply(.routed, to: item, queue: newValue)
            }
        )
    }

    private func statusChip(for item: WorkItem, decided: Handling?) -> some View {
        let text: String
        let tint: Color

        switch decided {
        case .none:
            text = round == .a ? "Open" : "Pending"
            tint = .orange
        case .some(.routed):
            text = "Routed · \(work.queue[item.id] ?? "")"
            tint = .green
        case .some(.cleared):
            text = "Closed"
            tint = .secondary
        case .some(let other):
            text = other.rawValue.capitalized
            tint = other == .approved ? .green : (other == .rejected ? .red : .blue)
        }

        return Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(tint.opacity(0.14)))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 16) {
            Button {
                work.recordConsult()
                eventLog.record("followup_requested", task: taskID)
            } label: {
                Label("Ask the agent", systemImage: "mic.fill")
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Spacer()

            Text("\(work.handling.count) of \(work.accepted.count) handled")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Button {
                submitted = true
                work.finishWork()

                // The agent has to know what happened before it can talk about
                // it, so the round is published and the branch is written to the
                // trigger document *before* the review window opens.
                Task {
                    await work.publish()
                    await syncService.setReviewBranch(work.branch.firestoreSuffix)
                    advance(from: taskID, autoAdvance: autoAdvanceTasks,
                            syncService: syncService, openWindow: openWindow, dismiss: dismiss)
                }
            } label: {
                Label(submitted ? "Submitted" : (round == .a ? "Submit queue" : "Submit reviews"),
                      systemImage: submitted ? "checkmark.circle.fill" : "arrow.right.circle")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!work.allAcceptedHandled || submitted)
        }
        .padding(20)
        .background(.thinMaterial)
    }
}

#Preview(windowStyle: .automatic) {
    TaskWorkView(round: .a, agent: .managerClone)
        .environmentObject(SessionEventLog.preview)
        .environmentObject(PrototypeSyncService.preview)
        .environmentObject(SessionWork.preview)
}
