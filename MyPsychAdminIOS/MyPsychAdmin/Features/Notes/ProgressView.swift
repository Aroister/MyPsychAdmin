//
//  ProgressView.swift
//  MyPsychAdmin
//
//  Progress panel matching desktop app's history_summary_engine style
//  - Detailed clinical narrative with clickable note references
//

import SwiftUI

// MARK: - Timeline Risk Level (for monthly timeline visualization)
enum TimelineRiskLevel: String, CaseIterable {
    case quiet = "Quiet"
    case low = "Low"
    case moderate = "Moderate"
    case elevated = "Elevated"
    case high = "High"

    var color: Color {
        switch self {
        case .quiet: return Color(red: 0.18, green: 0.35, blue: 0.24)
        case .low: return Color(red: 0.13, green: 0.77, blue: 0.37)
        case .moderate: return Color(red: 0.96, green: 0.62, blue: 0.04)
        case .elevated: return Color(red: 0.98, green: 0.45, blue: 0.09)
        case .high: return Color(red: 0.94, green: 0.27, blue: 0.27)
        }
    }

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
    let month: String
    let label: String
    let date: Date
    let riskLevel: TimelineRiskLevel
    let totalIncidents: Int
    let violenceCount: Int
    let verbalCount: Int
    let noteCount: Int
    let incidents: [RiskIncident]
    let tentpoleEvents: [TentpoleEvent]
}

// MARK: - Tentpole Event (significant events in timeline)
struct TentpoleEvent: Identifiable {
    let id = UUID()
    let date: Date
    let type: TentpoleType
    let description: String

    enum TentpoleType: String {
        case admission = "Admission"
        case discharge = "Discharge"
        case section136 = "Section 136"
        case seclusion = "Seclusion"
        case awol = "AWOL"
        case restraint = "Restraint"
        case other = "Event"

        var icon: String {
            switch self {
            case .admission: return "arrow.down.circle.fill"
            case .discharge: return "arrow.up.circle.fill"
            case .section136: return "exclamationmark.shield.fill"
            case .seclusion: return "lock.fill"
            case .awol: return "figure.walk"
            case .restraint: return "hand.raised.fill"
            case .other: return "star.fill"
            }
        }

        var color: Color {
            switch self {
            case .admission: return .blue
            case .discharge: return .green
            case .section136: return .red
            case .seclusion: return .purple
            case .awol: return .orange
            case .restraint: return .pink
            case .other: return .gray
            }
        }
    }
}

// MARK: - Narrative Models

/// A reference to a specific note that backs up an assertion
struct InlineReference: Identifiable {
    let id = UUID()
    let noteId: UUID
    let highlightText: String? // Text to highlight when showing the note
}

/// Text formatting options
struct TextFormat: OptionSet {
    let rawValue: Int
    static let bold = TextFormat(rawValue: 1 << 0)
    static let italic = TextFormat(rawValue: 1 << 1)
}

/// A segment of narrative text - either plain or with a reference
enum NarrativeSegment: Identifiable {
    case plain(String, TextFormat)
    case referenced(text: String, reference: InlineReference, format: TextFormat)

    var id: String {
        switch self {
        case .plain(let text, _): return "plain-\(text.prefix(20))-\(UUID().uuidString.prefix(8))"
        case .referenced(let text, let ref, _): return "ref-\(ref.id)-\(text.prefix(20))"
        }
    }

    // Convenience for plain text without formatting
    static func text(_ string: String) -> NarrativeSegment {
        .plain(string, [])
    }

    static func bold(_ string: String) -> NarrativeSegment {
        .plain(string, .bold)
    }
}

struct NarrativeSection: Identifiable {
    let id = UUID()
    let title: String?
    let content: [NarrativeParagraph]
}

struct NarrativeParagraph: Identifiable {
    let id = UUID()
    let segments: [NarrativeSegment]

    // Legacy support
    var text: String {
        segments.map { segment in
            switch segment {
            case .plain(let t, _): return t
            case .referenced(let t, _, _): return t
            }
        }.joined()
    }

    var linkedNoteIds: [UUID] {
        segments.compactMap { segment in
            if case .referenced(_, let ref, _) = segment {
                return ref.noteId
            }
            return nil
        }
    }

    // Convenience initializer for plain text
    init(text: String) {
        self.segments = [.plain(text, [])]
    }

    // Full initializer
    init(segments: [NarrativeSegment]) {
        self.segments = segments
    }

    // Legacy initializer for backwards compatibility
    init(text: String, linkedNoteIds: [UUID], highlightRanges: [Range<String.Index>]) {
        // Convert to segments - create references for linked notes
        if linkedNoteIds.isEmpty {
            self.segments = [.plain(text, [])]
        } else {
            // For legacy, just use first note as a reference at the end
            var segs: [NarrativeSegment] = [.plain(text, [])]
            self.segments = segs
        }
    }
}

// MARK: - Progress Notes View
struct ProgressNotesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SharedDataStore.self) private var sharedData
    @State private var narrativeSections: [NarrativeSection] = []
    @State private var isLoading = true
    @State private var selectedNoteId: UUID?
    @State private var selectedHighlightText: String?
    @State private var showNoteSheet = false
    @State private var referenceMap: [UUID: Int] = [:] // Maps note IDs to reference numbers

    // Timeline state
    @State private var monthlyTimelineData: [MonthlyTimelineData] = []
    @State private var selectedTimelineMonth: String?
    @State private var showMonthPopup = false
    @State private var selectedMonthData: MonthlyTimelineData?

    // Export state
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var showingExportError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else if narrativeSections.isEmpty {
                    emptyView
                } else {
                    narrativeContent
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Export button disabled - ProgressDOCXExporter not in project
                // ToolbarItem(placement: .navigationBarLeading) { ... }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await generateNarrative()
            }
            .sheet(isPresented: $showNoteSheet) {
                if let noteId = selectedNoteId,
                   let note = sharedData.notes.first(where: { $0.id == noteId }) {
                    NoteDetailSheet(note: note, highlightText: selectedHighlightText)
                }
            }
            // Timeline popup disabled - missing ProgressTimelineDataBuilder in project
            // .sheet(isPresented: $showMonthPopup) { ... }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Export Error", isPresented: $showingExportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Failed to generate Word document. Please try again.")
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Generating narrative...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Empty View
    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Progress Data", systemImage: "chart.line.uptrend.xyaxis")
        } description: {
            Text("Import clinical notes to generate progress narrative.")
        }
    }

    // MARK: - Narrative Content
    private var narrativeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Timeline visualization disabled - missing ProgressTimelineDataBuilder in project
                // if !monthlyTimelineData.isEmpty { ... }

                // Narrative sections
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(narrativeSections) { section in
                        narrativeSectionView(section)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Narrative Section View
    private func narrativeSectionView(_ section: NarrativeSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = section.title {
                Text(title)
                    .font(.system(.headline, design: .monospaced))
                    .fontWeight(.bold)
                    .padding(.top, 16)
            }

            ForEach(section.content) { paragraph in
                narrativeParagraphView(paragraph)
            }
        }
    }

    // MARK: - Narrative Paragraph View
    private func narrativeParagraphView(_ paragraph: NarrativeParagraph) -> some View {
        // Build attributed text with inline superscript references
        FlowingTextView(
            segments: paragraph.segments,
            referenceMap: referenceMap,
            onReferenceTap: { noteId, highlightText in
                selectedNoteId = noteId
                selectedHighlightText = highlightText
                showNoteSheet = true
            }
        )
    }

}

// MARK: - Flowing Text View with Inline References
struct FlowingTextView: View {
    let segments: [NarrativeSegment]
    let referenceMap: [UUID: Int]
    let onReferenceTap: (UUID, String?) -> Void

    @State private var tappedReference: InlineReference?

    var body: some View {
        // Build AttributedString with tappable links for each reference
        Text(buildAttributedString())
            .font(.system(.body, design: .monospaced))
            .environment(\.openURL, OpenURLAction { url in
                handleReferenceURL(url)
                return .handled
            })
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
    }

    private func buildAttributedString() -> AttributedString {
        var result = AttributedString()

        for segment in segments {
            switch segment {
            case .plain(let text, let format):
                var attr = AttributedString(text)
                if format.contains(.bold) {
                    attr.font = .system(.body, design: .monospaced).bold()
                }
                if format.contains(.italic) {
                    attr.font = (attr.font ?? .system(.body, design: .monospaced)).italic()
                }
                result += attr

            case .referenced(let text, let reference, let format):
                // Add the main text
                var textAttr = AttributedString(text)
                if format.contains(.bold) {
                    textAttr.font = .system(.body, design: .monospaced).bold()
                }
                if format.contains(.italic) {
                    textAttr.font = (textAttr.font ?? .system(.body, design: .monospaced)).italic()
                }
                result += textAttr

                // Add the reference number as a tappable link
                let refNum = referenceMap[reference.noteId] ?? 0
                var refAttr = AttributedString("[\(refNum)]")
                refAttr.font = .system(.caption2, design: .monospaced)
                refAttr.foregroundColor = .blue
                refAttr.baselineOffset = 6

                // Encode noteId and highlightText in URL
                let highlightEncoded = (reference.highlightText ?? "").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "mparef://\(reference.noteId.uuidString)?h=\(highlightEncoded)") {
                    refAttr.link = url
                }
                result += refAttr
            }
        }

        return result
    }

    private func handleReferenceURL(_ url: URL) {
        // Parse URL: mparef://{noteId}?h={highlightText}
        guard url.scheme == "mparef",
              let noteIdString = url.host,
              let noteId = UUID(uuidString: noteIdString) else {
            return
        }

        // Extract highlight text from query
        var highlightText: String? = nil
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            highlightText = queryItems.first(where: { $0.name == "h" })?.value
        }

        onReferenceTap(noteId, highlightText)
    }
}


// MARK: - Flow Layout for wrapping text with inline buttons
struct NarrativeFlowLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            if index < result.frames.count {
                let frame = result.frames[index]
                subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
            }
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                // Move to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))

            currentX += size.width
            lineHeight = max(lineHeight, size.height)
            totalWidth = max(totalWidth, currentX)
        }

        totalHeight = currentY + lineHeight
        return (CGSize(width: totalWidth, height: totalHeight), frames)
    }
}

// MARK: - Generate Narrative Extension
extension ProgressNotesView {
    func generateNarrative() async {
        let notes = sharedData.notes
        let patientInfo = sharedData.patientInfo

        guard !notes.isEmpty else {
            await MainActor.run {
                narrativeSections = []
                isLoading = false
            }
            return
        }

        // CHECK SHARED CACHE FIRST - if already generated (e.g., in PTR), use it
        if sharedData.hasValidNarrativeCache {
            await MainActor.run {
                narrativeSections = sharedData.cachedNarrativeSections
                referenceMap = sharedData.cachedNarrativeReferenceMap
                isLoading = false
                print("[ProgressNotesView] Using shared narrative cache")
            }
            return
        }

        print("[ProgressNotesView] Generating new narrative (will be cached for other views)")

        let result = await Task.detached(priority: .userInitiated) {
            // Build timeline episodes
            let episodes = TimelineBuilder.buildTimeline(from: notes, allNotes: notes)

            // Extract risks
            let risks = RiskExtractor.shared.extractRisks(from: notes)

            // Timeline data disabled - missing ProgressTimelineDataBuilder in project
            // let timelineData = ProgressTimelineDataBuilder.buildTimelineData(...)

            // Get patient name and pronouns
            let patientName = patientInfo.fullName.isEmpty ? "The patient" : patientInfo.fullName
            let pronouns = patientInfo.pronouns

            // Use the full desktop-style narrative engine with inline references
            let sections = generateProgressNarrativeWithReferences(
                patientName: patientName,
                pronouns: pronouns,
                episodes: episodes,
                risks: risks,
                notes: notes
            )

            // Build reference map - assign sequential numbers to each unique note ID
            var refMap: [UUID: Int] = [:]
            var refCounter = 1
            for section in sections {
                for paragraph in section.content {
                    for segment in paragraph.segments {
                        if case .referenced(_, let ref, _) = segment {
                            if refMap[ref.noteId] == nil {
                                refMap[ref.noteId] = refCounter
                                refCounter += 1
                            }
                        }
                    }
                }
            }

            // Get date range
            let allDates = notes.map { $0.date }
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            var dateRangeStr = ""
            if let minDate = allDates.min(), let maxDate = allDates.max() {
                dateRangeStr = "\(dateFormatter.string(from: minDate)) to \(dateFormatter.string(from: maxDate))"
            }

            return (sections, refMap, dateRangeStr, notes.count, notes.hashValue)
        }.value

        await MainActor.run {
            narrativeSections = result.0
            referenceMap = result.1
            // monthlyTimelineData disabled - missing ProgressTimelineDataBuilder
            isLoading = false

            // STORE IN SHARED CACHE for other views (PTR, etc.)
            sharedData.cachedNarrativeSections = result.0
            sharedData.cachedNarrativeReferenceMap = result.1
            sharedData.cachedNarrativeDateRange = result.2
            sharedData.cachedNarrativeEntryCount = result.3
            sharedData.cachedNarrativeNotesHash = result.4
            print("[ProgressNotesView] Narrative cached for sharing with other views")
        }
    }

    // MARK: - Export to Word (disabled - ProgressDOCXExporter not in project)
    // private func exportToWord() { ... }
}

#Preview {
    ProgressNotesView()
        .environment(SharedDataStore.shared)
}

// MARK: - Pattern Definitions (ported from desktop progress_panel.py)

/// Medication patterns for detection
let MEDICATION_PATTERNS: [(pattern: String, name: String)] = [
    // Antipsychotics
    ("\\b(olanzapine|zyprexa)\\b", "Olanzapine"),
    ("\\b(risperidone|risperdal)\\b", "Risperidone"),
    ("\\b(quetiapine|seroquel)\\b", "Quetiapine"),
    ("\\b(aripiprazole|abilify)\\b", "Aripiprazole"),
    ("\\b(clozapine|clozaril)\\b", "Clozapine"),
    ("\\b(haloperidol|haldol)\\b", "Haloperidol"),
    ("\\b(amisulpride|solian)\\b", "Amisulpride"),
    ("\\b(paliperidone|invega|xeplion)\\b", "Paliperidone"),
    ("\\b(lurasidone|latuda)\\b", "Lurasidone"),
    ("\\b(chlorpromazine|largactil)\\b", "Chlorpromazine"),
    ("\\b(flupentixol|depixol|fluanxol)\\b", "Flupentixol"),
    ("\\b(zuclopenthixol|clopixol)\\b", "Zuclopenthixol"),
    // Mood stabilisers
    ("\\b(lithium|priadel|camcolit)\\b", "Lithium"),
    ("\\b(valproate|depakote|epilim)\\b", "Valproate"),
    ("\\b(carbamazepine|tegretol)\\b", "Carbamazepine"),
    ("\\b(lamotrigine|lamictal)\\b", "Lamotrigine"),
    // Antidepressants
    ("\\b(sertraline|lustral)\\b", "Sertraline"),
    ("\\b(fluoxetine|prozac)\\b", "Fluoxetine"),
    ("\\b(mirtazapine|zispin)\\b", "Mirtazapine"),
    ("\\b(venlafaxine|efexor)\\b", "Venlafaxine"),
    ("\\b(duloxetine|cymbalta)\\b", "Duloxetine"),
    ("\\b(citalopram|cipramil)\\b", "Citalopram"),
    ("\\b(escitalopram|cipralex)\\b", "Escitalopram"),
    // Anxiolytics/Hypnotics
    ("\\b(lorazepam|ativan)\\b", "Lorazepam"),
    ("\\b(diazepam|valium)\\b", "Diazepam"),
    ("\\b(clonazepam|rivotril)\\b", "Clonazepam"),
    ("\\b(promethazine|phenergan)\\b", "Promethazine"),
    ("\\b(zopiclone|zimovane)\\b", "Zopiclone"),
    // Anticholinergics
    ("\\b(procyclidine|kemadrin)\\b", "Procyclidine"),
]

/// Community engagement patterns (therapy, clinics, activities, contact)
let COMMUNITY_ENGAGEMENT_PATTERNS: [(pattern: String, activity: String, category: String)] = [
    // Therapy
    ("\\bcbt\\b", "CBT", "therapy"),
    ("\\bdbt\\b", "DBT", "therapy"),
    ("\\b(mentalisation|mbt)\\b", "MBT", "therapy"),
    ("\\bemdr\\b", "EMDR", "therapy"),
    ("\\bschema\\s*(therapy)?\\b", "schema therapy", "therapy"),
    ("\\btrauma.{0,10}therapy\\b", "trauma-focused therapy", "therapy"),
    ("\\bindividual therapy\\b", "individual therapy", "therapy"),
    ("\\bgroup therapy\\b", "group therapy", "therapy"),
    ("\\bfamily therapy\\b", "family therapy", "therapy"),
    ("\\bsystemic\\s+(?:therapy|session)\\b", "systemic therapy", "therapy"),
    ("\\bart therapy\\b", "art therapy", "therapy"),
    ("\\bmusic therapy\\b", "music therapy", "therapy"),
    ("\\boccupational therapy\\b", "occupational therapy", "therapy"),
    ("\\b(psychology\\s+session|psychological\\s+therapy)\\b", "psychology", "therapy"),
    // Clinics
    ("\\b(depot clinic|injection clinic|clozapine clinic|lithium clinic)\\b", "depot/monitoring clinic", "clinic"),
    ("\\b(outpatient|opa|outpatient appointment)\\b", "outpatient clinic", "clinic"),
    ("\\b(blood|bloods|fbc|u&e|lft|clozapine level|lithium level)\\b", "blood monitoring", "clinic"),
    // Activities
    ("\\b(?:attend|engaged with)\\s+(?:the\\s+)?(?:day\\s+centre|resource\\s+centre)\\b", "day centre", "activity"),
    ("\\b(education|college|training)\\b", "education", "activity"),
    ("\\b(working\\s+(?:at|in|for)|started\\s+work|got\\s+a\\s+job|employed)\\b", "employment", "activity"),
    ("\\b(social group|activity group|recovery group|peer support)\\b", "group activities", "activity"),
    ("\\b(gym|swimming|sports|yoga|walking group)\\b", "exercise", "activity"),
    ("\\b(volunteer|volunteering)\\b", "volunteering", "activity"),
    // Contact people
    ("\\b(?:met with|seen by|visited by)\\s+(?:the\\s+)?(?:care co-?ordinator|cc)\\b", "care coordinator", "person"),
    ("\\b(?:care co-?ordinator|cc)\\s+(?:visit|contact|called|met)\\b", "care coordinator", "person"),
    ("\\b(?:cpn|community nurse)\\s+(?:visit|contact|called)\\b", "CPN", "person"),
    ("\\b(?:met with|seen by)\\s+(?:the\\s+)?(?:cpn|community nurse)\\b", "CPN", "person"),
    ("\\b(?:support worker|stw|recovery worker)\\s+(?:visit|contact)\\b", "support worker", "person"),
    ("\\b(?:social worker|sw)\\s+(?:visit|contact)\\b", "social worker", "person"),
    ("\\b(?:psychiatrist|consultant)\\s+(?:review|saw|visit)\\b", "psychiatrist", "person"),
    ("\\b(?:seen by|reviewed by)\\s+(?:the\\s+)?(?:psychiatrist|consultant)\\b", "psychiatrist", "person"),
    // Contact modes
    ("\\b(home visit|hv|visited at home|domiciliary)\\b", "home visit", "mode"),
    ("\\b(telephone|phone|call|rang|spoken to)\\b", "telephone", "mode"),
    ("\\b(clinic|attended|appointment)\\b", "clinic appointment", "mode"),
]

/// Crisis patterns
let COMMUNITY_CRISIS_PATTERNS: [(pattern: String, crisisType: String)] = [
    ("\\b(?:attended?|went to|presented to|taken to)\\s+(?:the\\s+)?(?:a&e|emergency department|casualty)\\b", "A&E attendance"),
    ("\\b(?:a&e|emergency department)\\s+(?:attendance|presentation)\\b", "A&E attendance"),
    ("\\b(htt|home treatment|crisis team|crisis service)\\b", "home treatment team"),
    ("\\b(crisis line|crisis call|samaritans)\\b", "crisis line contact"),
    ("\\b(crisis house|respite|sanctuary)\\b", "crisis respite"),
    ("\\bpolice\\s+(?:called|attended|involved|contact)\\b", "police involvement"),
    ("\\b(?:section\\s*136|s136|place of safety)\\b", "Section 136"),
]

/// Concern patterns
let COMMUNITY_CONCERN_PATTERNS: [(pattern: String, concernType: String)] = [
    ("\\b(non[- ]?complian|not taking medication|stopped medication|refusing medication)\\b", "medication non-compliance"),
    ("\\b(disengage|not engaging|missed.*appointment|dna|did not attend)\\b", "disengagement"),
    ("\\b(deteriorat|decline|relaps)\\b", "deterioration"),
    ("\\b(safeguard|vulnerable|exploitation|abuse)\\b", "safeguarding"),
    ("\\b(substance|alcohol|cannabis|drug use|intoxicat)\\b", "substance use"),
    ("\\b(risk.*increas|increas.*risk|elevated risk)\\b", "increased risk"),
]

/// Admission trigger patterns
let ADMISSION_TRIGGER_PATTERNS: [(pattern: String, trigger: String)] = [
    ("\\b(suicid|overdose|self[- ]?harm|cut.*self|harm.*self)\\b", "self-harm/suicidal ideation"),
    ("\\b(assault|attack|hit|punch|kick|bite|violent)\\b", "violence"),
    ("\\b(threaten|intimidat|verbal.*threat)\\b", "threatening behaviour"),
    ("\\b(relaps|deteriorat|decompens)\\b", "relapse/deterioration"),
    ("\\b(non[- ]?complian|stopped.*medication|off.*medication|refusing.*medication)\\b", "medication non-compliance"),
    ("\\b(psycho|hallucin|delusion|paranoi|thought disorder)\\b", "psychotic symptoms"),
    ("\\b(manic|elat|grandiose|pressure|flight of ideas)\\b", "manic symptoms"),
    ("\\b(depressed|low mood|hopeless|worthless)\\b", "depressive symptoms"),
    ("\\b(police|section 136|s136|place of safety)\\b", "police involvement"),
    ("\\b(safeguard|vulnerable|exploitation)\\b", "safeguarding concerns"),
]

/// Presenting complaint patterns
let PRESENTING_COMPLAINT_PATTERNS: [(pattern: String, complaint: String)] = [
    ("\\b(low[\\s\\-]*mood|depressed|feeling[\\s\\-]*low)\\b", "low mood"),
    ("\\b(hear(?:ing)?[\\s\\-]*voice|voices|auditory[\\s\\-]*hallucin)\\b", "hearing voices"),
    ("\\b(jumbled[\\s\\-]*thought|thought[\\s\\-]*disorder|disorganis)\\b", "disorganised thinking"),
    ("\\b(paranoi|persecutor|being[\\s\\-]*watch|being[\\s\\-]*follow)\\b", "paranoid ideation"),
    ("\\b(suicid|self[- ]?harm|harm[\\s\\-]*self|overdose)\\b", "suicidal ideation/self-harm"),
    ("\\b(agitat|restless|pacing|unable to sit)\\b", "agitation"),
    ("\\b(not sleeping|insomnia|sleep.*disturb|poor sleep)\\b", "sleep disturbance"),
    ("\\b(not eating|poor appetite|weight loss|refusing food)\\b", "reduced appetite"),
    ("\\b(manic|elat|grandiose|pressured speech)\\b", "elevated/manic symptoms"),
    ("\\b(catatoni|mute|not speaking|withdrawn)\\b", "catatonic/withdrawn"),
]

/// Notable incident patterns (seclusion, response team, etc.)
let NOTABLE_INCIDENT_PATTERNS: [(pattern: String, incidentType: String)] = [
    ("\\b(seclusion|secluded)\\b", "seclusion"),
    ("\\b(response team|emergency team|code)\\b", "response team"),
    ("\\b(restrain|held|physical intervention|pi\\b)\\b", "restraint"),
    ("\\b(rapid tranquil|rt\\b|im medication)\\b", "rapid tranquillisation"),
    ("\\b(abscon|awol|left.*without|missing)\\b", "absconding"),
]

/// Improvement factor patterns
let IMPROVEMENT_PATTERNS: [(pattern: String, factor: String)] = [
    ("\\b(accept.*medication|taking.*medication|compliant.*medication|adherent)\\b", "medication acceptance"),
    ("\\b(engag.*therapy|attend.*therapy|engag.*psychology)\\b", "therapy engagement"),
    ("\\b(insight.*improv|develop.*insight|recogni.*ill)\\b", "improved insight"),
    ("\\b(mood.*improv|mood.*stabl|euthymi|brighter)\\b", "mood improvement"),
    ("\\b(sleep.*improv|sleeping.*better|sleep.*normal)\\b", "improved sleep"),
    ("\\b(eating.*improv|appetite.*improv|eating.*well)\\b", "improved appetite"),
    ("\\b(no.*incident|incident.*free|no.*aggress)\\b", "reduced incidents"),
    ("\\b(engag.*activi|attend.*group|participat)\\b", "activity engagement"),
    ("\\b(leave.*success|took.*leave|unescorted.*leave)\\b", "successful leave"),
    ("\\b(family.*visit|contact.*family|visit.*from)\\b", "family contact"),
]

// MARK: - Data Models

struct AdmissionDetails {
    // Each tuple now includes matchedSnippet - the actual text from the note for robust highlighting
    var triggers: [(trigger: String, noteId: UUID, matchedSnippet: String)] = []
    var presentingComplaints: [(complaint: String, date: Date, noteId: UUID, matchedSnippet: String)] = []
    var legalStatus: String?
    var legalStatusNoteId: UUID?
    var legalStatusSnippet: String?
    var source: String?
    var sourceNoteId: UUID?
    var sourceSnippet: String?
    var medicationsBefore: [(name: String, date: Date)] = []
    var medicationsDuring: [(name: String, date: Date, noteId: UUID, matchedSnippet: String)] = []
    var medicationsAfter: [(name: String, date: Date)] = []
    var medicationChanges: [(name: String, noteId: UUID, matchedSnippet: String)] = [] // Newly commenced medications with source
    var keyIncidents: [(type: String, date: Date, reason: String?, snippet: String)] = []
    var notableIncidents: [(type: String, date: Date, reason: String?, noteId: UUID, matchedSnippet: String)] = []
    var improvementFactors: [(factor: String, date: Date, noteId: UUID, matchedSnippet: String)] = []
    var successfulLeave: (date: Date, noteId: UUID, matchedSnippet: String)?
    var dischargeMedications: [String] = []
    var dischargeNoteId: UUID?
    var dischargeSnippet: String?
    var firstNoteId: UUID?
    var firstNoteSnippet: String? // Snippet from admission note
}

struct CommunityDetails {
    var medications: [(name: String, date: Date)] = []
    var psychology: [(type: String, date: Date)] = []
    var clinics: [(type: String, date: Date)] = []
    var activities: [(type: String, date: Date)] = []
    var contactPeople: [String: (count: Int, date: Date)] = [:]
    var contactModes: [String: (count: Int, date: Date)] = [:]
    var crisisEvents: [(type: String, date: Date, summary: String)] = []
    var concerns: [(type: String, date: Date)] = []
    var incidents: [(type: String, date: Date)] = []
    var substanceMisuse: [(type: String, date: Date)] = []
}

// MARK: - Negation Detection

/// Check if a match is negated (e.g., "no self-harm", "denied suicidal ideation")
func isNegated(text: String, matchRange: Range<String.Index>) -> Bool {
    // Get context before the match (up to 80 chars for longer negation phrases)
    let startDistance = text.distance(from: text.startIndex, to: matchRange.lowerBound)
    let contextStart = text.index(text.startIndex, offsetBy: max(0, startDistance - 80))
    let beforeText = String(text[contextStart..<matchRange.lowerBound]).lowercased()

    // Negation patterns that must appear RIGHT BEFORE the match (ending with $)
    let immediateNegationPatterns = [
        "\\b(no|nil|none|denies?|denied|without|lacks?)\\s*$",
        "\\bno\\s+(evidence|history|signs?|indication)\\s+of\\s*$",
        "\\b(not\\s+noted|not\\s+reported|not\\s+observed)\\s*$",
        "\\bdenied\\s+(any|all)?\\s*$",
        "\\bwith\\s+no\\s*$",
        "\\bno\\s+need\\s+(for|to)\\s*$",
        "\\bavoid(ed|ing)?\\s*$",
        "\\bwithout\\s+(need(ing)?\\s+)?(for\\s+)?$",
        "\\bno\\s+(incidents?|episodes?)\\s+(of|requiring|involving)\\s*$",
        "\\bmanaged\\s+without\\s*$",
    ]

    for pattern in immediateNegationPatterns {
        if beforeText.range(of: pattern, options: .regularExpression) != nil {
            return true
        }
    }

    // Also check the FULL SENTENCE for negation patterns (not just immediately before)
    // Get the sentence containing the match
    let textNS = text as NSString
    let matchStart = text.distance(from: text.startIndex, to: matchRange.lowerBound)

    var sentStart = textNS.range(of: ".", options: .backwards, range: NSRange(location: 0, length: matchStart)).location
    if sentStart == NSNotFound { sentStart = 0 } else { sentStart += 1 }

    var sentEnd = textNS.range(of: ".", range: NSRange(location: matchStart, length: textNS.length - matchStart)).location
    if sentEnd == NSNotFound { sentEnd = textNS.length }

    let sentence = textNS.substring(with: NSRange(location: sentStart, length: sentEnd - sentStart)).lowercased()

    // Sentence-level negation patterns - if the SENTENCE contains these patterns, it's negated
    let sentenceNegationPatterns = [
        // "did not want to be secluded" - CRITICAL FIX
        "\\b(did|does|do)\\s+not\\s+(want|wish|feel).*\\b(seclu|restrain|isolat)",
        "\\b(didn't|doesn't|don't)\\s+(want|wish|feel).*\\b(seclu|restrain|isolat)",
        // "she did not want to be" patterns
        "\\b(did|does|do)\\s+not\\s+(want|wish|need|require)\\s+to\\s+be\\b",
        "\\b(didn't|doesn't|don't)\\s+(want|wish|need|require)\\s+to\\s+be\\b",
        // "no need for seclusion" anywhere in sentence
        "\\bno\\s+need\\s+(for|to)\\s+.*\\b(seclu|restrain)",
        "\\b(was|were)\\s+no(t)?\\s+(need|requirement)\\s+(for|to)\\s+.*\\b(seclu|restrain)",
        // "without requiring seclusion"
        "\\bwithout\\s+(requiring|needing|the\\s+need\\s+for)\\s+.*\\b(seclu|restrain)",
        // "did not need seclusion"
        "\\b(did|does|has|had)\\s+not\\s+(need|require)\\s+.*\\b(seclu|restrain)",
        // "refused seclusion" / "declined seclusion"
        "\\b(refused?|declined?|rejected?)\\s+.*\\b(seclu|restrain)",
        // "was not secluded" / "were not restrained"
        "\\b(was|were|is|are|has\\s+been|had\\s+been)\\s+not\\s+.*\\b(seclu|restrain)",
        // "has not been" / "had not been"
        "\\b(has|had|have)\\s+not\\s+been\\s+.*\\b(seclu|restrain)",
        // "not requiring" / "not needing"
        "\\bnot\\s+(requiring|needing)\\s+.*\\b(seclu|restrain)",
        // "there was no seclusion"
        "\\b(there\\s+)?(was|were)\\s+no\\s+.*\\b(seclu|restrain)",
        // "avoided seclusion"
        "\\b(avoided?|prevented?)\\s+.*\\b(seclu|restrain)",
    ]

    for pattern in sentenceNegationPatterns {
        if sentence.range(of: pattern, options: .regularExpression) != nil {
            return true
        }
    }

    return false
}

/// Check if a match is historical or refers to a past event (not current)
func isHistoricalOrContextual(text: String, matchRange: Range<String.Index>) -> Bool {
    // Get the sentence containing the match
    let matchStart = text.distance(from: text.startIndex, to: matchRange.lowerBound)
    let textNS = text as NSString

    var sentStart = textNS.range(of: ".", options: .backwards, range: NSRange(location: 0, length: matchStart)).location
    if sentStart == NSNotFound { sentStart = 0 } else { sentStart += 1 }

    var sentEnd = textNS.range(of: ".", range: NSRange(location: matchStart, length: textNS.length - matchStart)).location
    if sentEnd == NSNotFound { sentEnd = textNS.length }

    let sentence = textNS.substring(with: NSRange(location: sentStart, length: sentEnd - sentStart)).lowercased()

    // Historical patterns - these indicate the match is about past events or context
    let historicalPatterns = [
        "\\b(when|whilst|while)\\s+in\\s+seclusion\\b",      // "when in seclusion" = talking about events during seclusion
        "\\bprior\\s+to\\s+seclusion\\b",                    // "prior to seclusion" = before seclusion
        "\\b(after|following)\\s+seclusion\\b",              // "after seclusion" = events after seclusion
        "\\btried\\s+to\\s+(restrain|seclude)\\b",           // "tried to seclude" = attempted, not actual
        "\\b(risk|past|forensic|substance|personal|family)\\s+history\\b",
        "\\bh/?o\\s+",                                        // "h/o" = history of
        "\\b(had|previously|in\\s+the\\s+past|used\\s+to|history\\s+of)\\b",
        "\\b(when|during|while)\\s+(he|she|they|his|her|their)?\\s*(was|were)\\b",
        "\\byears?\\s+ago\\b",
        "\\bat\\s+that\\s+time\\b",
        "\\bon\\s+that\\s+occasion\\b",
    ]

    for pattern in historicalPatterns {
        if sentence.range(of: pattern, options: .regularExpression) != nil {
            return true
        }
    }

    return false
}

/// Check if text contains adverse reaction context for a medication
func isAdverseReactionContext(text: String, medication: String) -> Bool {
    let lower = text.lowercased()
    let med = medication.lowercased()

    let adversePatterns = [
        "adverse reaction to \(med)",
        "allergic to \(med)",
        "allergy to \(med)",
        "intolerant to \(med)",
        "intolerance of \(med)",
        "contraindicated",
        "cannot take \(med)",
        "cannot tolerate \(med)",
        "stopped \(med) due to",
        "discontinue",
        "\(med) side effect",
        "ams on \(med)",
        "reaction to \(med)",
        "adverse effect",
    ]

    return adversePatterns.contains { lower.contains($0) }
}

/// Extract the sentence containing a match for robust highlighting
/// Returns the actual sentence from the note that can be used to find and highlight the source
func extractMatchedSentence(from text: String, matchRange: Range<String.Index>, maxLength: Int = 200) -> String {
    // Find sentence boundaries
    var sentenceStart = matchRange.lowerBound
    var sentenceEnd = matchRange.upperBound

    // Go backwards to find sentence start
    var backCount = 0
    while sentenceStart > text.startIndex && backCount < 100 {
        let prevIndex = text.index(before: sentenceStart)
        let char = text[prevIndex]
        if char == "." || char == "\n" || char == "!" || char == "?" {
            break
        }
        sentenceStart = prevIndex
        backCount += 1
    }

    // Go forwards to find sentence end
    var forwardCount = 0
    while sentenceEnd < text.endIndex && forwardCount < 100 {
        let char = text[sentenceEnd]
        sentenceEnd = text.index(after: sentenceEnd)
        forwardCount += 1
        if char == "." || char == "\n" || char == "!" || char == "?" {
            break
        }
    }

    // Extract and clean the sentence
    var sentence = String(text[sentenceStart..<sentenceEnd])
        .trimmingCharacters(in: .whitespacesAndNewlines)

    // Truncate if too long
    if sentence.count > maxLength {
        sentence = String(sentence.prefix(maxLength))
    }

    return sentence
}

/// Extract a snippet around a keyword for highlighting
func extractSnippetAround(keyword: String, in text: String, maxLength: Int = 150) -> String? {
    let lower = text.lowercased()
    guard let lowerRange = lower.range(of: keyword.lowercased()) else {
        return nil
    }
    // Convert range from lowercased to original text
    let origRange = convertRangeToOriginal(lowerRange: lowerRange, lowerText: lower, originalText: text)
    return extractMatchedSentence(from: text, matchRange: origRange, maxLength: maxLength)
}

/// Convert a range from lowercased text to the equivalent range in original text
func convertRangeToOriginal(lowerRange: Range<String.Index>, lowerText: String, originalText: String) -> Range<String.Index> {
    let startOffset = lowerText.distance(from: lowerText.startIndex, to: lowerRange.lowerBound)
    let endOffset = lowerText.distance(from: lowerText.startIndex, to: lowerRange.upperBound)
    let origStart = originalText.index(originalText.startIndex, offsetBy: startOffset)
    let origEnd = originalText.index(originalText.startIndex, offsetBy: endOffset)
    return origStart..<origEnd
}

// MARK: - Extraction Functions

/// Extract admission details from notes during an episode
func extractAdmissionDetails(
    notes: [ClinicalNote],
    admissionDate: Date,
    dischargeDate: Date,
    allNotes: [ClinicalNote]
) -> AdmissionDetails {
    var details = AdmissionDetails()
    let calendar = Calendar.current

    // Time windows
    let preAdmissionStart = calendar.date(byAdding: .day, value: -30, to: admissionDate)!
    let earlyAdmissionEnd = calendar.date(byAdding: .day, value: 3, to: admissionDate)!
    let dischargeWindowStart = calendar.date(byAdding: .day, value: -3, to: dischargeDate)!
    let postDischargeEnd = calendar.date(byAdding: .day, value: 7, to: dischargeDate)!

    // Filter notes for each window
    let preAdmissionNotes = allNotes.filter { $0.date >= preAdmissionStart && $0.date <= admissionDate }
    let earlyAdmissionNotes = notes.filter { $0.date <= earlyAdmissionEnd }
    let dischargeNotes = notes.filter { $0.date >= dischargeWindowStart }

    // Store first note ID and snippet for admission reference
    if let firstNote = notes.sorted(by: { $0.date < $1.date }).first {
        details.firstNoteId = firstNote.id
        // Try to find admission-specific text, otherwise use first 100 chars
        details.firstNoteSnippet = extractSnippetAround(keyword: "admission", in: firstNote.body)
            ?? extractSnippetAround(keyword: "admitted", in: firstNote.body)
            ?? String(firstNote.body.prefix(100))
    }

    // Store last note ID and snippet for discharge reference
    if let lastNote = notes.sorted(by: { $0.date > $1.date }).first {
        details.dischargeNoteId = lastNote.id
        // Try to find discharge-specific text, otherwise use first 100 chars
        details.dischargeSnippet = extractSnippetAround(keyword: "discharge", in: lastNote.body)
            ?? extractSnippetAround(keyword: "discharged", in: lastNote.body)
            ?? String(lastNote.body.prefix(100))
    }

    // Extract triggers from pre-admission and early admission notes
    for note in (preAdmissionNotes + earlyAdmissionNotes) {
        let lower = note.body.lowercased()

        for (pattern, trigger) in ADMISSION_TRIGGER_PATTERNS {
            if let lowerRange = lower.range(of: pattern, options: .regularExpression) {
                if !isNegated(text: lower, matchRange: lowerRange) {
                    let existingTriggers = details.triggers.map { $0.trigger }
                    if !existingTriggers.contains(trigger) {
                        // Convert range from lowercased to original text
                        let startOffset = lower.distance(from: lower.startIndex, to: lowerRange.lowerBound)
                        let endOffset = lower.distance(from: lower.startIndex, to: lowerRange.upperBound)
                        let origStart = note.body.index(note.body.startIndex, offsetBy: startOffset)
                        let origEnd = note.body.index(note.body.startIndex, offsetBy: endOffset)
                        let origRange = origStart..<origEnd

                        // Extract the actual matched sentence for robust highlighting
                        let matchedSnippet = extractMatchedSentence(from: note.body, matchRange: origRange)
                        details.triggers.append((trigger, note.id, matchedSnippet))
                    }
                }
            }
        }
    }

    // Extract presenting complaints from first 3 days
    for note in earlyAdmissionNotes {
        let lower = note.body.lowercased()

        for (pattern, complaint) in PRESENTING_COMPLAINT_PATTERNS {
            if let lowerRange = lower.range(of: pattern, options: .regularExpression) {
                if !isNegated(text: lower, matchRange: lowerRange) {
                    let existing = details.presentingComplaints.map { $0.complaint }
                    if !existing.contains(complaint) {
                        // Convert range from lowercased to original text
                        let startOffset = lower.distance(from: lower.startIndex, to: lowerRange.lowerBound)
                        let endOffset = lower.distance(from: lower.startIndex, to: lowerRange.upperBound)
                        let origStart = note.body.index(note.body.startIndex, offsetBy: startOffset)
                        let origEnd = note.body.index(note.body.startIndex, offsetBy: endOffset)
                        let origRange = origStart..<origEnd

                        // Extract the actual matched sentence for robust highlighting
                        let matchedSnippet = extractMatchedSentence(from: note.body, matchRange: origRange)
                        details.presentingComplaints.append((complaint, note.date, note.id, matchedSnippet))
                    }
                }
            }
        }

        // Extract legal status with matched snippet - convert range to original text
        if details.legalStatus == nil {
            if let lowerRange = lower.range(of: "section 3|s3", options: .regularExpression) {
                details.legalStatus = "Section 3"
                details.legalStatusNoteId = note.id
                let origRange = convertRangeToOriginal(lowerRange: lowerRange, lowerText: lower, originalText: note.body)
                details.legalStatusSnippet = extractMatchedSentence(from: note.body, matchRange: origRange)
            } else if let lowerRange = lower.range(of: "section 2|s2", options: .regularExpression) {
                details.legalStatus = "Section 2"
                details.legalStatusNoteId = note.id
                let origRange = convertRangeToOriginal(lowerRange: lowerRange, lowerText: lower, originalText: note.body)
                details.legalStatusSnippet = extractMatchedSentence(from: note.body, matchRange: origRange)
            } else if let lowerRange = lower.range(of: "informal") {
                details.legalStatus = "informal"
                details.legalStatusNoteId = note.id
                let origRange = convertRangeToOriginal(lowerRange: lowerRange, lowerText: lower, originalText: note.body)
                details.legalStatusSnippet = extractMatchedSentence(from: note.body, matchRange: origRange)
            } else if lower.contains("cto") && lower.contains("revok"),
                      let lowerRange = lower.range(of: "cto") {
                details.legalStatus = "CTO revoked to Section 3"
                details.legalStatusNoteId = note.id
                let origRange = convertRangeToOriginal(lowerRange: lowerRange, lowerText: lower, originalText: note.body)
                details.legalStatusSnippet = extractMatchedSentence(from: note.body, matchRange: origRange)
            }
        }

        // Extract source of admission with matched snippet - convert range to original text
        if details.source == nil {
            // A&E - must be actual attendance, not just boilerplate
            if let lowerRange = lower.range(of: "\\b(presented to|attended|went to|brought to|seen at)\\s+(the\\s+)?(a&e|emergency department|casualty)\\b", options: .regularExpression) {
                details.source = "A&E"
                details.sourceNoteId = note.id
                let origRange = convertRangeToOriginal(lowerRange: lowerRange, lowerText: lower, originalText: note.body)
                details.sourceSnippet = extractMatchedSentence(from: note.body, matchRange: origRange)
            } else if let lowerRange = lower.range(of: "\\b(a&e|emergency department|casualty)\\s+(attendance|presentation)\\b", options: .regularExpression) {
                details.source = "A&E"
                details.sourceNoteId = note.id
                let origRange = convertRangeToOriginal(lowerRange: lowerRange, lowerText: lower, originalText: note.body)
                details.sourceSnippet = extractMatchedSentence(from: note.body, matchRange: origRange)
            }
            // Section 136/police - specific patterns
            else if let lowerRange = lower.range(of: "\\b(section\\s*136|s\\.?136|place of safety)\\b", options: .regularExpression) {
                details.source = "Section 136 (police)"
                details.sourceNoteId = note.id
                let origRange = convertRangeToOriginal(lowerRange: lowerRange, lowerText: lower, originalText: note.body)
                details.sourceSnippet = extractMatchedSentence(from: note.body, matchRange: origRange)
            } else if let lowerRange = lower.range(of: "\\bpolice\\s+(brought|conveyed|detained)\\b", options: .regularExpression) {
                details.source = "Section 136 (police)"
                details.sourceNoteId = note.id
                let origRange = convertRangeToOriginal(lowerRange: lowerRange, lowerText: lower, originalText: note.body)
                details.sourceSnippet = extractMatchedSentence(from: note.body, matchRange: origRange)
            }
            // CTO recall - must be EXPLICIT recall, not just CTO mentioned
            else if let lowerRange = lower.range(of: "\\b(cto\\s+recall|recalled\\s+(under|to)\\s+(the\\s+)?cto|cto\\s+revoked)\\b", options: .regularExpression) {
                details.source = "CTO recall"
                details.sourceNoteId = note.id
                let origRange = convertRangeToOriginal(lowerRange: lowerRange, lowerText: lower, originalText: note.body)
                details.sourceSnippet = extractMatchedSentence(from: note.body, matchRange: origRange)
            }
            // Home treatment team
            else if let lowerRange = lower.range(of: "\\b(htt|home treatment team|crisis team)\\s+(referr|admit|assess)\\b", options: .regularExpression) {
                details.source = "home treatment team"
                details.sourceNoteId = note.id
                let origRange = convertRangeToOriginal(lowerRange: lowerRange, lowerText: lower, originalText: note.body)
                details.sourceSnippet = extractMatchedSentence(from: note.body, matchRange: origRange)
            }
        }
    }

    // Default source to community if none found (use first note as reference)
    if details.source == nil {
        details.source = "the community"
        details.sourceNoteId = details.firstNoteId
        if let firstNoteId = details.firstNoteId,
           let firstNote = notes.first(where: { $0.id == firstNoteId }) {
            details.sourceSnippet = String(firstNote.body.prefix(100))
        }
    }

    // Extract medications BEFORE admission (from admission/clerking notes only)
    let admissionMedPatterns = ["admission medication", "on admission", "clerking", "current medication", "regular medication"]

    for note in preAdmissionNotes + earlyAdmissionNotes.prefix(3) {
        let lower = note.body.lowercased()
        let isAdmissionNote = admissionMedPatterns.contains { lower.contains($0) }
        let isMedList = lower.contains("medications:") || lower.contains("current meds")

        if isAdmissionNote || isMedList {
            for (pattern, medName) in MEDICATION_PATTERNS {
                if lower.range(of: pattern, options: .regularExpression) != nil {
                    if !isAdverseReactionContext(text: lower, medication: medName) {
                        let existing = details.medicationsBefore.map { $0.name.lowercased() }
                        if !existing.contains(medName.lowercased()) {
                            details.medicationsBefore.append((medName, note.date))
                        }
                    }
                }
            }
        }
    }

    // Extract medications DURING admission (with note IDs and matched snippets)
    for note in notes {
        let lower = note.body.lowercased()

        for (pattern, medName) in MEDICATION_PATTERNS {
            if let lowerRange = lower.range(of: pattern, options: .regularExpression) {
                if !isAdverseReactionContext(text: lower, medication: medName) {
                    let existing = details.medicationsDuring.map { $0.name.lowercased() }
                    if !existing.contains(medName.lowercased()) {
                        let origRange = convertRangeToOriginal(lowerRange: lowerRange, lowerText: lower, originalText: note.body)
                        let matchedSnippet = extractMatchedSentence(from: note.body, matchRange: origRange)
                        details.medicationsDuring.append((medName, note.date, note.id, matchedSnippet))
                    }
                }
            }
        }
    }

    // Calculate medication changes (commenced = during - before)
    let beforeNames = Set(details.medicationsBefore.map { $0.name.lowercased() })
    let duringNames = Set(details.medicationsDuring.map { $0.name.lowercased() })
    let newMedNames = duringNames.subtracting(beforeNames)

    // Additional filter: check for explicit "started/commenced" language
    for medName in newMedNames {
        var hasExplicitStart = false
        var wasInAnyPreNote = false
        var commencementNoteId: UUID?

        // Check pre-admission notes
        for note in preAdmissionNotes {
            if note.body.lowercased().contains(medName) {
                wasInAnyPreNote = true
                break
            }
        }

        // Check for explicit commencement
        for note in notes {
            let lower = note.body.lowercased()
            if lower.contains(medName) {
                let startPatterns = [
                    "\(medName) started", "\(medName) commenced", "started \(medName)",
                    "commenced \(medName)", "prescribed \(medName)", "initiated \(medName)",
                    "titrat", "increas.*\(medName)", "add.*\(medName)"
                ]
                for pat in startPatterns {
                    if lower.range(of: pat, options: .regularExpression) != nil {
                        hasExplicitStart = true
                        commencementNoteId = note.id
                        break
                    }
                }
            }
        }

        // Include if explicit start OR truly not seen before
        if hasExplicitStart || !wasInAnyPreNote {
            // Find the proper case version and its note ID with matched snippet
            if let med = details.medicationsDuring.first(where: { $0.name.lowercased() == medName }) {
                let noteId = commencementNoteId ?? med.noteId
                // Use the snippet from the medication during, or find better one from commencement note
                var matchedSnippet = med.matchedSnippet
                if let commenceId = commencementNoteId,
                   let commenceNote = notes.first(where: { $0.id == commenceId }),
                   let snippet = extractSnippetAround(keyword: medName, in: commenceNote.body) {
                    matchedSnippet = snippet
                }
                details.medicationChanges.append((med.name, noteId, matchedSnippet))
            }
        }
    }

    // Extract notable incidents - DEDUPLICATE BY DATE (only one per day per type)
    // Also check for historical/contextual references to avoid false positives
    for note in notes {
        let lower = note.body.lowercased()

        for (pattern, incidentType) in NOTABLE_INCIDENT_PATTERNS {
            if let lowerRange = lower.range(of: pattern, options: .regularExpression) {
                // Skip if negated or historical reference
                if isNegated(text: lower, matchRange: lowerRange) {
                    continue
                }
                if isHistoricalOrContextual(text: lower, matchRange: lowerRange) {
                    continue
                }

                // Check if we already have this incident type on this date
                let noteDay = calendar.startOfDay(for: note.date)
                let alreadyExists = details.notableIncidents.contains { incident in
                    calendar.startOfDay(for: incident.date) == noteDay && incident.type == incidentType
                }
                if !alreadyExists {
                    // Convert range to original text and extract matched sentence
                    let origRange = convertRangeToOriginal(lowerRange: lowerRange, lowerText: lower, originalText: note.body)
                    let matchedSnippet = extractMatchedSentence(from: note.body, matchRange: origRange)
                    details.notableIncidents.append((incidentType, note.date, nil, note.id, matchedSnippet))
                }
                break // Only one notable type per note
            }
        }
    }

    // Sort and limit notable incidents - prioritise seclusion
    let priorityTypes = ["seclusion", "the response team being called"]
    let priorityIncidents = details.notableIncidents.filter { priorityTypes.contains($0.type) }
        .sorted { $0.date < $1.date }
    let otherIncidents = details.notableIncidents.filter { !priorityTypes.contains($0.type) }
        .sorted { $0.date < $1.date }

    // Keep top 3 priority incidents, then fill with others up to 4 total
    var limitedIncidents = Array(priorityIncidents.prefix(3))
    if limitedIncidents.count < 4 {
        limitedIncidents.append(contentsOf: otherIncidents.prefix(4 - limitedIncidents.count))
    }
    details.notableIncidents = limitedIncidents

    // Extract improvement factors - only from last 14 days before discharge (matching desktop)
    let improvementWindowStart = calendar.date(byAdding: .day, value: -14, to: dischargeDate)!
    let improvementNotes = notes.filter { $0.date >= improvementWindowStart && $0.date <= dischargeDate }

    for note in improvementNotes {
        let lower = note.body.lowercased()

        // Must contain improvement context
        let hasImprovementContext = lower.range(of: "\\b(improv|better|settled|stable|recover|respond.*treatment|ready.*discharge)\\b", options: .regularExpression) != nil

        if hasImprovementContext {
            let existing = details.improvementFactors.map { $0.factor }

            // Check for medication changes - extract matched snippet with proper range conversion
            if let lowerRange = lower.range(of: "\\b(medication|medic|tablet|depot|antipsychotic|clozapine)\\b", options: .regularExpression) {
                if !existing.contains("medication changes") {
                    let origRange = convertRangeToOriginal(lowerRange: lowerRange, lowerText: lower, originalText: note.body)
                    let matchedSnippet = extractMatchedSentence(from: note.body, matchRange: origRange)
                    details.improvementFactors.append(("medication changes", note.date, note.id, matchedSnippet))
                }
            }

            // Check for nursing care - extract matched snippet with proper range conversion
            if let lowerRange = lower.range(of: "\\b(nurs|staff support|ward routine|structure)\\b", options: .regularExpression) {
                if !existing.contains("nursing care") {
                    let origRange = convertRangeToOriginal(lowerRange: lowerRange, lowerText: lower, originalText: note.body)
                    let matchedSnippet = extractMatchedSentence(from: note.body, matchRange: origRange)
                    details.improvementFactors.append(("nursing care", note.date, note.id, matchedSnippet))
                }
            }

            // Check for improved insight/engagement - extract matched snippet with proper range conversion
            if let lowerRange = lower.range(of: "\\b(insight|engag|complian|accept)\\b", options: .regularExpression) {
                if !existing.contains("improved insight") {
                    let origRange = convertRangeToOriginal(lowerRange: lowerRange, lowerText: lower, originalText: note.body)
                    let matchedSnippet = extractMatchedSentence(from: note.body, matchRange: origRange)
                    details.improvementFactors.append(("improved insight", note.date, note.id, matchedSnippet))
                }
            }

            // Check for actual psychological therapy (not just "therapy" which could be OT)
            let psychPatterns = [
                "psychology\\s+session", "psychological\\s+therapy", "psychologist",
                "\\bcbt\\b", "\\bdbt\\b", "\\bmbt\\b", "mentalisation", "\\bschema\\b", "\\bemdr\\b",
                "individual\\s+therapy", "group\\s+therapy", "family\\s+therapy",
                "systemic\\s+therapy", "talking\\s+therap", "counselling\\s+session"
            ]
            for pattern in psychPatterns {
                if let lowerRange = lower.range(of: pattern, options: .regularExpression) {
                    if !existing.contains("psychological intervention") {
                        let origRange = convertRangeToOriginal(lowerRange: lowerRange, lowerText: lower, originalText: note.body)
                        let matchedSnippet = extractMatchedSentence(from: note.body, matchRange: origRange)
                        details.improvementFactors.append(("psychological intervention", note.date, note.id, matchedSnippet))
                        break
                    }
                }
            }
        }

        // Check for successful leave (tracked separately as outcome) - extract matched snippet with proper range conversion
        if details.successfulLeave == nil {
            if let lowerRange = lower.range(of: "\\b(successful.*leave|leave.*successful|ground.*leave|escorted.*leave|unescorted.*leave|overnight.*leave|community.*leave)\\b", options: .regularExpression) {
                let origRange = convertRangeToOriginal(lowerRange: lowerRange, lowerText: lower, originalText: note.body)
                let matchedSnippet = extractMatchedSentence(from: note.body, matchRange: origRange)
                details.successfulLeave = (note.date, note.id, matchedSnippet)
            }
        }
    }

    return details
}

/// Extract community period details
func extractCommunityDetails(
    notes: [ClinicalNote],
    startDate: Date,
    endDate: Date,
    episodes: [Episode]
) -> CommunityDetails {
    var details = CommunityDetails()

    // Build list of inpatient periods to exclude
    let inpatientPeriods = episodes.filter { $0.type == .inpatient }.map { ($0.start, $0.end) }

    func isDuringInpatient(_ date: Date) -> Bool {
        for (start, end) in inpatientPeriods {
            if date >= start && date <= end {
                return true
            }
        }
        return false
    }

    // Filter notes to community period only
    let communityNotes = notes.filter { note in
        note.date >= startDate && note.date <= endDate && !isDuringInpatient(note.date)
    }

    for note in communityNotes {
        let lower = note.body.lowercased()

        // Extract medications
        for (pattern, medName) in MEDICATION_PATTERNS {
            if lower.range(of: pattern, options: .regularExpression) != nil {
                if !isAdverseReactionContext(text: lower, medication: medName) {
                    let existing = details.medications.map { $0.name.lowercased() }
                    if !existing.contains(medName.lowercased()) {
                        details.medications.append((medName, note.date))
                    }
                }
            }
        }

        // Extract engagement activities
        for (pattern, activity, category) in COMMUNITY_ENGAGEMENT_PATTERNS {
            if let range = lower.range(of: pattern, options: .regularExpression) {
                if !isNegated(text: lower, matchRange: range) {
                    switch category {
                    case "therapy":
                        let existing = details.psychology.map { $0.type }
                        if !existing.contains(activity) {
                            details.psychology.append((activity, note.date))
                        }
                    case "clinic":
                        let existing = details.clinics.map { $0.type }
                        if !existing.contains(activity) {
                            details.clinics.append((activity, note.date))
                        }
                    case "activity":
                        let existing = details.activities.map { $0.type }
                        if !existing.contains(activity) {
                            details.activities.append((activity, note.date))
                        }
                    case "person":
                        if details.contactPeople[activity] == nil {
                            details.contactPeople[activity] = (1, note.date)
                        } else {
                            details.contactPeople[activity]!.count += 1
                        }
                    case "mode":
                        if details.contactModes[activity] == nil {
                            details.contactModes[activity] = (1, note.date)
                        } else {
                            details.contactModes[activity]!.count += 1
                        }
                    default:
                        break
                    }
                }
            }
        }

        // Extract crisis events
        for (pattern, crisisType) in COMMUNITY_CRISIS_PATTERNS {
            if lower.range(of: pattern, options: .regularExpression) != nil {
                details.crisisEvents.append((crisisType, note.date, String(note.body.prefix(200))))
                break
            }
        }

        // Extract concerns
        for (pattern, concernType) in COMMUNITY_CONCERN_PATTERNS {
            if let range = lower.range(of: pattern, options: .regularExpression) {
                if !isNegated(text: lower, matchRange: range) {
                    let existing = details.concerns.map { $0.type }
                    if !existing.contains(concernType) {
                        details.concerns.append((concernType, note.date))
                    }
                    break
                }
            }
        }
    }

    return details
}

// MARK: - Narrative Generation

/// Generate comprehensive progress narrative matching desktop app output
func generateProgressNarrative(
    patientName: String,
    pronouns: Pronouns,
    episodes: [Episode],
    risks: ExtractedRisks?,
    notes: [ClinicalNote]
) -> [NarrativeSection] {
    var sections: [NarrativeSection] = []

    let firstName = patientName.components(separatedBy: " ").first ?? "The patient"
    let pro = pronouns.subject.lowercased()
    let proCap = pronouns.Subject
    let proObj = pronouns.object.lowercased()
    let proPoss = pronouns.possessive.lowercased()
    let proPossCap = pronouns.Possessive

    // Date range
    let allDates = notes.map { $0.date }
    guard let minDate = allDates.min(), let maxDate = allDates.max() else {
        return [NarrativeSection(title: nil, content: [
            NarrativeParagraph(text: "Insufficient data to generate narrative.", linkedNoteIds: [], highlightRanges: [])
        ])]
    }

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MMMM yyyy"
    let shortFormatter = DateFormatter()
    shortFormatter.dateFormat = "dd MMMM yyyy"

    let totalMonths = max(1, Calendar.current.dateComponents([.month], from: minDate, to: maxDate).month ?? 1)
    let inpatientEpisodes = episodes.filter { $0.type == .inpatient }
    let totalInpatientDays = inpatientEpisodes.reduce(0) { $0 + $1.duration }

    // Incident counts
    let totalIncidents = risks?.incidents.count ?? 0
    let physicalCount = risks?.incidents.filter { $0.category == .physicalAggression }.count ?? 0
    let verbalCount = risks?.incidents.filter { $0.category == .verbalAggression }.count ?? 0
    let selfHarmCount = risks?.incidents.filter { $0.category == .selfHarm }.count ?? 0

    // MARK: Header
    sections.append(NarrativeSection(title: nil, content: [
        NarrativeParagraph(
            text: "PROGRESS AND RISK NARRATIVE\n============================================================\n\n\(patientName)\n\(dateFormatter.string(from: minDate)) to \(dateFormatter.string(from: maxDate))",
            linkedNoteIds: [],
            highlightRanges: []
        )
    ]))

    // MARK: Overview
    var overviewLines: [String] = []
    overviewLines.append("\nOVERVIEW:")
    overviewLines.append("- Total months reviewed: \(totalMonths)")
    overviewLines.append("- Admissions: \(inpatientEpisodes.count) (\(totalInpatientDays) inpatient days total)")
    overviewLines.append("- Total concerns recorded: \(totalIncidents)")
    if physicalCount > 0 {
        overviewLines.append("- Physical violence concerns: \(physicalCount)")
    }
    if verbalCount > 0 {
        overviewLines.append("- Verbal aggression concerns: \(verbalCount)")
    }
    if selfHarmCount > 0 {
        overviewLines.append("- Self-harm concerns: \(selfHarmCount)")
    }
    overviewLines.append("- Key events documented: \(notes.count)")

    sections.append(NarrativeSection(title: nil, content: [
        NarrativeParagraph(text: overviewLines.joined(separator: "\n"), linkedNoteIds: [], highlightRanges: [])
    ]))

    // MARK: Admission History
    if !inpatientEpisodes.isEmpty {
        var historyLines: [String] = ["\nADMISSION HISTORY:"]
        for (index, episode) in inpatientEpisodes.enumerated() {
            historyLines.append("- Admission \(index + 1): \(shortFormatter.string(from: episode.start)) to \(shortFormatter.string(from: episode.end)) (\(episode.duration) days)")
        }
        sections.append(NarrativeSection(title: nil, content: [
            NarrativeParagraph(text: historyLines.joined(separator: "\n"), linkedNoteIds: [], highlightRanges: [])
        ]))
    }

    // MARK: Narrative
    var narrativeParagraphs: [NarrativeParagraph] = []
    narrativeParagraphs.append(NarrativeParagraph(text: "\nNARRATIVE:\n", linkedNoteIds: [], highlightRanges: []))

    // Initial community period (before first admission)
    if let firstInpatient = inpatientEpisodes.first {
        let firstCommunityNotes = notes.filter { $0.date < firstInpatient.start }.sorted { $0.date < $1.date }
        if !firstCommunityNotes.isEmpty {
            var initialPara = "The records begin in \(dateFormatter.string(from: minDate)) when \(firstName) was in the community"

            // Extract community details for this period
            let communityDetails = extractCommunityDetails(
                notes: notes,
                startDate: minDate,
                endDate: firstInpatient.start,
                episodes: episodes
            )

            // Describe engagement
            if !communityDetails.contactPeople.isEmpty {
                let mainPerson = communityDetails.contactPeople.max { $0.value.count < $1.value.count }?.key ?? ""
                if !mainPerson.isEmpty {
                    initialPara += " under the care of \(proPoss) \(mainPerson)"
                }
            }

            // Check for any concerns
            let earlyIncidents = risks?.incidents.filter { $0.date < firstInpatient.start } ?? []
            if !earlyIncidents.isEmpty || !communityDetails.concerns.isEmpty {
                let concernTypes = communityDetails.concerns.map { $0.type }
                if !concernTypes.isEmpty {
                    initialPara += " with \(concernTypes.prefix(2).joined(separator: " and ")) noted"
                }
            }

            initialPara += ". "

            // Add crisis events if any
            if !communityDetails.crisisEvents.isEmpty {
                let crisisTypes = Array(Set(communityDetails.crisisEvents.map { $0.type }))
                initialPara += "During this period, there was \(crisisTypes.joined(separator: " and ")). "
            }

            narrativeParagraphs.append(NarrativeParagraph(
                text: initialPara + "\n",
                linkedNoteIds: firstCommunityNotes.prefix(2).map { $0.id },
                highlightRanges: []
            ))
        }
    }

    // Process each episode
    var admissionNumber = 0
    var lastDischargeDate: Date?

    for (index, episode) in episodes.enumerated() {
        let episodeNotes = notes.filter { $0.date >= episode.start && $0.date <= episode.end }
        let episodeIncidents = risks?.incidents.filter { $0.date >= episode.start && $0.date <= episode.end } ?? []

        if episode.type == .inpatient {
            admissionNumber += 1

            // Extract detailed admission info
            let admDetails = extractAdmissionDetails(
                notes: episodeNotes,
                admissionDate: episode.start,
                dischargeDate: episode.end,
                allNotes: notes
            )

            var para = ""

            // Gap text (time since last discharge)
            if let lastDischarge = lastDischargeDate {
                let gapDays = Calendar.current.dateComponents([.day], from: lastDischarge, to: episode.start).day ?? 0
                if gapDays < 30 {
                    para += "\(proCap) had been out of hospital for only \(gapDays / 7) week\(gapDays / 7 == 1 ? "" : "s") before "
                } else if gapDays < 365 {
                    let months = gapDays / 30
                    para += "\(proCap) had been in the community for \(months) month\(months == 1 ? "" : "s") before "
                } else {
                    let years = gapDays / 365
                    let remainingMonths = (gapDays % 365) / 30
                    if remainingMonths > 0 {
                        para += "\(proCap) had been in the community for \(years) year\(years == 1 ? "" : "s") and \(remainingMonths) month\(remainingMonths == 1 ? "" : "s") before "
                    } else {
                        para += "\(proCap) had been in the community for \(years) year\(years == 1 ? "" : "s") before "
                    }
                }
            }

            // Admission description
            if admissionNumber == 1 {
                para += "The first admission was on \(shortFormatter.string(from: episode.start))"
            } else {
                para += "\(proPoss) \(ordinal(admissionNumber)) admission on \(shortFormatter.string(from: episode.start))"
            }

            // Source of admission
            if let source = admDetails.source {
                para += " from \(source)"
            }

            // Legal status
            if let status = admDetails.legalStatus {
                para += " under \(status)"
            }

            para += ". "

            // Triggers
            if !admDetails.triggers.isEmpty {
                let triggerNames = admDetails.triggers.prefix(3).map { $0.trigger }
                para += "This admission was precipitated by \(triggerNames.joined(separator: ", ")). "
            }

            // Presenting complaints
            if !admDetails.presentingComplaints.isEmpty {
                let complaints = admDetails.presentingComplaints.map { $0.complaint }
                para += "\(proCap) presented with \(complaints.prefix(4).joined(separator: ", ")). "
            }

            // Duration
            if episode.duration < 30 {
                para += "This admission lasted \(episode.duration) days. "
            } else if episode.duration < 90 {
                para += "This admission lasted approximately \(episode.duration / 7) weeks. "
            } else {
                para += "This admission lasted approximately \(episode.duration / 30) months. "
            }

            // Notable incidents - report specific dates, not counts (matching desktop)
            let seclusionIncidents = admDetails.notableIncidents.filter { $0.type == "seclusion" }
                .sorted { $0.date < $1.date }
            let restraintIncidents = admDetails.notableIncidents.filter { $0.type == "restraint" || $0.type == "rapid tranquillisation" }
                .sorted { $0.date < $1.date }

            if !seclusionIncidents.isEmpty {
                if seclusionIncidents.count == 1 {
                    para += "On \(shortFormatter.string(from: seclusionIncidents[0].date)), there was an incident requiring seclusion. "
                } else if seclusionIncidents.count == 2 {
                    // Two incidents - report both dates
                    para += "On \(shortFormatter.string(from: seclusionIncidents[0].date)), there was an incident requiring seclusion. "
                    para += "There was also seclusion required on \(shortFormatter.string(from: seclusionIncidents[1].date)). "
                } else {
                    // 3+ incidents - report first and mention others
                    para += "On \(shortFormatter.string(from: seclusionIncidents[0].date)), there was an incident requiring seclusion. "
                    para += "There was also seclusion required on \(shortFormatter.string(from: seclusionIncidents[1].date))"
                    if seclusionIncidents.count > 2 {
                        para += " and \(seclusionIncidents.count - 2) further occasion\(seclusionIncidents.count > 3 ? "s" : "")"
                    }
                    para += ". "
                }
            }

            if !restraintIncidents.isEmpty && seclusionIncidents.isEmpty {
                if restraintIncidents.count == 1 {
                    para += "On \(shortFormatter.string(from: restraintIncidents[0].date)), there was an incident requiring physical intervention. "
                } else {
                    para += "On \(shortFormatter.string(from: restraintIncidents[0].date)), there was an incident requiring physical intervention, with \(restraintIncidents.count - 1) further occasion\(restraintIncidents.count > 2 ? "s" : ""). "
                }
            }

            // Risk concerns during admission
            if episodeIncidents.count > 10 {
                para += "During this admission, \(proPoss) presentation fluctuated with many concerns. "
            } else if episodeIncidents.count > 3 {
                para += "During this admission, there were some concerns. "
            }

            // Medication changes (using sophisticated detection)
            if !admDetails.medicationChanges.isEmpty {
                let medNames = admDetails.medicationChanges.prefix(3).map { $0.name }
                para += "During the admission, \(medNames.joined(separator: ", ")) \(admDetails.medicationChanges.count == 1 ? "was" : "were") commenced. "
            }

            // Improvement factors
            if !admDetails.improvementFactors.isEmpty {
                let factors = admDetails.improvementFactors.prefix(2).map { $0.factor }
                para += "\(proCap) showed improvement with \(factors.joined(separator: " and ")). "
            } else {
                para += "\(proCap) showed improvement with treatment. "
            }

            // Successful leave
            if let leave = admDetails.successfulLeave {
                para += "\(proCap) took successful leave prior to discharge. "
            }

            // Discharge
            para += "\(proCap) was discharged on \(shortFormatter.string(from: episode.end)).\n\n"

            lastDischargeDate = episode.end

            narrativeParagraphs.append(NarrativeParagraph(
                text: para,
                linkedNoteIds: episodeNotes.prefix(3).map { $0.id },
                highlightRanges: []
            ))

        } else {
            // Community period
            if episode.duration > 60 && index > 0 {
                // Extract community details
                let communityDetails = extractCommunityDetails(
                    notes: notes,
                    startDate: episode.start,
                    endDate: episode.end,
                    episodes: episodes
                )

                var para = ""

                // Describe community care
                if !communityDetails.medications.isEmpty {
                    let meds = communityDetails.medications.prefix(3).map { $0.name }
                    para += "\(proCap) was maintained on \(meds.joined(separator: ", ")). "
                }

                // Contact with services
                if !communityDetails.contactPeople.isEmpty {
                    let mainPerson = communityDetails.contactPeople.max { $0.value.count < $1.value.count }?.key ?? ""
                    let mainMode = communityDetails.contactModes.max { $0.value.count < $1.value.count }?.key ?? ""
                    if !mainPerson.isEmpty {
                        if !mainMode.isEmpty {
                            para += "During this period, \(pro) had regular \(mainMode) contact with \(proPoss) \(mainPerson). "
                        } else {
                            para += "During this period, \(pro) had regular contact with \(proPoss) \(mainPerson). "
                        }
                    }
                }

                // Psychology/therapy engagement
                if !communityDetails.psychology.isEmpty {
                    let therapies = communityDetails.psychology.prefix(2).map { $0.type }
                    para += "\(proCap) engaged with \(therapies.joined(separator: " and ")). "
                }

                // Activities
                if !communityDetails.activities.isEmpty {
                    let activities = communityDetails.activities.prefix(2).map { $0.type }
                    para += "\(proCap) engaged in \(activities.joined(separator: " and ")). "
                }

                // Crisis events
                if !communityDetails.crisisEvents.isEmpty {
                    let crisisTypes = Array(Set(communityDetails.crisisEvents.map { $0.type }))
                    if crisisTypes.count == 1 && communityDetails.crisisEvents.count == 1 {
                        let event = communityDetails.crisisEvents[0]
                        para += "On \(shortFormatter.string(from: event.date)), \(crisisTypes[0]) were involved. "
                    } else {
                        para += "During this period, there were \(communityDetails.crisisEvents.count) crisis events involving \(crisisTypes.prefix(2).joined(separator: " and ")). "
                    }
                }

                // Concerns
                let seriousConcerns = communityDetails.concerns.filter {
                    ["safeguarding", "substance use", "deterioration"].contains($0.type)
                }
                if !seriousConcerns.isEmpty {
                    for concern in seriousConcerns.prefix(2) {
                        para += "On \(shortFormatter.string(from: concern.date)), \(concern.type) concerns were raised. "
                    }
                }

                // Community incidents
                let communityIncidents = episodeIncidents
                let selfHarm = communityIncidents.filter { $0.category == .selfHarm }
                let aggression = communityIncidents.filter { $0.category == .physicalAggression || $0.category == .verbalAggression }

                if !selfHarm.isEmpty {
                    para += "There were \(selfHarm.count) instance\(selfHarm.count == 1 ? "" : "s") of self-harm during this period. "
                }
                if !aggression.isEmpty {
                    para += "There were \(aggression.count) instance\(aggression.count == 1 ? "" : "s") of aggression. "
                }

                if !para.isEmpty {
                    narrativeParagraphs.append(NarrativeParagraph(
                        text: para + "\n",
                        linkedNoteIds: episodeNotes.prefix(2).map { $0.id },
                        highlightRanges: []
                    ))
                }
            }
        }
    }

    sections.append(NarrativeSection(title: nil, content: narrativeParagraphs))

    // MARK: Incident Log
    var summaryLines: [String] = ["\nINCIDENT LOG:"]

    // List physical aggression concerns (deduplicated)
    let physicalIncidentsRaw = risks?.incidents.filter { $0.category == .physicalAggression } ?? []
    let physicalIncidents = dedupeIncidents(physicalIncidentsRaw)
    if !physicalIncidents.isEmpty {
        summaryLines.append("Physical aggression concerns (\(physicalIncidents.count)):")
        for incident in physicalIncidents.prefix(10) {
            let dateStr = shortFormatter.string(from: incident.date)
            summaryLines.append("  • \(dateStr): \(incident.matchedText.prefix(80))")
        }
        if physicalIncidents.count > 10 {
            summaryLines.append("  ... and \(physicalIncidents.count - 10) more")
        }
    }

    // List verbal aggression concerns (deduplicated)
    let verbalIncidentsRaw = risks?.incidents.filter { $0.category == .verbalAggression } ?? []
    let verbalIncidents = dedupeIncidents(verbalIncidentsRaw)
    if !verbalIncidents.isEmpty {
        summaryLines.append("Verbal aggression concerns (\(verbalIncidents.count)):")
        for incident in verbalIncidents.prefix(10) {
            let dateStr = shortFormatter.string(from: incident.date)
            summaryLines.append("  • \(dateStr): \(incident.matchedText.prefix(80))")
        }
        if verbalIncidents.count > 10 {
            summaryLines.append("  ... and \(verbalIncidents.count - 10) more")
        }
    }

    // List self-harm concerns (deduplicated)
    let selfHarmIncidentsRaw = risks?.incidents.filter { $0.category == .selfHarm } ?? []
    let selfHarmIncidents = dedupeIncidents(selfHarmIncidentsRaw)
    if !selfHarmIncidents.isEmpty {
        summaryLines.append("Self-harm concerns (\(selfHarmIncidents.count)):")
        for incident in selfHarmIncidents.prefix(10) {
            let dateStr = shortFormatter.string(from: incident.date)
            summaryLines.append("  • \(dateStr): \(incident.matchedText.prefix(80))")
        }
        if selfHarmIncidents.count > 10 {
            summaryLines.append("  ... and \(selfHarmIncidents.count - 10) more")
        }
    }

    summaryLines.append("\(proCap) had \(inpatientEpisodes.count) admission\(inpatientEpisodes.count == 1 ? "" : "s") totalling \(totalInpatientDays) inpatient days.")
    summaryLines.append("")
    summaryLines.append("---")

    let reportDateFormatter = DateFormatter()
    reportDateFormatter.dateFormat = "dd MMMM yyyy"
    summaryLines.append("Report generated: \(reportDateFormatter.string(from: Date()))")

    sections.append(NarrativeSection(title: nil, content: [
        NarrativeParagraph(text: summaryLines.joined(separator: "\n"), linkedNoteIds: [], highlightRanges: [])
    ]))

    return sections
}

/// Generate progress narrative with inline references and bold formatting
func generateProgressNarrativeWithReferences(
    patientName: String,
    pronouns: Pronouns,
    episodes: [Episode],
    risks: ExtractedRisks?,
    notes: [ClinicalNote]
) -> [NarrativeSection] {
    var sections: [NarrativeSection] = []

    let firstName = patientName.components(separatedBy: " ").first ?? "The patient"
    let pro = pronouns.subject.lowercased()
    let proCap = pronouns.Subject
    let proObj = pronouns.object.lowercased()
    let proPoss = pronouns.possessive.lowercased()
    let proPossCap = pronouns.Possessive

    // Date range
    let allDates = notes.map { $0.date }
    guard let minDate = allDates.min(), let maxDate = allDates.max() else {
        return [NarrativeSection(title: nil, content: [
            NarrativeParagraph(segments: [.text("Insufficient data to generate narrative.")])
        ])]
    }

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MMMM yyyy"
    let shortFormatter = DateFormatter()
    shortFormatter.dateFormat = "dd MMMM yyyy"

    let calendar = Calendar.current
    let totalMonths = max(1, calendar.dateComponents([.month], from: minDate, to: maxDate).month ?? 1)
    let inpatientEpisodes = episodes.filter { $0.type == .inpatient }
    let totalInpatientDays = inpatientEpisodes.reduce(0) { $0 + $1.duration }

    // Incident counts
    let totalIncidents = risks?.incidents.count ?? 0
    let physicalCount = risks?.incidents.filter { $0.category == .physicalAggression }.count ?? 0
    let verbalCount = risks?.incidents.filter { $0.category == .verbalAggression }.count ?? 0
    let selfHarmCount = risks?.incidents.filter { $0.category == .selfHarm }.count ?? 0

    // MARK: Header
    sections.append(NarrativeSection(title: nil, content: [
        NarrativeParagraph(segments: [
            .bold("PROGRESS AND RISK NARRATIVE"),
            .text("\n============================================================\n\n"),
            .bold(patientName),
            .text("\n\(dateFormatter.string(from: minDate)) to \(dateFormatter.string(from: maxDate))")
        ])
    ]))

    // MARK: Overview
    var overviewSegments: [NarrativeSegment] = [
        .text("\nOVERVIEW:\n"),
        .text("- Total months reviewed: \(totalMonths)\n"),
        .text("- Admissions: \(inpatientEpisodes.count) (\(totalInpatientDays) inpatient days total)\n"),
        .text("- Total concerns recorded: \(totalIncidents)\n")
    ]
    if physicalCount > 0 {
        overviewSegments.append(.text("- Physical violence concerns: \(physicalCount)\n"))
    }
    if verbalCount > 0 {
        overviewSegments.append(.text("- Verbal aggression concerns: \(verbalCount)\n"))
    }
    if selfHarmCount > 0 {
        overviewSegments.append(.text("- Self-harm concerns: \(selfHarmCount)\n"))
    }
    overviewSegments.append(.text("- Key events documented: \(notes.count)"))

    sections.append(NarrativeSection(title: nil, content: [
        NarrativeParagraph(segments: overviewSegments)
    ]))

    // MARK: Admission History
    if !inpatientEpisodes.isEmpty {
        var historySegments: [NarrativeSegment] = [.text("\nADMISSION HISTORY:\n")]
        for (index, episode) in inpatientEpisodes.enumerated() {
            historySegments.append(.text("- Admission \(index + 1): \(shortFormatter.string(from: episode.start)) to \(shortFormatter.string(from: episode.end)) (\(episode.duration) days)\n"))
        }
        sections.append(NarrativeSection(title: nil, content: [
            NarrativeParagraph(segments: historySegments)
        ]))
    }

    // MARK: Narrative
    var narrativeParagraphs: [NarrativeParagraph] = []
    narrativeParagraphs.append(NarrativeParagraph(segments: [.bold("\nNARRATIVE:\n")]))

    // Initial community period (before first admission) - comprehensive paragraph
    var initialCommunityEndDate: Date?
    if let firstInpatient = inpatientEpisodes.first {
        initialCommunityEndDate = firstInpatient.start
        let firstCommunityNotes = notes.filter { $0.date < firstInpatient.start }.sorted { $0.date < $1.date }
        if !firstCommunityNotes.isEmpty {
            var segments: [NarrativeSegment] = []
            segments.append(.text("The records begin in \(dateFormatter.string(from: minDate)) when \(firstName) was in the community"))

            let communityDetails = extractCommunityDetails(
                notes: notes,
                startDate: minDate,
                endDate: firstInpatient.start,
                episodes: episodes
            )

            // Concerns (safeguarding, substance use, etc.)
            let concernTypes = communityDetails.concerns.map { $0.type }
            if !concernTypes.isEmpty {
                segments.append(.text(" with \(concernTypes.prefix(2).joined(separator: " and ")) noted"))
            }

            // Crisis events (Section 136, A&E) - only mention once
            if !communityDetails.crisisEvents.isEmpty {
                let crisisTypes = Array(Set(communityDetails.crisisEvents.map { $0.type }))
                segments.append(.text(". During this period, there was \(crisisTypes.joined(separator: " and "))"))
            }

            segments.append(.text(".\n\n"))

            // Medications with reference
            let medNames = communityDetails.medications.map { $0.name }
            if !medNames.isEmpty {
                let medNote = firstCommunityNotes.first { note in
                    medNames.contains { med in note.body.lowercased().contains(med.lowercased()) }
                }
                let medsText = "\(proCap) was maintained on \(medNames.prefix(3).joined(separator: ", "))"
                if let note = medNote {
                    let ref = InlineReference(noteId: note.id, highlightText: medNames.first)
                    segments.append(.referenced(text: medsText, reference: ref, format: []))
                } else {
                    segments.append(.text(medsText))
                }
                segments.append(.text(". "))
            }

            // Engagement (psychology, activities) - only mention if present
            var engagementTypes: [String] = []
            engagementTypes.append(contentsOf: communityDetails.psychology.map { $0.type })
            engagementTypes.append(contentsOf: communityDetails.activities.map { $0.type })
            let uniqueEngagement = Array(Set(engagementTypes))
            if !uniqueEngagement.isEmpty {
                segments.append(.text("\(proCap) engaged with \(uniqueEngagement.prefix(2).joined(separator: " and ")). "))
            }

            // Incidents with references (self-harm, aggression)
            let earlyIncidents = risks?.incidents.filter { $0.date < firstInpatient.start } ?? []
            let selfHarm = earlyIncidents.filter { $0.category == .selfHarm }
            let aggression = earlyIncidents.filter { $0.category == .physicalAggression || $0.category == .verbalAggression }

            if !selfHarm.isEmpty {
                let selfHarmNote = firstCommunityNotes.first { note in
                    let lower = note.body.lowercased()
                    return lower.contains("self-harm") || lower.contains("self harm") || lower.contains("cut") || lower.contains("overdose")
                }
                let shText = "There were \(selfHarm.count) instance\(selfHarm.count == 1 ? "" : "s") of self-harm during this period"
                if let note = selfHarmNote {
                    let ref = InlineReference(noteId: note.id, highlightText: "self-harm")
                    segments.append(.referenced(text: shText, reference: ref, format: []))
                } else {
                    segments.append(.text(shText))
                }
                segments.append(.text(". "))
            }

            if !aggression.isEmpty {
                let aggressionNote = firstCommunityNotes.first { note in
                    let lower = note.body.lowercased()
                    return lower.contains("aggression") || lower.contains("assault") || lower.contains("violence")
                }
                let agText = "There were \(aggression.count) instance\(aggression.count == 1 ? "" : "s") of aggression"
                if let note = aggressionNote {
                    let ref = InlineReference(noteId: note.id, highlightText: "aggression")
                    segments.append(.referenced(text: agText, reference: ref, format: []))
                } else {
                    segments.append(.text(agText))
                }
                segments.append(.text(". "))
            }

            segments.append(.text("\n"))
            narrativeParagraphs.append(NarrativeParagraph(segments: segments))
        }
    }

    // Process each episode
    var admissionNumber = 0
    var lastDischargeDate: Date?

    for (index, episode) in episodes.enumerated() {
        let episodeNotes = notes.filter { $0.date >= episode.start && $0.date <= episode.end }
        let episodeIncidents = risks?.incidents.filter { $0.date >= episode.start && $0.date <= episode.end } ?? []

        if episode.type == .inpatient {
            admissionNumber += 1

            let admDetails = extractAdmissionDetails(
                notes: episodeNotes,
                admissionDate: episode.start,
                dischargeDate: episode.end,
                allNotes: notes
            )

            var segments: [NarrativeSegment] = []

            // Gap text (time since last discharge)
            if let lastDischarge = lastDischargeDate {
                let gapDays = calendar.dateComponents([.day], from: lastDischarge, to: episode.start).day ?? 0
                if gapDays < 30 {
                    segments.append(.text("\(proCap) had been out of hospital for only \(gapDays / 7) week\(gapDays / 7 == 1 ? "" : "s") before "))
                } else if gapDays < 365 {
                    let months = gapDays / 30
                    segments.append(.text("\(proCap) had been in the community for \(months) month\(months == 1 ? "" : "s") before "))
                } else {
                    let years = gapDays / 365
                    let remainingMonths = (gapDays % 365) / 30
                    if remainingMonths > 0 {
                        segments.append(.text("\(proCap) had been in the community for \(years) year\(years == 1 ? "" : "s") and \(remainingMonths) month\(remainingMonths == 1 ? "" : "s") before "))
                    } else {
                        segments.append(.text("\(proCap) had been in the community for \(years) year\(years == 1 ? "" : "s") before "))
                    }
                }
            }

            // ADMISSION DESCRIPTION - BOLD with reference - use stored firstNoteId and snippet
            let admNoteId = admDetails.firstNoteId ?? episodeNotes.sorted { $0.date < $1.date }.first?.id
            let admHighlightText = admDetails.firstNoteSnippet ?? "admission"

            if admissionNumber == 1 {
                let admText = "The first admission was on \(shortFormatter.string(from: episode.start))"
                if let noteId = admNoteId {
                    let ref = InlineReference(noteId: noteId, highlightText: admHighlightText)
                    segments.append(.referenced(text: admText, reference: ref, format: .bold))
                } else {
                    segments.append(.bold(admText))
                }
            } else {
                let admText = "\(proPoss) \(ordinal(admissionNumber)) admission on \(shortFormatter.string(from: episode.start))"
                if let noteId = admNoteId {
                    let ref = InlineReference(noteId: noteId, highlightText: admHighlightText)
                    segments.append(.referenced(text: admText, reference: ref, format: .bold))
                } else {
                    segments.append(.bold(admText))
                }
            }

            // Source of admission - use stored noteId and matchedSnippet
            if let source = admDetails.source {
                if let sourceNoteId = admDetails.sourceNoteId {
                    // Use the actual matched snippet for robust highlighting
                    let highlightText = admDetails.sourceSnippet ?? source
                    let ref = InlineReference(noteId: sourceNoteId, highlightText: highlightText)
                    segments.append(.referenced(text: " from \(source)", reference: ref, format: []))
                } else {
                    segments.append(.text(" from \(source)"))
                }
            }

            // Legal status - use stored noteId and matchedSnippet
            if let status = admDetails.legalStatus {
                if let legalNoteId = admDetails.legalStatusNoteId {
                    // Use the actual matched snippet for robust highlighting
                    let highlightText = admDetails.legalStatusSnippet ?? status
                    let ref = InlineReference(noteId: legalNoteId, highlightText: highlightText)
                    segments.append(.referenced(text: " under \(status)", reference: ref, format: []))
                } else {
                    segments.append(.text(" under \(status)"))
                }
            }

            segments.append(.text(". "))

            // Triggers - EACH trigger gets its own reference to its source note
            if !admDetails.triggers.isEmpty {
                segments.append(.text("This admission was precipitated by "))
                let triggersToShow = Array(admDetails.triggers.prefix(3))
                for (index, trigger) in triggersToShow.enumerated() {
                    // Add separator
                    if index > 0 {
                        if index == triggersToShow.count - 1 {
                            segments.append(.text(" and "))
                        } else {
                            segments.append(.text(", "))
                        }
                    }
                    // Each trigger references ITS OWN source note
                    let ref = InlineReference(noteId: trigger.noteId, highlightText: trigger.matchedSnippet)
                    segments.append(.referenced(text: trigger.trigger, reference: ref, format: []))
                }
                segments.append(.text(". "))
            }

            // Presenting symptoms - EACH symptom gets its own reference to its source note
            if !admDetails.presentingComplaints.isEmpty {
                segments.append(.text("\(proCap) presented with "))
                let complaintsToShow = Array(admDetails.presentingComplaints.prefix(3))
                for (index, complaint) in complaintsToShow.enumerated() {
                    // Add separator
                    if index > 0 {
                        if index == complaintsToShow.count - 1 {
                            segments.append(.text(" and "))
                        } else {
                            segments.append(.text(", "))
                        }
                    }
                    // Each complaint references ITS OWN source note
                    let ref = InlineReference(noteId: complaint.noteId, highlightText: complaint.matchedSnippet)
                    segments.append(.referenced(text: complaint.complaint, reference: ref, format: []))
                }
                segments.append(.text(". "))
            }

            // Duration
            let days = episode.duration
            let durationDesc: String
            if days < 7 {
                durationDesc = "less than a week"
            } else if days < 30 {
                durationDesc = "\(days) days"
            } else if days < 60 {
                durationDesc = "approximately \(days / 30) month"
            } else {
                durationDesc = "approximately \(days / 30) months"
            }
            segments.append(.text("This admission lasted \(durationDesc). "))

            // Notable incidents (seclusion) with references - use stored noteId and matchedSnippet
            let seclusionIncidents = admDetails.notableIncidents.filter { $0.type == "seclusion" }
                .sorted { $0.date < $1.date }

            if !seclusionIncidents.isEmpty {
                if seclusionIncidents.count == 1 {
                    let secDate = shortFormatter.string(from: seclusionIncidents[0].date)
                    let secText = "On \(secDate), there was an incident requiring seclusion"
                    // Use the actual matched snippet for robust highlighting
                    let ref = InlineReference(noteId: seclusionIncidents[0].noteId, highlightText: seclusionIncidents[0].matchedSnippet)
                    segments.append(.referenced(text: secText, reference: ref, format: []))
                    segments.append(.text(". "))
                } else if seclusionIncidents.count == 2 {
                    // First seclusion - use stored noteId and matchedSnippet
                    let sec1Date = shortFormatter.string(from: seclusionIncidents[0].date)
                    let sec1Text = "On \(sec1Date), there was an incident requiring seclusion"
                    let ref1 = InlineReference(noteId: seclusionIncidents[0].noteId, highlightText: seclusionIncidents[0].matchedSnippet)
                    segments.append(.referenced(text: sec1Text, reference: ref1, format: []))
                    segments.append(.text(". "))

                    // Second seclusion - use stored noteId and matchedSnippet
                    let sec2Date = shortFormatter.string(from: seclusionIncidents[1].date)
                    let sec2Text = "There was also seclusion required on \(sec2Date)"
                    let ref2 = InlineReference(noteId: seclusionIncidents[1].noteId, highlightText: seclusionIncidents[1].matchedSnippet)
                    segments.append(.referenced(text: sec2Text, reference: ref2, format: []))
                    segments.append(.text(". "))
                } else {
                    // First seclusion (3+ incidents) - use stored noteId and matchedSnippet
                    let sec1Date = shortFormatter.string(from: seclusionIncidents[0].date)
                    let sec1Text = "On \(sec1Date), there was an incident requiring seclusion"
                    let ref1 = InlineReference(noteId: seclusionIncidents[0].noteId, highlightText: seclusionIncidents[0].matchedSnippet)
                    segments.append(.referenced(text: sec1Text, reference: ref1, format: []))
                    segments.append(.text(". "))

                    // Second + more - use stored noteId and matchedSnippet
                    let sec2Date = shortFormatter.string(from: seclusionIncidents[1].date)
                    let moreCount = seclusionIncidents.count - 2
                    let sec2Text = "There was also seclusion required on \(sec2Date)"
                    let ref2 = InlineReference(noteId: seclusionIncidents[1].noteId, highlightText: seclusionIncidents[1].matchedSnippet)
                    segments.append(.referenced(text: sec2Text, reference: ref2, format: []))
                    segments.append(.text(" and \(moreCount) further occasion\(moreCount > 1 ? "s" : ""). "))
                }
            }

            // Presentation fluctuation - WITH REFERENCES for each incident type
            if !episodeIncidents.isEmpty && episodeIncidents.count > 5 {
                // Group incidents by category and get a representative note for each
                var incidentsByCategory: [RiskCategory: [RiskIncident]] = [:]
                for incident in episodeIncidents {
                    incidentsByCategory[incident.category, default: []].append(incident)
                }

                // Calculate incident progression pattern
                let sortedIncidents = episodeIncidents.sorted { $0.date < $1.date }
                let midpoint = episode.start.addingTimeInterval(episode.end.timeIntervalSince(episode.start) / 2)
                let firstHalf = sortedIncidents.filter { $0.date < midpoint }.count
                let secondHalf = sortedIncidents.filter { $0.date >= midpoint }.count

                let pattern: String
                if firstHalf > secondHalf * 2 {
                    pattern = "improving"
                } else if secondHalf > firstHalf * 2 {
                    pattern = "worsening"
                } else {
                    pattern = "fluctuating"
                }

                // Build concern description with references
                if pattern == "fluctuating" {
                    segments.append(.text("During this admission, \(proPoss) presentation fluctuated with many concerns about "))
                } else if pattern == "improving" {
                    segments.append(.text("During this admission, initially there were many concerns involving "))
                } else if pattern == "worsening" {
                    segments.append(.text("During this admission, \(proPoss) behaviour deteriorated with concerns about "))
                } else {
                    segments.append(.text("During this admission, there were multiple concerns involving "))
                }

                // Add each incident type WITH REFERENCE to a specific incident note
                let categoriesToShow = Array(incidentsByCategory.keys.prefix(3))
                for (index, category) in categoriesToShow.enumerated() {
                    if index > 0 {
                        if index == categoriesToShow.count - 1 {
                            segments.append(.text(" and "))
                        } else {
                            segments.append(.text(", "))
                        }
                    }

                    // Get a representative incident for this category - use the incident's noteId directly
                    if let incidents = incidentsByCategory[category],
                       let firstIncident = incidents.first {
                        // Use the incident's noteId and matchedText for the reference
                        let highlightText = firstIncident.matchedText.isEmpty ? category.rawValue : firstIncident.matchedText
                        let ref = InlineReference(noteId: firstIncident.noteId, highlightText: highlightText)
                        segments.append(.referenced(text: category.rawValue, reference: ref, format: []))
                    } else {
                        segments.append(.text(category.rawValue))
                    }
                }

                if pattern == "improving" {
                    segments.append(.text(", which gradually reduced. "))
                } else {
                    segments.append(.text(". "))
                }
            }

            // Medications with reference - use stored noteId
            // Medications - EACH medication gets its own reference to its source note
            if !admDetails.medicationChanges.isEmpty {
                segments.append(.text("During the admission, "))
                let medsToShow = Array(admDetails.medicationChanges.prefix(3))
                for (index, med) in medsToShow.enumerated() {
                    // Add separator
                    if index > 0 {
                        if index == medsToShow.count - 1 {
                            segments.append(.text(" and "))
                        } else {
                            segments.append(.text(", "))
                        }
                    }
                    // Each medication references ITS OWN source note
                    let ref = InlineReference(noteId: med.noteId, highlightText: med.matchedSnippet)
                    segments.append(.referenced(text: med.name, reference: ref, format: []))
                }
                segments.append(.text(" \(admDetails.medicationChanges.count == 1 ? "was" : "were") commenced. "))
            }

            // Improvement factors - EACH factor gets its own reference to its source note
            if !admDetails.improvementFactors.isEmpty {
                segments.append(.text("\(proCap) showed improvement with "))
                let factorsToShow = Array(admDetails.improvementFactors.prefix(2))
                for (index, factor) in factorsToShow.enumerated() {
                    // Add separator
                    if index > 0 {
                        segments.append(.text(" and "))
                    }
                    // Each factor references ITS OWN source note
                    let ref = InlineReference(noteId: factor.noteId, highlightText: factor.matchedSnippet)
                    segments.append(.referenced(text: factor.factor, reference: ref, format: []))
                }
                // Add successful leave if present
                if let leave = admDetails.successfulLeave {
                    segments.append(.text(" and took "))
                    let leaveRef = InlineReference(noteId: leave.noteId, highlightText: leave.matchedSnippet)
                    segments.append(.referenced(text: "successful leave", reference: leaveRef, format: []))
                }
                segments.append(.text(". "))
            } else if let leave = admDetails.successfulLeave {
                // Use stored noteId and matchedSnippet for successful leave
                segments.append(.text("\(proCap) took "))
                let ref = InlineReference(noteId: leave.noteId, highlightText: leave.matchedSnippet)
                segments.append(.referenced(text: "successful leave", reference: ref, format: []))
                segments.append(.text(" prior to discharge. "))
            }

            // DISCHARGE - BOLD with reference - use stored noteId and snippet
            let dischargeText = "\(proCap) was discharged on \(shortFormatter.string(from: episode.end))"
            if let dischargeNoteId = admDetails.dischargeNoteId {
                let highlightText = admDetails.dischargeSnippet ?? "discharge"
                let ref = InlineReference(noteId: dischargeNoteId, highlightText: highlightText)
                segments.append(.referenced(text: dischargeText, reference: ref, format: .bold))
            } else if let lastNote = episodeNotes.sorted(by: { $0.date < $1.date }).last {
                let highlightText = extractSnippetAround(keyword: "discharge", in: lastNote.body) ?? "discharge"
                let ref = InlineReference(noteId: lastNote.id, highlightText: highlightText)
                segments.append(.referenced(text: dischargeText, reference: ref, format: .bold))
            } else {
                segments.append(.bold(dischargeText))
            }
            segments.append(.text(".\n\n"))

            lastDischargeDate = episode.end

            narrativeParagraphs.append(NarrativeParagraph(segments: segments))

        } else if episode.type == .community && episode.duration > 30 {
            // Skip the initial community period - it was already covered above
            if let initialEnd = initialCommunityEndDate, episode.end <= initialEnd {
                continue
            }

            // Community period
            let nextAdmissionIndex = episodes.suffix(from: index + 1).firstIndex { $0.type == .inpatient }
            let nextAdmissionDate = nextAdmissionIndex.flatMap { episodes[$0].start }

            let communityDetails = extractCommunityDetails(
                notes: notes,
                startDate: episode.start,
                endDate: nextAdmissionDate ?? episode.end,
                episodes: episodes
            )

            var segments: [NarrativeSegment] = []

            // Medications
            let medNames = communityDetails.medications.map { $0.name }
            if !medNames.isEmpty {
                let medNote = episodeNotes.first { note in
                    medNames.contains { med in
                        note.body.lowercased().contains(med.lowercased())
                    }
                }
                let medsText = "\(proCap) was maintained on \(medNames.prefix(3).joined(separator: ", "))"
                if let note = medNote {
                    let ref = InlineReference(noteId: note.id, highlightText: medNames.first)
                    segments.append(.referenced(text: medsText, reference: ref, format: []))
                } else {
                    segments.append(.text(medsText))
                }
                segments.append(.text(". "))
            }

            // Engagement - derive from psychology, clinics, activities
            var engagementTypes: [String] = []
            engagementTypes.append(contentsOf: communityDetails.psychology.map { $0.type })
            engagementTypes.append(contentsOf: communityDetails.clinics.map { $0.type })
            engagementTypes.append(contentsOf: communityDetails.activities.map { $0.type })
            let uniqueEngagement = Array(Set(engagementTypes))
            if !uniqueEngagement.isEmpty {
                segments.append(.text("\(proCap) engaged with \(uniqueEngagement.prefix(2).joined(separator: " and ")). "))
            }

            // Crisis events
            if !communityDetails.crisisEvents.isEmpty {
                let crisisTypes = Array(Set(communityDetails.crisisEvents.map { $0.type }))
                segments.append(.text("There was \(crisisTypes.joined(separator: " and ")) during this period. "))
            }

            // Incidents with references
            let selfHarm = episodeIncidents.filter { $0.category == .selfHarm }
            let aggression = episodeIncidents.filter { $0.category == .physicalAggression || $0.category == .verbalAggression }

            if !selfHarm.isEmpty {
                // Find a note with self-harm reference
                let selfHarmNote = episodeNotes.first { note in
                    let lower = note.body.lowercased()
                    return lower.contains("self-harm") || lower.contains("self harm") || lower.contains("cut") || lower.contains("overdose") || lower.contains("ligature")
                }
                let shText = "There were \(selfHarm.count) instance\(selfHarm.count == 1 ? "" : "s") of self-harm during this period"
                if let note = selfHarmNote {
                    let ref = InlineReference(noteId: note.id, highlightText: "self-harm")
                    segments.append(.referenced(text: shText, reference: ref, format: []))
                } else {
                    segments.append(.text(shText))
                }
                segments.append(.text(". "))
            }
            if !aggression.isEmpty {
                // Find a note with aggression reference
                let aggressionNote = episodeNotes.first { note in
                    let lower = note.body.lowercased()
                    return lower.contains("aggression") || lower.contains("aggressive") || lower.contains("assault") || lower.contains("violence") || lower.contains("attacked")
                }
                let agText = "There were \(aggression.count) instance\(aggression.count == 1 ? "" : "s") of aggression"
                if let note = aggressionNote {
                    let ref = InlineReference(noteId: note.id, highlightText: "aggression")
                    segments.append(.referenced(text: agText, reference: ref, format: []))
                } else {
                    segments.append(.text(agText))
                }
                segments.append(.text(". "))
            }

            if !segments.isEmpty {
                segments.append(.text("\n"))
                narrativeParagraphs.append(NarrativeParagraph(segments: segments))
            }
        }
    }

    sections.append(NarrativeSection(title: nil, content: narrativeParagraphs))

    // MARK: Incident Log
    var summarySegments: [NarrativeSegment] = [
        .bold("\nINCIDENT LOG:\n")
    ]

    // List physical aggression concerns with references (deduplicated)
    let physicalIncidentsRaw = risks?.incidents.filter { $0.category == .physicalAggression } ?? []
    let physicalIncidents = dedupeIncidents(physicalIncidentsRaw)
    if !physicalIncidents.isEmpty {
        summarySegments.append(.bold("Physical aggression concerns (\(physicalIncidents.count)):\n"))
        for incident in physicalIncidents.prefix(10) {  // Limit to 10 most significant
            let dateStr = shortFormatter.string(from: incident.date)
            let ref = InlineReference(noteId: incident.noteId, highlightText: incident.matchedText)
            summarySegments.append(.text("  • \(dateStr): "))
            summarySegments.append(.referenced(text: incident.matchedText.prefix(80).description, reference: ref, format: []))
            summarySegments.append(.text("\n"))
        }
        if physicalIncidents.count > 10 {
            summarySegments.append(.text("  ... and \(physicalIncidents.count - 10) more\n"))
        }
        summarySegments.append(.text("\n"))
    }

    // List verbal aggression concerns with references (deduplicated)
    let verbalIncidentsRaw = risks?.incidents.filter { $0.category == .verbalAggression } ?? []
    let verbalIncidents = dedupeIncidents(verbalIncidentsRaw)
    if !verbalIncidents.isEmpty {
        summarySegments.append(.bold("Verbal aggression concerns (\(verbalIncidents.count)):\n"))
        for incident in verbalIncidents.prefix(10) {
            let dateStr = shortFormatter.string(from: incident.date)
            let ref = InlineReference(noteId: incident.noteId, highlightText: incident.matchedText)
            summarySegments.append(.text("  • \(dateStr): "))
            summarySegments.append(.referenced(text: incident.matchedText.prefix(80).description, reference: ref, format: []))
            summarySegments.append(.text("\n"))
        }
        if verbalIncidents.count > 10 {
            summarySegments.append(.text("  ... and \(verbalIncidents.count - 10) more\n"))
        }
        summarySegments.append(.text("\n"))
    }

    // List self-harm concerns with references (deduplicated)
    let selfHarmIncidentsRaw = risks?.incidents.filter { $0.category == .selfHarm } ?? []
    let selfHarmIncidents = dedupeIncidents(selfHarmIncidentsRaw)
    if !selfHarmIncidents.isEmpty {
        summarySegments.append(.bold("Self-harm concerns (\(selfHarmIncidents.count)):\n"))
        for incident in selfHarmIncidents.prefix(10) {
            let dateStr = shortFormatter.string(from: incident.date)
            let ref = InlineReference(noteId: incident.noteId, highlightText: incident.matchedText)
            summarySegments.append(.text("  • \(dateStr): "))
            summarySegments.append(.referenced(text: incident.matchedText.prefix(80).description, reference: ref, format: []))
            summarySegments.append(.text("\n"))
        }
        if selfHarmIncidents.count > 10 {
            summarySegments.append(.text("  ... and \(selfHarmIncidents.count - 10) more\n"))
        }
        summarySegments.append(.text("\n"))
    }

    summarySegments.append(.text("\(proCap) had \(inpatientEpisodes.count) admission\(inpatientEpisodes.count == 1 ? "" : "s") totalling \(totalInpatientDays) inpatient days.\n\n"))
    summarySegments.append(.text("---\n"))

    let reportDateFormatter = DateFormatter()
    reportDateFormatter.dateFormat = "dd MMMM yyyy"
    summarySegments.append(.text("Report generated: \(reportDateFormatter.string(from: Date()))"))

    sections.append(NarrativeSection(title: nil, content: [
        NarrativeParagraph(segments: summarySegments)
    ]))

    return sections
}

// MARK: - Helper Functions

private func ordinal(_ n: Int) -> String {
    let suffix: String
    if (11...13).contains(n % 100) {
        suffix = "th"
    } else {
        switch n % 10 {
        case 1: suffix = "st"
        case 2: suffix = "nd"
        case 3: suffix = "rd"
        default: suffix = "th"
        }
    }
    return "\(n)\(suffix)"
}

/// Deduplicate incidents by removing entries with the same date and similar matched text
private func dedupeIncidents(_ incidents: [RiskIncident]) -> [RiskIncident] {
    var seen: Set<String> = []
    var result: [RiskIncident] = []

    let dayFormatter = DateFormatter()
    dayFormatter.dateFormat = "yyyy-MM-dd"

    for incident in incidents {
        // Create a key from date (day only) and normalized matched text
        let dateKey = dayFormatter.string(from: incident.date)
        let textKey = incident.matchedText.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(50)  // Use first 50 chars for comparison
        let key = "\(dateKey)|\(textKey)"

        if !seen.contains(key) {
            seen.insert(key)
            result.append(incident)
        }
    }

    return result
}
