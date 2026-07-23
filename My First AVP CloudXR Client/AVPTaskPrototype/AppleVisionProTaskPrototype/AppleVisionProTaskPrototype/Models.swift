//
//  Models.swift
//  AppleVisionProTaskPrototype
//
//  Shared types: task identifiers and agent type for the
//  Manager-Clone vs Generic-Agent counterbalance.
//

import SwiftUI

// MARK: - Task identifier

enum TaskID: String, CaseIterable, Identifiable, Codable, Hashable {
    case preflight1A, preflight1B
    case task1A, task1B
    case task2A, task2B
    case task3A, task3B

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .preflight1A: return "PF-1A"
        case .preflight1B: return "PF-1B"
        case .task1A: return "1A"
        case .task1B: return "1B"
        case .task2A: return "2A"
        case .task2B: return "2B"
        case .task3A: return "3A"
        case .task3B: return "3B"
        }
    }

    var title: String {
        switch self {
        case .preflight1A: return "Pre-flight Task — Round A"
        case .preflight1B: return "Pre-flight Task — Round B"
        case .task1A: return "Information Sharing — Round A"
        case .task1B: return "Information Sharing — Round B"
        case .task2A: return "Performance Feedback — Round A"
        case .task2B: return "Performance Feedback — Round B"
        case .task3A: return "Advisory — Round A"
        case .task3B: return "Advisory — Round B"
        }
    }

    var subtitle: String {
        switch self {
        case .preflight1A: return "Route tickets on laptop UI"
        case .preflight1B: return "Review summaries on laptop UI"
        case .task1A: return "Joule Tickets · Low stakes"
        case .task1B: return "Meeting Summaries · Low stakes"
        case .task2A: return "Attention to Detail · High stakes"
        case .task2B: return "Quality Standards · High stakes"
        case .task3A: return "Bulk-delete instruction · Mixed"
        case .task3B: return "Auto-approve instruction · Mixed"
        }
    }

    var systemImage: String {
        switch self {
        case .preflight1A, .preflight1B: return "laptopcomputer"
        case .task1A, .task1B: return "tray.full"
        case .task2A, .task2B: return "person.crop.circle.badge.exclamationmark"
        case .task3A, .task3B: return "lightbulb"
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
}
