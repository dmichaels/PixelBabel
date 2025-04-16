import SwiftUI

struct ContentView: View
{
    @StateObject var pixelMap = PixelMap()

    private let draggingThreshold: CGFloat = 3.0
    @State private var dragging: Bool = false
    @State private var draggingStart: CGPoint? = nil

    @State private var autoTapping = false
    @State private var autoTappingTimer: Timer?

    func autoTappingStart() {
        autoTappingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            pixelMap.onTap(CGPoint(x: 0.0, y: 0.0))
        }
    }

    func autoTappingStop() {
        autoTappingTimer?.invalidate()
        autoTappingTimer = nil
    }

    var body: some View
    {
        GeometryReader { geometry in
            ZStack {
                if let image = pixelMap.image {
                    Image(decorative: image, scale: pixelMap.displayScale)
                        .resizable()
                        .scaledToFill()
                }
            }
            .onAppear {
                ScreenInfo.shared.configure(size: geometry.size, scale: UIScreen.main.scale)
                pixelMap.configure(screen: ScreenInfo.shared)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
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
                LongPressGesture(minimumDuration: 1.0).onEnded { value in
                    autoTapping.toggle()
                    if (autoTapping) {
                        autoTappingStart()
                    }
                    else {
                        autoTappingStop()
                    }
                }
            )
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
