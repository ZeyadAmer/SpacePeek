import Foundation

struct Thumbnail: Hashable {
    let id: String
    let frame: CGRect
    let rawTitle: String
    let title: String
    /// Owning application, when Mission Control exposes it (macOS 27+). Window titles often omit
    /// the app entirely — a terminal named after its project, for example — so this is the only
    /// reliable way to tell which app a space belongs to.
    let appName: String?
}
