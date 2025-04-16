import SwiftUI

struct ContentView: View
{
    @StateObject var pixelMap = PixelMap()
    @State var text = "xyzzy"

    private let draggingThreshold: CGFloat = 3.0
    @State private var dragging: Bool = false
    @State private var draggingStart: CGPoint? = nil

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
                text = "Screen: \(ScreenInfo.shared.width) x \(ScreenInfo.shared.height) x \(ScreenInfo.shared.scale) | \(ScreenInfo.shared.bufferSize)"
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
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
