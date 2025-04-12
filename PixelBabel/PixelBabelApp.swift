import SwiftUI

@main
struct PixelBabelApp: App {
    @State private var useGrayscale = false
    @StateObject private var settings = Settings()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
        }
    }
}
