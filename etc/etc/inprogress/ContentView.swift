import SwiftUI

struct ContentView: View
{
    @StateObject var pixelMap = PixelMap()
    @State private var geometrySize: CGSize = .zero
       @State private var orientation: UIDeviceOrientation = UIDevice.current.orientation


    private let draggingThreshold: CGFloat = 3.0
    @State private var dragging: Bool = false
    @State private var draggingStart: CGPoint? = nil

    @State private var autoTapping = false
    @State private var autoTappingTimer: Timer?

    @State private var background: PixelValue = PixelMap.Defaults.cellBackground

    func autoTappingStart() {
        /*
        autoTappingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            pixelMap.onTap(CGPoint(x: 0.0, y: 0.0))
        }
        */
    }

    func autoTappingStop() {
        /*
        autoTappingTimer?.invalidate()
        autoTappingTimer = nil
        */
    }
    private var orientationChanged: some View {
        EmptyView()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                orientation = UIDevice.current.orientation
                print("Orientation changed to: \(orientation.rawValue)")
                ScreenInfo.shared.configure(size: geometrySize, scale: UIScreen.main.scale)
                pixelMap.configure(screen: ScreenInfo.shared,
                                   displayWidth: ScreenInfo.shared.width,
                                   displayHeight: ScreenInfo.shared.height,
                                   cellBackground: background)
           
            }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // orientationChanged
                Color.yellow.ignoresSafeArea()
                if let image = pixelMap.image {
                    Image(decorative: image, scale: pixelMap.displayScale)
                    // .onTapGesture { print("CONTENT-VIEW.ON-TAP") }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    print("CONTENT-VIEW.DRAG-ON-CHANGED: \(value.location)")
                                    if draggingStart == nil {
                                        draggingStart = value.location
                                    }
                                    let delta = hypot(value.location.x - draggingStart!.x, value.location.y - draggingStart!.y)
                                    if delta > draggingThreshold {
                                        dragging = true
                                        pixelMap.onDrag(value.location)
                                        pixelMap.update()
                                    }
                                }
                                .onEnded { value in
                                    print("CONTENT-VIEW.DRAG-ON-ENDED: \(value.location)")
                                    if dragging {
                                        pixelMap.onDragEnd(value.location)
                                    } else {
                                        pixelMap.onTap(value.location)
                                    }
                                    draggingStart = nil
                                    dragging = false
                                }
                        )
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 1.0)
                                .sequenced(before: DragGesture(minimumDistance: 0))
                                .onEnded { value in
                                    print("CONTENT-VIEW.LONG-PRESS-ON-ENDED: \(value)")
                                    switch value {
                                        case .second(true, let drag):
                                            if let dragLocation = drag?.location {
                                                if let location = pixelMap.locate(dragLocation) {
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
            .statusBar(hidden: true)
            .onAppear {
                print("XYZZYSCREEN-INFO-ON-APPEAR: \(UIScreen.main.scale)")
                print("UIScreen.main.scale = \(UIScreen.main.scale)")
                print("UIScreen.main.bounds = \(UIScreen.main.bounds)")
                print("XYZZYSCREEN-INFO-ON-APPEAR-END: \(UIScreen.main.scale)")
                geometrySize = geometry.size
                ScreenInfo.shared.configure(size: geometry.size, scale: UIScreen.main.scale)
                pixelMap.configure(screen: ScreenInfo.shared, displayWidth: ScreenInfo.shared.width,
                                                              displayHeight: ScreenInfo.shared.height,
                                                              cellBackground: background)
            }
            .onChange(of: geometrySize) { previous, size in 
                print("XYZZY.onChange: \(previous) \(size) - \(geometrySize)")
                if (previous != size) {
                    print("XYZZY.onChange.OK: \(previous) \(size) - \(geometrySize)")
                    geometrySize = geometry.size
                    ScreenInfo.shared.configure(size: geometry.size, scale: UIScreen.main.scale)
                    pixelMap.configure(screen: ScreenInfo.shared, displayWidth: ScreenInfo.shared.width,
                                                                  displayHeight: ScreenInfo.shared.height,
                                                                  cellBackground: background)
                }
            }
            /*
            .onTapGesture {
                print("CONTENT-VIEW.ON-TAP")
            }
            */
            .frame(width: geometry.size.width, height: geometry.size.height)
            // .background(background.color)
            .background(Color.red)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
