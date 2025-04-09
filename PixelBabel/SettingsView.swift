import SwiftUI
import AudioToolbox
import CoreHaptics
import AVFoundation

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var randomFixedImagePeriodSelected: RandomFixedImagePeriod = .sometimes

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
                    }.pickerStyle(MenuPickerStyle())
                    .onChange(of: settings.colorMode) { newValue in
                        settings.colorMode = newValue
                    }
                }
            }

            Section(header: Label("ZOOM", systemImage: "magnifyingglass").labelStyle(ReverseLabelStyle()).padding(.leading, -12)) {
                VStack {
                    Text("Pixel Size: \(Int(settings.pixelSize))")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    //Text("Pixel Size: \(Int(settings.pixelSize))")
                        //.frame(maxWidth: .infinity, alignment: .leading)
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
                HStack { Label("Background  [\(settings.pixels.cached)]", systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    Toggle("", isOn: $settings.backgroundRefresh)
                        .labelsHidden()
                }
                /*
                HStack {
                    Text("Background [\(settings.pixels.cached)]")
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading)
                    Toggle("", isOn: $settings.backgroundRefresh)
                        .labelsHidden()
                        .padding(.trailing, 30)
                }.padding(.top, 10)
                */
            }
            Section(header: Text("RANDOM IMAGE").padding(.leading, -12)) {
                HStack {
                    Text("Image")
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading)
                    Toggle("", isOn: $settings.randomFixedImage)
                        .labelsHidden()
                        .padding(.trailing, 30)
                }.padding(.top, 10)
                HStack {
                    Text("Image Period")
                        .bold()
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading)
                    Spacer()
                    Picker("", selection: $randomFixedImagePeriodSelected) {
                        ForEach(RandomFixedImagePeriod.allCases) { mode in
                            Text(mode.rawValue)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .tag(mode)
                        }
                    }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 200, alignment: .trailing)
                        .padding(.trailing)
                        .lineLimit(1)
                        .onChange(of: randomFixedImagePeriodSelected) { newMode in
                            settings.randomFixedImagePeriod = newMode
                        }
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
