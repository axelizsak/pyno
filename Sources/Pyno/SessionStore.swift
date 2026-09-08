import Foundation
import SwiftUI

/// Reads and writes sessions as Markdown files in ~/Documents/Pyno.
/// No database: one file per session, readable and pasteable as-is.
@MainActor
final class SessionStore: ObservableObject {

    @Published private(set) var sessions: [Session] = []

    let folder: URL

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        folder = documents.appendingPathComponent("Pyno", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        reload()
    }

    // MARK: - Loading

    func reload() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        sessions = urls
            .filter { $0.pathExtension == "md" }
            .compactMap { Self.parse(url: $0) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Mutations

    func create(title: String, language: SessionLanguage) -> Session {
        let now = Date()
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = Session(
            id: UUID(),
            title: cleanTitle.isEmpty ? tr(.untitledSession, language) : cleanTitle,
            createdAt: now,
            language: language,
            duration: 0,
            isFinished: false,
            paragraphs: [],
            fileURL: uniqueURL(for: Self.fileName(title: cleanTitle, date: now, language: language))
        )
        sessions.insert(session, at: 0)
        save(session)
        return session
    }

    func save(_ session: Session) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }
        try? Self.markdown(for: session).write(to: session.fileURL, atomically: true, encoding: .utf8)
    }

    func delete(_ session: Session) {
        try? FileManager.default.removeItem(at: session.fileURL)
        sessions.removeAll { $0.id == session.id }
    }

    func session(id: UUID?) -> Session? {
        guard let id else { return nil }
        return sessions.first { $0.id == id }
    }

    // MARK: - Markdown

    /// Two sessions can share a title and a minute: suffix rather than overwrite.
    private func uniqueURL(for name: String) -> URL {
        let base = (name as NSString).deletingPathExtension
        var candidate = folder.appendingPathComponent(name)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base) (\(counter)).md")
            counter += 1
        }
        return candidate
    }

    private static func fileName(title: String, date: Date, language: SessionLanguage) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        let allowed = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: " -_àâäéèêëîïôöùûüçÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ"))
        let slug = String(title.unicodeScalars.filter { allowed.contains($0) })
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")
        let base = slug.isEmpty ? tr(.fallbackFileName, language) : String(slug.prefix(60))
        return "\(formatter.string(from: date)) \(base).md"
    }

    /// The document follows the language that was spoken, not the current UI language.
    static func markdown(for session: Session) -> String {
        var out = "---\n"
        out += "pyno: 1\n"
        out += "id: \(session.id.uuidString)\n"
        out += "title: \(session.title)\n"
        out += "created: \(isoFormatter.string(from: session.createdAt))\n"
        out += "language: \(session.language.rawValue)\n"
        out += "duration: \(Int(session.duration.rounded()))\n"
        out += "finished: \(session.isFinished)\n"
        out += "---\n\n"
        out += "# \(session.title)\n\n"

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: session.language == .french ? "fr_FR" : "en_US")
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        out += "_\(dateFormatter.string(from: session.createdAt)) · \(Clock.short(session.duration)) · \(session.language.label)_\n\n"

        if session.paragraphs.isEmpty {
            out += tr(.noSpeechMarkdown, session.language) + "\n"
        } else {
            for paragraph in session.paragraphs {
                out += "**[\(Clock.stamp(paragraph.start))]** \(paragraph.text)\n\n"
            }
        }
        return out
    }

    static func parse(url: URL) -> Session? {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        guard raw.hasPrefix("---\n") else { return nil }

        let afterOpening = raw.dropFirst(4)
        guard let closingRange = afterOpening.range(of: "\n---\n") else { return nil }
        let header = String(afterOpening[..<closingRange.lowerBound])
        let body = String(afterOpening[closingRange.upperBound...])

        var fields: [String: String] = [:]
        for line in header.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            fields[key] = value
        }
        guard fields["pyno"] != nil,
              let idString = fields["id"], let id = UUID(uuidString: idString) else { return nil }

        let language = SessionLanguage(rawValue: fields["language"] ?? "en") ?? .english

        return Session(
            id: id,
            title: fields["title"] ?? tr(.untitledSession, language),
            createdAt: fields["created"].flatMap { isoFormatter.date(from: $0) } ?? Date(),
            language: language,
            duration: TimeInterval(fields["duration"] ?? "0") ?? 0,
            isFinished: (fields["finished"] ?? "true") == "true",
            paragraphs: parseParagraphs(body),
            fileURL: url
        )
    }

    private static func parseParagraphs(_ body: String) -> [Paragraph] {
        var result: [Paragraph] = []
        for line in body.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("**["), let close = trimmed.range(of: "]** ") else { continue }
            let stampText = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 3)..<close.lowerBound])
            let text = String(trimmed[close.upperBound...])
            let parts = stampText.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 3 else { continue }
            result.append(Paragraph(start: TimeInterval(parts[0] * 3600 + parts[1] * 60 + parts[2]), text: text))
        }
        return result
    }
}
