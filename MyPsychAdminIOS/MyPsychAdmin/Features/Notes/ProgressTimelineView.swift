//
//  ProgressTimelineView.swift
//  MyPsychAdmin
//
//  Interactive progress timeline visualization matching desktop progress_panel.py
//  Features: risk-level bars, event markers, violence/verbal markers, zoom controls
//

import SwiftUI

// MARK: - Progress Timeline View

struct ProgressTimelineView: View {
    let monthlyData: [MonthlyTimelineData]
    @Binding var selectedMonth: String?
    var onMonthTap: ((MonthlyTimelineData) -> Void)?
    var onEventTap: ((TentpoleEvent) -> Void)?

    @State private var zoomLevel: TimelineZoom = .all

    // Layout constants
    private let barHeight: CGFloat = 44
    private let markersHeight: CGFloat = 26
    private let axisHeight: CGFloat = 24
    private let backgroundColor = Color(hex: "#1a1a2e")

    // Marker colors (matching desktop)
    private let eventMarkerColor = Color(hex: "#64B5F6")    // Blue diamond
    private let violenceMarkerColor = Color(hex: "#EF5350") // Red triangle
    private let verbalMarkerColor = Color(hex: "#AB47BC")   // Purple circle

    private var filteredData: [MonthlyTimelineData] {
        ProgressTimelineDataBuilder.filterToRecentMonths(monthlyData, months: zoomLevel.monthCount)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Zoom controls
            zoomControlBar

            // Timeline content
            timelineContent
                .frame(height: barHeight + markersHeight + axisHeight)
                .background(backgroundColor)

            // Legend
            legendBar
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    // MARK: - Zoom Control Bar

    private var zoomControlBar: some View {
        HStack(spacing: 8) {
            ForEach(TimelineZoom.allCases) { zoom in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        zoomLevel = zoom
                    }
                } label: {
                    Text(zoom.rawValue)
                        .font(.system(size: 12, weight: zoom == zoomLevel ? .semibold : .regular))
                        .foregroundColor(zoom == zoomLevel ? .white : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            zoom == zoomLevel
                                ? Color.blue
                                : Color(UIColor.tertiarySystemFill)
                        )
                        .cornerRadius(6)
                }
            }

            Spacer()

            // Statistics summary
            let stats = ProgressTimelineDataBuilder.getStatistics(from: filteredData)
            Text("\(stats.totalIncidents) incidents")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Timeline Content

    private var timelineContent: some View {
        GeometryReader { geometry in
            let totalWidth = max(geometry.size.width, CGFloat(filteredData.count) * 24)

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Risk level bars
                    riskBarsView(totalWidth: totalWidth)
                        .frame(height: barHeight)

                    // Markers row
                    markersView(totalWidth: totalWidth)
                        .frame(height: markersHeight)

                    // Date axis
                    dateAxisView(totalWidth: totalWidth)
                        .frame(height: axisHeight)
                }
                .frame(width: totalWidth)
            }
        }
    }

    // MARK: - Risk Bars View

    private func riskBarsView(totalWidth: CGFloat) -> some View {
        let barWidth = totalWidth / CGFloat(max(1, filteredData.count))

        return HStack(spacing: 0) {
            ForEach(filteredData) { data in
                riskBar(for: data, width: barWidth)
            }
        }
    }

    private func riskBar(for data: MonthlyTimelineData, width: CGFloat) -> some View {
        let isSelected = selectedMonth == data.month

        return data.riskLevel.color
            .frame(width: width, height: barHeight)
            .overlay(
                // Show incident count if bar is wide enough
                Group {
                    if width > 28 && data.totalIncidents > 0 {
                        Text("\(data.totalIncidents)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            )
            .overlay(
                // Selection highlight
                Rectangle()
                    .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
            )
            .onTapGesture {
                selectedMonth = data.month
                onMonthTap?(data)
            }
    }

    // MARK: - Markers View

    private func markersView(totalWidth: CGFloat) -> some View {
        let barWidth = totalWidth / CGFloat(max(1, filteredData.count))

        return ZStack(alignment: .leading) {
            // Background
            Rectangle()
                .fill(backgroundColor.opacity(0.8))

            // Markers for each month
            HStack(spacing: 0) {
                ForEach(filteredData) { data in
                    monthMarkers(for: data, width: barWidth)
                }
            }
        }
    }

    private func monthMarkers(for data: MonthlyTimelineData, width: CGFloat) -> some View {
        HStack(spacing: 2) {
            Spacer(minLength: 0)

            // Event marker (diamond) - highest priority event only
            if let event = data.tentpoleEvents.min(by: { $0.type.priority < $1.type.priority }) {
                DiamondMarker()
                    .fill(eventMarkerColor)
                    .frame(width: 10, height: 10)
                    .onTapGesture {
                        onEventTap?(event)
                    }
            }

            // Violence marker (triangle)
            if data.violenceCount > 0 {
                let size = min(12, CGFloat(6 + data.violenceCount))
                TriangleMarker()
                    .fill(violenceMarkerColor)
                    .frame(width: size, height: size)
            }

            // Verbal marker (circle)
            if data.verbalCount > 0 {
                let size = min(10, CGFloat(5 + data.verbalCount))
                Circle()
                    .fill(verbalMarkerColor)
                    .frame(width: size, height: size)
            }

            Spacer(minLength: 0)
        }
        .frame(width: width)
    }

    // MARK: - Date Axis View

    private func dateAxisView(totalWidth: CGFloat) -> some View {
        let barWidth = totalWidth / CGFloat(max(1, filteredData.count))
        let ticks = generateDateTicks()

        return ZStack(alignment: .topLeading) {
            // Background
            Rectangle()
                .fill(Color(hex: "#252547"))

            // Tick marks and labels
            HStack(spacing: 0) {
                ForEach(filteredData.indices, id: \.self) { index in
                    let data = filteredData[index]
                    let showLabel = ticks.contains(data.month)

                    ZStack {
                        if showLabel {
                            VStack(spacing: 2) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.6))
                                    .frame(width: 1, height: 4)

                                Text(data.label)
                                    .font(.system(size: 8))
                                    .foregroundColor(.gray)
                                    .fixedSize()
                            }
                        }
                    }
                    .frame(width: barWidth, height: axisHeight)
                }
            }
        }
    }

    private func generateDateTicks() -> Set<String> {
        guard !filteredData.isEmpty else { return [] }

        let count = filteredData.count
        var ticks = Set<String>()

        // Determine tick interval based on count
        let interval: Int
        if count > 48 {
            interval = 12  // Yearly
        } else if count > 24 {
            interval = 6   // Every 6 months
        } else if count > 12 {
            interval = 3   // Quarterly
        } else if count > 6 {
            interval = 2   // Bi-monthly
        } else {
            interval = 1   // Monthly
        }

        // Add ticks at intervals
        for (index, data) in filteredData.enumerated() {
            if index % interval == 0 {
                ticks.insert(data.month)
            }
        }

        // Always include first and last
        if let first = filteredData.first {
            ticks.insert(first.month)
        }
        if let last = filteredData.last {
            ticks.insert(last.month)
        }

        return ticks
    }

    // MARK: - Legend Bar

    private var legendBar: some View {
        HStack(spacing: 16) {
            // Risk level legend
            HStack(spacing: 4) {
                ForEach(TimelineRiskLevel.allCases, id: \.self) { level in
                    HStack(spacing: 3) {
                        Circle()
                            .fill(level.color)
                            .frame(width: 8, height: 8)
                        Text(level.rawValue)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Marker legend
            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    DiamondMarker()
                        .fill(eventMarkerColor)
                        .frame(width: 8, height: 8)
                    Text("Event")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 3) {
                    TriangleMarker()
                        .fill(violenceMarkerColor)
                        .frame(width: 8, height: 8)
                    Text("Violence")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 3) {
                    Circle()
                        .fill(verbalMarkerColor)
                        .frame(width: 8, height: 8)
                    Text("Verbal")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Diamond Shape

struct DiamondMarker: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let halfWidth = rect.width / 2
        let halfHeight = rect.height / 2

        path.move(to: CGPoint(x: center.x, y: center.y - halfHeight))
        path.addLine(to: CGPoint(x: center.x + halfWidth, y: center.y))
        path.addLine(to: CGPoint(x: center.x, y: center.y + halfHeight))
        path.addLine(to: CGPoint(x: center.x - halfWidth, y: center.y))
        path.closeSubpath()

        return path
    }
}

// MARK: - Triangle Shape

struct TriangleMarker: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

// MARK: - Month Detail Popup

struct MonthDetailPopup: View {
    let monthData: MonthlyTimelineData
    var onIncidentTap: ((RiskIncident) -> Void)?
    var onEventTap: ((TentpoleEvent) -> Void)?
    @Environment(\.dismiss) private var dismiss

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd MMM"
        return df
    }()

    var body: some View {
        NavigationStack {
            List {
                // Events section
                if !monthData.tentpoleEvents.isEmpty {
                    Section("Key Events") {
                        ForEach(monthData.tentpoleEvents) { event in
                            HStack {
                                DiamondMarker()
                                    .fill(event.type.color)
                                    .frame(width: 12, height: 12)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.type.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(dateFormatter.string(from: event.date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onEventTap?(event)
                            }
                        }
                    }
                }

                // Incidents section
                if !monthData.incidents.isEmpty {
                    Section("Incidents (\(monthData.incidents.count))") {
                        ForEach(monthData.incidents) { incident in
                            HStack {
                                Circle()
                                    .fill(incident.severity.color)
                                    .frame(width: 8, height: 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(incident.category.rawValue)
                                        .font(.subheadline)
                                    Text(dateFormatter.string(from: incident.date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text(incident.severity.rawValue)
                                    .font(.caption)
                                    .foregroundColor(incident.severity.color)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onIncidentTap?(incident)
                            }
                        }
                    }
                }

                // Summary section
                Section("Summary") {
                    HStack {
                        Text("Notes")
                        Spacer()
                        Text("\(monthData.noteCount)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Total Incidents")
                        Spacer()
                        Text("\(monthData.totalIncidents)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Violence")
                        Spacer()
                        Text("\(monthData.violenceCount)")
                            .foregroundColor(.red)
                    }
                    HStack {
                        Text("Verbal Aggression")
                        Spacer()
                        Text("\(monthData.verbalCount)")
                            .foregroundColor(.purple)
                    }
                }
            }
            .navigationTitle(monthData.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
