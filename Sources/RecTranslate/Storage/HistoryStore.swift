import Foundation
import Combine

/// Recent translation history, persisted to a JSON file in Application Support and capped to
/// the user's configured limit.
@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var entries: [HistoryEntry] = []

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("com.recweb.rectranslate", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("history.json")

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        load()
    }

    /// Prepend a new entry, remove all exact duplicates (re-promoting it to the top), and cap to `limit`.
    func add(_ entry: HistoryEntry, limit: Int) {
        var updated = entries
        updated.removeAll {
            $0.original == entry.original
                && $0.translation == entry.translation
                && $0.sourceCode == entry.sourceCode
                && $0.targetCode == entry.targetCode
        }
        updated.insert(entry, at: 0)
        if updated.count > max(0, limit) {
            updated = Array(updated.prefix(max(0, limit)))
        }
        entries = updated
        save()
    }

    func clear() {
        entries = []
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        entries = (try? decoder.decode([HistoryEntry].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
