import Foundation
import Combine

struct SpaceSnapshot: Identifiable, Equatable, Codable {
    let id: String           // base key (post-strategy, pre-rename)
    let rawTitle: String
}

final class SpacesSnapshotStore: ObservableObject {
    static let shared = SpacesSnapshotStore()
    private static let storageKey = "SpacePeek.Snapshots.v1"

    @Published private(set) var snapshots: [SpaceSnapshot] = []

    private init() {
        self.snapshots = Self.load()
    }

    func update(from thumbnails: [Thumbnail]) {
        let prefs = PreferencesStore.shared.preferences
        let items = thumbnails.map { thumb -> SpaceSnapshot in
            let base = TitleProcessor.baseTitle(forRawTitle: thumb.rawTitle, preferences: prefs)
            return SpaceSnapshot(id: base, rawTitle: thumb.rawTitle)
        }
        var seen = Set<String>()
        let unique = items.filter { seen.insert($0.id).inserted }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.snapshots != unique {
                self.snapshots = unique
                Self.persist(unique)
            }
        }
    }

    private static func load() -> [SpaceSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SpaceSnapshot].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func persist(_ snapshots: [SpaceSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
