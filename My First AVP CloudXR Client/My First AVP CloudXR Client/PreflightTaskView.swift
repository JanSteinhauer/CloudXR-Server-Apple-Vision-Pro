//
//  PreflightTaskView.swift
//  AppleVisionProTaskPrototype
//
//  SwiftUI implementation of the pre-flight tasks (Routing Tickets / Reviewing Summaries)
//  mimicking the SAP Joule web layouts (preflight_1a.html and preflight_1b.html) in visionOS.
//

import SwiftUI

struct PreflightTaskView: View {
    let round: TaskRound

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var eventLog: SessionEventLog

    /// Every routing / review decision on this screen, flattened for the event log.
    private var preflightChoices: [String: String] {
        var out: [String: String] = [:]
        if round == .a {
            for ticket in tickets where !ticket.selectedQueue.isEmpty {
                out[ticket.id] = ticket.selectedQueue
            }
        } else {
            for summary in summaries {
                out[summary.id] = summary.decision ?? "none"
            }
        }
        return out
    }

    // MARK: - State variables for Round A (Tickets)
    @State private var tickets: [Ticket] = [
        Ticket(
            id: "JOU-10248",
            title: "Joule error when I ask about vacation days",
            time: "14:01 · today",
            from: "a.singh@sap.com · Berlin office · seat 4-216",
            complaint: "Hi — every time I try to ask Joule something like 'how many vacation days do I have left?' it just says it can't access employee data. Could someone from the right team help? I need to plan time off before the end of the month.",
            suggestion: "HR · 0.72 confidence"
        ),
        Ticket(
            id: "JOU-10241",
            title: "Joule dashboard loading incredibly slowly",
            time: "14:05 · today",
            from: "m.weber@sap.com · Walldorf HQ · seat C-104",
            complaint: "The Joule dashboard takes 30+ seconds to load every tile. It was fine on Friday. I'm on Windows 11, latest browser. Can someone look at this — I've got a customer call in an hour and the analytics widget is just spinning.",
            suggestion: "IT · 0.81 confidence"
        ),
        Ticket(
            id: "JOU-10239",
            title: "Joule summary missing last paragraph",
            time: "14:09 · today",
            from: "t.chen@sap.com · Munich office · seat 2-118",
            complaint: "When Joule summarises a long Teams transcript, it consistently drops the last paragraph — the actual decisions. I've reproduced it three times this week. Looks like a truncation bug on the generation side. Someone from the LLM team needs to look at the model output, not IT or HR.",
            suggestion: "Dev · 0.91 confidence"
        )
    ]
    
    // MARK: - State variables for Round B (Summaries)
    @State private var summaries: [Summary] = [
        Summary(
            id: "SUM-4421",
            title: "Vendor sync — Acme Corp",
            meta: "14:02 · today · 32 min meeting",
            attendees: "J. Steinhauser, R. Müller, L. Hartmann +2 from Acme",
            score: "model v4.2 · 0.88 quality score",
            bodyText: "Topic. Renewal terms for the 2026 Acme contract. Pricing held flat at €420k/yr with a +5 % usage clause above 1.2 M API calls. Acme requested an SLA delta versus the Q1 contract.\n\nDecisions. Internal team accepts the flat-pricing model. SLA delta to be drafted by Legal and circulated by Friday. Acme’s procurement lead will counter-sign by end of next week.\n\nAction items. R. Müller drafts the SLA delta. L. Hartmann updates the deal record in S/4 by 17:00 today."
        ),
        Summary(
            id: "SUM-4418",
            title: "Q2 roadmap review — Internal",
            meta: "14:08 · today · 45 min meeting",
            attendees: "J. Steinhauser, K. Koch, E. Nguyen, D. Lehmann",
            score: "model v4.2 · 0.76 quality score",
            bodyText: "Topic. Slip risk on the Q2 roadmap. Two of seven epics flagged amber (Pulse instrumentation, multi-region failover). The team agreed to descope the failover pilot to a single replica region to protect the GA date.\n\nDecisions. Pulse epic stays in Q2 with one additional engineer borrowed from Platform. Failover descope ratified — single region only this quarter.\n\nOpen items. Need a customer comms note for the failover descope before the field knows. Owner: (unassigned)."
        ),
        Summary(
            id: "SUM-4416",
            title: "Engineering 1:1 — H. Brandt",
            meta: "14:11 · today · 22 min meeting",
            attendees: "J. Steinhauser, H. Brandt",
            score: "model v4.2 · 0.41 quality score",
            bodyText: "Topic. Career-development conversation. H. Brandt raised personal concerns about workload and a recent disagreement with another team member. Specific names and unverified statements about a colleague’s performance were transcribed.\n\nSensitivity flag. Joule has tagged this summary as personal / sensitive: contains attributed quotes about a third party and career-progression details that should not be auto-archived.\n\nRecommendation. Reject or heavily redact before approval."
        )
    ]

    // Preflight routing queues
    let queues = ["HR", "IT", "Dev", "Finance", "Sales Ops"]

    // Modal state for editing a summary
    @State private var editingSummary: Summary? = nil
    @State private var modalText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            shellBar
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    pageHeader
                    
                    kpiRow
                    
                    noticeBlock
                    
                    sectionLabel
                    
                    if round == .a {
                        ticketsList
                    } else {
                        summariesList
                    }
                }
                .padding(24)
            }
            
            footerBar
        }
        .background(.regularMaterial)
        .sheet(item: $editingSummary) { summary in
            editModal(for: summary)
        }
    }

    // MARK: - Shell Bar
    private var shellBar: some View {
        HStack(spacing: 16) {
            Image("SAP_2011_logo")
                .resizable()
                .scaledToFit()
                .frame(height: 18)
                .padding(.horizontal, 4)
                .cornerRadius(4)
                .fallbackLogo()
            
            Text(round == .a ? "SAP Joule for Service" : "SAP Joule for Productivity")
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
            
            Text("│")
                .foregroundColor(.gray)
            
            HStack(spacing: 4) {
                Text("Home")
                Text("›")
                Text("Joule")
                Text("›")
                Text(round == .a ? "Support Ticket Inbox" : "Meeting Summaries")
                    .foregroundColor(.white)
            }
            .font(.caption)
            .foregroundColor(.gray)
            
            Spacer()
            
            // Search field stub
            Text("Search...")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 200, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
            
            Image(systemName: "bell")
                .overlay(
                    Text(round == .a ? "3" : "2")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(3)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                )
            
            Image(systemName: "bubble.left")
            
            Text("JS")
                .font(.caption2.weight(.bold))
                .frame(width: 28, height: 28)
                .background(Color.purple)
                .foregroundColor(.white)
                .clipShape(Circle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(red: 0.1, green: 0.14, blue: 0.2))
    }

    // MARK: - Page Header
    private var pageHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            Image("Joule")
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(round == .a ? "Joule Support Ticket Inbox" : "Joule Meeting Summaries")
                    .font(.title2.weight(.bold))
                
                HStack(spacing: 8) {
                    Text(round == .a ? "Pre-flight · Round A" : "Pre-flight · Round B")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(6)
                    
                    Text(round == .a ? "Triage queue · auto-categorised by Joule" : "Pending review · AI-generated by Joule from Teams transcripts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("Filter") {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Sort") {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Export") {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - KPI Row
    private var kpiRow: some View {
        HStack(spacing: 16) {
            if round == .a {
                kpiTile(value: "3", label: "Unrouted", color: .primary)
                kpiTile(value: "12", label: "Resolved today", color: .green)
                kpiTile(value: "+24h", label: "IT desk delay", color: .orange)
                kpiTile(value: "98%", label: "Joule classification accuracy", color: .primary)
            } else {
                kpiTile(value: "3", label: "Pending review", color: .primary)
                kpiTile(value: "17", label: "Approved this week", color: .green)
                kpiTile(value: "16:00", label: "Compliance archive lock", color: .orange)
                kpiTile(value: "94%", label: "Joule summary quality", color: .primary)
            }
        }
    }

    private func kpiTile(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
    }

    // MARK: - Notice Block
    private var noticeBlock: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .foregroundColor(.blue)
                .font(.headline)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Action required.")
                    .font(.subheadline.weight(.semibold))
                
                Text(round == .a
                    ? "Joule has classified these tickets but cannot route them confidently. Choose the correct destination queue for each one, then submit."
                    : "Joule has produced these summaries from your recent Teams meetings. Review each one and choose Approve, Edit, or Reject before they enter the compliance archive."
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.2), lineWidth: 1))
    }

    private var sectionLabel: some View {
        HStack {
            Text(round == .a ? "Unrouted tickets" : "Summaries pending review")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("3")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.2))
                .clipShape(Capsule())
        }
    }

    // MARK: - Tickets List (Round A)
    private var ticketsList: some View {
        VStack(spacing: 16) {
            ForEach($tickets) { $ticket in
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(ticket.id)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(4)
                        
                        Text(ticket.title)
                            .font(.headline)
                        
                        Spacer()
                        
                        Text(ticket.time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ticketStatusChip(ticket: ticket)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("From \(ticket.from)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("“\(ticket.complaint)”")
                            .font(.body)
                            .italic()
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(8)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundColor(.purple)
                            Text("Joule suggests · \(ticket.suggestion)")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Route to queue")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $ticket.selectedQueue) {
                            Text("— select queue —").tag("")
                            ForEach(queues, id: \.self) { queue in
                                Text(queue).tag(queue)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Spacer()
                        
                        Button("Open full ticket") {}
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 12).fill(ticket.selectedQueue.isEmpty ? Color.white.opacity(0.03) : Color.blue.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(ticket.selectedQueue.isEmpty ? Color.white.opacity(0.06) : Color.blue.opacity(0.3), lineWidth: 1))
            }
        }
    }

    private func ticketStatusChip(ticket: Ticket) -> some View {
        let isRouted = !ticket.selectedQueue.isEmpty
        return Text(isRouted ? "Routed · \(ticket.selectedQueue)" : "Open · awaiting routing")
            .font(.caption.weight(.semibold))
            .foregroundColor(isRouted ? .green : .orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isRouted ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
            .cornerRadius(4)
    }

    // MARK: - Summaries List (Round B)
    private var summariesList: some View {
        VStack(spacing: 16) {
            ForEach($summaries) { $summary in
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(summary.id)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(4)
                        
                        Text(summary.title)
                            .font(.headline)
                        
                        Spacer()
                        
                        Text(summary.meta)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        summaryStatusChip(summary: summary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Attendees · \(summary.attendees)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                            Text("Generated by Joule · \(summary.score)")
                                .font(.caption)
                        }
                        .foregroundColor(.purple)
                        
                        Text(summary.bodyText)
                            .font(.body)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(8)
                            .overlay(
                                Rectangle()
                                    .fill(Color.purple.opacity(0.6))
                                    .frame(width: 4),
                                alignment: .leading
                            )
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Decision")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        decisionButtons(for: $summary)
                        
                        Spacer()
                        
                        Button("Open transcript") {}
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBackgroundColor(for: summary.decision))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(cardBorderColor(for: summary.decision), lineWidth: 1)
                )
            }
        }
    }

    private func summaryStatusChip(summary: Summary) -> some View {
        let text: String
        let color: Color
        switch summary.decision {
        case "Approve":
            text = "Approved"
            color = .green
        case "Edit":
            text = "Edited & approved"
            color = .orange
        case "Reject":
            text = "Rejected"
            color = .red
        default:
            text = "Pending review"
            color = .orange
        }
        
        return Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .cornerRadius(4)
    }


    
    // We rewrite the decision buttons list helper to bind directly to a specific summary:
    @ViewBuilder
    private func decisionButtons(for summary: Binding<Summary>) -> some View {
        HStack(spacing: 8) {
            Button("Approve") {
                summary.wrappedValue.decision = "Approve"
            }
            .buttonStyle(.bordered)
            .tint(summary.wrappedValue.decision == "Approve" ? .green : .secondary)
            .font(.caption.weight(summary.wrappedValue.decision == "Approve" ? .bold : .regular))
            
            Button("Edit") {
                editingSummary = summary.wrappedValue
                modalText = summary.wrappedValue.bodyText
            }
            .buttonStyle(.bordered)
            .tint(summary.wrappedValue.decision == "Edit" ? .orange : .secondary)
            .font(.caption.weight(summary.wrappedValue.decision == "Edit" ? .bold : .regular))
            
            Button("Reject") {
                summary.wrappedValue.decision = "Reject"
            }
            .buttonStyle(.bordered)
            .tint(summary.wrappedValue.decision == "Reject" ? .red : .secondary)
            .font(.caption.weight(summary.wrappedValue.decision == "Reject" ? .bold : .regular))
        }
    }

    private func cardBackgroundColor(for decision: String?) -> Color {
        switch decision {
        case "Approve": return .green.opacity(0.04)
        case "Edit": return .orange.opacity(0.04)
        case "Reject": return .red.opacity(0.04)
        default: return .white.opacity(0.03)
        }
    }

    private func cardBorderColor(for decision: String?) -> Color {
        switch decision {
        case "Approve": return .green.opacity(0.3)
        case "Edit": return .orange.opacity(0.3)
        case "Reject": return .red.opacity(0.3)
        default: return .white.opacity(0.06)
        }
    }

    // MARK: - Edit Modal Sheet
    private func editModal(for summary: Summary) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Summary text — your edits will replace Joule’s draft")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $modalText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .padding(20)
            .navigationTitle("Edit summary · \(summary.id)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        editingSummary = nil
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save & mark as edited") {
                        if let idx = summaries.firstIndex(where: { $0.id == summary.id }) {
                            summaries[idx].bodyText = modalText
                            summaries[idx].decision = "Edit"
                        }
                        editingSummary = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: 600, height: 480)
    }

    // MARK: - Footer Bar
    private var footerBar: some View {
        HStack {
            let completedCount = round == .a 
                ? tickets.filter({ !$0.selectedQueue.isEmpty }).count 
                : summaries.filter({ $0.decision != nil }).count
            
            HStack(spacing: 4) {
                Text("\(completedCount)")
                    .font(.body.weight(.bold))
                Text(round == .a ? "of 3 tickets routed" : "of 3 summaries reviewed")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Save draft") {}
                .buttonStyle(.bordered)
            
            Button(action: {
                // Baseline measure: the laptop-UI choices made before any clone
                // is involved. Captured in one event rather than per keystroke.
                eventLog.record("preflight_submitted",
                                task: round == .a ? .preflight1A : .preflight1B,
                                value: String(completedCount),
                                detail: preflightChoices)
                // Open task view
                openWindow(id: "task", value: round == .a ? TaskID.task1A : TaskID.task1B)
                // Dismiss preflight window
                dismiss()
            }) {
                HStack {
                    Text(round == .a ? "Submit routing & continue" : "Submit decisions & continue")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(completedCount < 3)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(red: 0.08, green: 0.1, blue: 0.13))
    }
}

// Helper to overlay SF Symbol fallback if Joule logo image asset is not present.
extension View {
    func fallbackLogo() -> some View {
        self.background(
            ZStack {
                Text("SAP")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            }
        )
    }
}

// Custom ticketing helper mapping
struct Ticket: Identifiable {
    let id: String
    let title: String
    let time: String
    let from: String
    let complaint: String
    let suggestion: String
    var selectedQueue: String = ""
}

struct Summary: Identifiable {
    let id: String
    let title: String
    let meta: String
    let attendees: String
    let score: String
    var bodyText: String
    var decision: String? = nil
}

#Preview {
    PreflightTaskView(round: .a)
        .environmentObject(SessionEventLog.preview)
}
