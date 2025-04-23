import SwiftUI

struct ContentView: View
{
    @StateObject var pixelMap = PixelMap()
    @State private var geometrySize: CGSize = .zero
    @State private var orientation: UIDeviceOrientation = UIDevice.current.orientation
    @State private var previousOrientation: UIDeviceOrientation = UIDevice.current.orientation
    @State private var pixelMapConfigured: Bool = false
    @State private var parentRelativeImagePosition: CGPoint = CGPoint.zero

    private let draggingThreshold: CGFloat = 3.0
    @State private var dragging: Bool = false
    @State private var draggingStart: CGPoint? = nil

    @State private var autoTapping = false
    @State private var autoTappingTimer: Timer?

    @State private var background: PixelValue = PixelMap.Defaults.cellBackground
    @State private var image: CGImage? = nil

    func autoTappingStart() {
        autoTappingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            pixelMap.onTap(CGPoint(x: 0.0, y: 0.0))
            refreshImage()
        }
    }

    func autoTappingStop() {
        autoTappingTimer?.invalidate()
        autoTappingTimer = nil
    }

    private func refreshImage() {
        self.image = pixelMap.image
    }

    private func rotationAngle(for orientation: UIDeviceOrientation) -> Angle {
        let xorientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.interfaceOrientation
        switch orientation {
        case .landscapeLeft:
            return .degrees(-90)
        case .landscapeRight:
            return .degrees(90)
        case .portraitUpsideDown:
            if previousOrientation.isLandscape {
                return .degrees(90)
            } else {
                return .degrees(0)
            }
        default:
            return .degrees(0)
        }
    }

    public func normalizedLocation(_ location: CGPoint) -> CGPoint {
        let x, y: CGFloat
        switch self.orientation {
        case .portrait:
            x = location.x - parentRelativeImagePosition.x
            y = location.y - parentRelativeImagePosition.y
        case .portraitUpsideDown:
            if self.previousOrientation.isLandscape {
                x = location.y - parentRelativeImagePosition.x
                y = CGFloat(pixelMap.displayHeightUnscaled) - 1 - (location.x - parentRelativeImagePosition.y)
            }
            else {
                x = location.x - parentRelativeImagePosition.x
                y = location.y - parentRelativeImagePosition.y
            }
        case .landscapeRight:
            x = location.y - parentRelativeImagePosition.x
            y = CGFloat(pixelMap.displayHeightUnscaled) - 1 - (location.x - parentRelativeImagePosition.y)
        case .landscapeLeft:
            x = CGFloat(pixelMap.displayWidthUnscaled) - 1 - (location.y - parentRelativeImagePosition.x)
            y = location.x - parentRelativeImagePosition.y
        default:
            x = location.x - parentRelativeImagePosition.x
            y = location.y - parentRelativeImagePosition.y
        }
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        GeometryReader { geometry in
            let screenSize = geometry.size
            let screenCenter = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            ZStack { // N.B. ZStack centers (horizontally/vertically) its children by default.
                if let image = image {
                    Image(decorative: image, scale: pixelMap.displayScale)
                        .background( GeometryReader { geo in Color.clear
                            .onAppear {
                                parentRelativeImagePosition = geo.frame(in: .named("zstack")).origin }
                            .onChange(of: parentRelativeImagePosition) { value in
                                parentRelativeImagePosition = value }
                        })
                        .frame(width: geometry.size.width, height: geometry.size.height) // do i need this or not?
                        .rotationEffect(rotationAngle(for: orientation))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let normalizedLocation = self.normalizedLocation(value.location)
                                    if draggingStart == nil {
                                        draggingStart = normalizedLocation
                                    }
                                    let delta = hypot(normalizedLocation.x - draggingStart!.x, normalizedLocation.y - draggingStart!.y)
                                    if delta > draggingThreshold {
                                        dragging = true
                                        pixelMap.onDrag(normalizedLocation)
                                        refreshImage()
                                    }
                                }
                                .onEnded { value in
                                    let normalizedLocation = self.normalizedLocation(value.location)
                                    if dragging {
                                        pixelMap.onDragEnd(normalizedLocation)
                                        refreshImage()
                                    } else {
                                        let imageRelativeLocation = ((orientation == .landscapeLeft) || (orientation == .landscapeRight)) ? CGPoint(x: value.location.x - parentRelativeImagePosition.y, y: value.location.y - parentRelativeImagePosition.x) : CGPoint(x: value.location.x - parentRelativeImagePosition.x, y: value.location.y - parentRelativeImagePosition.y)
                                        pixelMap.onTap(normalizedLocation)
                                        refreshImage()
                                    }
                                    draggingStart = nil
                                    dragging = false
                                }
                        )
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 1.0)
                                .sequenced(before: DragGesture(minimumDistance: 0))
                                .onEnded { value in
                                    switch value {
                                        case .second(true, let drag):
                                            if let location = drag?.location {
                                                let normalizedLocation = self.normalizedLocation(location)
                                                if pixelMap.locate(normalizedLocation) != nil {
                                                    autoTapping.toggle()
                                                    if (autoTapping) {
                                                        autoTappingStart()
                                                    }
                                                    else {
                                                        autoTappingStop()
                                                    }
                                                }
                                            }
                                        default:
                                            break
                                    }
                                }
                        )
                }
            }
            .onAppear {
                UIDevice.current.beginGeneratingDeviceOrientationNotifications()
                print("ON-APPEAR-UIScreen.main.scale = \(UIScreen.main.scale)")
                print("ON-APPEAR-UIScreen.main.bounds = \(UIScreen.main.bounds)")
                print("ON-APPEAR.geometry.size = \(geometry.size)")
                print("ON-APPEAR.screenSize = \(screenSize)")
                print("ON-APPEAR.screenCenter = \(screenCenter)")
                print("ON-APPEAR.PIXELMAP-CONFIGURED: \(pixelMapConfigured)")
                if (!pixelMapConfigured) {
                    pixelMapConfigured = true
                    geometrySize = geometry.size
                    ScreenInfo.shared.configure(size: geometry.size, scale: UIScreen.main.scale)
                    pixelMap.configure(screen: ScreenInfo.shared, displayWidth: ScreenInfo.shared.width,
                                                                  displayHeight: ScreenInfo.shared.height,
                                                                  cellBackground: background)
                }
                refreshImage()
            }
            .onDisappear {
                UIDevice.current.endGeneratingDeviceOrientationNotifications()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                let newOrientation = UIDevice.current.orientation
                if newOrientation.isValidInterfaceOrientation {
                    previousOrientation = orientation
                    orientation = newOrientation
                }
            }
            .background(Color.yellow)
            .statusBar(hidden: true)
            .coordinateSpace(name: "zstack")
        }
        .background(Color.green)
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
