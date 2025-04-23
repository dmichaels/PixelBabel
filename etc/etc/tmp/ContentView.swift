import SwiftUI

struct ContentView: View
{
    @StateObject var pixelMap = PixelMap()
    @State private var geometrySize: CGSize = .zero
    @State private var orientation: UIDeviceOrientation = UIDevice.current.orientation
    @State private var previousOrientation: UIDeviceOrientation = UIDevice.current.orientation
    @State private var pixelMapConfigured: Bool = false
    @State private var parentRelativeImagePosition: CGPoint = CGPoint.zero
    @State private var trackingLocation: CGPoint = CGPoint.zero

    private let draggingThreshold: CGFloat = 3.0
    @State private var dragging: Bool = false
    @State private var draggingStart: CGPoint? = nil

    @State private var autoTapping = false
    @State private var autoTappingTimer: Timer?

    @State private var background: PixelValue = PixelMap.Defaults.cellBackground
    @State private var image: CGImage? = nil

    func autoTappingStart() {
        /* autoTappingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            pixelMap.onTap(CGPoint(x: 0.0, y: 0.0))
        } */
    }

    func autoTappingStop() {
        /* autoTappingTimer?.invalidate()
        autoTappingTimer = nil */
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
            print("ROTATION-ANGLE-LL: \(orientation) (was \(previousOrientation)) -> -90 degrees")
            return .degrees(-90)
        case .landscapeRight:
            print("ROTATION-ANGLE-LR: \(orientation) (was \(previousOrientation)) -> 90 degrees")
            return .degrees(90)
        case .portraitUpsideDown:
            if previousOrientation.isLandscape {
                print("ROTATION-ANGLE-UD-A: \(orientation) (was \(previousOrientation)) -> 90 degrees")
                return .degrees(90)
            } else {
                print("ROTATION-ANGLE-UD-B: \(orientation) (was \(previousOrientation)) -> 0 degrees")
                return .degrees(0)
            }
            // Don’t rotate the rectangle visually; treat it like portrait
            // return .degrees(0)
        default:
            print("ROTATION-ANGLE-DF: \(orientation) (was \(previousOrientation)) -> 0 degrees")
            return .degrees(0)
        }
    }

    public func _normalizedLocation(_ location: CGPoint,
                                    orientation: UIDeviceOrientation = UIDeviceOrientation.portrait,
                                    previousOrientation: UIDeviceOrientation = UIDeviceOrientation.portrait) -> CGPoint {
        // let locationX: CGFloat = location.x - (orientation.isLandscape ? parentRelativeImagePosition.y : (previousOrientation.isLandscape ? parentRelativeImagePosition.y : parentRelativeImagePosition.x))
        // let locationY: CGFloat = location.y - (orientation.isLandscape ? parentRelativeImagePosition.x : (previousOrientation.isLandscape ? parentRelativeImagePosition.x : parentRelativeImagePosition.y))

        // SEEMS TO BE OK
        // let locationX: CGFloat = location.x - (orientation.isLandscape ? parentRelativeImagePosition.y : (previousOrientation.isLandscape ? parentRelativeImagePosition.x : parentRelativeImagePosition.x))
        // let locationY: CGFloat = location.y - (orientation.isLandscape ? parentRelativeImagePosition.x : (previousOrientation.isLandscape ? parentRelativeImagePosition.y : parentRelativeImagePosition.y))

        // let locationX: CGFloat = location.x - (orientation.isLandscape ? parentRelativeImagePosition.y : (previousOrientation.isLandscape ? parentRelativeImagePosition.y : parentRelativeImagePosition.x))
        // let locationY: CGFloat = location.y - (orientation.isLandscape ? parentRelativeImagePosition.x : (previousOrientation.isLandscape ? parentRelativeImagePosition.x : parentRelativeImagePosition.y))

        // let locationX: CGFloat = location.x - (orientation.isLandscape ? parentRelativeImagePosition.y : parentRelativeImagePosition.x)
        // let locationY: CGFloat = location.y - (orientation.isLandscape ? parentRelativeImagePosition.x : parentRelativeImagePosition.y)

     // OK - but now it is off in upside-down mode if i got there from landscape ...
     // let locationX: CGFloat = location.x - (orientation.isLandscape ? parentRelativeImagePosition.y : parentRelativeImagePosition.x)
     // let locationY: CGFloat = location.y - (orientation.isLandscape ? parentRelativeImagePosition.x : parentRelativeImagePosition.y)

        // TRY THIS AGAIN
        let locationX: CGFloat = location.x - (orientation.isLandscape ? parentRelativeImagePosition.y : (orientation == .portraitUpsideDown && previousOrientation.isLandscape ? parentRelativeImagePosition.y : parentRelativeImagePosition.x))
        let locationY: CGFloat = location.y - (orientation.isLandscape ? parentRelativeImagePosition.x : (orientation == .portraitUpsideDown && previousOrientation.isLandscape ? parentRelativeImagePosition.x : parentRelativeImagePosition.y))


        let x, y: CGFloat
        switch orientation {
        case .portrait:
            x = locationX
            y = locationY
            print("NORMALIZE-LOC-PO: \(location) -> \(x), \(y) | or: \(orientation.rawValue) por: \(previousOrientation.rawValue) iw: \(pixelMap.unscaled(pixelMap.displayWidth)) ih: \(pixelMap.unscaled(pixelMap.displayHeight))")
        case .portraitUpsideDown:
            if previousOrientation.isLandscape {
                x = locationY
                y = CGFloat(pixelMap.unscaled(pixelMap.displayHeight)) - 1 - locationX
            }
            else {
                x = locationX
                y = locationY
            }
            print("NORMALIZE-LOC-UD: \(location) -> \(x), \(y) | or: \(orientation.rawValue) por: \(previousOrientation.rawValue) iw: \(pixelMap.unscaled(pixelMap.displayWidth)) ih: \(pixelMap.unscaled(pixelMap.displayHeight))")
        case .landscapeRight:
            x = locationY
            y = CGFloat(pixelMap.unscaled(pixelMap.displayHeight)) - 1 - locationX
            print("NORMALIZE-LOC-LR: \(location) -> \(x), \(y) | or: \(orientation.rawValue) por: \(previousOrientation.rawValue) iw: \(pixelMap.unscaled(pixelMap.displayWidth)) ih: \(pixelMap.unscaled(pixelMap.displayHeight))")
        case .landscapeLeft:
            x = CGFloat(pixelMap.unscaled(pixelMap.displayWidth)) - 1 - locationY
            y = locationX
            print("NORMALIZE-LOC-LL: \(location) -> \(x), \(y) | or: \(orientation.rawValue) por: \(previousOrientation.rawValue) iw: \(pixelMap.unscaled(pixelMap.displayWidth)) ih: \(pixelMap.unscaled(pixelMap.displayHeight))")
        default:
            x = locationX
            y = locationY
            print("NORMALIZE-LOC-DF: \(location) -> \(x), \(y) | or: \(orientation.rawValue) por: \(previousOrientation.rawValue) iw: \(pixelMap.unscaled(pixelMap.displayWidth)) ih: \(pixelMap.unscaled(pixelMap.displayHeight))")
        }
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        GeometryReader { geometry in
            let screenSize = geometry.size
            let screenCenter = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            ZStack { // N.B. ZStack centers (horizontally/vertically) its children by default.
                if let image = image {
                    GeometryReader { geometryImage in
                    Image(decorative: image, scale: pixelMap.displayScale)
                        .background( GeometryReader { geo in Color.clear
                            .onAppear {
                                let value = geo.frame(in: .named("zstack")).origin
                                print("CONTENT-VIEW-IMAGE-BACKGROUND-ON-APPEAR: \(parentRelativeImagePosition) -> \(value)")
                                parentRelativeImagePosition = value
                            }
                            .onChange(of: parentRelativeImagePosition) { value in
                                print("CONTENT-VIEW-IMAGE-BACKGROUND-ON-CHANGE: \(parentRelativeImagePosition) -> \(value)")
                                parentRelativeImagePosition = value }
                        })
                        .frame(width: geometry.size.width, height: geometry.size.height) // do i need this or not?
                        .rotationEffect(rotationAngle(for: orientation))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let normalizedLocation = self._normalizedLocation(value.location, orientation: orientation, previousOrientation: previousOrientation)
                                    // print("CONTENT-VIEW.DRAG-ON-CHANGED: \(value.location)")
                                    print("CONTENT-VIEW.ON-CHANGE: \(value.location) -> \(normalizedLocation) geo: \(geometry.size) geoimage: \(geometryImage.size)")
                                    print("CONTENT-VIEW.ON-CHANGE-MORE: or: \(orientation.rawValue) por: \(previousOrientation.rawValue) sc: \(screenCenter) is: \(image.width)x\(image.height) ip: \(geometry.frame(in: .named("zstack")).origin) rip: \(parentRelativeImagePosition)")
                                    if draggingStart == nil {
                                        // draggingStart = value.location
                                        draggingStart = normalizedLocation
                                    }
                                    // let delta = hypot(value.location.x - draggingStart!.x, value.location.y - draggingStart!.y)
                                    let delta = hypot(normalizedLocation.x - draggingStart!.x, normalizedLocation.y - draggingStart!.y)
                                    if delta > draggingThreshold {
                                        dragging = true
                                        // pixelMap.onDrag(value.location, orientation: orientation, previousOrientation: previousOrientation)
                                        pixelMap.onDrag(normalizedLocation)
                                        refreshImage()
                                    }
                                }
                                .onEnded { value in
                                    let normalizedLocation = self._normalizedLocation(value.location, orientation: orientation, previousOrientation: previousOrientation)
                                    print("CONTENT-VIEW.ON-END: \(value.location) -> \(normalizedLocation) geo: \(geometry.size) geoimage: \(geometryImage.size)")
                                    print("CONTENT-VIEW.ON-END-MORE: or: \(orientation.rawValue) por: \(previousOrientation.rawValue) sc: \(screenCenter) is: \(image.width)x\(image.height) ip: \(geometry.frame(in: .named("zstack")).origin) rip: \(parentRelativeImagePosition)")
                                    if dragging {
                                        // pixelMap.onDragEnd(value.location, orientation: orientation, previousOrientation: previousOrientation)
                                        // pixelMap.onDragEnd(value.location)
                                        pixelMap.onDragEnd(normalizedLocation)
                                        refreshImage()
                                    } else {
                                        // let imagePositionX = (geometry.size.width - (CGFloat(image.width) / CGFloat(3.0))) / CGFloat(2.0)
                                        // let imagePositionY = (geometry.size.height - (CGFloat(image.height) / CGFloat(3.0))) / CGFloat(2.0)
                                        // print(" - IMAGE-REAL-POSITION: \(imagePositionX) , \(imagePositionY)")
                                        // let imageRelativeLocation = CGPoint(x: value.location.x - imagePositionX, y: value.location.y - imagePositionY)
                                        let imageRelativeLocation = ((orientation == .landscapeLeft) || (orientation == .landscapeRight)) ? CGPoint(x: value.location.x - parentRelativeImagePosition.y, y: value.location.y - parentRelativeImagePosition.x) : CGPoint(x: value.location.x - parentRelativeImagePosition.x, y: value.location.y - parentRelativeImagePosition.y)
                                        /*
                                        let local = mapToUpright(point: imageRelativeLocation,
                                                        center: screenCenter,
                                                        orientation: orientation,
                                                        imageSize: CGSize(width: image.width, height: image.height))
                                        */
                                        // print(" - IMAGE-RELATIVE-TAP-POINT-LOCATE: \(pixelMap.locate(local))")
                                        // print(" - IMAGE-RELATIVE-TAP-POINT-LOCATE-NEW: \(pixelMap.locate2(value.location, orientation: orientation, previousOrientation: previousOrientation))")
                                        // print(" - IMAGE-RELATIVE-TAP-POINT-LOCATE-NEW: \(pixelMap.locate2(value.location, orientation: orientation, previousOrientation: previousOrientation))")
                                        pixelMap.onTap(normalizedLocation) // xyzzy/try
                                        // let local = mapToUpright(point: value.location,
                                        //let local = mapToUpright(point: imageRelativeLocation,
                                         //                        center: screenCenter,
                                          //                       orientation: orientation,
                                           //                      imageSize: CGSize(width: image.width, height: image.height)) // imageSize)
                                        //print("CONTENT-VIEW.ON-TAP-POINT-MAPPED: \(local)")
                                        // pixelMap.onTap(value.location)
                                        // pixelMap.onTap(local)
                                        refreshImage()
                                    }
                                    draggingStart = nil
                                    dragging = false
                                }
                        )
                        /*
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 1.0)
                                .sequenced(before: DragGesture(minimumDistance: 0))
                                .onEnded { value in
                                    // print("CONTENT-VIEW.LONG-PRESS-ON-ENDED: \(value)")
                                    switch value {
                                        case .second(true, let drag):
                                            if let dragLocation = drag?.location {
                                                let normalizedLocation = self._normalizedLocation(dragLocation, orientation: orientation, previousOrientation: previousOrientation)
                                                // if pixelMap.locate(dragLocation) != nil CURLY
                                                // if pixelMap.locate2(dragLocation, orientation: orientation, previousOrientation: previousOrientation) != nil CURLY
                                                if pixelMap.locate2(normalizedLocation) != nil {
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
                        */
                        //Text("\(image.width) x \(image.height) \(orientation.rawValue) [\(previousOrientation.rawValue)]")
                         //   .fontWeight(.bold)
                          //  .foregroundColor(.yellow)
                    }
                }
            }
            .onAppear {
                // UIDevice.current.beginGeneratingDeviceOrientationNotifications()
                print("ON-APPEAR-UIScreen.main.scale = \(UIScreen.main.scale)")
                print("ON-APPEAR-UIScreen.main.bounds = \(UIScreen.main.bounds)")
                print("ON-APPEAR.geometry.size = \(geometry.size)")
                print("ON-APPEAR.screenSize = \(screenSize)")
                print("ON-APPEAR.screenCenter = \(screenCenter)")
                print("XYZZY: \(pixelMapConfigured)")
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
            // .frame(width: geometry.size.width, height: geometry.size.height)
            // .background(background.color)
            // .frame(maxWidth: .infinity, maxHeight: .infinity)
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
