import SwiftUI

struct ContentView: View
{
    @StateObject var pixelMap: PixelMap = PixelMap()
    @State private var pixelMapConfigured: Bool = false
    @State private var geometrySize: CGSize = .zero
    @State private var parentRelativeImagePosition: CGPoint = CGPoint.zero
    @State private var orientation: UIDeviceOrientation = UIDevice.current.orientation
    @State private var previousOrientation: UIDeviceOrientation = UIDevice.current.orientation
    @State private var background: PixelValue = PixelMap.Defaults.cellBackground
    @State private var image: CGImage? = nil

    @State private var dragging: Bool = false
    @State private var draggingStart: CGPoint? = nil
    private let draggingThreshold: CGFloat = 3.0

    @State private var autoTapping: Bool = false
    @State private var autoTappingTimer: Timer?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    Image(decorative: image, scale: self.pixelMap.displayScale)
                        .background( GeometryReader { geo in Color.clear
                            .onAppear {
                                self.parentRelativeImagePosition = geo.frame(in: .named("zstack")).origin }
                            .onChange(of: self.parentRelativeImagePosition) { value in
                                self.parentRelativeImagePosition = value }
                        })
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .rotationEffect(rotationAngle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let normalizedLocation = self.normalizedLocation(value.location)
                                    if (self.draggingStart == nil) {
                                        self.draggingStart = normalizedLocation
                                    }
                                    let delta = hypot(normalizedLocation.x - self.draggingStart!.x, normalizedLocation.y - self.draggingStart!.y)
                                    if (delta > self.draggingThreshold) {
                                        self.dragging = true
                                        self.pixelMap.onDrag(normalizedLocation)
                                        self.refreshImage()
                                    }
                                }
                                .onEnded { value in
                                    let normalizedLocation = self.normalizedLocation(value.location)
                                    if (self.dragging) {
                                        self.pixelMap.onDragEnd(normalizedLocation)
                                        self.refreshImage()
                                    } else {
                                        self.pixelMap.onTap(normalizedLocation)
                                        self.refreshImage()
                                    }
                                    self.draggingStart = nil
                                    self.dragging = false
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
                                                if (self.pixelMap.locate(normalizedLocation) != nil) {
                                                    self.autoTapping.toggle()
                                                    if (self.autoTapping) {
                                                        self.autoTappingStart()
                                                    }
                                                    else {
                                                        self.autoTappingStop()
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
                let orientation = UIDevice.current.orientation
                if (orientation.isValidInterfaceOrientation) {
                    self.orientation = orientation
                    self.previousOrientation = .unknown
                }
                if (!self.pixelMapConfigured) {
                    self.pixelMapConfigured = true
                    self.geometrySize = geometry.size
                    ScreenInfo.shared.configure(size: geometry.size, scale: UIScreen.main.scale)
                    self.pixelMap.configure(
                        screen: ScreenInfo.shared,
                        displayWidth: self.orientation.isLandscape ?  ScreenInfo.shared.height : ScreenInfo.shared.width,
                        displayHeight: self.orientation.isLandscape ?  ScreenInfo.shared.width : ScreenInfo.shared.height,
                        cellBackground: self.background)
                }
                self.pixelMap.onTap(CGPoint(x: 100, y: 100))
                self.refreshImage()
            }
            .onDisappear {
                UIDevice.current.endGeneratingDeviceOrientationNotifications()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                let newOrientation = UIDevice.current.orientation
                if (newOrientation.isValidInterfaceOrientation) {
                    self.previousOrientation = orientation
                    self.orientation = newOrientation
                }
            }
            .background(self.background.color)
            .statusBar(hidden: true)
            .coordinateSpace(name: "zstack")
        }
        .ignoresSafeArea()
    }

    func autoTappingStart() {
        self.autoTappingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            self.pixelMap.onTap(CGPoint(x: 0.0, y: 0.0))
            self.refreshImage()
        }
    }

    func autoTappingStop() {
        self.autoTappingTimer?.invalidate()
        self.autoTappingTimer = nil
    }

    private func refreshImage() {
        self.image = pixelMap.image
    }

    private func rotationAngle() -> Angle {
        print("ROTATION-ANGLE: \(self.previousOrientation.rawValue) -> \(self.orientation.rawValue) -> \(UIDevice.current.orientation.rawValue)")
        let angle: Angle
        switch self.orientation {
        case .landscapeLeft:
            angle = .degrees(-90)
        case .landscapeRight:
            angle = .degrees(90)
        case .portraitUpsideDown:
            //
            // All sorts of odd trouble with upside-down mode;
            // going there from portrait yields portrait mode;
            // going there from landscape yield upside-down mode.
            // But still acts weird sometimes (e.g. iPhone SE from
            // Jake and iPad simulator); best to just disable
            // upside-down mode in project deployment-info.
            //
            if (self.previousOrientation.isLandscape) {
                angle = .degrees(90)
            } else {
                angle = .degrees(0)
            }
        default:
            angle = .degrees(0)
        }
        self.previousOrientation = self.orientation
        return angle
    }

    public func normalizedLocation(_ location: CGPoint) -> CGPoint {
        let x, y: CGFloat
        switch self.orientation {
        case .portrait:
            x = location.x - self.parentRelativeImagePosition.x
            y = location.y - self.parentRelativeImagePosition.y
        case .portraitUpsideDown:
            if (self.previousOrientation.isLandscape) {
                x = location.y - self.parentRelativeImagePosition.x
                y = CGFloat(pixelMap.displayHeightUnscaled) - 1 - (location.x - self.parentRelativeImagePosition.y)
            }
            else {
                x = location.x - self.parentRelativeImagePosition.x
                y = location.y - self.parentRelativeImagePosition.y
            }
        case .landscapeRight:
            x = location.y - self.parentRelativeImagePosition.x
            y = CGFloat(pixelMap.displayHeightUnscaled) - 1 - (location.x - self.parentRelativeImagePosition.y)
        case .landscapeLeft:
            x = CGFloat(pixelMap.displayWidthUnscaled) - 1 - (location.y - self.parentRelativeImagePosition.x)
            y = location.x - self.parentRelativeImagePosition.y
        default:
            x = location.x - self.parentRelativeImagePosition.x
            y = location.y - self.parentRelativeImagePosition.y
        }
        return CGPoint(x: x, y: y)
    }
}

#Preview {
    ContentView()
}
