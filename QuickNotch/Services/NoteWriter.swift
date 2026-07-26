import Foundation

enum NoteWriterError: LocalizedError {
    case emptyText
    case folderMissing(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Note text is empty."
        case .folderMissing(let path):
            return "Notes folder does not exist: \(path)"
        case .writeFailed(let message):
            return "Could not write note: \(message)"
        }
    }
}

enum NoteWriter {
    /// Saves markdown into `folder`. Filename uses the first line (slug) plus a timestamp.
    static func save(text: String, toFolder folder: URL) throws -> URL {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NoteWriterError.emptyText }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw NoteWriterError.folderMissing(folder.path)
        }

        let filename = makeFilename(from: trimmed)
        let fileURL = folder.appendingPathComponent(filename)
        let body = makeMarkdownBody(from: trimmed)

        do {
            try body.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            throw NoteWriterError.writeFailed(error.localizedDescription)
        }
    }

    static func makeFilename(from text: String, date: Date = Date()) -> String {
        let stamp = Self.timestampFormatter.string(from: date)
        let slug = slugify(firstLine(of: text))
        if slug.isEmpty {
            return "\(stamp).md"
        }
        return "\(stamp)-\(slug).md"
    }

    static func makeMarkdownBody(from text: String, date: Date = Date()) -> String {
        let title = firstLine(of: text)
        let iso = Self.isoFormatter.string(from: date)
        var lines: [String] = [
            "---",
            "created: \(iso)",
            "source: Quick Notch",
            "---",
            "",
        ]

        if !title.isEmpty {
            lines.append("# \(title)")
            lines.append("")
            let rest = text
                .split(separator: "\n", omittingEmptySubsequences: false)
                .dropFirst()
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !rest.isEmpty {
                lines.append(rest)
                lines.append("")
            }
        } else {
            lines.append(text)
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private static func firstLine(of text: String) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func slugify(_ value: String) -> String {
        let lowered = value.lowercased()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "- "))
        let filtered = String(lowered.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
        let collapsed = filtered
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return String(collapsed.prefix(48))
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
