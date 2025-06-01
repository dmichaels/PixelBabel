import SwiftUI
import AudioToolbox
import CoreHaptics
import AVFoundation

struct SettingsView: View
{
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var cellGridView: CellGridView

    var body: some View {
        Form {
            Section(header: Text("PIXELS").padding(.leading, -12)) {
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DeveloperSettingsView: View {

    @EnvironmentObject var settings: Settings

    var body: some View {
        Form {
            Section(header: Text("PIXELS").padding(.leading, -12)) {
            }
        }
        .onAppear {
        }
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
    }
}
