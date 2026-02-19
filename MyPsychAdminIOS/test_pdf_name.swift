#!/usr/bin/env swift

import Foundation
import PDFKit

let pdfPath = "/Users/avie/Desktop/MPA2/Materials/Building materials/Raw test materials/Reports/Tribunal reports/Medical/ES Psychiatric MHRT Report by Dr Stephenson June 2018.pdf"

guard let pdf = PDFDocument(url: URL(fileURLWithPath: pdfPath)) else {
    print("Failed to open PDF")
    exit(1)
}

var allText = ""
for i in 0..<min(pdf.pageCount, 3) {
    if let page = pdf.page(at: i), let text = page.string {
        allText += text + "\n\n"
    }
}

// Show context around "Name"
if let nameRange = allText.range(of: "Name") {
    let startIdx = allText.index(nameRange.lowerBound, offsetBy: -30, limitedBy: allText.startIndex) ?? allText.startIndex
    let endIdx = allText.index(nameRange.upperBound, offsetBy: 50, limitedBy: allText.endIndex) ?? allText.endIndex
    let context = allText[startIdx..<endIdx]
    print("Context: '\(context.replacingOccurrences(of: "\n", with: "\\n"))'")
}

// Test the EXACT patterns from DocumentProcessor
let patterns: [(String, String, NSRegularExpression.Options)] = [
    ("Name at SOL + space", "(?:^|\\n)\\s*Name[ ]+([A-Z][a-z]+(?:[ ]+[A-Z][a-z]+)+)(?=\\n|$)", [.anchorsMatchLines]),
    ("Patient Name", "\\bPatient\\s+[Nn]ame\\s*[:  ]\\s*([A-Z][a-z]+(?:[ ]+[A-Z][a-z]+)+)", []),
    ("Name of Patient", "[Nn]ame\\s+of\\s+[Pp]atient\\s*[: ]\\s*([A-Z][a-z]+(?:[ ]+[A-Z][a-z]+)+)", []),
    ("Name colon/tab", "\\bName\\s*[:\\t]\\s*([A-Z][a-z]+(?:[ ]+[A-Z][a-z]+)+)", []),
    ("Name newline value", "(?:^|\\n)\\s*Name\\s*\\n\\s*([A-Z][a-z]+(?:[ ]+[A-Z][a-z]+)+)", []),
    ("Re:", "\\bRe:\\s+([A-Z][a-z]+(?:[ ]+[A-Z][a-z]+)+)", []),
]

let range = NSRange(allText.startIndex..., in: allText)
print("\n=== REGEX TESTS ===")
for (name, pattern, options) in patterns {
    do {
        let regex = try NSRegularExpression(pattern: pattern, options: options)
        if let match = regex.firstMatch(in: allText, range: range),
           let matchRange = Range(match.range(at: 1), in: allText) {
            let result = String(allText[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            print("  \(name): MATCH '\(result)'")
        } else {
            print("  \(name): NO MATCH")
        }
    } catch {
        print("  \(name): REGEX ERROR: \(error)")
    }
}
