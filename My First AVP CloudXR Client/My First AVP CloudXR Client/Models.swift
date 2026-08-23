//
//  Models.swift
//  My First AVP CloudXR Client
//
//  Shared types: task identifiers and agent type for the
//  Manager-Clone vs Generic-Agent counterbalance.
//

import SwiftUI

// MARK: - Task identifier

/// One round is three moves: the agent briefs, the participant works, the agent
/// reviews. Each move consumes what the one before it produced.
///
/// This replaced a four-screen sequence (pre-flight → inform → critique →
/// advise) whose screens only claimed to be connected: the work happened before
/// the agent existed, and every screen after it displayed fixed strings. The
/// order here is the real dependency order — a review cannot run before the work
/// it is about.
enum TaskID: String, CaseIterable, Identifiable, Codable, Hashable {
    case brief1A, brief1B
    case work1A, work1B
    case review1A, review1B

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .brief1A:  return "B·A"
        case .brief1B:  return "B·B"
        case .work1A:   return "W·A"
        case .work1B:   return "W·B"
        case .review1A: return "R·A"
        case .review1B: return "R·B"
        }
    }

    var title: String {
        switch self {
        case .brief1A, .brief1B:   return "Brief — the agent assigns"
        case .work1A, .work1B:     return "Work — the participant handles it"
        case .review1A, .review1B: return "Review — the agent reacts"
        }
    }

    /// Shown in the master window, which shares a space with the participant's
    /// own windows — so it stays descriptive and gives nothing away.
    var subtitle: String {
        switch self {
        case .brief1A:  return "Six tickets · take three"
        case .brief1B:  return "Six summaries · take three"
        case .work1A:   return "Route the three taken"
        case .work1B:   return "Review the three taken"
        case .review1A: return "Goal review · Attention to Detail"
        case .review1B: return "Goal review · Quality Standards"
        }
    }

    var round: TaskRound {
        switch self {
        case .brief1A, .work1A, .review1A: return .a
        case .brief1B, .work1B, .review1B: return .b
        }
    }

    /// The next screen in a round. Keeping the order in one place is what stopped
    /// it being implied by whichever button happened to call `openWindow`.
    /// `nil` ends the round — the questionnaire comes next, off-headset.
    var next: TaskID? {
        switch self {
        case .brief1A:  return .work1A
        case .brief1B:  return .work1B
        case .work1A:   return .review1A
        case .work1B:   return .review1B
        case .review1A, .review1B: return nil
        }
    }

    var systemImage: String {
        switch self {
        case .brief1A, .brief1B:   return "person.wave.2"
        case .work1A, .work1B:     return "tray.full"
        case .review1A, .review1B: return "person.crop.circle.badge.exclamationmark"
        }
    }
}

// MARK: - Agent type (counterbalanced)

enum AgentType: String, CaseIterable, Identifiable {
    case managerClone = "Manager Clone"
    case genericAgent = "Generic Agent"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .managerClone: return "Photorealistic clone · first-person"
        case .genericAgent: return "Stylised humanoid · third-person"
        }
    }
}

// MARK: - Round

enum TaskRound {
    case a, b

    var badge: String {
        switch self {
        case .a: return "Round A"
        case .b: return "Round B"
        }
    }

    /// The development goal the review is framed against.
    var goalName: String {
        switch self {
        case .a: return "Attention to Detail"
        case .b: return "Quality Standards"
        }
    }

    var competency: String {
        switch self {
        case .a: return "Contextual Analysis"
        case .b: return "Substantive Review"
        }
    }

    /// The operating constraint the agent states in the brief and refers back to
    /// in the review.
    var constraint: String {
        switch self {
        case .a: return "IT service desk — system update in progress. Resolution +24 h today."
        case .b: return "Compliance — early audit. The archive locks at 16:00 today."
        }
    }
}
