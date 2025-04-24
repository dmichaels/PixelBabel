//
//  PixelBabelApp.swift
//  PixelBabel
//
//  Created by David Michaels on 4/14/25.
//

import SwiftUI

@main
struct PixelBabelApp: App {
    @StateObject var pixelMap: PixelMap = PixelMap()
    @StateObject var settings: Settings = Settings()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pixelMap)
                .environmentObject(settings)
        }
    }
}
