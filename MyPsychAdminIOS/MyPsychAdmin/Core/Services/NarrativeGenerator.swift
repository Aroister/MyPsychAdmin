import Foundation

/// Comprehensive narrative generator for clinical reports.
/// Ported from Python tribunal_popups.py _generate_narrative_summary()
///
/// Used by:
/// - ASR Section 8 (1 year filter)
/// - MOJ Leave Section 4d (1 year filter)
/// - Psych Tribunal Section 14 (1 year filter)
/// - Nursing Tribunal Section 9 (1 year filter)
/// - Social Circumstances Section 16 (1 year filter)
/// - General Psychiatric Report Section 3 (last admission filter)

// MARK: - Data Structures

struct NarrativeEntry {
    let date: Date?
    let content: String
    let type: String
    let originator: String
    var score: Int = 0
    var drivers: [(String, Int)] = []

    var contentLower: String {
        content.lowercased()
    }
}

struct NarrativeResult {
    let plainText: String
    let htmlText: String
    let dateRange: String
    let entryCount: Int
}

enum NarrativePeriod: String {
    case all = "all"
    case oneYear = "1_year"
    case sixMonths = "6_months"
    case lastAdmission = "last_admission"
}

// MARK: - Episode Detection

struct Episode {
    let type: EpisodeType
    let start: Date
    let end: Date
    let ward: String?
    let external: Bool

    enum EpisodeType: String {
        case inpatient
        case community
    }
}

// MARK: - NarrativeGenerator

class NarrativeGenerator {

    // MARK: - Properties

    private var riskDict: [String: Int] = [:]
    private var entries: [NarrativeEntry] = []
    private var referenceCounter: Int = 0
    private var references: [String: [String: Any]] = [:]

    // Excluded generic terms that cause false positives
    private let excludedTerms: Set<String> = [
        "high", "low", "reduce", "reduced", "reducing", "reduction",
        "increase", "increased", "increasing",
        "good", "bad", "well", "poor",
        "im", "war", "king", "ran", "poo",
        "can", "will", "may", "has", "had", "was", "were",
        "new", "old", "some", "any", "all", "one", "two",
        "time", "times", "day", "days", "week", "weeks",
        "said", "says", "told", "asked", "noted",
        "need", "needs", "want", "wants",
        "see", "seen", "saw", "look", "looked",
        "feel", "felt", "feeling", "feelings",
        "think", "thought", "thinking",
        "make", "made", "making",
        "take", "took", "taking",
        "go", "going", "went", "gone",
        "come", "came", "coming",
        "get", "got", "getting",
        "know", "known", "knowing",
        "give", "gave", "given",
        "find", "found", "finding",
        "tell", "telling",
        "work", "working", "worked",
        "seem", "seems", "seemed",
        "leave", "left",
        "call", "called", "calling",
        "try", "tried", "trying",
        "use", "used", "using",
        "help", "helped", "helping",
        "please"
    ]

    // Signature block starters to filter out
    private let signatureStarters = [
        "kind regards", "best regards", "warm regards", "regards,",
        "many thanks", "thanks,", "thank you,", "yours sincerely",
        "yours faithfully", "best wishes", "with thanks", "cheers,"
    ]

    // Job title patterns to filter
    private let jobTitlePatterns = [
        "anti.?social\\s+behaviour\\s+officer",
        "staff\\s+nurse|ward\\s+manager|consultant|psychiatrist",
        "social\\s+worker|care\\s*coordinator",
        "clinical\\s+nurse|specialist\\s+nurse",
        "team\\s+leader|service\\s+manager",
        "safeguarding\\s+officer|liaison\\s+officer",
        "community\\s+nurse|community\\s+mental\\s+health",
        "forensic\\s+community\\s+nurse|specialist\\s+forensic",
        "cpn|cpa|rcn|rmn",
        "occupational\\s+therapist|physiotherapist",
        "psychologist|psychology\\s+assistant",
        "support\\s+worker|recovery\\s+worker|healthcare\\s+assistant",
        "registrar|sho|fy\\d|ct\\d|st\\d",
        "band\\s+\\d|deputy\\s+manager|matron"
    ]

    // MARK: - Initialization

    init() {
        loadRiskDictionary()
    }

    // MARK: - Public Methods

    /// Generate narrative from entries with specified period filter
    func generateNarrative(
        from entries: [NarrativeEntry],
        period: NarrativePeriod = .oneYear,
        patientName: String? = nil,
        gender: String? = nil
    ) -> NarrativeResult {
        // Filter entries by period
        let filteredEntries = filterEntries(entries, by: period)

        if filteredEntries.isEmpty {
            return NarrativeResult(plainText: "", htmlText: "", dateRange: "No entries", entryCount: 0)
        }

        // Reset reference tracker
        resetReferenceTracker()

        // Score entries
        var scoredEntries = filteredEntries.map { entry -> NarrativeEntry in
            var mutableEntry = entry
            let (score, drivers) = scoreEntry(entry.content)
            mutableEntry.score = score
            mutableEntry.drivers = drivers
            return mutableEntry
        }

        // Sort by date
        scoredEntries.sort { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }

        self.entries = scoredEntries

        // Set up pronouns
        let pronouns = getPronouns(for: gender)
        let name = patientName?.components(separatedBy: " ").first ?? "The patient"

        // Build narrative
        let (plainText, htmlText) = buildNarrative(
            name: name,
            pronouns: pronouns,
            entries: scoredEntries
        )

        // Get date range
        let dateRange = getDateRangeInfo(entries: filteredEntries, period: period)

        return NarrativeResult(
            plainText: plainText,
            htmlText: htmlText,
            dateRange: dateRange,
            entryCount: filteredEntries.count
        )
    }

    /// Convenience method for 1-year narrative
    func generateNarrativeOneYear(
        from entries: [NarrativeEntry],
        patientName: String? = nil,
        gender: String? = nil
    ) -> NarrativeResult {
        return generateNarrative(from: entries, period: .oneYear, patientName: patientName, gender: gender)
    }

    /// Convenience method for full notes narrative
    func generateNarrativeFull(
        from entries: [NarrativeEntry],
        patientName: String? = nil,
        gender: String? = nil
    ) -> NarrativeResult {
        return generateNarrative(from: entries, period: .all, patientName: patientName, gender: gender)
    }

    /// Convenience method for last admission narrative
    func generateNarrativeLastAdmission(
        from entries: [NarrativeEntry],
        patientName: String? = nil,
        gender: String? = nil
    ) -> NarrativeResult {
        return generateNarrative(from: entries, period: .lastAdmission, patientName: patientName, gender: gender)
    }

    // MARK: - Entry Filtering

    private func filterEntries(_ entries: [NarrativeEntry], by period: NarrativePeriod) -> [NarrativeEntry] {
        guard !entries.isEmpty else { return [] }

        switch period {
        case .all:
            return entries

        case .oneYear:
            guard let mostRecent = entries.compactMap({ $0.date }).max() else { return entries }
            let cutoff = Calendar.current.date(byAdding: .day, value: -365, to: mostRecent) ?? mostRecent
            return entries.filter { ($0.date ?? .distantPast) >= cutoff }

        case .sixMonths:
            guard let mostRecent = entries.compactMap({ $0.date }).max() else { return entries }
            let cutoff = Calendar.current.date(byAdding: .day, value: -180, to: mostRecent) ?? mostRecent
            return entries.filter { ($0.date ?? .distantPast) >= cutoff }

        case .lastAdmission:
            return filterByLastAdmission(entries)
        }
    }

    private func filterByLastAdmission(_ entries: [NarrativeEntry]) -> [NarrativeEntry] {
        // Detect episodes from entries
        let episodes = detectEpisodes(from: entries)

        // Find last inpatient episode
        let inpatientEpisodes = episodes.filter { $0.type == .inpatient }
        guard let lastAdmission = inpatientEpisodes.last else {
            return entries // Return all if no admission found
        }

        return entries.filter { entry in
            guard let date = entry.date else { return false }
            return date >= lastAdmission.start && date <= lastAdmission.end
        }
    }

    // MARK: - Episode Detection

    private func detectEpisodes(from entries: [NarrativeEntry]) -> [Episode] {
        var episodes: [Episode] = []

        // Keywords for admission detection
        let admissionKeywords = ["admitted", "admission", "transfer to ward", "arrived on ward"]
        let dischargeKeywords = ["discharged", "discharge", "left ward", "transferred out"]
        let inpatientKeywords = ["ward", "inpatient", "section 3", "section 2", "detained"]
        let communityKeywords = ["community", "outpatient", "home visit", "cpa"]

        // Sort entries by date
        let sortedEntries = entries.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }

        var currentEpisodeStart: Date?
        var currentEpisodeType: Episode.EpisodeType?
        var currentWard: String?

        for entry in sortedEntries {
            guard let date = entry.date else { continue }
            let contentLower = entry.contentLower

            // Detect admission
            let isAdmission = admissionKeywords.contains { contentLower.contains($0) }
            let isDischarge = dischargeKeywords.contains { contentLower.contains($0) }
            let isInpatient = inpatientKeywords.contains { contentLower.contains($0) }
            let isCommunity = communityKeywords.contains { contentLower.contains($0) }

            if isAdmission && currentEpisodeStart == nil {
                currentEpisodeStart = date
                currentEpisodeType = .inpatient
                // Try to extract ward name
                if let wardMatch = contentLower.range(of: "\\b([a-z]+)\\s+ward\\b", options: .regularExpression) {
                    currentWard = String(contentLower[wardMatch])
                }
            } else if isDischarge && currentEpisodeStart != nil {
                // End current episode
                episodes.append(Episode(
                    type: currentEpisodeType ?? .inpatient,
                    start: currentEpisodeStart!,
                    end: date,
                    ward: currentWard,
                    external: false
                ))
                currentEpisodeStart = nil
                currentEpisodeType = nil
                currentWard = nil
            } else if isCommunity && currentEpisodeStart == nil {
                // Start community episode
                currentEpisodeStart = date
                currentEpisodeType = .community
            } else if isInpatient && currentEpisodeType == .community && currentEpisodeStart != nil {
                // Transition from community to inpatient
                episodes.append(Episode(
                    type: .community,
                    start: currentEpisodeStart!,
                    end: date,
                    ward: nil,
                    external: false
                ))
                currentEpisodeStart = date
                currentEpisodeType = .inpatient
            }
        }

        // Close any open episode
        if let start = currentEpisodeStart, let last = sortedEntries.last?.date {
            episodes.append(Episode(
                type: currentEpisodeType ?? .inpatient,
                start: start,
                end: last,
                ward: currentWard,
                external: false
            ))
        }

        return episodes
    }

    // MARK: - Pronouns

    struct Pronouns {
        let subject: String      // he/she/they
        let object: String       // him/her/them
        let possessive: String   // his/her/their
        let subjectCap: String   // He/She/They
        let possessiveCap: String // His/Her/Their
    }

    private func getPronouns(for gender: String?) -> Pronouns {
        let genderLower = (gender ?? "").lowercased()

        switch genderLower {
        case "female", "f":
            return Pronouns(
                subject: "she",
                object: "her",
                possessive: "her",
                subjectCap: "She",
                possessiveCap: "Her"
            )
        case "male", "m":
            return Pronouns(
                subject: "he",
                object: "him",
                possessive: "his",
                subjectCap: "He",
                possessiveCap: "His"
            )
        default:
            return Pronouns(
                subject: "they",
                object: "them",
                possessive: "their",
                subjectCap: "They",
                possessiveCap: "Their"
            )
        }
    }

    // MARK: - Risk Scoring

    private func loadRiskDictionary() {
        // Load from riskDICT.txt if available, otherwise use built-in dictionary
        // For iOS, we'll use a built-in dictionary
        riskDict = [
            // High-risk terms (score 10-15)
            "suicide": 15, "suicidal": 15, "self-harm": 14, "self harm": 14,
            "overdose": 14, "od": 12, "ligature": 14, "hanging": 14,
            "violence": 13, "violent": 13, "assault": 13, "assaulted": 13,
            "aggression": 12, "aggressive": 12, "attack": 12, "attacked": 12,
            "seclusion": 12, "restraint": 11, "rapid tranq": 12,
            "awol": 11, "abscond": 11, "absconded": 11, "absconding": 11,
            "police": 10, "arrested": 11, "arrest": 11,
            "fire": 12, "arson": 14,
            "weapon": 13, "knife": 13,

            // Medium-risk terms (score 5-9)
            "paranoid": 8, "paranoia": 8, "persecutory": 8,
            "delusion": 8, "delusional": 8, "hallucination": 8,
            "psychosis": 9, "psychotic": 9,
            "manic": 8, "mania": 8, "elated": 7,
            "agitated": 7, "agitation": 7, "irritable": 6, "irritability": 6,
            "threatening": 8, "threat": 8, "intimidat": 7,
            "damage": 7, "property": 6,
            "non-compliant": 7, "non compliant": 7, "refused": 6, "refusing": 6,
            "deteriorat": 8, "relapse": 8,
            "withdrawn": 6, "isolat": 6,
            "cannabis": 5, "cocaine": 6, "heroin": 7, "drug": 5, "substance": 5,
            "intoxicat": 6, "alcohol": 5,

            // Lower-risk terms (score 1-4)
            "anxiety": 4, "anxious": 4, "depressed": 4, "depression": 4,
            "low mood": 4, "poor sleep": 3, "insomnia": 3,
            "voices": 5, "hearing voices": 5,
            "concern": 3, "worried": 3,
            "incident": 5, "altercation": 6,
            "verbal": 4, "verbally": 4,
            "unwell": 4, "unstable": 5
        ]
    }

    private func scoreEntry(_ content: String) -> (Int, [(String, Int)]) {
        let contentLower = content.lowercased()
        let strippedContent = stripSignatureBlock(contentLower)
        var totalScore = 0
        var drivers: [(String, Int)] = []

        for (term, score) in riskDict {
            // Skip excluded terms
            if excludedTerms.contains(term) { continue }
            // Skip very short terms
            if term.count <= 2 { continue }

            // Check if term appears in content
            if strippedContent.contains(term) {
                // Check if negated
                if !isNegated(text: strippedContent, keyword: term) {
                    totalScore += score
                    drivers.append((term, score))
                }
            }
        }

        // Sort drivers by score descending
        drivers.sort { $0.1 > $1.1 }

        return (totalScore, Array(drivers.prefix(5)))
    }

    // MARK: - Signature Stripping

    private func stripSignatureBlock(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var resultLines: [String] = []
        var inSignature = false

        for line in lines {
            let lineStripped = line.trimmingCharacters(in: .whitespaces).lowercased()

            // Check for signature starters
            if signatureStarters.contains(where: { lineStripped.hasPrefix($0) || lineStripped == $0.replacingOccurrences(of: ",", with: "") }) {
                inSignature = true
                continue
            }

            if inSignature { continue }

            // Check for job title lines
            var isJobTitle = false
            for pattern in jobTitlePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(lineStripped.startIndex..., in: lineStripped)
                    if regex.firstMatch(in: lineStripped, options: [], range: range) != nil && lineStripped.count < 60 {
                        isJobTitle = true
                        break
                    }
                }
            }

            if !isJobTitle {
                resultLines.append(line)
            }
        }

        return resultLines.joined(separator: "\n")
    }

    // MARK: - Negation Detection

    private func isNegated(text: String, keyword: String) -> Bool {
        let escapedKeyword = NSRegularExpression.escapedPattern(for: keyword)

        // Quick negation patterns
        let negationPatterns = [
            "not\\s+led\\s+to\\s+\(escapedKeyword)",
            "have\\s+not\\s+led\\s+to\\s+\(escapedKeyword)",
            "has\\s+not\\s+led\\s+to\\s+\(escapedKeyword)",
            "no\\s+\(escapedKeyword)",
            "nil\\s+\(escapedKeyword)",
            "without\\s+\(escapedKeyword)",
            "absence\\s+of\\s+\(escapedKeyword)",
            "no\\s+self[- ]?harm\\s+(or\\s+)?(incidents?\\s+of\\s+)?\(escapedKeyword)",
            "\\bno\\b[^.!?]{0,100}\\b\(escapedKeyword)",
            "didn'?t\\s+present\\s+(as\\s+)?\(escapedKeyword)",
            "did\\s+not\\s+present\\s+(as\\s+)?\(escapedKeyword)",
            "does\\s+not\\s+present\\s+(as\\s+)?\(escapedKeyword)",
            "no\\s+signs?\\s+of\\s+\(escapedKeyword)",
            "there\\s+have\\s+not\\s+been\\b[^.]*\(escapedKeyword)",
            "there\\s+has\\s+not\\s+been\\b[^.]*\(escapedKeyword)",
            "no\\s+incident[^.]*\(escapedKeyword)",
            "\\blow\\b[^.]*\(escapedKeyword)",
            "risks?[:\\s]+[^.]*\\b\(escapedKeyword)",
            "history\\s+of\\s+\(escapedKeyword)",
            "risk\\s+of\\s+\(escapedKeyword)",
            "can\\s+be\\s+\(escapedKeyword)",
            "may\\s+be(come)?\\s+\(escapedKeyword)",
            "\\bcalm\\s+and\\s+settled\\b[^.]*\\b\(escapedKeyword)",
            "nothing\\s+to\\s+suggest\\b[^.]*\\b\(escapedKeyword)",
            "no\\s+evidence\\s+(of|to\\s+suggest)\\b[^.]*\\b\(escapedKeyword)",
            "no\\s+concerns?\\s+(about|regarding|of)\\b[^.]*\\b\(escapedKeyword)"
        ]

        for pattern in negationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    return true
                }
            }
        }

        // Special handling for seclusion - often refers to third party
        if keyword == "seclusion" {
            let thirdPartyPatterns = [
                "\\b(he|his|him|boyfriend|bf|partner)\\b[^.]*\\bseclusion\\b",
                "\\bseclusion\\b[^.]*\\b(he|his|him|boyfriend|bf|partner)\\b"
            ]
            for pattern in thirdPartyPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(text.startIndex..., in: text)
                    if regex.firstMatch(in: text, options: [], range: range) != nil {
                        return true
                    }
                }
            }
        }

        return false
    }

    // MARK: - Narrative Building

    private func buildNarrative(
        name: String,
        pronouns: Pronouns,
        entries: [NarrativeEntry]
    ) -> (String, String) {
        var narrativeParts: [String] = []

        // Detect episodes
        let episodes = detectEpisodes(from: entries)

        // Generate admission headers and narratives
        var admissionIndex = 0
        for episode in episodes where episode.type == .inpatient {
            admissionIndex += 1

            // Add numbered admission header
            let ordinalWords = ["First", "Second", "Third", "Fourth", "Fifth",
                               "Sixth", "Seventh", "Eighth", "Ninth", "Tenth"]
            let ordinal = admissionIndex <= 10 ? ordinalWords[admissionIndex - 1] : "\(admissionIndex)th"
            narrativeParts.append("<b>\(ordinal) Admission</b>")

            // Filter entries for this episode
            let episodeEntries = entries.filter { entry in
                guard let date = entry.date else { return false }
                return date >= episode.start && date <= episode.end
            }

            // Generate narrative for this episode
            let episodeNarrative = generateEpisodeNarrative(
                entries: episodeEntries,
                episode: episode,
                name: name,
                pronouns: pronouns,
                isFirstAdmission: admissionIndex == 1
            )

            narrativeParts.append(episodeNarrative)
        }

        // If no episodes detected, generate general narrative
        if episodes.isEmpty {
            let generalNarrative = generateGeneralNarrative(
                entries: entries,
                name: name,
                pronouns: pronouns
            )
            narrativeParts.append(generalNarrative)
        }

        let htmlText = narrativeParts.joined(separator: " ")
        let plainText = htmlText.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        return (plainText, htmlText)
    }

    private func generateEpisodeNarrative(
        entries: [NarrativeEntry],
        episode: Episode,
        name: String,
        pronouns: Pronouns,
        isFirstAdmission: Bool
    ) -> String {
        var parts: [String] = []

        // Admission intro
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMMM yyyy"
        let startDate = dateFormatter.string(from: episode.start)

        let intro: String
        if isFirstAdmission {
            intro = "\(name) was admitted on \(startDate)"
        } else {
            intro = "\(pronouns.subjectCap) was readmitted on \(startDate)"
        }

        if let ward = episode.ward {
            parts.append("\(intro) to \(ward).")
        } else {
            parts.append("\(intro).")
        }

        // Analyze entries for key information
        let analysis = analyzeEntries(entries, pronouns: pronouns)

        // Mental state
        if !analysis.mentalStatePositive.isEmpty || !analysis.mentalStateNegative.isEmpty {
            var mentalStateParts: [String] = []
            if !analysis.mentalStatePositive.isEmpty {
                let positive = analysis.mentalStatePositive.prefix(3).joined(separator: ", ")
                mentalStateParts.append("\(pronouns.subjectCap) has been \(positive)")
            }
            if !analysis.mentalStateNegative.isEmpty {
                let negative = analysis.mentalStateNegative.prefix(3).joined(separator: ", ")
                if mentalStateParts.isEmpty {
                    mentalStateParts.append("\(pronouns.subjectCap) has shown \(negative)")
                } else {
                    mentalStateParts.append("although has also shown \(negative)")
                }
            }
            parts.append(mentalStateParts.joined(separator: " ") + ".")
        }

        // Incidents
        if !analysis.incidents.isEmpty {
            let incidentCount = analysis.incidents.count
            let incidentWord = incidentCount == 1 ? "incident" : "incidents"
            parts.append("There have been \(incidentCount) notable \(incidentWord) during this period.")
        }

        // Engagement
        if !analysis.engagementPositive.isEmpty {
            let engagement = analysis.engagementPositive.prefix(3).joined(separator: ", ")
            parts.append("\(pronouns.subjectCap) has engaged with \(engagement).")
        }

        // Medication
        if let medCompliance = analysis.medicationCompliance {
            parts.append(medCompliance)
        }

        // Discharge if episode has ended
        if episode.end < Date() {
            let endDate = dateFormatter.string(from: episode.end)
            parts.append("\(pronouns.subjectCap) was discharged on \(endDate).")
        }

        return parts.joined(separator: " ")
    }

    private func generateGeneralNarrative(
        entries: [NarrativeEntry],
        name: String,
        pronouns: Pronouns
    ) -> String {
        var parts: [String] = []

        // Get date range
        let dates = entries.compactMap { $0.date }
        guard let earliest = dates.min(), let latest = dates.max() else {
            return "No dated entries available."
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        let startMonth = dateFormatter.string(from: earliest)
        let endMonth = dateFormatter.string(from: latest)

        if startMonth == endMonth {
            parts.append("During \(startMonth), ")
        } else {
            parts.append("From \(startMonth) to \(endMonth), ")
        }

        // Analyze entries
        let analysis = analyzeEntries(entries, pronouns: pronouns)

        // Overview
        if !analysis.mentalStatePositive.isEmpty {
            let positive = analysis.mentalStatePositive.prefix(2).joined(separator: " and ")
            parts.append("\(name) has generally been \(positive).")
        }

        if !analysis.mentalStateNegative.isEmpty {
            let negative = analysis.mentalStateNegative.prefix(2).joined(separator: " and ")
            parts.append("However, \(pronouns.subject) has also experienced periods of \(negative).")
        }

        // Incidents
        if !analysis.incidents.isEmpty {
            let incidentCount = analysis.incidents.count
            parts.append("There were \(incidentCount) notable incidents during this period.")
        }

        // Engagement
        if !analysis.engagementPositive.isEmpty {
            let engagement = analysis.engagementPositive.joined(separator: ", ")
            parts.append("\(pronouns.subjectCap) has engaged with \(engagement).")
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Entry Analysis

    struct EntryAnalysis {
        var mentalStatePositive: [String] = []
        var mentalStateNegative: [String] = []
        var incidents: [NarrativeEntry] = []
        var engagementPositive: [String] = []
        var engagementNegative: [String] = []
        var medicationCompliance: String?
        var professionalContacts: [String] = []
    }

    private func analyzeEntries(_ entries: [NarrativeEntry], pronouns: Pronouns) -> EntryAnalysis {
        var analysis = EntryAnalysis()

        // Mental state indicators
        let positiveIndicators = ["stable", "settled", "calm", "relaxed", "bright", "euthymic", "pleasant", "cooperative"]
        let negativeIndicators = ["agitated", "irritable", "withdrawn", "paranoid", "delusional", "psychotic", "manic", "depressed", "anxious"]

        // Incident indicators
        let incidentIndicators = ["incident", "altercation", "assault", "aggression", "self-harm", "overdose", "seclusion", "restraint", "awol", "abscond"]

        // Engagement indicators
        let engagementTypes = ["psychology", "ot", "occupational therapy", "nursing", "ward round", "cpa", "activities", "groups"]

        // Medication compliance indicators
        let compliantIndicators = ["compliant", "concordant", "taking medication", "accepted medication"]
        let nonCompliantIndicators = ["non-compliant", "refused medication", "not taking", "declined"]

        var compliantCount = 0
        var nonCompliantCount = 0
        var engagementSet = Set<String>()
        var positiveSet = Set<String>()
        var negativeSet = Set<String>()

        for entry in entries {
            let contentLower = entry.contentLower

            // Check mental state
            for indicator in positiveIndicators {
                if contentLower.contains(indicator) && !isNegated(text: contentLower, keyword: indicator) {
                    positiveSet.insert(indicator)
                }
            }
            for indicator in negativeIndicators {
                if contentLower.contains(indicator) && !isNegated(text: contentLower, keyword: indicator) {
                    negativeSet.insert(indicator)
                }
            }

            // Check incidents
            for indicator in incidentIndicators {
                if contentLower.contains(indicator) && !isNegated(text: contentLower, keyword: indicator) {
                    analysis.incidents.append(entry)
                    break
                }
            }

            // Check engagement
            for engType in engagementTypes {
                if contentLower.contains(engType) {
                    engagementSet.insert(engType)
                }
            }

            // Check medication compliance
            for indicator in compliantIndicators {
                if contentLower.contains(indicator) { compliantCount += 1 }
            }
            for indicator in nonCompliantIndicators {
                if contentLower.contains(indicator) { nonCompliantCount += 1 }
            }
        }

        analysis.mentalStatePositive = Array(positiveSet)
        analysis.mentalStateNegative = Array(negativeSet)
        analysis.engagementPositive = Array(engagementSet)

        // Determine medication compliance
        if compliantCount > 0 || nonCompliantCount > 0 {
            if compliantCount > nonCompliantCount * 2 {
                analysis.medicationCompliance = "\(pronouns.subjectCap) has been compliant with medication."
            } else if nonCompliantCount > compliantCount * 2 {
                analysis.medicationCompliance = "\(pronouns.subjectCap) has been non-compliant with medication."
            } else if compliantCount > 0 && nonCompliantCount > 0 {
                analysis.medicationCompliance = "\(pronouns.possessiveCap) compliance with medication has been variable."
            }
        }

        return analysis
    }

    // MARK: - Reference Tracking

    private func resetReferenceTracker() {
        referenceCounter = 0
        references = [:]
    }

    private func makeLink(text: String, keyword: String, date: Date?, contentSnippet: String = "") -> String {
        referenceCounter += 1
        let refId = "ref_\(referenceCounter)"

        references[refId] = [
            "matched": keyword,
            "date": date as Any,
            "content_snippet": contentSnippet
        ]

        return "<a href=\"#\(refId)\">\(text)</a>"
    }

    // MARK: - Utility Methods

    private func getDateRangeInfo(entries: [NarrativeEntry], period: NarrativePeriod) -> String {
        let dates = entries.compactMap { $0.date }
        guard let earliest = dates.min(), let latest = dates.max() else {
            return "No dated entries"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        let earliestStr = formatter.string(from: earliest)
        let latestStr = formatter.string(from: latest)

        switch period {
        case .all:
            return "Full notes (\(earliestStr) - \(latestStr))"
        case .oneYear:
            return "\(earliestStr) - \(latestStr) (1 year)"
        case .sixMonths:
            return "\(earliestStr) - \(latestStr) (6 months)"
        case .lastAdmission:
            return "\(earliestStr) - \(latestStr) (last admission)"
        }
    }

    /// Get reference data by ID (for link click handling)
    func getReference(id: String) -> [String: Any]? {
        return references[id]
    }
}

// MARK: - Convenience Extension for Converting from Dictionary

extension NarrativeEntry {
    init?(from dict: [String: Any]) {
        guard let content = dict["content"] as? String ?? dict["text"] as? String else {
            return nil
        }

        var date: Date? = nil
        if let dateVal = dict["date"] {
            if let d = dateVal as? Date {
                date = d
            } else if let dateStr = dateVal as? String {
                let formatter = DateFormatter()
                for format in ["yyyy-MM-dd", "dd/MM/yyyy", "yyyy-MM-dd'T'HH:mm:ss", "dd-MM-yyyy"] {
                    formatter.dateFormat = format
                    if let d = formatter.date(from: String(dateStr.prefix(10))) {
                        date = d
                        break
                    }
                }
            }
        }

        self.date = date
        self.content = content
        self.type = dict["type"] as? String ?? ""
        self.originator = dict["originator"] as? String ?? ""
    }
}
