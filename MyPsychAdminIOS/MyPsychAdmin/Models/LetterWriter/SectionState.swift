//
//  SectionState.swift
//  MyPsychAdmin
//

import Foundation

struct SectionState: Codable, Equatable {
    var content: String = ""
    var isLocked: Bool = false
    var lastModified: Date = Date()
    var popupData: Data?
    var lastPopupGeneratedContent: String?
    var fontSize: CGFloat = 15

    mutating func setContent(_ text: String) {
        content = text
        lastModified = Date()
    }

    mutating func appendContent(_ text: String) {
        if content.isEmpty {
            content = text
        } else {
            content += "\n\n" + text
        }
        lastModified = Date()
    }

    mutating func toggleLock() {
        isLocked.toggle()
    }

    var isEmpty: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 100 {
            return trimmed
        }
        return String(trimmed.prefix(100)) + "..."
    }
}

struct LetterSection: Identifiable, Equatable {
    let type: SectionType
    var state: SectionState

    var id: String { type.id }
    var title: String { type.title }
    var isLocked: Bool { state.isLocked }
    var content: String { state.content }

    init(type: SectionType, state: SectionState = SectionState()) {
        self.type = type
        self.state = state
    }
}
