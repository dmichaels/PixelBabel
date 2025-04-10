import SwiftUI
import AudioToolbox
import CoreHaptics
import AVFoundation

struct SettingsView: View
{
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
                    Label("RGB Selection", systemImage: "eyedropper")
                        .lineLimit(1)
                        .layoutPriority(1)
                    Picker("", selection: $settings.rgbFilter) {
                        ForEach(RGBFilterOptions.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(settings.colorMode != ColorMode.color)
                }
                VStack {
                    HStack {
                        Label("Pixel Size", systemImage: "magnifyingglass")
                        Spacer()
                        Text("\(settings.pixelSize)")
                    }
                    Slider(
                        value: Binding(
                            get: { Double(settings.pixelSize) },
                            set: { settings.pixelSize = Int($0) }
                        ),
                        in: 1...50, step: 1)
                        .padding(.top, -8)
                        .padding(.bottom, -2)
                    .onChange(of: settings.pixelSize) { newValue in
                        settings.pixelSize = newValue
                    }
                }
            }

            Section(header: Text("ANIMATION").padding(.leading, -12), footer: Text("Long press to start/stop automation.").padding(.leading, -10)) {
                HStack {
                    Label("Automation", systemImage: "play.circle")
                    Spacer()
                    Toggle("", isOn: $settings.automationEnabled)
                        .labelsHidden()
                }
                HStack {
                    Label("Automation Speed", systemImage: "sparkles")
                        .lineLimit(1)
                        .layoutPriority(1)
                    Spacer()
                    Picker("", selection: $settings.automationSpeed) {
                        ForEach(AutomationSpeedOptions, id: \.value) { option in
                            Text(option.label)
                                .tag(option.value)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .disabled(!settings.automationEnabled)
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

            Section(header: Text("ADVANCED").padding(.leading, -12),
                    footer: Text("System Memory: \(Memory.system()) • App: \(Memory.app()) • \(Memory.app(percent: true))").padding(.leading, -10)) {
                NavigationLink(destination: DeveloperSettingsView()) {
                    Label("Developer", systemImage: "gearshape")
                }
                HStack {
                    Label("Buffered", systemImage: "rectangle.stack")
                    Spacer()
                    Text("\(settings.pixels.cached)")
                }
                .onTapGesture {
                    settings.dummy = Date()
                }
            }

        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DeveloperSettingsView: View {

    @EnvironmentObject var settings: AppSettings
    @State private var randomFixedImagePeriodSelected: RandomFixedImagePeriod = .sometimes

    var body: some View {
        Form {
            Section(header: Text("BUFFERING").padding(.leading, -12)) {
                HStack {
                    // Label("Background  [\(settings.pixels.cached)]", systemImage: "arrow.triangle.2.circlepath")
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Enabled")
                            .padding(.leading, 17)
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
        .navigationTitle("Developer")
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

let RandomFixedImagePeriodOptions: [(label: String, value: Int)] = [
    ("Frequent", 5),
    ("Sometimes", 25),
    ("Seldom", 100)
]

let AutomationSpeedOptions: [(label: String, value: Double)] = [
    ("Slowest", 7.0),
    ("Slower", 3.0),
    ("Slow", 2.0),
    ("Medium", 1.0),
    ("Fast", 0.5),
    ("Faster", 0.25),
    ("Fastest", 0.1),
    ("Max", 0.0)
]
