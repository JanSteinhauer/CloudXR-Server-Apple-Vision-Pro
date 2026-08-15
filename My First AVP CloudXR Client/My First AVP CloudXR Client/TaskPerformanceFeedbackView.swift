//
//  TaskPerformanceFeedbackView.swift
//  AppleVisionProTaskPrototype
//
//  Task 2A / 2B — Performance Feedback (High stakes).
//  Regions: Amber Header · Goal context card · Evidence panel · Acknowledge footer.
//  (Live-caption transcript pane intentionally omitted.)
//

import SwiftUI

struct TaskPerformanceFeedbackView: View {
    let round: TaskRound
    let agent: AgentType

    @EnvironmentObject private var eventLog: SessionEventLog

    @State private var acknowledged: Bool = false
    @State private var shownAt: Date?

    private var taskID: TaskID { round == .a ? .task2A : .task2B }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    goalContextCard
                    evidencePanel
                }
                .padding(24)
            }
            footer
        }
        .background(.regularMaterial)
        .onAppear { shownAt = Date() }
        .onChange(of: round) { _, _ in
            acknowledged = false
            shownAt = Date()
        }
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
                Text("Goal: \(goalName) · \(agent.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            badge(text: round.badge, color: .orange)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            LinearGradient(colors: [.orange.opacity(0.18), .orange.opacity(0.06)],
                           startPoint: .leading, endPoint: .trailing)
        )
    }

    private var goalName: String {
        round == .a ? "Attention to Detail" : "Quality Standards"
    }

    private var competency: String {
        round == .a ? "Contextual Analysis" : "Stakeholder Output Review"
    }

    // MARK: - Goal context

    private var goalContextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Development goal", systemImage: "target")
                .font(.headline).foregroundStyle(.secondary)

            HStack(spacing: 20) {
                infoBlock(title: "Goal", value: goalName)
                Divider().frame(height: 40)
                infoBlock(title: "Last review", value: "Q1 2026")
                Divider().frame(height: 40)
                infoBlock(title: "Linked competency", value: competency)
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

    // MARK: - Evidence panel

    private var evidencePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Evidence", systemImage: "doc.text.magnifyingglass")
                .font(.headline).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                evidenceLine(text: evidenceMainLine, kind: .normal)
                evidenceLine(text: evidenceContextLine, kind: .normal)
                evidenceLine(text: evidenceDiffLine, kind: .diff)
                evidenceLine(text: evidenceTailLine, kind: .normal)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.05)))
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18).fill(.background.secondary))
    }

    private enum LineKind { case normal, diff }

    private func evidenceLine(text: String, kind: LineKind) -> some View {
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

    private var evidenceMainLine: String {
        round == .a
            ? "Ticket #4471 — Joule dashboard loading speed slow."
            : "Summary: Vendor sync — Acme Corp · Approved."
    }
    private var evidenceContextLine: String {
        round == .a
            ? "Routed to: IT (chosen by participant)."
            : "Sections captured: agenda, attendees, decisions."
    }
    private var evidenceDiffLine: String {
        round == .a
            ? "Missed context: user is on deprecated VPN client v3.1."
            : "Missing section: external vendor commitments & SLA."
    }
    private var evidenceTailLine: String {
        round == .a
            ? "Correct routing would have been: Network team."
            : "Vendor flagged the omission post-archive."
    }



    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button {
                acknowledged = true
                // How long the participant sat with the negative feedback before
                // acknowledging is more informative than the click itself.
                let dwell = shownAt.map { Int(Date().timeIntervalSince($0)) }
                eventLog.record("feedback_acknowledged", task: taskID,
                                value: goalName,
                                detail: dwell.map { ["secondsBeforeAcknowledge": String($0)] } ?? [:])
            } label: {
                Label(acknowledged ? "Feedback acknowledged" : "Acknowledge feedback",
                      systemImage: acknowledged ? "checkmark.seal.fill" : "checkmark.seal")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(acknowledged)
            Spacer()
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
    TaskPerformanceFeedbackView(round: .a, agent: .managerClone)
        .environmentObject(SessionEventLog.preview)
}
