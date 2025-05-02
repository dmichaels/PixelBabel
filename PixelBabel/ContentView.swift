import SwiftUI
import Utils

struct ContentView: View
{
    @StateObject var orientation = OrientationObserver()

    @EnvironmentObject var cellGrid: CellGrid
    @EnvironmentObject var settings: Settings

    @State private var ignoreSafeArea: Bool = DefaultSettings.ignoreSafeArea
    @State private var cellGridConfigured: Bool = false
    @State private var geometrySize: CGSize = .zero
    @State private var parentRelativeImagePosition: CGPoint = CGPoint.zero
    @State private var image: CGImage? = nil
    @State private var imageAngle: Angle = Angle.zero
    @State private var timerInterval: Double = DefaultSettings.timerInterval

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
                        Image(decorative: image, scale: self.cellGrid.displayScale)
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
                                            self.cellGrid.onDrag(normalizedLocation)
                                            self.updateImage()
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
                                            self.cellGrid.onDragEnd(normalizedLocation)
                                            self.updateImage()
                                        } else {
                                            self.cellGrid.onTap(normalizedLocation)
                                            self.updateImage()
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
                                                    if (self.cellGrid.locate(normalizedLocation) != nil) {
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
                    if (!self.cellGridConfigured) {
                        self.cellGridConfigured = true
                        self.geometrySize = geometry.size
                        print("ON-APPEAR: geosize: \(geometrySize.width) x \(geometrySize.height)")
                        Screen.shared.configure(size: geometry.size, scale: UIScreen.main.scale)
                        let landscape = self.orientation.current.isLandscape
                        self.cellGrid.configure(
                            screen: Screen.shared,
                            displayWidth: landscape ? Screen.shared.height : Screen.shared.width,
                            displayHeight: landscape ? Screen.shared.width : Screen.shared.height,
                            cellSize: DefaultSettings.cellSize,
                            cellPadding: DefaultSettings.cellPadding,
                            cellShape: DefaultSettings.cellShape,
                            cellColorMode: DefaultSettings.cellColorMode,
                            cellBackground: DefaultSettings.cellBackground)
                        // self.cellGrid.randomize()
                        self.cellGrid.testingLifeSetup()
                        self.updateImage()
                        self.rotateImage()
                    }
                }
                .navigationTitle("Home")
                .navigationBarHidden(true)
                // .background(self.cellGrid.background.color) // xyzzy
                .background(Color.yellow) // xyzzy
                .statusBar(hidden: true)
                .coordinateSpace(name: "zstack")
            }
            //
            // TODO: Almost working without this; margins
            // off a bit; would be nice if it did as an option.
            //
            // .ignoresSafeArea()
            .conditionalModifier(ignoreSafeArea) { view in
                view.ignoresSafeArea()
            }
        }
        .onAppear {
            orientation.callback = self.onChangeOrientation
        }
        // .conditionalModifier(ignoreSafeArea) { view in
            // view.ignoresSafeArea()
        // }
        .navigationViewStyle(.stack)
        // .ignoresSafeArea()
    }

    private func updateImage() {
        self.image = self.cellGrid.image
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
                x = CGFloat(self.cellGrid.displayWidthUnscaled) - 1 - (location.x - self.parentRelativeImagePosition.x)
                y = CGFloat(self.cellGrid.displayHeightUnscaled) - 1 - (location.y - self.parentRelativeImagePosition.y)
            }
            else if (self.orientation.previous.isLandscape) {
                x = location.y - self.parentRelativeImagePosition.x
                y = CGFloat(self.cellGrid.displayHeightUnscaled) - 1 - (location.x - self.parentRelativeImagePosition.y)
            }
            else {
                x = location.x - self.parentRelativeImagePosition.x
                y = location.y - self.parentRelativeImagePosition.y
            }
        case .landscapeRight:
            x = location.y - self.parentRelativeImagePosition.x
            y = CGFloat(self.cellGrid.displayHeightUnscaled) - 1 - (location.x - self.parentRelativeImagePosition.y)
        case .landscapeLeft:
            x = CGFloat(self.cellGrid.displayWidthUnscaled) - 1 - (location.y - self.parentRelativeImagePosition.x)
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
        self.autoTappingTimer = Timer.scheduledTimer(withTimeInterval: self.timerInterval, repeats: true) { _ in
            // self.cellGrid.randomize()
            self.cellGrid.testingLife()
            self.updateImage()
        }
    }

    private func autoTappingStop() {
        self.autoTappingTimer?.invalidate()
        self.autoTappingTimer = nil
    }
}

struct ContentView_Previews: PreviewProvider {
    static let cellFactory = LifeCell.factory(activeColor: DefaultLifeSettings.cellActiveColor,
                                              inactiveColor: DefaultLifeSettings.cellInactiveColor)
    static let cellGrid = CellGrid(cellFactory: cellFactory)
    static let settings = Settings()
    static var previews: some View {
        ContentView()
            .environmentObject(cellGrid)
            .environmentObject(settings)
    }
}
