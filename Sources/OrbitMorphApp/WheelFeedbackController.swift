import AppKit
import Foundation

@MainActor
final class WheelFeedbackController {
    private let minimumInterval: TimeInterval
    private let now: () -> TimeInterval
    private let play: () -> Void
    private var lastPlayedIndex: Int?
    private var lastPlayedAt = -Double.infinity

    init(
        minimumInterval: TimeInterval = 0.04,
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        play: @escaping () -> Void
    ) {
        self.minimumInterval = minimumInterval
        self.now = now
        self.play = play
    }

    convenience init(soundURL: URL = SampleResources.tickSoundURL) {
        let sound = NSSound(contentsOf: soundURL, byReference: true)
        sound?.volume = 0.13
        self.init(play: {
            guard let sound else { return }
            if sound.isPlaying { sound.stop() }
            sound.play()
        })
    }

    func selectionChanged(to index: Int?, enabled: Bool) {
        guard enabled else {
            lastPlayedIndex = index
            return
        }
        guard let index else {
            lastPlayedIndex = nil
            return
        }
        guard index != lastPlayedIndex else { return }
        let timestamp = now()
        guard timestamp - lastPlayedAt >= minimumInterval else { return }
        lastPlayedIndex = index
        lastPlayedAt = timestamp
        play()
    }

    func reset() {
        lastPlayedIndex = nil
        lastPlayedAt = -Double.infinity
    }
}
