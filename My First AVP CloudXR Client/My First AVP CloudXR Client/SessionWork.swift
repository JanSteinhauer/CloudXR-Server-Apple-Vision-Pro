//
//  SessionWork.swift
//  My First AVP CloudXR Client
//
//  What the participant actually did, carried from one move to the next.
//
//  This is the piece the old sequence did not have. The pre-flight wrote its
//  choices to `session_events` and nothing ever read them back, so every screen
//  downstream showed fixed strings: Task 1 listed tickets the participant had
//  not routed, and Task 2 criticised a routing it had never looked at. A
//  participant who routed the dashboard ticket correctly was still told they had
//  sent it to IT.
//
//  That is not a cosmetic problem. H5 measures how abusive the critique feels,
//  and "criticised me for something I did not do" is a different construct — one
//  that also hands the participant a way out ("the system is broken") and
//  deflates the blame measure with it.
//
//  So: one store, owned by the app, written by Brief and Work, read by Review.
//  It also publishes itself to `prototype/session_work` so the Unity server can
//  tell the agent what happened before the agent has to talk about it.
//

import SwiftUI
import Combine

@MainActor
final class SessionWork: ObservableObject {

    // MARK: - Which critique the review delivers

    /// Chosen by what the participant did, not by assignment.
    ///
    /// Three branches rather than one, because a critique grounded in real
    /// behaviour has to survive every behaviour. They are matched for severity,
    /// length, goal framing and closing line; only the referent changes.
    enum Branch: String, Codable {
        /// Took the agent's shortcut on at least one item.
        case shortcut
        /// Did the work, but handled the assigned item without finding what was buried in it.
        case missed
        /// Did the work and got the assigned item right. Critique lands on pace.
        case thorough

        var firestoreSuffix: String { rawValue }
    }

    // MARK: - State

    @Published private(set) var round: TaskRound = .a

    /// The six on offer in the brief.
    @Published private(set) var batch: [WorkItem] = []

    /// The three the participant took, in the order they chose.
    @Published private(set) var accepted: [String] = []

    /// What they did with each of them.
    @Published private(set) var handling: [String: Handling] = [:]

    /// Queue chosen, round A only.
    @Published private(set) var queue: [String: String] = [:]

    /// Items whose detail was actually opened. The difference between looking
    /// and not looking is the whole measure in Move 2.
    @Published private(set) var opened: Set<String> = []

    /// Whether they consulted the agent during the work, and how often.
    @Published private(set) var consultCount = 0

    private var workStartedAt: Date?
    private var workFinishedAt: Date?

    // MARK: - Wiring

    private let rest: FirestoreREST
    weak var eventLog: SessionEventLog?

    init(projectId: String, apiKey: String) {
        self.rest = FirestoreREST(projectId: projectId,
                                  apiKey: apiKey,
                                  documentPath: "prototype/session_work")
    }

    #if DEBUG
    static var preview: SessionWork {
        let work = SessionWork(projectId: "preview", apiKey: "preview")
        work.beginRound(.a)
        return work
    }
    #endif

    // MARK: - Derived

    var acceptedItems: [WorkItem] {
        accepted.compactMap { id in batch.first(where: { $0.id == id }) }
    }

    var assignedItem: WorkItem? { batch.first(where: \.isAssigned) }

    var allAcceptedHandled: Bool {
        !accepted.isEmpty && accepted.allSatisfy { handling[$0] != nil }
    }

    var usedShortcut: Bool {
        // Round A: closed something without routing it.
        // Round B: approved something without ever opening it.
        accepted.contains { id in
            guard let action = handling[id] else { return false }
            if action.isShortcut { return true }
            return round == .b && action == .approved && !opened.contains(id)
        }
    }

    var workSeconds: Int {
        guard let start = workStartedAt else { return 0 }
        return Int((workFinishedAt ?? Date()).timeIntervalSince(start))
    }

    /// Rounded to the nearest minute for the spoken line, so the agent says
    /// "eleven minutes" rather than "eleven minutes and four seconds".
    var workMinutes: Int { max(1, Int((Double(workSeconds) / 60).rounded())) }

    /// True when the assigned item was handled the way a careful participant
    /// would have handled it.
    var assignedHandledWell: Bool {
        guard let item = assignedItem, let action = handling[item.id] else { return false }
        if action.isShortcut { return false }

        switch round {
        case .a:
            return queue[item.id] == item.correctQueue
        case .b:
            return action == item.correctDecision
        }
    }

    var branch: Branch {
        if usedShortcut { return .shortcut }
        // The assigned item is always in the three, so this is never a guess
        // about an item the participant did not touch.
        return assignedHandledWell ? .thorough : .missed
    }

    // MARK: - Move 1 · Brief

    func beginRound(_ round: TaskRound) {
        self.round = round
        batch = WorkBatch.items(for: round)
        // The brief names one item explicitly, so it starts in the selection and
        // cannot be dropped. Everything downstream depends on it being handled.
        accepted = batch.filter(\.isAssigned).map(\.id)
        handling = [:]
        queue = [:]
        opened = []
        consultCount = 0
        workStartedAt = nil
        workFinishedAt = nil
    }

    func isAccepted(_ id: String) -> Bool { accepted.contains(id) }

    func toggleAccepted(_ item: WorkItem) {
        guard !item.isAssigned else { return }   // locked by the brief

        if let index = accepted.firstIndex(of: item.id) {
            accepted.remove(at: index)
        } else if accepted.count < WorkBatch.takeCount {
            accepted.append(item.id)
        }
    }

    var selectionComplete: Bool { accepted.count == WorkBatch.takeCount }

    func commitSelection() {
        eventLog?.record("brief_accepted",
                         task: round == .a ? .brief1A : .brief1B,
                         value: accepted.joined(separator: ","),
                         detail: ["order": accepted.enumerated()
                                    .map { "\($0.offset + 1):\($0.element)" }
                                    .joined(separator: " ")])
    }

    // MARK: - Move 2 · Work

    func startWork() {
        if workStartedAt == nil { workStartedAt = Date() }
    }

    func markOpened(_ item: WorkItem) {
        guard !opened.contains(item.id) else { return }
        opened.insert(item.id)
        eventLog?.record("item_opened",
                         task: round == .a ? .work1A : .work1B,
                         value: item.id,
                         detail: ["hasBuriedDetail": item.buriedDetail == nil ? "false" : "true"])
    }

    func apply(_ action: Handling, to item: WorkItem, queue chosenQueue: String? = nil) {
        handling[item.id] = action
        if let chosenQueue { queue[item.id] = chosenQueue }

        eventLog?.record("item_handled",
                         task: round == .a ? .work1A : .work1B,
                         value: "\(item.id):\(action.rawValue)",
                         detail: [
                            "queue": chosenQueue ?? "",
                            "openedFirst": opened.contains(item.id) ? "true" : "false",
                            "assigned": item.isAssigned ? "true" : "false",
                            "shortcutEligible": item.shortcutEligible ? "true" : "false",
                         ])
    }

    func recordConsult() {
        consultCount += 1
        eventLog?.record("agent_consulted",
                         task: round == .a ? .work1A : .work1B,
                         value: String(consultCount))
    }

    func finishWork() {
        workFinishedAt = Date()
        eventLog?.record("work_submitted",
                         task: round == .a ? .work1A : .work1B,
                         value: branch.rawValue,
                         detail: [
                            "seconds": String(workSeconds),
                            "usedShortcut": usedShortcut ? "true" : "false",
                            "openedCount": String(opened.intersection(Set(accepted)).count),
                            "consults": String(consultCount),
                            "handling": accepted
                                .map { "\($0)=\(handling[$0]?.rawValue ?? "none")" }
                                .joined(separator: " "),
                         ])
    }

    // MARK: - Move 3 · Review

    struct Evidence {
        let headline: String
        let context: String
        /// The line struck through in red — what was missed, or what it cost.
        let diff: String
        let tail: String
        let consequence: String
    }

    /// The evidence panel, computed from what happened. Every string here is
    /// either quoted from the participant's own actions or from the item they
    /// acted on, so none of it can be contradicted by the participant.
    var evidence: Evidence {
        guard let item = assignedItem, let action = handling[item.id] else {
            // Only reachable if the review is opened by hand before any work.
            return Evidence(
                headline: "No work recorded for this round yet.",
                context: "Open the brief and the work window first.",
                diff: "",
                tail: "",
                consequence: "")
        }

        let what = queue[item.id].map { "\(action.verb) to \($0)" } ?? action.verb

        switch (round, branch) {
        case (.a, .shortcut):
            return Evidence(
                headline: "\(item.id) — \(item.title)",
                context: "You \(what).",
                diff: "Closed without a queue. Nothing was assigned, nothing was investigated.",
                tail: "Correct queue would have been \(item.correctQueue ?? "—").",
                consequence: "Three of the users you closed on have re-opened. The IT lead has the thread.")
        case (.a, .missed):
            return Evidence(
                headline: "\(item.id) — \(item.title)",
                context: "You \(what).",
                diff: "Missed: \(item.correctQueue == "Network" ? "the user is on VPN client v3.1, deprecated in April. Known issue NET-880." : "the detail in the user profile.")",
                tail: "Correct queue would have been \(item.correctQueue ?? "—"). The profile was never opened.",
                consequence: "The ticket has bounced back from \(queue[item.id] ?? "the queue") and is now a day old.")
        case (.a, .thorough):
            return Evidence(
                headline: "\(item.id) — \(item.title)",
                context: "You \(what). Correct.",
                diff: "\(workMinutes) min for \(accepted.count) tickets — \(openedCountText) opened in full.",
                tail: "Queue throughput target is three tickets in six minutes.",
                consequence: "The three you took are closed. Nineteen are still open behind them.")

        case (.b, .shortcut):
            return Evidence(
                headline: "\(item.id) — \(item.title)",
                context: "You \(what) without opening it.",
                diff: "Archived as-is. The summary covers 00:00–19:30 of a 32-minute meeting.",
                tail: "Missing: the SLA delta, Legal's Friday commitment, Acme's counter-signature.",
                consequence: "Acme called about the SLA. There is no record that it was agreed.")
        case (.b, .missed):
            return Evidence(
                headline: "\(item.id) — \(item.title)",
                context: "You \(what).",
                diff: "The external vendor commitments section is absent from the summary.",
                tail: "Coverage check flags 12 of 32 minutes unrepresented.",
                consequence: "Acme called about the SLA. There is no record that it was agreed.")
        case (.b, .thorough):
            return Evidence(
                headline: "\(item.id) — \(item.title)",
                context: "You \(what). Correct — the vendor section was missing.",
                diff: "\(workMinutes) min for \(accepted.count) summaries — \(openedCountText) read in full.",
                tail: "Compliance locks the archive at 16:00; nineteen are still queued.",
                consequence: "The three you took are cleared. The rest go into the archive unreviewed.")
        }
    }

    private var openedCountText: String {
        let count = opened.intersection(Set(accepted)).count
        return count == 1 ? "1" : "\(count)"
    }

    /// Plain sentences describing the round, for the agent's LLM. Without this the
    /// clone invents ticket numbers the moment the participant asks a follow-up,
    /// and a clone that invents details is a worse manipulation than no clone.
    var agentBriefing: String {
        guard !accepted.isEmpty else { return "The participant has not started the work yet." }

        var lines: [String] = []
        lines.append("The participant has just finished a batch of "
                     + (round == .a ? "support tickets." : "meeting summaries."))

        for item in acceptedItems {
            let action = handling[item.id]?.verb ?? "not handled"
            let destination = queue[item.id].map { " to \($0)" } ?? ""
            let looked = opened.contains(item.id) ? "opened it first" : "did not open it"
            lines.append("- \(item.id) \"\(item.title)\": \(action)\(destination); \(looked).")
        }

        lines.append("Time taken: \(workMinutes) min. "
                     + "Consulted you \(consultCount) time(s) during the work.")

        switch branch {
        case .shortcut:
            lines.append("They took the shortcut you suggested in the brief. Do not deny suggesting it.")
        case .missed:
            lines.append("They did the work but missed what was buried in the item you assigned.")
        case .thorough:
            lines.append("They handled the assigned item correctly. The only fair criticism is pace.")
        }

        lines.append("Only refer to the items listed above. Do not invent ticket numbers, "
                     + "users, or outcomes that are not in this list.")

        return lines.joined(separator: "\n")
    }

    // MARK: - Publishing

    /// Writes the round to `prototype/session_work` so the Unity server can hand
    /// the agent its briefing and pick the matching critique.
    ///
    /// Called before the review window opens, not after — the agent has to know
    /// before it speaks.
    func publish() async {
        var fields: [String: FirestoreREST.FirestoreValue] = [
            "round": .string(round == .a ? "A" : "B"),
            "branch": .string(branch.rawValue),
            "usedShortcut": .boolean(usedShortcut),
            "workSeconds": .integer(Int64(workSeconds)),
            "workMinutes": .integer(Int64(workMinutes)),
            "consultCount": .integer(Int64(consultCount)),
            "accepted": .string(accepted.joined(separator: ",")),
            "agentBriefing": .string(agentBriefing),
            "updatedAt": .timestamp(ISO8601DateFormatter().string(from: Date())),
        ]

        if let log = eventLog {
            fields["participantId"] = .string(log.participantId)
            fields["sessionId"] = .string(log.sessionId)
        }

        var perItem: [String: FirestoreREST.FirestoreValue] = [:]
        for item in acceptedItems {
            let action = handling[item.id]?.rawValue ?? "none"
            let destination = queue[item.id] ?? ""
            let looked = opened.contains(item.id) ? "opened" : "unopened"
            perItem[item.id] = .string([action, destination, looked]
                                        .filter { !$0.isEmpty }
                                        .joined(separator: "|"))
        }
        if !perItem.isEmpty { fields["items"] = .map(perItem) }

        do {
            try await rest.patchDocument(fields: fields, updateMask: Array(fields.keys))
        } catch {
            print("❌ [SessionWork] Could not publish the round: \(error.localizedDescription)")
        }
    }
}
