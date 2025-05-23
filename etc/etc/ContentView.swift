import SwiftUI

struct ContentView: View
{
    @StateObject var orientation = OrientationObserver()

    @EnvironmentObject var pixelMap: PixelMap
    @EnvironmentObject var settings: Settings

    @State private var pixelMapConfigured: Bool = false
    @State private var geometrySize: CGSize = .zero
    @State private var parentRelativeImagePosition: CGPoint = CGPoint.zero
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
                            .background(GeometryReader { geo in Color.clear
                                .onAppear {
                                    let parentOrigin = geo.frame(in: .named("zstack")).origin
                                    self.parentRelativeImagePosition = self.orientation.current.isLandscape ?
                                                                       CGPoint(x: parentOrigin.y, y: parentOrigin.x) :
                                                                       parentOrigin
                                }
                                .onChange(of: self.parentRelativeImagePosition) { value in
                                    self.parentRelativeImagePosition = value
                                 }
                            })
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .rotationEffect(self.imageAngle)
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
                                        let swipeDistance = (self.orientation.current == .portraitUpsideDown) ?
                                                             value.translation.height : value.translation.width
                                        if (swipeDistance < -DefaultSettings.swipeDistance) {
                                            //
                                            // Swipe left.
                                            //
                                            withAnimation {
                                                showSettingsView = true
                                            }
                                        }
                                        else if (swipeDistance > DefaultSettings.swipeDistance) {
                                            //
                                            // Swipe right.
                                            //
                                        }
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
                    if (!self.pixelMapConfigured) {
                        self.pixelMapConfigured = true
                        self.geometrySize = geometry.size
                        ScreenInfo.shared.configure(size: geometry.size, scale: UIScreen.main.scale)
                        let landscape = self.orientation.current.isLandscape
                        self.pixelMap.configure(
                            screen: ScreenInfo.shared,
                            displayWidth: landscape ? ScreenInfo.shared.height : ScreenInfo.shared.width,
                            displayHeight: landscape ? ScreenInfo.shared.width : ScreenInfo.shared.height,
                            cellBackground: self.background)
                        self.pixelMap.randomize()
                        self.refreshImage()
                        self.rotateImage()
                    }
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
            orientation.callback = self.onChangeOrientation
        }
        .navigationViewStyle(.stack)
    }

    private func refreshImage() {
        self.image = self.pixelMap.image
    }

    private func rotateImage() {
        switch self.orientation.current {
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
            if (orientation.ipad) {
                self.imageAngle = Angle.degrees(180)
            }
            else if (self.orientation.previous.isLandscape) {
                self.imageAngle = Angle.degrees(90)
            } else {
                self.imageAngle = Angle.degrees(0)
            }
        default:
            self.imageAngle = Angle.degrees(0)
        }
    }

    public func normalizedLocation(_ location: CGPoint) -> CGPoint {
        let x, y: CGFloat
        switch self.orientation.current {
        case .portrait:
            x = location.x - self.parentRelativeImagePosition.x
            y = location.y - self.parentRelativeImagePosition.y
        case .portraitUpsideDown:
            if (orientation.ipad) {
                x = CGFloat(self.pixelMap.displayWidthUnscaled) - 1 - (location.x - self.parentRelativeImagePosition.x)
                y = CGFloat(self.pixelMap.displayHeightUnscaled) - 1 - (location.y - self.parentRelativeImagePosition.y)
            }
            else if (self.orientation.previous.isLandscape) {
                x = location.y - self.parentRelativeImagePosition.x
                y = CGFloat(self.pixelMap.displayHeightUnscaled) - 1 - (location.x - self.parentRelativeImagePosition.y)
            }
            else {
                x = location.x - self.parentRelativeImagePosition.x
                y = location.y - self.parentRelativeImagePosition.y
            }
        case .landscapeRight:
            x = location.y - self.parentRelativeImagePosition.x
            y = CGFloat(self.pixelMap.displayHeightUnscaled) - 1 - (location.x - self.parentRelativeImagePosition.y)
        case .landscapeLeft:
            x = CGFloat(self.pixelMap.displayWidthUnscaled) - 1 - (location.y - self.parentRelativeImagePosition.x)
            y = location.x - self.parentRelativeImagePosition.y
        default:
            x = location.x - self.parentRelativeImagePosition.x
            y = location.y - self.parentRelativeImagePosition.y
        }
        return CGPoint(x: x, y: y)
    }

    private func onChangeOrientation(_ current: UIDeviceOrientation, _ previous: UIDeviceOrientation) {
        self.rotateImage()
    }

    private func autoTappingStart() {
        self.autoTappingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            self.pixelMap.onTap(CGPoint(x: 0.0, y: 0.0))
            self.refreshImage()
        }
    }

    private func autoTappingStop() {
        self.autoTappingTimer?.invalidate()
        self.autoTappingTimer = nil
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
