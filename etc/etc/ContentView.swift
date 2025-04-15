import SwiftUI

struct ContentView: View
{
    @StateObject var pixelMap = PixelMap()
    @State var text = "xyzzy"

    var body: some View {
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
            .onTapGesture {
                pixelMap.randomize()
                pixelMap.update()
            }
        }
    }
}

#Preview {
    ContentView()
}
