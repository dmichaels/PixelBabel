//
//  PixelBabelApp.swift
//  PixelBabel
//
//  Created by David Michaels on 4/14/25.
//

import SwiftUI
import CellGridView

@main
struct PixelBabelApp: App {
    @StateObject var pixelMap: CellGridView = LifeCellGridView()
    @StateObject var settings: Settings = LifeSettings()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pixelMap)
                .environmentObject(settings)
        }
    }
}
