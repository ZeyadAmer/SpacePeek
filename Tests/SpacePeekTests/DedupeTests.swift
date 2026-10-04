import CoreGraphics
import Testing
@testable import SpacePeek

@Suite("Tile dedupe")
struct DedupeTests {
    private func tile(_ title: String, x: CGFloat, width: CGFloat = 180) -> Thumbnail {
        Thumbnail(
            id: "\(title).\(x).\(width)",
            frame: CGRect(x: x, y: 90, width: width, height: 120),
            rawTitle: title,
            title: title,
            appName: nil
        )
    }

    @Test("separate spaces sharing a title both keep their labels")
    func keepsSameTitleAtDifferentPositions() {
        let tiles = [tile("Desktop", x: 340), tile("dorkaman", x: 790), tile("dorkaman", x: 1240)]
        #expect(ThumbnailScanner.dedupeByRawTitle(tiles).count == 3)
    }

    @Test("overlapping copies of one tile collapse to the larger")
    func collapsesOverlappingCopies() {
        let small = tile("WhatsApp", x: 560, width: 90)
        let large = tile("WhatsApp", x: 540, width: 180)
        #expect(ThumbnailScanner.dedupeByRawTitle([small, large]) == [large])
    }
}
