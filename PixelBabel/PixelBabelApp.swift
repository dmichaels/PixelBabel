//
//  PixelBabelApp.swift
//  PixelBabel
//
//  Created by David Michaels on 4/14/25.
//

import SwiftUI

@main
struct PixelBabelApp: App {
    static let cellFactory = LifeCell.factory()
    // @StateObject var pixelMap: CellGrid = CellGrid(cellFactory: cellFactory)
    @StateObject var pixelMap: CellGrid = LifeCellGrid(cellFactory: cellFactory)
    @StateObject var settings: Settings = Settings()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pixelMap)
                .environmentObject(settings)
        }
    }
}
