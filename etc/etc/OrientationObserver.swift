import SwiftUI
import Combine

// Have not yet tried this (suggestion from ChatGPT).
//
class OrientationObserver: ObservableObject {

    @Published var current: UIDeviceOrientation = Orientation.current

    private var _cancellable: AnyCancellable?

    init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        self.current = Orientation.current
        self._cancellable = NotificationCenter.default
            .publisher(for: UIDevice.orientationDidChangeNotification)
            .sink { _ in
                let newOrientation = Orientation.current
                if newOrientation.isValidInterfaceOrientation {
                    DispatchQueue.main.async {
                        self.current = newOrientation
                    }
                }
            }
    }

    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        self._cancellable?.cancel()
    }
}
