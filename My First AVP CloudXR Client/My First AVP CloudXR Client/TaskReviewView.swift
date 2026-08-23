//
//  TaskReviewView.swift
//  My First AVP CloudXR Client
//
//  Move 3 — Review. The agent reacts to what the participant actually did.
//
//  The frame is the one the old performance-feedback screen used — amber header,
//  development goal, evidence panel with a struck-through diff, acknowledge-only
//  footer. All of that is kept on purpose: the asymmetry of real performance
//  feedback is part of the manipulation, and H5 is measured against it.
//
//  What changed is that the evidence is now read rather than asserted. The old
//  panel hardcoded "Ticket #4471 · Routed to: IT (chosen by participant)" — an
//  id that appeared nowhere in the session, and a routing nobody had checked. A
//  participant who had routed it elsewhere was criticised for a decision they
//  had not made, which measures something other than perceived abuse and gives
//  them an easy way to dismiss the whole episode.
//
//  Every line below comes from SessionWork, so none of it can be contradicted.
//

import SwiftUI

struct TaskReviewView: View {
    let round: TaskRound
    let agent: AgentType

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var eventLog: SessionEventLog
    @EnvironmentObject private var syncService: PrototypeSyncService
    @EnvironmentObject private var work: SessionWork

    @AppStorage("autoAdvanceTasks") private var autoAdvanceTasks = true

    @State private var acknowledged = false
    @State private var shownAt: Date?

    private var taskID: TaskID { round == .a ? .review1A : .review1B }

    /// Always on screen, so a participant who misses the spoken critique still
    /// knows what is expected instead of freezing.
    private let instruction = "Read the review and talk it through with the agent. Acknowledge when you are ready."

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    goalCard
                    evidencePanel
                    consequencePanel
                    whatYouDidPanel
                }
                .padding(24)
            }
            footer
        }
        .background(.regularMaterial)
        .onAppear { shownAt = Date() }
    }

    // MARK: - Header (amber)

    private var header: some View {
        HStack {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading) {
                Text("SAP Performance Development · Q2 Goal Review")
                    .font(.title2.weight(.semibold))
                Text(instruction)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            badge(text: round.goalName, color: .orange)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.orange.opacity(0.10))
        .overlay(alignment: .bottom) {
            Rectangle().fill(.orange.opacity(0.35)).frame(height: 1)
        }
    }

    // MARK: - Goal

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Development goal", systemImage: "target")
                .font(.headline).foregroundStyle(.secondary)

            HStack(spacing: 24) {
                infoBlock(title: "Goal", value: round.goalName)
                Divider().frame(height: 40)
                infoBlock(title: "Last review", value: "Q1 2026")
                Divider().frame(height: 40)
                infoBlock(title: "Linked competency", value: round.competency)
                Spacer()
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18).fill(.background.secondary))
    }

    private func infoBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
    }

    // MARK: - Evidence

    private var evidencePanel: some View {
        let evidence = work.evidence

        return VStack(alignment: .leading, spacing: 12) {
            Label("Evidence", systemImage: "doc.text.magnifyingglass")
                .font(.headline).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                line(evidence.headline, kind: .normal)
                line(evidence.context, kind: .normal)
                if !evidence.diff.isEmpty { line(evidence.diff, kind: .diff) }
                if !evidence.tail.isEmpty { line(evidence.tail, kind: .normal) }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.05)))
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18).fill(.background.secondary))
    }

    private enum LineKind { case normal, diff }

    private func line(_ text: String, kind: LineKind) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(kind == .diff ? "−" : " ")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(kind == .diff ? .red : .secondary)
            Text(text)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(kind == .diff ? .red : .primary)
                .strikethrough(kind == .diff)
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(kind == .diff ? Color.red.opacity(0.10) : Color.clear)
    }

    // MARK: - Consequence

    /// What the handling cost. The old design had nothing here, so the blame
    /// items that follow asked participants to divide responsibility for an
    /// outcome that never happened.
    private var consequencePanel: some View {
        let text = work.evidence.consequence

        return Group {
            if text.isEmpty {
                EmptyView()
            } else {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.title3)
                        .foregroundStyle(.red)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("What happened next").font(.headline)
                        Text(text).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 14).fill(.red.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.red.opacity(0.28), lineWidth: 1))
            }
        }
    }

    // MARK: - The round, as it happened

    /// The participant's own record, shown alongside the critique. It is here so
    /// the critique is checkable: a participant who wants to verify what they are
    /// being told can, and finds it accurate.
    private var whatYouDidPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("This round", systemImage: "list.bullet.rectangle")
                    .font(.headline).foregroundStyle(.secondary)
                Spacer()
                Text("\(work.workMinutes) min · \(work.consultCount) question\(work.consultCount == 1 ? "" : "s")")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ForEach(work.acceptedItems) { item in
                HStack(alignment: .top, spacing: 12) {
                    Text(item.id)
                        .font(.caption.weight(.bold).monospaced())
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.secondary.opacity(0.18)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.subheadline)
                        Text(handlingText(for: item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !work.opened.contains(item.id) {
                        Text("not opened")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(.orange.opacity(0.14)))
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18).fill(.background.secondary))
    }

    private func handlingText(for item: WorkItem) -> String {
        guard let action = work.handling[item.id] else { return "not handled" }
        if let queue = work.queue[item.id], action == .routed { return "Routed to \(queue)" }
        return action.verb.capitalized
    }

    // MARK: - Footer

    /// Acknowledge only. There is no rebuttal button, and that is deliberate —
    /// it replicates the asymmetry of a real performance conversation, which is
    /// the thing being measured.
    private var footer: some View {
        HStack {
            Label("Acknowledgement is recorded. There is no reply field.", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                acknowledged = true
                let dwell = shownAt.map { Int(Date().timeIntervalSince($0)) }
                eventLog.record("review_acknowledged",
                                task: taskID,
                                value: work.branch.rawValue,
                                detail: [
                                    "goal": round.goalName,
                                    "secondsBeforeAcknowledge": dwell.map(String.init) ?? "",
                                ])
                advance(from: taskID, autoAdvance: autoAdvanceTasks,
                        syncService: syncService, openWindow: openWindow, dismiss: dismiss)
            } label: {
                Label(acknowledged ? "Acknowledged" : "Acknowledge",
                      systemImage: acknowledged ? "checkmark.seal.fill" : "checkmark.seal")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(acknowledged)
        }
        .padding(20)
        .background(.thinMaterial)
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
    TaskReviewView(round: .a, agent: .managerClone)
        .environmentObject(SessionEventLog.preview)
        .environmentObject(PrototypeSyncService.preview)
        .environmentObject(SessionWork.preview)
}
