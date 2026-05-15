import Foundation
import Combine

struct SpaceSnapshot: Identifiable, Equatable {
    let id: String           // base key (post-strategy, pre-rename)
    let rawTitle: String
}

final class SpacesSnapshotStore: ObservableObject {
    static let shared = SpacesSnapshotStore()

    @Published private(set) var snapshots: [SpaceSnapshot] = []

    private init() {}

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
            }
        }
    }
}
