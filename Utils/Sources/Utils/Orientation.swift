import SwiftUI

@MainActor
public class Orientation {

    public static var current: UIDeviceOrientation {
        var orientation: UIDeviceOrientation = UIDevice.current.orientation
        if (orientation == .unknown) {
            orientation = Orientation._currentBackup
        }
        switch orientation {
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            return orientation
        case .faceUp, .faceDown:
            return .portrait
        case .unknown:
            return .portrait
        @unknown default:
            return .portrait
        }
    }

    public static func beginNotifications() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }

    public static func endNotifications() {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    private static var _currentBackup: UIDeviceOrientation {
        let orientation: UIInterfaceOrientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.interfaceOrientation ?? .unknown
        return Orientation._deviceOrientation(orientation)
    }

    private static func _deviceOrientation(_ interfaceOrientation: UIInterfaceOrientation) -> UIDeviceOrientation {
        switch interfaceOrientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        case .unknown:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
}
