import SwiftUI

struct ContentView: View
{
    @StateObject var pixelMap = PixelMap()
    @State var text = "xyzzy"

    private let draggingThreshold: CGFloat = 4.0
    @State private var dragging: Bool = false
    @State private var draggingStart: CGPoint? = nil

    var body: some View
    {
        GeometryReader { geometry in
            /*
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
                Spacer()
                Text(text)
            }
            */
            ZStack {
                if let image = pixelMap.image {
                    Image(decorative: image, scale: pixelMap.displayScale)
                        .resizable()
                        .scaledToFill()
                        // .ignoresSafeArea()
                }
            }
            /*
            Canvas { context, size in
                if let image = pixelMap.image {
                    // context.draw(Image(decorative: image, scale: ScreenInfo.shared.scale), in: CGRect(origin: .zero, size: size))
                    // context.draw(Image(decorative: image, scale: ScreenInfo.shared.scale), in: CGRect(origin: .zero, size: size))
                    context.draw(Image(decorative: image, scale: 1.0), in: CGRect(origin: .zero, size: size))
                }
            }
            .ignoresSafeArea()
            */
            .onAppear {
                ScreenInfo.shared.configure(size: geometry.size, scale: UIScreen.main.scale)
                pixelMap.configure(screen: ScreenInfo.shared)
                text = "Screen: \(ScreenInfo.shared.width) x \(ScreenInfo.shared.height) x \(ScreenInfo.shared.scale) | \(ScreenInfo.shared.bufferSize)"
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if draggingStart == nil {
                            draggingStart = value.startLocation
                        }
                        let delta = hypot(value.location.x - draggingStart!.x, value.location.y - draggingStart!.y)
                        if delta > draggingThreshold {
                            dragging = true

                            // let p = pixelMap.locate(value.location)
                            // let color = PixelValue.black
                            // pixelMap.write(x: Int(p.x), y: Int(p.y), red: color.red, green: color.green, blue: color.blue)
                            // pixelMap.update()

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
            /*
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let x = Int(value.location.x)
                        let y = Int(value.location.y)
                        let p = pixelMap.locate(value.location)
                        print("DRAG-CHANGE: xy: [\(x),\(y)] -> \(p)")
                        // dragDuringUpdate(px, py)
                        let color = PixelValue.black
                        pixelMap.write(x: Int(p.x), y: Int(p.y), red: color.red, green: color.green, blue: color.blue)
                        pixelMap.update()
                    }
                    .onEnded { value in
                        print("DRAG-END: [\(Int(value.location.x)),\(Int(value.location.y))]")
                        let p = pixelMap.locate(value.location)
                        let color = PixelValue.random()
                        pixelMap.write(x: Int(p.x), y: Int(p.y), red: color.red, green: color.green, blue: color.blue)
                        pixelMap.update()
                    }
            )
            .onTapGesture {
                pixelMap.randomize()
                pixelMap.update()
            }
            */
        }
    }
}

#Preview {
    ContentView()
}
