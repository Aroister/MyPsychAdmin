//
//  ProgressTimelineDataBuilder.swift
//  MyPsychAdmin
//
//  Aggregates notes into monthly timeline data for progress visualization
//  Matches desktop progress_panel.py analyze_notes_for_progress()
//

import Foundation
import SwiftUI

// MARK: - Timeline Risk Level (matching desktop colors)

enum TimelineRiskLevel: String, CaseIterable {
    case quiet = "Quiet"
    case low = "Low"
    case moderate = "Moderate"
    case elevated = "Elevated"
    case high = "High"

    var color: Color {
        switch self {
        case .quiet: return Color(hex: "#2d5a3d")
        case .low: return Color(hex: "#22c55e")
        case .moderate: return Color(hex: "#f59e0b")
        case .elevated: return Color(hex: "#f97316")
        case .high: return Color(hex: "#ef4444")
        }
    }

    /// Calculate risk level from incident count
    static func from(incidentCount: Int) -> TimelineRiskLevel {
        switch incidentCount {
        case 0: return .quiet
        case 1...3: return .low
        case 4...8: return .moderate
        case 9...15: return .elevated
        default: return .high
        }
    }
}

// MARK: - Monthly Timeline Data

struct MonthlyTimelineData: Identifiable {
    let id = UUID()
    let month: String           // "YYYY-MM" format
    let label: String           // "MMM 'YY" format for display
    let date: Date              // First day of month
    let riskLevel: TimelineRiskLevel
    let totalIncidents: Int
    let violenceCount: Int
    let verbalCount: Int
    let noteCount: Int
    let incidents: [RiskIncident]
    let tentpoleEvents: [TentpoleEvent]
}

// MARK: - Progress Timeline Data Builder

class ProgressTimelineDataBuilder {

    private static let monthKeyFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM"
        return df
    }()

    private static let monthLabelFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM ''yy"
        return df
    }()

    /// Build timeline data from notes and risk extraction results
    /// - Parameters:
    ///   - notes: Array of clinical notes
    ///   - risks: Extracted risks from RiskExtractor
    /// - Returns: Array of monthly timeline data sorted chronologically
    static func buildTimelineData(
        from notes: [ClinicalNote],
        risks: ExtractedRisks
    ) -> [MonthlyTimelineData] {
        // Extract tentpole events
        let allEvents = TentpoleEventExtractor.shared.extractEvents(from: notes)
        let eventsByMonth = Dictionary(grouping: allEvents) { $0.month }

        // Group notes by month
        var notesByMonth: [String: [ClinicalNote]] = [:]
        for note in notes {
            let monthKey = monthKeyFormatter.string(from: note.date)
            notesByMonth[monthKey, default: []].append(note)
        }

        // Group incidents by month
        var incidentsByMonth: [String: [RiskIncident]] = [:]
        for incident in risks.incidents {
            let monthKey = monthKeyFormatter.string(from: incident.date)
            incidentsByMonth[monthKey, default: []].append(incident)
        }

        // Get all unique months
        var allMonths = Set<String>()
        allMonths.formUnion(notesByMonth.keys)
        allMonths.formUnion(incidentsByMonth.keys)
        allMonths.formUnion(eventsByMonth.keys)

        // Build monthly data
        var monthlyData: [MonthlyTimelineData] = []

        for monthKey in allMonths {
            guard let date = monthKeyFormatter.date(from: monthKey) else { continue }

            let incidents = incidentsByMonth[monthKey] ?? []
            let events = eventsByMonth[monthKey] ?? []
            let monthNotes = notesByMonth[monthKey] ?? []

            // Count violence and verbal incidents
            let violenceCount = incidents.filter { $0.category == .physicalAggression }.count
            let verbalCount = incidents.filter { $0.category == .verbalAggression }.count
            let totalIncidents = incidents.count

            let data = MonthlyTimelineData(
                month: monthKey,
                label: monthLabelFormatter.string(from: date),
                date: date,
                riskLevel: TimelineRiskLevel.from(incidentCount: totalIncidents),
                totalIncidents: totalIncidents,
                violenceCount: violenceCount,
                verbalCount: verbalCount,
                noteCount: monthNotes.count,
                incidents: incidents,
                tentpoleEvents: events
            )
            monthlyData.append(data)
        }

        // Sort chronologically
        return monthlyData.sorted { $0.date < $1.date }
    }

    /// Filter timeline data to recent months
    /// - Parameters:
    ///   - data: Full timeline data
    ///   - months: Number of months to include (nil for all)
    /// - Returns: Filtered timeline data
    static func filterToRecentMonths(
        _ data: [MonthlyTimelineData],
        months: Int?
    ) -> [MonthlyTimelineData] {
        guard let months = months, !data.isEmpty else { return data }

        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(
            byAdding: .month,
            value: -months,
            to: Date()
        ) else {
            return data
        }

        return data.filter { $0.date >= cutoffDate }
    }

    /// Get statistics for timeline data
    static func getStatistics(from data: [MonthlyTimelineData]) -> TimelineStatistics {
        let totalNotes = data.reduce(0) { $0 + $1.noteCount }
        let totalIncidents = data.reduce(0) { $0 + $1.totalIncidents }
        let totalViolence = data.reduce(0) { $0 + $1.violenceCount }
        let totalVerbal = data.reduce(0) { $0 + $1.verbalCount }
        let totalEvents = data.reduce(0) { $0 + $1.tentpoleEvents.count }

        let startDate = data.first?.date
        let endDate = data.last?.date

        return TimelineStatistics(
            totalMonths: data.count,
            totalNotes: totalNotes,
            totalIncidents: totalIncidents,
            totalViolence: totalViolence,
            totalVerbal: totalVerbal,
            totalEvents: totalEvents,
            startDate: startDate,
            endDate: endDate
        )
    }
}

// MARK: - Timeline Statistics

struct TimelineStatistics {
    let totalMonths: Int
    let totalNotes: Int
    let totalIncidents: Int
    let totalViolence: Int
    let totalVerbal: Int
    let totalEvents: Int
    let startDate: Date?
    let endDate: Date?

    var dateRangeString: String {
        guard let start = startDate, let end = endDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

// MARK: - Timeline Zoom Level

enum TimelineZoom: String, CaseIterable, Identifiable {
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case twoYears = "2Y"
    case fiveYears = "5Y"
    case all = "All"

    var id: String { rawValue }

    /// Number of months to show (nil for all)
    var monthCount: Int? {
        switch self {
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .oneYear: return 12
        case .twoYears: return 24
        case .fiveYears: return 60
        case .all: return nil
        }
    }
}
