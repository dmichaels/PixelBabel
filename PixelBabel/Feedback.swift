import SwiftUI
import AudioToolbox
import CoreHaptics
import AVFoundation

struct Feedback
{
    private var _settings: Settings

    init(_ settings: Settings) {
        self._settings = settings
    }
    
    func triggerTapSound() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: .mixWithOthers)
            try session.setActive(true)
            AudioServicesPlaySystemSound(1104)
        } catch {
            print("Error setting audio session: \(error)")
        }
    }
    
    func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    func trigger() {
        if (self._settings.soundEnabled) {
            self.triggerTapSound()
        }
        if (self._settings.hapticEnabled) {
            self.triggerHaptic()
        }
    }
}
