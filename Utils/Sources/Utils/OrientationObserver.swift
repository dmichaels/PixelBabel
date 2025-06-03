import SwiftUI
import Combine

// Full disclosure: This idea was mostly from ChatGPT.
//
@MainActor
public class OrientationObserver: ObservableObject {

    @Published public var current: UIDeviceOrientation = Orientation.current
    @Published public var previous: UIDeviceOrientation = Orientation.current

    public let ipad: Bool = (UIDevice.current.userInterfaceIdiom == .pad)

    public typealias Callback = (_ current: UIDeviceOrientation, _ previous: UIDeviceOrientation) -> Void

    private var _callback: Callback?
    private var _cancellable: AnyCancellable?

    public init(callback: Callback? = nil) {
        Orientation.beginNotifications()
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
        // Orientation.endNotifications() // TODO main actor-isolcated static method error
        // self._cancellable?.cancel() // TODO Cannot access property '_cancellable' with a non-sendable type 'AnyCancellable?' from nonisolated deinit
    }
}
