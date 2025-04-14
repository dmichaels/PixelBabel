import SwiftUI

struct ContentView: View
{
    @EnvironmentObject var settings: Settings
    @State private var viewSize: CGSize = .zero
    @State private var _randomImage: CGImage?
    @State private var tapCount = 0
    @State private var autoTapping = false
    @State private var autoTappingTimer: Timer?
    @State private var showSettings = false

    private var _feedback: Feedback {
        return Feedback(settings) // TODO: Figure out how to make lazy evaluation so not creating every time.
    }
    
    func refreshRandomImage() {
        if let randomImage = RandomPixelGenerator.generate(width: Int(viewSize.width), height: Int(viewSize.height),
                                                           settings: settings, taps: tapCount) {
            self._randomImage = randomImage
        }
    }

    func autoTappingStart() {
        autoTappingTimer = Timer.scheduledTimer(withTimeInterval: settings.automationSpeed, repeats: true) { _ in
            refreshRandomImage()
        }
    }

    func autoTappingStop() {
        autoTappingTimer?.invalidate()
        autoTappingTimer = nil
    }


    func dragDuringUpdate(_ x: Int, _ y: Int) {
        // let filter: Pixel.FilterFunction = {pixels, index in Pixel.tintBlue(pixels: &pixels, index: index, amount: 0.4)}
        // settings.pixels.write(x: x, y: y, red: 0, green: 0, blue: 0, filter: filter)
        settings.pixels.write(x: x, y: y, red: 0, green: 0, blue: 0, filter:
        {
            pixels, index in Pixel.tintGreen(pixels: &pixels, index: index, amount: 0.2)
        })
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        var image: CGImage? = nil
        let width = Int(viewSize.width)
        let height = Int(viewSize.height)
        settings.pixels.data.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                fatalError("Buffer has no base address")
            }
            let context = CGContext(
                data: baseAddress,
                width: width, // ScreenWidth,
                height: height, // ScreenHeight,
                bitsPerComponent: 8,
                bytesPerRow:  width * ScreenDepth, // ScreenWidth * ScreenDepth,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            )
            if let cgImage = context?.makeImage() {
                image = cgImage
            } else {
                fatalError("Failed to make CGImage")
            }
        }
        print("dragDuringUpate.ok")
        if (image != nil) {
            // return image!
            print("dragDuringUpate.finish")
            self._randomImage = image
        }
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
            /*
            Text("HELLO")
                AnyView(RoundedRectangle(cornerRadius: 20).fill(Color.black))
                .frame(width: 100, height: 200)
                .padding(.leading, 100)
                .padding(.top, 100)
                let uiImage = view.asUIImage(size: CGSize(width: cellSize, height: cellSize))
            */
            ZStack { if let image = self._randomImage {
                Image(decorative: image, scale: 1.0)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .onChange(of: settings.colorMode) { _ in
                        settings.pixels.mode = settings.colorMode
                        if (!showSettings) {
                            refreshRandomImage()
                        }
                    }
                    .onChange(of: settings.rgbFilter) { _ in
                        settings.pixels.filter = settings.rgbFilter
                        if (!showSettings) {
                            refreshRandomImage()
                        }
                    }
                    .onChange(of: settings.pixelShape) { _ in
                        settings.pixels.shape = settings.pixelShape
                        if (!showSettings) {
                            refreshRandomImage()
                        }
                    }
                    .onChange(of: settings.pixelSize) { _ in
                        settings.pixels.scale = settings.pixelSize
                        if (!showSettings) {
                            refreshRandomImage()
                        }
                    }
                    .onChange(of: settings.pixelMargin) { _ in
                        settings.pixels.margin = settings.pixelMargin
                        if (!showSettings) {
                            refreshRandomImage()
                        }
                    }
                    .onChange(of: settings.backgroundColor) { _ in
                        settings.pixels.background = settings.backgroundColor
                        if (!showSettings) {
                            refreshRandomImage()
                        }
                    }
                    .onChange(of: settings.backgroundBufferEnabled) { _ in
                        settings.pixels.producer = settings.backgroundBufferEnabled
                        if (!showSettings) {
                            refreshRandomImage()
                        }
                    }
                    .onChange(of: settings.backgroundBufferSize) { _ in
                        settings.pixels.backgroundBufferSize = settings.backgroundBufferSize
                        if (!showSettings) {
                            refreshRandomImage()
                        }
                    }
                    .onChange(of: settings.writeAlgorithm) { _ in
                        settings.pixels.algorithm = settings.writeAlgorithm
                        if (!showSettings) {
                            refreshRandomImage()
                        }
                    }
                    .onChange(of: settings.automationEnabled) { _ in
                        if (!settings.automationEnabled) {
                            autoTappingStop()
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // print("DRAG-CHANGE: [\(x),\(y)] [\(px),\(py)]")
                                if (settings.updateMode) {
                                    let x = Int(value.location.x)
                                    let y = Int(value.location.y)
                                    let px = x / settings.pixels.scale
                                    let py = y / settings.pixels.scale
                                    dragDuringUpdate(px, py)
                                }
                            }
                            .onEnded { value in
                                // print("DRAG-END: [\(Int(value.location.x)),\(Int(value.location.y))]")
                                if value.translation.width < -100 { // Swipe left
                                    withAnimation {
                                        showSettings = true
                                    }
                                }
                                else if (value.translation.width > 100) { // Swipe right
                                }
                            }
                    )
                    .gesture(
                        TapGesture().onEnded {
                            if (!showSettings) {
                                tapCount += 1
                                self._feedback.trigger()
                                refreshRandomImage()
                            }
                        }
                    )
                    .gesture(
                        LongPressGesture(minimumDuration: 1.0).onEnded { value in
                            if (settings.automationEnabled) {
                                autoTapping.toggle()
                                if (autoTapping) {
                                    autoTappingStart()
                                }
                                else {
                                    autoTappingStop()
                                }
                            }
                            else if (autoTapping) {
                                autoTappingStop()
                            }
                        }
                    )
                    NavigationLink(
                        destination: SettingsView(),
                        isActive: $showSettings,
                        label: { EmptyView() }
                    )
            }
            }
            .statusBar(hidden: true)
            .navigationTitle("Home")
            .navigationBarHidden(true)
            .onAppear {
                viewSize = geometry.size
                DispatchQueue.main.async {
                    let _ = PrecomputedSwiftUIMasks.shared
                }
                refreshRandomImage()
            }
        }
        // .edgesIgnoringSafeArea(.all)    
        }
        .navigationViewStyle(.stack)
    }
}

struct RandomPixelGenerator {

    static func generate(width: Int, height: Int, settings: Settings, taps: Int = 0) -> CGImage?
    {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        var image: CGImage? = nil
        var randomFixedImage: Bool = false

        if (settings.randomFixedImage) {
            if (settings.randomFixedImagePeriod == RandomFixedImagePeriod.frequent) {
                if (taps % 4 == 1) {
                    randomFixedImage = true
                }
            }
            else if (settings.randomFixedImagePeriod == RandomFixedImagePeriod.sometimes) {
                if (taps % 8 == 1) {
                    randomFixedImage = true
                }
            }
            else if (settings.randomFixedImagePeriod == RandomFixedImagePeriod.seldom) {
                if (taps % 16 == 1) {
                    randomFixedImage = true
                }
            }
        }

        if (randomFixedImage) {
            settings.pixels.load("emilbisttram")
        }
        else {
            settings.pixels.randomize()
        }

        settings.pixels.data.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                fatalError("Buffer has no base address")
            }

            let context = CGContext(
                data: baseAddress,
                width: width, // ScreenWidth,
                height: height, // ScreenHeight,
                bitsPerComponent: 8,
                bytesPerRow:  width * ScreenDepth, // ScreenWidth * ScreenDepth,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            )
        
            if let cgImage = context?.makeImage() {
                image = cgImage
            } else {
                fatalError("Failed to make CGImage")
            }
        }
        if (image != nil) {
            return image!
        }
        return nil
    }
}

struct ContentView_Previews: PreviewProvider {
    static let settings = Settings()
    static var previews: some View {
        ContentView()
            .environmentObject(settings)
    }
}
