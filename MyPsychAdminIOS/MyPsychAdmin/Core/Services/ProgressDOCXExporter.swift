//
//  ProgressDOCXExporter.swift
//  MyPsychAdmin
//
//  Generates Word document from progress narrative sections
//  Builds DOCX from scratch (no template required)
//

import Foundation
import Compression

// MARK: - Progress DOCX Exporter

class ProgressDOCXExporter {

    // MARK: - DOCX Structure Constants

    private let contentTypesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
      <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
    </Types>
    """

    private let relsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    </Relationships>
    """

    private let documentRelsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
    </Relationships>
    """

    private let stylesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:docDefaults>
        <w:rPrDefault>
          <w:rPr>
            <w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/>
            <w:sz w:val="24"/>
            <w:szCs w:val="24"/>
          </w:rPr>
        </w:rPrDefault>
        <w:pPrDefault>
          <w:pPr>
            <w:spacing w:after="120" w:line="276" w:lineRule="auto"/>
          </w:pPr>
        </w:pPrDefault>
      </w:docDefaults>
      <w:style w:type="paragraph" w:styleId="Normal" w:default="1">
        <w:name w:val="Normal"/>
      </w:style>
      <w:style w:type="paragraph" w:styleId="Heading1">
        <w:name w:val="Heading 1"/>
        <w:pPr>
          <w:spacing w:before="240" w:after="120"/>
        </w:pPr>
        <w:rPr>
          <w:b/>
          <w:sz w:val="28"/>
          <w:szCs w:val="28"/>
        </w:rPr>
      </w:style>
      <w:style w:type="paragraph" w:styleId="Heading2">
        <w:name w:val="Heading 2"/>
        <w:pPr>
          <w:spacing w:before="200" w:after="80"/>
        </w:pPr>
        <w:rPr>
          <w:b/>
          <w:sz w:val="26"/>
          <w:szCs w:val="26"/>
        </w:rPr>
      </w:style>
    </w:styles>
    """

    // MARK: - Export Narrative

    /// Export narrative sections to DOCX data
    /// - Parameters:
    ///   - sections: Narrative sections to export
    ///   - patientName: Patient name for header
    ///   - dateRange: Date range string
    /// - Returns: DOCX file data, or nil if export fails
    func exportNarrative(
        sections: [NarrativeSection],
        patientName: String,
        dateRange: String
    ) -> Data? {
        // Build document body
        var documentBody = ""

        // Add title
        documentBody += buildTitleParagraph("Progress Report")

        // Add patient info and date range
        if !patientName.isEmpty {
            documentBody += buildParagraph(text: "Patient: \(patientName)", bold: true)
        }
        if !dateRange.isEmpty {
            documentBody += buildParagraph(text: "Period: \(dateRange)", bold: false)
        }

        // Add disclaimer
        documentBody += buildParagraph(
            text: "The following account is a guide - please check the narrative presented against the notes.",
            italic: true
        )

        // Add empty paragraph for spacing
        documentBody += "<w:p><w:pPr><w:spacing w:after=\"240\"/></w:pPr></w:p>"

        // Add narrative sections
        for section in sections {
            // Section title
            if let title = section.title, !title.isEmpty {
                documentBody += buildSectionHeading(title)
            }

            // Section paragraphs
            for paragraph in section.content {
                documentBody += buildNarrativeParagraph(paragraph)
            }
        }

        // Wrap in document XML
        let documentXML = wrapInDocumentXML(body: documentBody)

        // Create ZIP archive
        return createDOCXArchive(documentXML: documentXML)
    }

    // MARK: - Build Paragraphs

    private func buildTitleParagraph(_ text: String) -> String {
        let escaped = escapeXML(text)
        return """
        <w:p>
          <w:pPr>
            <w:pStyle w:val="Heading1"/>
            <w:jc w:val="center"/>
          </w:pPr>
          <w:r>
            <w:rPr><w:b/><w:sz w:val="32"/><w:szCs w:val="32"/></w:rPr>
            <w:t>\(escaped)</w:t>
          </w:r>
        </w:p>
        """
    }

    private func buildSectionHeading(_ text: String) -> String {
        let escaped = escapeXML(text)
        return """
        <w:p>
          <w:pPr>
            <w:pStyle w:val="Heading2"/>
            <w:spacing w:before="300" w:after="120"/>
          </w:pPr>
          <w:r>
            <w:rPr><w:b/><w:sz w:val="26"/><w:szCs w:val=\"26\"/></w:rPr>
            <w:t>\(escaped)</w:t>
          </w:r>
        </w:p>
        """
    }

    private func buildParagraph(text: String, bold: Bool = false, italic: Bool = false) -> String {
        let escaped = escapeXML(text)
        var rPr = "<w:rPr>"
        if bold { rPr += "<w:b/>" }
        if italic { rPr += "<w:i/>" }
        rPr += "</w:rPr>"

        return """
        <w:p>
          <w:pPr><w:spacing w:after="120"/></w:pPr>
          <w:r>
            \(rPr)
            <w:t xml:space="preserve">\(escaped)</w:t>
          </w:r>
        </w:p>
        """
    }

    private func buildNarrativeParagraph(_ paragraph: NarrativeParagraph) -> String {
        var runs = ""

        for segment in paragraph.segments {
            switch segment {
            case .plain(let text, let format):
                runs += buildRun(text: text, bold: format.contains(.bold), italic: format.contains(.italic))

            case .referenced(let text, _, let format):
                // In DOCX, we render the text without the interactive reference
                runs += buildRun(text: text, bold: format.contains(.bold), italic: format.contains(.italic))
            }
        }

        return "<w:p><w:pPr><w:spacing w:after=\"120\"/></w:pPr>\(runs)</w:p>"
    }

    private func buildRun(text: String, bold: Bool = false, italic: Bool = false) -> String {
        let escaped = escapeXML(text)
        var rPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/>"
        if bold { rPr += "<w:b/>" }
        if italic { rPr += "<w:i/>" }
        rPr += "</w:rPr>"

        return "<w:r>\(rPr)<w:t xml:space=\"preserve\">\(escaped)</w:t></w:r>"
    }

    // MARK: - Document Assembly

    private func wrapInDocumentXML(body: String) -> String {
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            \(body)
            <w:sectPr>
              <w:pgSz w:w="12240" w:h="15840"/>
              <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
            </w:sectPr>
          </w:body>
        </w:document>
        """
    }

    // MARK: - ZIP Archive Creation

    private func createDOCXArchive(documentXML: String) -> Data? {
        var entries: [(name: String, data: Data)] = []

        // [Content_Types].xml
        guard let contentTypesData = contentTypesXML.data(using: .utf8) else { return nil }
        entries.append(("[Content_Types].xml", contentTypesData))

        // _rels/.rels
        guard let relsData = relsXML.data(using: .utf8) else { return nil }
        entries.append(("_rels/.rels", relsData))

        // word/_rels/document.xml.rels
        guard let docRelsData = documentRelsXML.data(using: .utf8) else { return nil }
        entries.append(("word/_rels/document.xml.rels", docRelsData))

        // word/document.xml
        guard let docData = documentXML.data(using: .utf8) else { return nil }
        entries.append(("word/document.xml", docData))

        // word/styles.xml
        guard let stylesData = stylesXML.data(using: .utf8) else { return nil }
        entries.append(("word/styles.xml", stylesData))

        return createZipFile(from: entries)
    }

    private func createZipFile(from entries: [(name: String, data: Data)]) -> Data {
        var zipData = Data()
        var centralDirectory = Data()
        var localHeaderOffsets: [UInt32] = []

        for entry in entries {
            localHeaderOffsets.append(UInt32(zipData.count))

            let nameData = entry.name.data(using: .utf8) ?? Data()
            let compressedData = deflateData(entry.data) ?? entry.data
            let compressionMethod: UInt16 = compressedData.count < entry.data.count ? 8 : 0
            let finalData = compressionMethod == 8 ? compressedData : entry.data

            let crc = crc32(entry.data)

            // Local file header
            var localHeader = Data()
            localHeader.append(contentsOf: [0x50, 0x4b, 0x03, 0x04]) // Signature
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(20).littleEndian) { Array($0) }) // Version
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Flags
            localHeader.append(contentsOf: withUnsafeBytes(of: compressionMethod.littleEndian) { Array($0) }) // Compression
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Mod time
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Mod date
            localHeader.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { Array($0) }) // CRC
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt32(finalData.count).littleEndian) { Array($0) }) // Compressed size
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt32(entry.data.count).littleEndian) { Array($0) }) // Uncompressed size
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(nameData.count).littleEndian) { Array($0) }) // Name length
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Extra length
            localHeader.append(nameData)
            localHeader.append(finalData)

            zipData.append(localHeader)

            // Central directory entry
            var cdEntry = Data()
            cdEntry.append(contentsOf: [0x50, 0x4b, 0x01, 0x02]) // Signature
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(20).littleEndian) { Array($0) }) // Version made by
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(20).littleEndian) { Array($0) }) // Version needed
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Flags
            cdEntry.append(contentsOf: withUnsafeBytes(of: compressionMethod.littleEndian) { Array($0) }) // Compression
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Mod time
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Mod date
            cdEntry.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { Array($0) }) // CRC
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt32(finalData.count).littleEndian) { Array($0) }) // Compressed size
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt32(entry.data.count).littleEndian) { Array($0) }) // Uncompressed size
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(nameData.count).littleEndian) { Array($0) }) // Name length
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Extra length
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Comment length
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Disk number
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Internal attrs
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt32(0).littleEndian) { Array($0) }) // External attrs
            cdEntry.append(contentsOf: withUnsafeBytes(of: localHeaderOffsets.last!.littleEndian) { Array($0) }) // Offset
            cdEntry.append(nameData)

            centralDirectory.append(cdEntry)
        }

        let cdStart = UInt32(zipData.count)
        zipData.append(centralDirectory)

        // End of central directory
        var eocd = Data()
        eocd.append(contentsOf: [0x50, 0x4b, 0x05, 0x06]) // Signature
        eocd.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Disk number
        eocd.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // CD disk
        eocd.append(contentsOf: withUnsafeBytes(of: UInt16(entries.count).littleEndian) { Array($0) }) // Entries on disk
        eocd.append(contentsOf: withUnsafeBytes(of: UInt16(entries.count).littleEndian) { Array($0) }) // Total entries
        eocd.append(contentsOf: withUnsafeBytes(of: UInt32(centralDirectory.count).littleEndian) { Array($0) }) // CD size
        eocd.append(contentsOf: withUnsafeBytes(of: cdStart.littleEndian) { Array($0) }) // CD offset
        eocd.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Comment length

        zipData.append(eocd)

        return zipData
    }

    private func deflateData(_ data: Data) -> Data? {
        let destSize = data.count + 1024
        var destBuffer = [UInt8](repeating: 0, count: destSize)
        var sourceBuffer = [UInt8](data)

        let result = compression_encode_buffer(
            &destBuffer, destSize,
            &sourceBuffer, data.count,
            nil,
            COMPRESSION_ZLIB
        )

        guard result > 0 else { return nil }
        return Data(destBuffer.prefix(result))
    }

    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        let table = makeCRC32Table()

        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = table[index] ^ (crc >> 8)
        }

        return ~crc
    }

    private func makeCRC32Table() -> [UInt32] {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 == 1 {
                    crc = 0xEDB88320 ^ (crc >> 1)
                } else {
                    crc >>= 1
                }
            }
            table[i] = crc
        }
        return table
    }

    private func escapeXML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
