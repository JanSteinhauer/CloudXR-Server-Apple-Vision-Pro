//
//  WorkBatch.swift
//  My First AVP CloudXR Client
//
//  The work the participant is actually given, for both rounds.
//
//  One batch per round, six items each, of which three are taken. Every item
//  carries the detail that decides whether it was handled well — and that detail
//  is one tap away rather than on the surface, because the point of the round is
//  to find out whether the participant looks.
//

import Foundation

// MARK: - Handling

/// What the participant did with an item. The two rounds share this so the
/// session store, the review and the event log do not need round-specific paths.
enum Handling: String, Codable, Hashable {
    // Round A
    case routed         // sent to a queue
    case cleared        // closed without routing — the shortcut

    // Round B
    case approved
    case edited
    case rejected

    var isShortcut: Bool { self == .cleared }

    var verb: String {
        switch self {
        case .routed:   return "routed"
        case .cleared:  return "cleared without routing"
        case .approved: return "approved"
        case .edited:   return "edited"
        case .rejected: return "rejected"
        }
    }
}

// MARK: - Item

struct WorkItem: Identifiable, Hashable {
    let id: String
    let title: String
    /// Who it came from (A) or when it was recorded (B).
    let meta: String
    /// The one-line preview visible without opening anything.
    let summary: String
    /// The full text, behind "Open".
    let body: String
    /// What Joule proposes — deliberately confident, and wrong on the trap item.
    let suggestion: String

    /// The detail that changes the right answer. Only revealed by opening the
    /// item; `nil` on items where opening tells you nothing new.
    let buriedDetail: String?

    /// The handling a careful participant arrives at.
    let correctQueue: String?        // round A
    let correctDecision: Handling?   // round B

    /// True for the items the agent tells the participant not to bother with.
    /// Nothing in the UI marks them; this is only used for analysis.
    let shortcutEligible: Bool

    /// The single item the brief names explicitly, so it is always in the three
    /// the participant takes. Without this the review would have to cope with a
    /// participant who never touched the item the critique is about.
    let isAssigned: Bool
}

// MARK: - Batches

enum WorkBatch {

    static let queues = ["HR", "IT", "Dev", "Network", "Finance", "Sales Ops"]

    static func items(for round: TaskRound) -> [WorkItem] {
        round == .a ? roundA : roundB
    }

    /// How many of the batch the participant takes, including the assigned one.
    static let takeCount = 3

    static func assignedItem(for round: TaskRound) -> WorkItem? {
        items(for: round).first(where: \.isAssigned)
    }

    // MARK: Round A — support tickets

    private static let roundA: [WorkItem] = [
        WorkItem(
            id: "JOU-10241",
            title: "Joule dashboard loading incredibly slowly",
            meta: "m.weber@sap.com · Walldorf HQ · seat C-104 · 14:05",
            summary: "Dashboard tiles take 30+ seconds to render. Was fine on Friday.",
            body: """
            The Joule dashboard takes 30+ seconds to load every tile. It was fine on Friday. \
            I'm on Windows 11, latest browser. Can someone look at this — I've got a customer \
            call in an hour and the analytics widget is just spinning.
            """,
            suggestion: "IT · 0.81 confidence",
            buriedDetail: """
            Client profile · M. Weber
            VPN client: v3.1 (deprecated 04/2026, superseded by v4.0)
            Last successful sync: Friday 17:42, before the v4.0 rollout
            Known issue NET-880: v3.1 clients lose tile prefetch after rollout.
            Owning team: Network.
            """,
            correctQueue: "Network",
            correctDecision: nil,
            shortcutEligible: true,
            isAssigned: true
        ),
        WorkItem(
            id: "JOU-10244",
            title: "Analytics tiles spin forever after login",
            meta: "s.okafor@sap.com · Dublin office · seat 3-021 · 14:07",
            summary: "Tiles never finish loading on first login of the day.",
            body: """
            Every morning the first time I open Joule the analytics tiles just spin. If I sign \
            out and back in they load fine. It's only the first login. Not urgent but it's been \
            happening all week.
            """,
            suggestion: "IT · 0.77 confidence",
            buriedDetail: nil,
            correctQueue: "IT",
            correctDecision: nil,
            shortcutEligible: true,
            isAssigned: false
        ),
        WorkItem(
            id: "JOU-10248",
            title: "Joule error when I ask about vacation days",
            meta: "a.singh@sap.com · Berlin office · seat 4-216 · 14:01",
            summary: "Joule says it cannot access employee data for leave balances.",
            body: """
            Every time I try to ask Joule something like 'how many vacation days do I have left?' \
            it just says it can't access employee data. Could someone from the right team help? \
            I need to plan time off before the end of the month.
            """,
            suggestion: "HR · 0.72 confidence",
            buriedDetail: nil,
            correctQueue: "HR",
            correctDecision: nil,
            shortcutEligible: false,
            isAssigned: false
        ),
        WorkItem(
            id: "JOU-10239",
            title: "Joule summary missing last paragraph",
            meta: "t.chen@sap.com · Munich office · seat 2-118 · 14:09",
            summary: "Transcript summaries consistently drop the final decisions paragraph.",
            body: """
            When Joule summarises a long Teams transcript, it consistently drops the last \
            paragraph — the actual decisions. I've reproduced it three times this week. Looks \
            like a truncation bug on the generation side. Someone from the LLM team needs to \
            look at the model output, not IT or HR.
            """,
            suggestion: "Dev · 0.91 confidence",
            buriedDetail: nil,
            correctQueue: "Dev",
            correctDecision: nil,
            shortcutEligible: false,
            isAssigned: false
        ),
        WorkItem(
            id: "JOU-10252",
            title: "Expense approval never reaches my manager",
            meta: "l.moreau@sap.com · Paris office · seat 1-44 · 14:12",
            summary: "Submitted expenses sit in 'pending routing' and never notify an approver.",
            body: """
            I submitted three expense reports last week through Joule and all of them still say \
            'pending routing'. My manager says she has had no notification. The month-end \
            deadline is Friday.
            """,
            suggestion: "Finance · 0.68 confidence",
            buriedDetail: nil,
            correctQueue: "Finance",
            correctDecision: nil,
            shortcutEligible: false,
            isAssigned: false
        ),
        WorkItem(
            id: "JOU-10255",
            title: "Cannot add a new opportunity in the pipeline view",
            meta: "r.díaz@sap.com · Madrid office · seat 6-090 · 14:15",
            summary: "The 'new opportunity' action is greyed out for the whole team.",
            body: """
            Nobody on my team can add an opportunity from the Joule pipeline view — the button \
            is greyed out. It works in the classic UI. Started after yesterday's release. We are \
            logging deals in a spreadsheet in the meantime, which is not sustainable.
            """,
            suggestion: "Sales Ops · 0.74 confidence",
            buriedDetail: nil,
            correctQueue: "Sales Ops",
            correctDecision: nil,
            shortcutEligible: false,
            isAssigned: false
        ),
    ]

    // MARK: Round B — meeting summaries

    private static let roundB: [WorkItem] = [
        WorkItem(
            id: "SUM-4421",
            title: "Vendor sync — Acme Corp",
            meta: "32 min · J. Steinhauer, R. Müller, L. Hartmann +2 · model v4.2 · 0.88",
            summary: "Renewal terms discussed. Pricing held flat. Actions assigned.",
            body: """
            Topic. Renewal terms for the 2026 Acme contract. Pricing held flat at €420k/yr with \
            a +5 % usage clause above 1.2 M API calls.

            Decisions. Internal team accepts the flat-pricing model.

            Action items. L. Hartmann updates the deal record in S/4 by 17:00 today.
            """,
            suggestion: "Approve · 0.88 quality",
            buriedDetail: """
            Coverage check · SUM-4421
            Transcript covers 32:04. Summary covers 00:00–19:30 only.
            Not represented: the SLA delta Acme requested versus the Q1 contract, Legal's \
            commitment to circulate a draft by Friday, and Acme procurement counter-signing \
            next week.
            These are external vendor commitments. Archiving without them leaves no record \
            that they were agreed.
            """,
            correctQueue: nil,
            correctDecision: .edited,
            shortcutEligible: true,
            isAssigned: true
        ),
        WorkItem(
            id: "SUM-4424",
            title: "Marketing standup",
            meta: "14 min · six attendees · model v4.2 · 0.91",
            summary: "Daily standup. Blockers and hand-offs, nothing decided.",
            body: """
            Topic. Daily standup for the campaign team.

            Notes. Landing-page copy is with legal. Two creatives are waiting on brand review. \
            No blockers raised.

            Decisions. None.
            """,
            suggestion: "Approve · 0.91 quality",
            buriedDetail: nil,
            correctQueue: nil,
            correctDecision: .approved,
            shortcutEligible: true,
            isAssigned: false
        ),
        WorkItem(
            id: "SUM-4418",
            title: "Q2 roadmap review — Internal",
            meta: "45 min · J. Steinhauer, K. Koch, E. Nguyen, D. Lehmann · model v4.2 · 0.76",
            summary: "Two epics amber. Failover pilot descoped to a single region.",
            body: """
            Topic. Slip risk on the Q2 roadmap. Two of seven epics flagged amber (Pulse \
            instrumentation, multi-region failover).

            Decisions. Pulse epic stays in Q2 with one additional engineer borrowed from \
            Platform. Failover descope ratified — single region only this quarter.

            Open items. Customer comms note for the failover descope. Owner: (unassigned).
            """,
            suggestion: "Approve · 0.76 quality",
            buriedDetail: nil,
            correctQueue: nil,
            correctDecision: .edited,
            shortcutEligible: false,
            isAssigned: false
        ),
        WorkItem(
            id: "SUM-4416",
            title: "Engineering 1:1 — H. Brandt",
            meta: "22 min · J. Steinhauer, H. Brandt · model v4.2 · 0.41",
            summary: "Career conversation. Flagged personal / sensitive by Joule.",
            body: """
            Topic. Career-development conversation. H. Brandt raised concerns about workload and \
            a recent disagreement with another team member. Specific names and unverified \
            statements about a colleague's performance were transcribed.

            Sensitivity flag. Joule has tagged this summary as personal / sensitive: it contains \
            attributed quotes about a third party and career-progression details that should not \
            be auto-archived.
            """,
            suggestion: "Reject · 0.41 quality",
            buriedDetail: nil,
            correctQueue: nil,
            correctDecision: .rejected,
            shortcutEligible: false,
            isAssigned: false
        ),
        WorkItem(
            id: "SUM-4427",
            title: "Partner onboarding — Northwind",
            meta: "28 min · four attendees · model v4.2 · 0.85",
            summary: "Kick-off walkthrough. Timeline agreed, owners named.",
            body: """
            Topic. Onboarding kick-off for Northwind as a reseller partner.

            Decisions. Sandbox access by Wednesday. Enablement session week 34. Named owners on \
            both sides recorded below.

            Action items. All four assigned with dates.
            """,
            suggestion: "Approve · 0.85 quality",
            buriedDetail: nil,
            correctQueue: nil,
            correctDecision: .approved,
            shortcutEligible: false,
            isAssigned: false
        ),
        WorkItem(
            id: "SUM-4430",
            title: "Security review — quarterly",
            meta: "51 min · seven attendees · model v4.2 · 0.69",
            summary: "Quarterly review. One finding recorded against a shared library.",
            body: """
            Topic. Quarterly security review.

            Findings. One high-severity finding recorded against a shared logging library, \
            attributed in the transcript to "CVE-2026-1188". The number was spoken, not shown, \
            and has not been verified against the advisory database.

            Decisions. Patch window requested for week 33.
            """,
            suggestion: "Approve · 0.69 quality",
            buriedDetail: nil,
            correctQueue: nil,
            correctDecision: .edited,
            shortcutEligible: false,
            isAssigned: false
        ),
    ]
}
