import SwiftUI
import Combine

// Have not yet tried this (suggestion from ChatGPT).
//
class OrientationObserver: ObservableObject {

    @Published var current: UIDeviceOrientation = Orientation.current
    @Published var previous: UIDeviceOrientation = Orientation.current

    typealias Callback = (_ current: UIDeviceOrientation, _ previous: UIDeviceOrientation) -> Void

    private var _callback: Callback?
    private var _cancellable: AnyCancellable?

    init(callback: Callback? = nil) {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        self.current = Orientation.current
        self.previous = self.current
        self._callback = callback
        self._cancellable = NotificationCenter.default
            .publisher(for: UIDevice.orientationDidChangeNotification)
            .sink { _ in
                let newOrientation = Orientation.current
                if newOrientation.isValidInterfaceOrientation {
                    DispatchQueue.main.async {
                        self.previous = self.current
                        self.current = newOrientation
                        self._callback?(self.current, self.previous)
                    }
                }
            }
    }

    public var callback: Callback? {
        get { self._callback }
        set { self._callback = newValue }
    }

    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        self._cancellable?.cancel()
    }
}
