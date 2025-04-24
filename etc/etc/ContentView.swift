import SwiftUI

struct ContentView: View
{
    @EnvironmentObject var pixelMap: PixelMap
    @EnvironmentObject var settings: Settings

    @State private var pixelMapConfigured: Bool = false
    @State private var geometrySize: CGSize = .zero
    @State private var parentRelativeImagePosition: CGPoint = CGPoint.zero
    @State private var orientation: UIDeviceOrientation = UIDevice.current.orientation
    @State private var previousOrientation: UIDeviceOrientation = UIDevice.current.orientation
    @State private var background: PixelValue = PixelMap.Defaults.cellBackground
    @State private var image: CGImage? = nil
    @State private var imageAngle: Angle = Angle.zero

    @State private var showSettingsView = false

    @State private var dragging: Bool = false
    @State private var draggingStart: CGPoint? = nil

    @State private var autoTapping: Bool = false
    @State private var autoTappingTimer: Timer?

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    if let image = image {
                        Image(decorative: image, scale: self.pixelMap.displayScale)
                            .background( GeometryReader { geo in Color.clear
                                .onAppear {
                                    let zstackOrigin = geo.frame(in: .named("zstack")).origin
                                    self.parentRelativeImagePosition = orientation.isLandscape ?
                                                                       CGPoint(x: zstackOrigin.y, y: zstackOrigin.x) :
                                                                       zstackOrigin
                                    print("BG-ON-APPEAR: zo: \(zstackOrigin) prip: \(parentRelativeImagePosition) or: \(orientation) por: \(previousOrientation)")
                                }
                                .onChange(of: self.parentRelativeImagePosition) { value in
                                    self.parentRelativeImagePosition = value
                                    print("BG-ON-CHANGE: prip: \(parentRelativeImagePosition) or: \(orientation) por: \(previousOrientation)")
                                 }
                            })
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .rotationEffect(imageAngle)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let normalizedLocation = self.normalizedLocation(value.location)
                                        if (self.draggingStart == nil) {
                                            self.draggingStart = normalizedLocation
                                        }
                                        let delta = hypot(normalizedLocation.x - self.draggingStart!.x,
                                                          normalizedLocation.y - self.draggingStart!.y)
                                        if (delta > DefaultSettings.draggingThreshold) {
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
                            NavigationLink(
                                destination: SettingsView(),
                                isActive: $showSettingsView,
                                label: { EmptyView() }
                            )
                    }
                }
                .onAppear {
                    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
                    let orientation = UIDevice.current.orientation
                    if (orientation.isValidInterfaceOrientation) {
                        self.orientation = orientation
                        self.previousOrientation = UIDeviceOrientation.unknown
                        self.rotateImage()
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
                    print("ON-APPEAR: prip: \(parentRelativeImagePosition) or: \(orientation) por: \(previousOrientation)")
                }
                .onDisappear {
                    UIDevice.current.endGeneratingDeviceOrientationNotifications()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                    let newOrientation: UIDeviceOrientation = UIDevice.current.orientation
                    if (newOrientation.isValidInterfaceOrientation) {
                        if (self.orientation != self.previousOrientation) {
                            self.previousOrientation = orientation
                            self.orientation = newOrientation
                            self.rotateImage()
                        }
                    }
                    print("ON-RECEIVE: prip: \(parentRelativeImagePosition) or: \(orientation) por: \(previousOrientation)")
                }
                .navigationTitle("Home")
                .navigationBarHidden(true)
                .background(self.background.color)
                .statusBar(hidden: true)
                .coordinateSpace(name: "zstack")
            }
            .ignoresSafeArea()
        }
        .navigationViewStyle(.stack)
    }

    func autoTappingStart() {
                                    withAnimation {
                                        self.showSettingsView = true
                                    }
        /*
        self.autoTappingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            self.pixelMap.onTap(CGPoint(x: 0.0, y: 0.0))
            self.refreshImage()
        }
        */
    }

    func autoTappingStop() {
        self.autoTappingTimer?.invalidate()
        self.autoTappingTimer = nil
    }

    private func refreshImage() {
        self.image = pixelMap.image
    }

    private func rotateImage() {
        print("ROTATE-ANGLE: \(self.previousOrientation.rawValue) -> \(self.orientation.rawValue) -> \(UIDevice.current.orientation.rawValue)")
        switch self.orientation {
        case .landscapeLeft:
            self.imageAngle = Angle.degrees(-90)
        case .landscapeRight:
            self.imageAngle = Angle.degrees(90)
        case .portraitUpsideDown:
            //
            // All sorts of odd trouble with upside-down mode;
            // going there from portrait yields portrait mode;
            // going there from landscape yield upside-down mode.
            // But still acts weird sometimes (e.g. iPhone SE via
            // Jake and iPad simulator); best to just disable
            // upside-down mode in project deployment-info.
            //
            if (self.previousOrientation.isLandscape) {
                self.imageAngle = Angle.degrees(90)
                print("XYZZY-A: \(self.imageAngle)")
            } else {
                self.imageAngle = .degrees(0)
            }
        default:
            self.imageAngle = .degrees(0)
        }
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

// #Preview {
    // ContentView()
// }

struct ContentView_Previews: PreviewProvider {
    static let pixelMap = PixelMap()
    static let settings = Settings()
    static var previews: some View {
        ContentView()
            .environmentObject(pixelMap)
            .environmentObject(settings)
    }
}
