import SwiftUI
import Combine

// Full disclosure: This idea was mostly from ChatGPT.
//
@MainActor
public class OrientationObserver: ObservableObject
{
    public typealias Callback = (_ current: UIDeviceOrientation, _ previous: UIDeviceOrientation) -> Void

    @Published public var current: UIDeviceOrientation = Orientation.current
    @Published public var previous: UIDeviceOrientation = Orientation.current

    public let ipad: Bool = (UIDevice.current.userInterfaceIdiom == .pad)

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

    public final func normalizePoint(screenPoint: CGPoint, view: CGRect) -> CGPoint
    {
        // Various oddities with upside-down mode and having to know the
        // previous orientation and whether or not we are an iPad and whatnot.
        //
        let x, y: CGFloat
        switch self.current {
        case .portrait:
            x = screenPoint.x - view.origin.x
            y = screenPoint.y - view.origin.y
        case .portraitUpsideDown:
            if (self.ipad) {
                x = CGFloat(view.size.width) - 1 - (screenPoint.x - view.origin.x)
                y = CGFloat(view.size.height) - 1 - (screenPoint.y - view.origin.y)
            }
            else if (self.previous.isLandscape) {
                x = screenPoint.y - view.origin.x
                y = CGFloat(view.size.height) - 1 - (screenPoint.x - view.origin.y)
            }
            else {
                x = screenPoint.x - view.origin.x
                y = screenPoint.y - view.origin.y
            }
        case .landscapeRight:
            x = screenPoint.y - view.origin.x
            y = CGFloat(view.size.height) - 1 - (screenPoint.x - view.origin.y)
        case .landscapeLeft:
            x = CGFloat(view.size.width) - 1 - (screenPoint.y - view.origin.x)
            y = screenPoint.x - view.origin.y
        default:
            x = screenPoint.x - view.origin.x
            y = screenPoint.y - view.origin.y
        }
        return CGPoint(x: x, y: y)
    }

    public final lazy var supported: [UIDeviceOrientation] = {
        var result: [UIDeviceOrientation] = []
        if let orientations = Bundle.main.object(forInfoDictionaryKey: "UISupportedInterfaceOrientations") as? [String] {
            if (orientations.contains("UIInterfaceOrientationPortrait")) {
                result.append(.portrait)
            }
            if (orientations.contains("UIInterfaceOrientationPortraitUpsideDown")) {
                result.append(.portraitUpsideDown)
            }
            if (orientations.contains("UIInterfaceOrientationLandscapeLeft")) {
                result.append(.landscapeLeft)
            }
            if (orientations.contains("UIInterfaceOrientationLandscapeRight")) {
                result.append(.landscapeRight)
            }
        }
        return result
    }()

    public func deregister() {
        Orientation.endNotifications()
        self._cancellable?.cancel()
    }
}
