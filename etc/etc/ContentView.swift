import SwiftUI

struct ContentView: View
{
    @StateObject var orientationObserver = OrientationObserver() // TODO: test

    @EnvironmentObject var pixelMap: PixelMap
    @EnvironmentObject var settings: Settings

    @State private var pixelMapConfigured: Bool = false
    @State private var geometrySize: CGSize = .zero
    @State private var parentRelativeImagePosition: CGPoint = CGPoint.zero
    @State private var orientation: UIDeviceOrientation = Orientation.current
    @State private var previousOrientation: UIDeviceOrientation = Orientation.current
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
                                    print("BG-ON-APPEAR: zo: \(zstackOrigin) ip: \(parentRelativeImagePosition) ia: \(imageAngle.degrees) or: \(orientation) por: \(previousOrientation) o: \(Orientation.current)")
                                }
                                .onChange(of: self.parentRelativeImagePosition) { value in
                                    self.parentRelativeImagePosition = value
                                    print("BG-ON-CHANGE: ip: \(parentRelativeImagePosition) ia: \(imageAngle.degrees) or: \(orientation) por: \(previousOrientation) o: \(Orientation.current)")
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
                                        if value.translation.width < -100 { // Swipe left
                                            print("SWIPE-LEFT")
                                            //withAnimation {
                                                //showSettingsView = true
                                            //}
                                        }
                                        else if (value.translation.width > 100) { // Swipe right
                                            print("SWIPE-RIGHT")
                                        }
                                        if (self.dragging) {
                                            self.pixelMap.onDragEnd(normalizedLocation)
                                            self.refreshImage()
                                        } else {
                                            print("ON-TAP: IP: \(parentRelativeImagePosition) O: \(orientation.rawValue) | \(UIDevice.current.orientation.rawValue) PO: \(previousOrientation.rawValue) IA: \(String(format: "%.2f", imageAngle.degrees))")
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
                    Orientation.beginNotifications()
                    let orientation: UIDeviceOrientation = Orientation.current
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
                    self.rotateImage()
                    print("ON-APPEAR: ip: \(parentRelativeImagePosition) ia: \(imageAngle.degrees) or: \(orientation) por: \(previousOrientation) o: \(Orientation.current)")
                }
                .onDisappear {
                    Orientation.endNotifications()
                    print("XYZZY-ON-DISAPPEAR")
                }
                .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                    let newOrientation: UIDeviceOrientation = Orientation.current
                    self.previousOrientation = orientation
                    self.orientation = newOrientation
                    self.rotateImage()
                    print("ON-RECEIVE: ip: \(parentRelativeImagePosition) ia: \(imageAngle.degrees) or: \(orientation) por: \(previousOrientation) o: \(Orientation.current)")
                }
                .navigationTitle("Home")
                .navigationBarHidden(true)
                .background(self.background.color)
                .statusBar(hidden: true)
                .coordinateSpace(name: "zstack")
            }
            .ignoresSafeArea()
        }
        .onAppear {
            Orientation.beginNotifications()
            print("NAV-ON-APPEAR: ip: \(parentRelativeImagePosition) ia: \(imageAngle.degrees) or: \(orientation) por: \(previousOrientation) o: \(Orientation.current)")
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

struct ContentView_Previews: PreviewProvider {
    static let pixelMap = PixelMap()
    static let settings = Settings()
    static var previews: some View {
        ContentView()
            .environmentObject(pixelMap)
            .environmentObject(settings)
    }
}
