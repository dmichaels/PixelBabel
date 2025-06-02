import SwiftUI
import Utils

struct ContentView: View
{
    @StateObject var orientation = OrientationObserver()

    @EnvironmentObject var cellGridView: CellGridView
    @EnvironmentObject var settings: Settings

    @State private var ignoreSafeArea: Bool = DefaultSettings.ignoreSafeArea
    @State private var cellGridConfigured: Bool = false
    @State private var geometrySize: CGSize = .zero
    @State private var parentRelativeImagePosition: CGPoint = CGPoint.zero
    @State private var image: CGImage? = nil
    @State private var imageAngle: Angle = Angle.zero

    @State private var showSettingsView = false
    @State private var dragging: Bool = false
    @State private var draggingStart: CGPoint? = nil

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    if let image = image {
                        Image(decorative: image, scale: self.cellGridView.viewScale)
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
                                        let normalizedPoint = self.normalizedPoint(value.location)
                                        if (self.draggingStart == nil) {
                                            self.draggingStart = normalizedPoint
                                        }
                                        let delta = hypot(normalizedPoint.x - self.draggingStart!.x,
                                                          normalizedPoint.y - self.draggingStart!.y)
                                        if (delta > DefaultSettings.draggingThreshold) {
                                            self.dragging = true
                                            self.cellGridView.onDrag(normalizedPoint)
                                        }
                                    }
                                    .onEnded { value in
                                        let normalizedPoint = self.normalizedPoint(value.location)
                                        let swipeDistance = (self.orientation.current == .portraitUpsideDown) ?
                                                             value.translation.height : value.translation.width
                                        if (swipeDistance < -DefaultSettings.swipeDistance) {
                                            //
                                            // Swipe left.
                                            //
                                            // withAnimation {
                                                // showSettingsView = true
                                            // }
                                        }
                                        else if (swipeDistance > DefaultSettings.swipeDistance) {
                                            //
                                            // Swipe right.
                                            //
                                        }
                                        if (self.dragging) {
                                            self.cellGridView.onDragEnd(normalizedPoint)
                                        } else {
                                            self.cellGridView.onTap(normalizedPoint)
                                        }
                                        self.draggingStart = nil
                                        self.dragging = false
                                    }
                            )
                            .simultaneousGesture(
                                TapGesture(count: 2)
                                    .onEnded {
                                        self.cellGridView.onDoubleTap()
                                    }
                            )
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 1.0)
                                    .sequenced(before: DragGesture(minimumDistance: 0))
                                    .onEnded { value in
                                        switch value {
                                            case .second(true, let drag):
                                                if let location = drag?.location {
                                                    self.cellGridView.onLongTap(location) // TODO
                                                    let normalizedPoint = self.normalizedPoint(location)
                                                    if (self.cellGridView.gridCellLocation(viewPoint: normalizedPoint) != nil) {
                                                        self.cellGridView.automateToggle()
                                                    }
                                                }
                                            default:
                                                break
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        self.cellGridView.onZoom(value)
                                    }
                                    .onEnded { value in
                                        self.cellGridView.onZoomEnd(value)
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
                        Screen.shared.initialize(size: geometry.size, scale: UIScreen.main.scale)
                        let landscape = self.orientation.current.isLandscape
                        self.cellGridView.initialize(
                            viewWidth: landscape ? Screen.shared.height : Screen.shared.width,
                            viewHeight: landscape ? Screen.shared.width : Screen.shared.height,
                            viewBackground: DefaultSettings.viewBackground,
                            viewTransparency: DefaultSettings.viewTransparency,
                            viewScaling: DefaultSettings.viewScaling,
                            cellSize: DefaultSettings.cellSize,
                            cellPadding: DefaultSettings.cellPadding,
                            cellSizeFit: DefaultSettings.cellSizeFit,
                            cellShape: DefaultSettings.cellShape,
                            cellForeground: DefaultSettings.cellForeground,
                            gridColumns: DefaultSettings.gridColumns,
                            gridRows: DefaultSettings.gridRows,
                            updateImage: self.updateImage)
                        self.rotateImage()
                    }
                }
                .navigationTitle("Home")
                .navigationBarHidden(true)
                // .background(self.cellGridView.background.color) // xyzzy
                // .background(Color.pink) // xyzzy
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
        self.image = self.cellGridView.image
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

    public func normalizedPoint(_ location: CGPoint) -> CGPoint {
        return self.cellGridView.normalizedPoint(screenPoint: location,
                                                 viewOrigin: parentRelativeImagePosition,
                                                 orientation: self.orientation)
    }

    private func onChangeOrientation(_ current: UIDeviceOrientation, _ previous: UIDeviceOrientation) {
        self.rotateImage()
    }
}

struct ContentView_Previews: PreviewProvider {
    static let cellGridView: CellGridView = LifeCellGridView()
    static let settings: Settings = LifeSettings()
    static var previews: some View {
        ContentView()
            .environmentObject(cellGridView)
            .environmentObject(settings)
    }
}
