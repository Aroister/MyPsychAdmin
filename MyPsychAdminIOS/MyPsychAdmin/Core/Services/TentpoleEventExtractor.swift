//
//  TentpoleEventExtractor.swift
//  MyPsychAdmin
//
//  Extracts key milestone events from clinical notes
//  Matches desktop progress_panel.py TENTPOLE_PATTERNS
//

import Foundation
import SwiftUI

// MARK: - Tentpole Event Type

enum TentpoleEventType: String, CaseIterable, Identifiable {
    case tribunal = "Tribunal"
    case managersHearing = "Managers Hearing"
    case cpaReview = "CPA Review"
    case wardRound = "Ward Round"
    case groundLeave = "Ground Leave"
    case escortedLeave = "Escorted Leave"
    case unescortedLeave = "Unescorted Leave"
    case overnightLeave = "Overnight Leave"
    case communityLeave = "Community Leave"
    case sectionChange = "Section Change"
    case medicationChange = "Medication Change"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .tribunal: return Color(hex: "#1565c0")
        case .managersHearing: return Color(hex: "#0d47a1")
        case .cpaReview: return Color(hex: "#2e7d32")
        case .wardRound: return Color(hex: "#388e3c")
        case .groundLeave: return Color(hex: "#4caf50")
        case .escortedLeave: return Color(hex: "#8bc34a")
        case .unescortedLeave: return Color(hex: "#cddc39")
        case .overnightLeave: return Color(hex: "#ffeb3b")
        case .communityLeave: return Color(hex: "#ffc107")
        case .sectionChange: return Color(hex: "#ff9800")
        case .medicationChange: return Color(hex: "#9c27b0")
        }
    }

    /// Short label for timeline markers
    var shortLabel: String {
        switch self {
        case .tribunal: return "T"
        case .managersHearing: return "M"
        case .cpaReview: return "C"
        case .wardRound: return "W"
        case .groundLeave: return "G"
        case .escortedLeave: return "E"
        case .unescortedLeave: return "U"
        case .overnightLeave: return "O"
        case .communityLeave: return "L"
        case .sectionChange: return "S"
        case .medicationChange: return "Rx"
        }
    }

    /// Priority for display when multiple events in same month (lower = higher priority)
    var priority: Int {
        switch self {
        case .tribunal: return 1
        case .managersHearing: return 2
        case .unescortedLeave: return 3
        case .overnightLeave: return 4
        case .communityLeave: return 5
        case .groundLeave: return 6
        case .escortedLeave: return 7
        case .sectionChange: return 8
        case .cpaReview: return 9
        case .wardRound: return 10
        case .medicationChange: return 11
        }
    }
}

// MARK: - Tentpole Event

struct TentpoleEvent: Identifiable {
    let id = UUID()
    let type: TentpoleEventType
    let date: Date
    let month: String  // "YYYY-MM" format
    let noteId: UUID
    let matchedText: String
}

// MARK: - Compiled Pattern

private struct CompiledEventPattern {
    let type: TentpoleEventType
    let regexes: [NSRegularExpression]
}

// MARK: - Tentpole Event Extractor

class TentpoleEventExtractor {
    static let shared = TentpoleEventExtractor()

    private var compiledPatterns: [CompiledEventPattern] = []
    private let monthFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM"
        return df
    }()

    private init() {
        compilePatterns()
    }

    // MARK: - Pattern Definitions (matching desktop TENTPOLE_PATTERNS)

    private let patterns: [(TentpoleEventType, [String])] = [
        (.tribunal, [
            #"\b(tribunal|mental\s+health\s+tribunal|mht)\b"#
        ]),
        (.managersHearing, [
            #"manager'?s?\s+hearing"#,
            #"hospital\s+manager.{0,10}(hearing|review)"#
        ]),
        (.cpaReview, [
            #"\bcpa\s+(review|meeting|held|took\s+place|scheduled|arranged)\b"#,
            #"\b(cpa|care\s+programme\s+approach)\s+(review|meeting)\b"#,
            #"\breview.{0,15}(cpa|care\s+programme)\b"#,
            #"\b(mdt|multi\s*disciplinary)\s+(review|meeting)\s+(held|took\s+place)\b"#,
            #"\battended\s+(cpa|mdt)\b"#
        ]),
        (.wardRound, [
            #"\bward\s+round\b"#
        ]),
        (.groundLeave, [
            #"ground\w?\s+leave\s+(granted|approved|started|used)"#,
            #"(first|initial)\s+ground\w?\s+leave"#
        ]),
        (.escortedLeave, [
            #"escorted\s+leave\s+(granted|approved|started|used)"#
        ]),
        (.unescortedLeave, [
            #"unescorted\s+leave\s+(granted|approved|started|used)"#
        ]),
        (.overnightLeave, [
            #"overnight\s+leave"#,
            #"overnight\s+stay"#
        ]),
        (.communityLeave, [
            #"community\s+(leave|placement)"#,
            #"(section\s+17|s17)\s+leave"#
        ]),
        (.sectionChange, [
            #"(section|s)\s*\d+\s+(to|changed)"#,
            #"detained\s+under\s+(section|s)\s*\d+"#
        ]),
        (.medicationChange, [
            #"(started|commenced|initiated)\s+(on\s+)?\w+\s*\d+\s*mg"#,
            #"depot\s+(changed|started|increased)"#
        ])
    ]

    // MARK: - Compile Patterns

    private func compilePatterns() {
        for (type, patternStrings) in patterns {
            var regexes: [NSRegularExpression] = []
            for pattern in patternStrings {
                do {
                    let regex = try NSRegularExpression(
                        pattern: pattern,
                        options: [.caseInsensitive]
                    )
                    regexes.append(regex)
                } catch {
                    print("Failed to compile tentpole pattern: \(pattern)")
                }
            }
            if !regexes.isEmpty {
                compiledPatterns.append(CompiledEventPattern(type: type, regexes: regexes))
            }
        }
    }

    // MARK: - Extract Events

    /// Extract tentpole events from notes
    /// - Parameter notes: Array of clinical notes
    /// - Returns: Array of detected tentpole events
    func extractEvents(from notes: [ClinicalNote]) -> [TentpoleEvent] {
        var events: [TentpoleEvent] = []

        for note in notes {
            let text = note.text
            let textRange = NSRange(text.startIndex..., in: text)

            for compiled in compiledPatterns {
                for regex in compiled.regexes {
                    if let match = regex.firstMatch(in: text, options: [], range: textRange) {
                        let matchedText: String
                        if let range = Range(match.range, in: text) {
                            matchedText = String(text[range])
                        } else {
                            matchedText = compiled.type.rawValue
                        }

                        let event = TentpoleEvent(
                            type: compiled.type,
                            date: note.date,
                            month: monthFormatter.string(from: note.date),
                            noteId: note.id,
                            matchedText: matchedText
                        )
                        events.append(event)
                        break // One event type per note
                    }
                }
            }
        }

        return events.sorted { $0.date < $1.date }
    }

    /// Extract events grouped by month
    /// - Parameter notes: Array of clinical notes
    /// - Returns: Dictionary mapping month keys to events
    func extractEventsByMonth(from notes: [ClinicalNote]) -> [String: [TentpoleEvent]] {
        let allEvents = extractEvents(from: notes)
        return Dictionary(grouping: allEvents) { $0.month }
    }

    /// Get highest priority event per month (for timeline display)
    /// - Parameter notes: Array of clinical notes
    /// - Returns: Dictionary mapping month keys to the highest priority event
    func extractPrimaryEventPerMonth(from notes: [ClinicalNote]) -> [String: TentpoleEvent] {
        let eventsByMonth = extractEventsByMonth(from: notes)
        var primaryEvents: [String: TentpoleEvent] = [:]

        for (month, events) in eventsByMonth {
            // Sort by priority (lower = higher priority) and take first
            if let primary = events.min(by: { $0.type.priority < $1.type.priority }) {
                primaryEvents[month] = primary
            }
        }

        return primaryEvents
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
