import AppKit

final class MissionControlWatcher {
    private let onShow: ([Thumbnail]) -> Void
    private let onHide: () -> Void
    private let onUpdate: ([Thumbnail]) -> Void

    private var pollTimer: Timer?
    private var refreshTimer: Timer?
    private var isVisible = false

    init(
        onShow: @escaping ([Thumbnail]) -> Void,
        onHide: @escaping () -> Void,
        onUpdate: @escaping ([Thumbnail]) -> Void
    ) {
        self.onShow = onShow
        self.onHide = onHide
        self.onUpdate = onUpdate
    }

    func start() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(pollTimer!, forMode: .common)
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func scanOnce() {
        let thumbnails = ThumbnailScanner.scan()
        if thumbnails.isEmpty {
            if isVisible {
                isVisible = false
                onHide()
            }
        } else {
            if isVisible {
                onUpdate(thumbnails)
            } else {
                isVisible = true
                onShow(thumbnails)
            }
        }
    }

    private func tick() {
        let thumbnails = ThumbnailScanner.scan()
        let nowVisible = !thumbnails.isEmpty
        if nowVisible && !isVisible {
            isVisible = true
            onShow(thumbnails)
            startRefreshLoop()
        } else if !nowVisible && isVisible {
            isVisible = false
            stopRefreshLoop()
            onHide()
        }
    }

    private func startRefreshLoop() {
        refreshTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self, self.isVisible else { return }
            let thumbnails = ThumbnailScanner.scan()
            if thumbnails.isEmpty {
                self.isVisible = false
                self.stopRefreshLoop()
                self.onHide()
            } else {
                self.onUpdate(thumbnails)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func stopRefreshLoop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
