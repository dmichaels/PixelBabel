import SwiftUI
import Utils

struct ContentView: View
{
    private let screen: Screen = Screen(size: UIScreen.main.bounds, scale: UIScreen.main.scale)

    @StateObject var orientation = OrientationObserver()

    @EnvironmentObject var cellGridView: CellGridView
    @EnvironmentObject var settings: Settings

    @State private var ignoreSafeArea: Bool = DefaultSettings.ignoreSafeArea
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
                            .onSmartGesture(threshold: DefaultSettings.draggingThreshold,
                                            normalize: self.normalizePoint,
                                onDrag:      { value in self.cellGridView.onDrag(value) },
                                onDragEnd:   { value in self.cellGridView.onDragEnd(value) },
                                onTap:       { value in self.cellGridView.onTap(value) },
                                onDoubleTap: { self.cellGridView.onDoubleTap() },
                                onLongTap:   { value in self.cellGridView.onLongTap(value) },
                                onZoom:      { value in self.cellGridView.onZoom(value) },
                                onZoomEnd:   { value in self.cellGridView.onZoomEnd(value) }
                            )
                            NavigationLink(
                                destination: SettingsView(),
                                isActive: $showSettingsView,
                                label: { EmptyView() }
                            )
                    }
                }
                .onAppear {
                    if (!self.cellGridView.initialized) {
                        let landscape = self.orientation.current.isLandscape
                        self.cellGridView.initialize(screen: screen,
                                                     viewWidth: landscape ? screen.height : screen.width,
                                                     viewHeight: landscape ? screen.width : screen.height,
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

    public func normalizePoint(_ location: CGPoint) -> CGPoint {
        return self.cellGridView.normalizePoint(screenPoint: location,
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
