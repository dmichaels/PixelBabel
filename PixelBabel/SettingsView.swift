import SwiftUI
import AudioToolbox
import CoreHaptics
import AVFoundation

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
            Form {

            Section(header: Text("PIXELS").padding(.leading, -12)) {
                HStack {
                    Label("Color Mode", systemImage: "paintpalette")
                    Picker("", selection: $settings.colorMode) {
                        ForEach(ColorMode.allCases) { mode in
                            Text(mode.rawValue)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: settings.colorMode) { newValue in
                        settings.colorMode = newValue
                    }
                }
                HStack {
                    Label("Automation", systemImage: "play.circle" /*"sparkles"*/)
                    Spacer()
                    Toggle("", isOn: $settings.automationEnabled)
                        .labelsHidden()
                }
            }

            Section(header: Label("ZOOM", systemImage: "magnifyingglass").labelStyle(ReverseLabelStyle()).padding(.leading, -12)) {
                VStack {
                    Text("Pixel Size: \(Int(settings.pixelSize))")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { Double(settings.pixelSize) },
                            set: { settings.pixelSize = Int($0) }
                        ),
                        in: 1...50, step: 1)
                        .padding(.top, -10)
                    .onChange(of: settings.pixelSize) { newValue in
                        settings.pixelSize = newValue
                    }
                }
            }

            Section(header: Text("MULTIMEDIA").padding(.leading, -12)) {
                HStack { Label("Sounds", systemImage: "speaker.wave.2")
                    Spacer()
                    Toggle("", isOn: $settings.soundEnabled)
                        .labelsHidden()
                }
                HStack { Label("Haptics", systemImage: "hand.tap")
                    Spacer()
                    Toggle("", isOn: $settings.hapticEnabled)
                }
            }

            Section(header: Text("DEVELOPER").padding(.leading, -12)) {
                NavigationLink(destination: AdvancedSettingsView()) {
                    Label("Advanced", systemImage: "gearshape")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AdvancedSettingsView: View {

    @EnvironmentObject var settings: AppSettings
    @State private var randomFixedImagePeriodSelected: RandomFixedImagePeriod = .sometimes

    var body: some View {
        Form {
            Section(header: Text("PROCESSING").padding(.leading, -12)) {
                HStack {
                    // Label("Background  [\(settings.pixels.cached)]", systemImage: "arrow.triangle.2.circlepath")
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Background")
                            .padding(.leading, 10)
                        Text("  (\(settings.pixels.cached))")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .baselineOffset(-2)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.backgroundBufferEnabled)
                        .labelsHidden()
                }
                HStack {
                    Label("Buffer Size", systemImage: "rectangle.stack")
                    Picker("", selection: $settings.backgroundBufferSize) {
                        ForEach(Array(stride(from: 0,
                                             through: DefaultAppSettings.backgroundBufferSizeMax,
                                             by: 10)), id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .disabled(!settings.backgroundBufferEnabled)
                }
            }
            Section(header: Text("RANDOM IMAGE").padding(.leading, -12)) {
                HStack { Label("Enabled", systemImage: "photo")
                    Spacer()
                    Toggle("", isOn: $settings.randomFixedImage)
                        .labelsHidden()
                }
                HStack {
                    Label("Frequency", systemImage: "repeat")
                    Picker("", selection: $randomFixedImagePeriodSelected) {
                        ForEach(RandomFixedImagePeriod.allCases) { mode in
                            Text(mode.rawValue)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .tag(mode)
                        }
                    }   .pickerStyle(MenuPickerStyle())
                        .onChange(of: randomFixedImagePeriodSelected) { newMode in
                            settings.randomFixedImagePeriod = newMode
                        }
                        .disabled(!settings.randomFixedImage)
                }
            }
        }
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ReverseLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon
        }
    }
}
