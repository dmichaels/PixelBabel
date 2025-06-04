import SwiftUI
import AudioToolbox
import CoreHaptics
import AVFoundation

@MainActor
public struct Feedback
{
    private var _soundsEnabled: Bool = false
    private var _hapticsEnabled: Bool = false

    init(sounds: Bool = false, haptics: Bool = false) {
        self._soundsEnabled = sounds
        self._hapticsEnabled = haptics
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
        if (self._soundsEnabled) {
            self.triggerTapSound()
        }
        if (self._hapticsEnabled) {
            self.triggerHaptic()
        }
    }
}
