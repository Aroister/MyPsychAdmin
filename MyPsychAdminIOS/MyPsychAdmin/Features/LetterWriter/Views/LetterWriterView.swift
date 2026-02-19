//
//  LetterWriterView.swift
//  MyPsychAdmin
//

import SwiftUI

struct LetterWriterView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @State private var selectedSection: SectionType?
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false

    var body: some View {
        @Bindable var appStoreBindable = appStore

        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(SectionType.orderedSections) { section in
                        LetterCardView(
                            section: section,
                            content: $appStoreBindable[section],
                            isLocked: appStore.getSection(section).isLocked,
                            onOpenPopup: {
                                selectedSection = section
                            }
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Clinic Letter")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingImportSheet = true
                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingExportSheet = true
                        } label: {
                            Label("Export Letter", systemImage: "square.and.arrow.up")
                        }

                        Button(role: .destructive) {
                            appStore.clearAllSections()
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $selectedSection) { section in
                SectionPopupView(sectionType: section)
            }
            .sheet(isPresented: $showingImportSheet) {
                DocumentImportView()
            }
            .sheet(isPresented: $showingExportSheet) {
                LetterExportView()
            }
        }
    }
}

// MARK: - Letter Card View (Editable) - matches GPREditableCard style
struct LetterCardView: View {
    let section: SectionType
    @Binding var content: String
    let isLocked: Bool
    let onOpenPopup: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var editorHeight: CGFloat = 150

    var body: some View {
        VStack(spacing: 0) {
            // Header - tappable to open popup
            Button(action: onOpenPopup) {
                HStack(spacing: 10) {
                    Image(systemName: section.iconName)
                        .foregroundColor(section.headerColor)
                        .frame(width: 20)

                    Text(section.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(section.headerColor)
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
            .buttonStyle(.plain)

            // Editable text area
            TextEditor(text: $content)
                .frame(height: editorHeight)
                .padding(8)
                .scrollContentBackground(.hidden)
                .disabled(isLocked)

            // Resize handle
            ResizeHandle(height: $editorHeight)
        }
        .background(.thinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.9 : 0.7), radius: colorScheme == .dark ? 20 : 12, y: colorScheme == .dark ? 10 : 6)
    }
}

// MARK: - Letter Export View
struct LetterExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var isExporting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Export Letter")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Export as Word document (.docx)")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)

                    // Filename preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Filename:")
                            .font(.headline)
                        Text(generatedFilename)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Preview of what's included
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sections to include:")
                            .font(.headline)

                        ForEach(SectionType.orderedSections) { section in
                            let state = appStore.getSection(section)
                            if !state.isEmpty {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(section.title)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    Spacer(minLength: 40)

                    Button {
                        exportDocument()
                    } label: {
                        if isExporting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Export Word Document", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isExporting)
                }
                .padding()
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private var generatedFilename: String {
        let patientName = sharedData.patientInfo.fullName.isEmpty ? "Patient" : sharedData.patientInfo.fullName
        let clinician = getClinician()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMM yyyy HH-mm"
        let dateStr = dateFormatter.string(from: Date())

        return "Clinic Letter for \(patientName) on \(dateStr) by \(clinician).docx"
    }

    private func getClinician() -> String {
        // Try to get clinician from front page state
        if let frontState = appStore.loadPopupData(FrontPageState.self, for: .front),
           !frontState.clinician.isEmpty {
            return frontState.clinician
        }
        return "Clinician"
    }

    private func exportDocument() {
        isExporting = true

        DispatchQueue.global(qos: .userInitiated).async {
            // Generate DOCX content
            let docxData = generateDOCX()

            // Save to temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let filename = generatedFilename
            let fileURL = tempDir.appendingPathComponent(filename)

            do {
                try docxData.write(to: fileURL)

                DispatchQueue.main.async {
                    self.exportURL = fileURL
                    self.isExporting = false
                    self.showingShareSheet = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.isExporting = false
                    print("Export error: \(error)")
                }
            }
        }
    }

    private func generateDOCX() -> Data {
        // Create a minimal DOCX file (which is a ZIP containing XML)
        // For simplicity, we'll create an RTF-based approach that Word can open

        let content = buildFormattedContent()
        let rtfContent = convertToRTF(content)

        // Create DOCX structure
        return createDOCXFromContent(rtfContent)
    }

    private func buildFormattedContent() -> String {
        var output = ""

        for section in SectionType.orderedSections {
            guard let state = appStore.letterSections[section], !state.isEmpty else { continue }

            // Add section title (bold)
            output += "**\(section.title)**\n\n"
            output += state.content
            output += "\n\n"
        }

        // Add signature block
        let clinician = getClinician()
        output += "\n**\(clinician)**\n"

        return output
    }

    private func convertToRTF(_ content: String) -> String {
        // Convert markdown-style bold (**text**) to RTF
        var rtf = "{\\rtf1\\ansi\\deff0 {\\fonttbl {\\f0 Times New Roman;}}\n"
        rtf += "\\f0\\fs24\n"

        // Process content line by line
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            var processedLine = line

            // Convert **bold** to RTF bold
            let boldPattern = #"\*\*([^*]+)\*\*"#
            if let regex = try? NSRegularExpression(pattern: boldPattern) {
                let range = NSRange(processedLine.startIndex..., in: processedLine)
                processedLine = regex.stringByReplacingMatches(
                    in: processedLine,
                    range: range,
                    withTemplate: "{\\b $1}"
                )
            }

            // Escape special RTF characters
            processedLine = processedLine
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "{", with: "\\{")
                .replacingOccurrences(of: "}", with: "\\}")

            rtf += processedLine + "\\par\n"
        }

        rtf += "}"
        return rtf
    }

    private func createDOCXFromContent(_ rtfContent: String) -> Data {
        // Create a proper DOCX file structure
        // DOCX is a ZIP file containing XML files

        let documentXML = createDocumentXML()
        let contentTypesXML = createContentTypesXML()
        let relsXML = createRelsXML()

        // Create ZIP archive
        return createZipArchive(
            documentXML: documentXML,
            contentTypesXML: contentTypesXML,
            relsXML: relsXML
        )
    }

    private func createDocumentXML() -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
        """

        for section in SectionType.orderedSections {
            let state = appStore.letterSections[section]
            let hasContent = state != nil && !state!.isEmpty

            if section == .front {
                // Front page: render as table, no title
                if hasContent {
                    xml += createFrontPageTable(content: state!.content)
                } else {
                    // Empty front page - show minimal table
                    xml += createFrontPageTable(content: "Patient: \nDate of Letter: ")
                }
                xml += "<w:p/>"
            } else {
                // Other sections: title + content (or "Nil of note")
                xml += """
                <w:p>
                <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
                <w:r><w:rPr><w:b/></w:rPr><w:t>\(escapeXML(section.title))</w:t></w:r>
                </w:p>
                """

                if hasContent {
                    // Section content - process each paragraph
                    let paragraphs = state!.content.components(separatedBy: "\n\n")
                    for para in paragraphs {
                        let lines = para.components(separatedBy: "\n")
                        for line in lines {
                            xml += createParagraphXML(line)
                        }
                    }
                } else {
                    // Empty section - show "Nil of note"
                    xml += "<w:p><w:r><w:t>Nil of note</w:t></w:r></w:p>"
                }

                // Empty paragraph for spacing
                xml += "<w:p/>"
            }
        }

        // Signature block with registration info
        let clinician = getClinician()
        xml += """
        <w:p/>
        <w:p>
        <w:r><w:rPr><w:b/></w:rPr><w:t>\(escapeXML(clinician))</w:t></w:r>
        </w:p>
        """

        // Add registration info if available
        let regBody = appStore.clinicianInfo.registrationBody
        let regNumber = appStore.clinicianInfo.registrationNumber
        if !regBody.isEmpty && !regNumber.isEmpty {
            xml += """
            <w:p>
            <w:r><w:t>\(escapeXML(regBody)): \(escapeXML(regNumber))</w:t></w:r>
            </w:p>
            """
        } else if !regNumber.isEmpty {
            xml += """
            <w:p>
            <w:r><w:t>\(escapeXML(regNumber))</w:t></w:r>
            </w:p>
            """
        }

        xml += """
        </w:body>
        </w:document>
        """

        return xml
    }

    private func createFrontPageTable(content: String) -> String {
        // Parse front page content into label/value pairs
        var rows: [(String, String)] = []
        var inMedications = false
        var medicationLines: [String] = []

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed == "Medications:" {
                inMedications = true
                continue
            }

            if inMedications {
                medicationLines.append(trimmed)
            } else if let colonIndex = trimmed.firstIndex(of: ":") {
                let label = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                rows.append((label, value))
            }
        }

        // Add medications as a single row if present
        if !medicationLines.isEmpty {
            rows.append(("Medications", medicationLines.joined(separator: ", ")))
        }

        // Build Word table XML
        var xml = """
        <w:tbl>
        <w:tblPr>
        <w:tblW w:w="9000" w:type="dxa"/>
        <w:tblBorders>
        <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        </w:tblBorders>
        </w:tblPr>
        <w:tblGrid>
        <w:gridCol w:w="3000"/>
        <w:gridCol w:w="6000"/>
        </w:tblGrid>
        """

        for (label, value) in rows {
            xml += """
            <w:tr>
            <w:tc>
            <w:tcPr><w:tcW w:w="3000" w:type="dxa"/><w:shd w:val="clear" w:fill="F0F0F0"/></w:tcPr>
            <w:p><w:r><w:rPr><w:b/></w:rPr><w:t>\(escapeXML(label))</w:t></w:r></w:p>
            </w:tc>
            <w:tc>
            <w:tcPr><w:tcW w:w="6000" w:type="dxa"/></w:tcPr>
            <w:p><w:r><w:t>\(escapeXML(value))</w:t></w:r></w:p>
            </w:tc>
            </w:tr>
            """
        }

        xml += "</w:tbl>"
        return xml
    }

    private func createParagraphXML(_ text: String) -> String {
        var xml = "<w:p>"

        // Check for bold markers (**text**)
        let boldPattern = #"\*\*([^*]+)\*\*"#
        var remaining = text
        var lastEnd = text.startIndex

        if let regex = try? NSRegularExpression(pattern: boldPattern) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)

            for match in matches {
                // Add text before bold
                if let beforeRange = Range(NSRange(location: text.distance(from: text.startIndex, to: lastEnd),
                                                    length: match.range.location - text.distance(from: text.startIndex, to: lastEnd)), in: text) {
                    let beforeText = String(text[beforeRange])
                    if !beforeText.isEmpty {
                        xml += "<w:r><w:t xml:space=\"preserve\">\(escapeXML(beforeText))</w:t></w:r>"
                    }
                }

                // Add bold text
                if let boldRange = Range(match.range(at: 1), in: text) {
                    let boldText = String(text[boldRange])
                    xml += "<w:r><w:rPr><w:b/></w:rPr><w:t>\(escapeXML(boldText))</w:t></w:r>"
                }

                if let fullRange = Range(match.range, in: text) {
                    lastEnd = fullRange.upperBound
                }
            }

            // Add remaining text
            let afterText = String(text[lastEnd...])
            if !afterText.isEmpty {
                xml += "<w:r><w:t xml:space=\"preserve\">\(escapeXML(afterText))</w:t></w:r>"
            }
        } else {
            // No bold, just add plain text
            xml += "<w:r><w:t xml:space=\"preserve\">\(escapeXML(text))</w:t></w:r>"
        }

        xml += "</w:p>"
        return xml
    }

    private func escapeXML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private func createContentTypesXML() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """
    }

    private func createRelsXML() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """
    }

    private func createZipArchive(documentXML: String, contentTypesXML: String, relsXML: String) -> Data {
        // Create a minimal ZIP archive for DOCX manually
        return createMinimalDOCX(documentXML: documentXML)
    }

    private func createMinimalDOCX(documentXML: String) -> Data {
        // Create a minimal valid DOCX using manual ZIP construction
        var zipData = Data()

        // ZIP local file header + content types
        let contentTypesData = createContentTypesXML().data(using: .utf8) ?? Data()
        zipData.append(createZipEntry(name: "[Content_Types].xml", data: contentTypesData))

        // _rels/.rels
        let relsData = createRelsXML().data(using: .utf8) ?? Data()
        zipData.append(createZipEntry(name: "_rels/.rels", data: relsData))

        // word/document.xml
        let docData = documentXML.data(using: .utf8) ?? Data()
        zipData.append(createZipEntry(name: "word/document.xml", data: docData))

        // Central directory and end of central directory
        zipData.append(createZipCentralDirectory(entries: [
            ("[Content_Types].xml", contentTypesData),
            ("_rels/.rels", relsData),
            ("word/document.xml", docData)
        ]))

        return zipData
    }

    private func createZipEntry(name: String, data: Data) -> Data {
        var entry = Data()

        // Local file header signature
        entry.append(contentsOf: [0x50, 0x4B, 0x03, 0x04])

        // Version needed (2.0)
        entry.append(contentsOf: [0x14, 0x00])

        // General purpose bit flag
        entry.append(contentsOf: [0x00, 0x00])

        // Compression method (0 = stored)
        entry.append(contentsOf: [0x00, 0x00])

        // Last mod time/date
        entry.append(contentsOf: [0x00, 0x00, 0x00, 0x00])

        // CRC-32
        let crc = crc32(data)
        entry.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { Array($0) })

        // Compressed size
        let size = UInt32(data.count)
        entry.append(contentsOf: withUnsafeBytes(of: size.littleEndian) { Array($0) })

        // Uncompressed size
        entry.append(contentsOf: withUnsafeBytes(of: size.littleEndian) { Array($0) })

        // Filename length
        let nameData = name.data(using: .utf8) ?? Data()
        let nameLen = UInt16(nameData.count)
        entry.append(contentsOf: withUnsafeBytes(of: nameLen.littleEndian) { Array($0) })

        // Extra field length
        entry.append(contentsOf: [0x00, 0x00])

        // Filename
        entry.append(nameData)

        // File data
        entry.append(data)

        return entry
    }

    private func createZipCentralDirectory(entries: [(String, Data)]) -> Data {
        var centralDir = Data()
        var offset: UInt32 = 0

        for (name, data) in entries {
            // Central directory file header
            centralDir.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])

            // Version made by
            centralDir.append(contentsOf: [0x14, 0x00])

            // Version needed
            centralDir.append(contentsOf: [0x14, 0x00])

            // Flags
            centralDir.append(contentsOf: [0x00, 0x00])

            // Compression
            centralDir.append(contentsOf: [0x00, 0x00])

            // Time/date
            centralDir.append(contentsOf: [0x00, 0x00, 0x00, 0x00])

            // CRC
            let crc = crc32(data)
            centralDir.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { Array($0) })

            // Sizes
            let size = UInt32(data.count)
            centralDir.append(contentsOf: withUnsafeBytes(of: size.littleEndian) { Array($0) })
            centralDir.append(contentsOf: withUnsafeBytes(of: size.littleEndian) { Array($0) })

            // Name length
            let nameData = name.data(using: .utf8) ?? Data()
            let nameLen = UInt16(nameData.count)
            centralDir.append(contentsOf: withUnsafeBytes(of: nameLen.littleEndian) { Array($0) })

            // Extra, comment, disk, internal/external attrs
            centralDir.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])

            // Offset
            centralDir.append(contentsOf: withUnsafeBytes(of: offset.littleEndian) { Array($0) })

            // Name
            centralDir.append(nameData)

            // Update offset for next entry
            offset += UInt32(30 + nameData.count + data.count)
        }

        // End of central directory
        let cdOffset = offset
        let cdSize = UInt32(centralDir.count)
        let numEntries = UInt16(entries.count)

        centralDir.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])
        centralDir.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        centralDir.append(contentsOf: withUnsafeBytes(of: numEntries.littleEndian) { Array($0) })
        centralDir.append(contentsOf: withUnsafeBytes(of: numEntries.littleEndian) { Array($0) })
        centralDir.append(contentsOf: withUnsafeBytes(of: cdSize.littleEndian) { Array($0) })
        centralDir.append(contentsOf: withUnsafeBytes(of: cdOffset.littleEndian) { Array($0) })
        centralDir.append(contentsOf: [0x00, 0x00])

        return centralDir
    }

    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        let table = makeCRC32Table()

        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = table[index] ^ (crc >> 8)
        }

        return crc ^ 0xFFFFFFFF
    }

    private func makeCRC32Table() -> [UInt32] {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = 0xEDB88320 ^ (crc >> 1)
                } else {
                    crc >>= 1
                }
            }
            table[i] = crc
        }
        return table
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    LetterWriterView()
        .environment(AppStore())
        .environment(SharedDataStore.shared)
}
