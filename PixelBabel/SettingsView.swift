import SwiftUI
import AudioToolbox
import CoreHaptics
import AVFoundation

struct SettingsView: View
{
    @EnvironmentObject var settings: Settings

    var body: some View {
        Form {

            Section(header: Text("PIXELS").padding(.leading, -12)) {
                HStack {
                    Label("Pixel Depth", systemImage: "paintpalette")
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
                    Label("Pixel Colors", systemImage: "eyedropper")
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
                HStack {
                    Label("Pixel Shape", systemImage: "puzzlepiece.fill")
                    Picker("", selection: $settings.pixelShape) {
                        ForEach(PixelShape.allCases) { mode in
                            Text(mode.rawValue)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(settings.pixelSize < 6)
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

            Section(
                    footer: Text("Memory: \(Memory.system()) • \(Memory.app()) • \(Memory.app(percent: true)) • Buffered: \(settings.pixels.cached)").padding(.leading, -10).onTapGesture { settings.dummy = Date() }) {
                NavigationLink(destination: DeveloperSettingsView()) {
                    Label("Advanced", systemImage: "gearshape")
                }
            }

        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
                
    }
}

struct DeveloperSettingsView: View {

    @EnvironmentObject var settings: Settings
    @State private var randomFixedImagePeriodSelected: RandomFixedImagePeriod = .sometimes
    @State private var backgroundColor: Color
    @State private var initialized = false

    init() {
        _backgroundColor = State(initialValue: .clear)
    }

    var body: some View {
        Form {
            Section(header: Text("PIXELS").padding(.leading, -12)) {
                HStack {
                    Label("Pixel Margin", systemImage: /*"squareshape.squareshape.dotted"*/ "ruler")
                    Picker("", selection: $settings.pixelMargin) {
                        ForEach(Array(stride(from: 0,
                                             through: FixedSettings.pixelMarginMax, by: 1)), id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .disabled(!settings.backgroundBufferEnabled)
                }
                HStack {
                    HStack {
                        ColorCircleIcon()
                        Text("Background Color")
                            .frame(width: 162) // TODO: only need to stop wrapping; need better way.
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                        Spacer()
                    }
                    ColorPicker("", selection: $backgroundColor)
                        .onChange(of: backgroundColor) { newValue in
                            let color = UIColor(backgroundColor)
                            var red: CGFloat = 0
                            var green: CGFloat = 0
                            var blue: CGFloat = 0
                            var alpha: CGFloat = 0
                            if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
                                settings.backgroundColor = Pixel(UInt8(red * 255), UInt8(green * 255), UInt8(blue * 255))
                            }
                        }
                }
            }
            Section(header: Text("BUFFERING").padding(.leading, -12)) {
                HStack {
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
                                             through: DefaultSettings.backgroundBufferSizeMax,
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
            Section(header: Text("EXPERIMENTAL").padding(.leading, -12)) {
                HStack {
                    Label("Write Algorithm", systemImage: "compass.drawing" /*"pencil.and.outline"*/)
                        .lineLimit(1)
                        .layoutPriority(1)
                    Picker("", selection: $settings.writeAlgorithm) {
                        ForEach(WriteAlgorithm.allCases) { mode in
                            Text(mode.rawValue)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                HStack {
                    Label("Update Mode", systemImage: "highlighter")
                    Spacer()
                    Toggle("", isOn: $settings.updateMode)
                        .labelsHidden()
                }
            }
            Section(footer:
                VStack(alignment: .leading, spacing: 6) {
                    Divider() // light horizontal line
                        .padding(.top, 8)
                    Text("Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")"
                        + " • Build: #\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.top, 10)
                .padding(.leading, 4)
            ) { EmptyView() }
        }
    .onAppear {
        if (!initialized) {
            backgroundColor = settings.backgroundColor.color
            // writeAlgorithmLegacy = settings.writeAlgorithmLegacy
            initialized = true
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

struct ColorCircleIcon: View {
    var body: some View {
        Circle()
            .fill(
                AngularGradient(
                    gradient: Gradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red]),
                    center: .center
                )
            )
            .frame(width: 24, height: 24)
    }
}
