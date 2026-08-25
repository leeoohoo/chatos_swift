import SwiftUI

@main
struct ChatOSApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("ChatOS") {
            RootView()
                .environmentObject(model)
                .environment(\.interfaceFontScale, model.interfaceFontScale)
                .font(.system(size: model.interfaceFontSize))
                .frame(minWidth: 1_100, minHeight: 720)
        }
        .defaultSize(width: 1_440, height: 900)
        .windowStyle(.titleBar)

        Settings {
            SettingsView()
                .environmentObject(model)
                .environment(\.interfaceFontScale, model.interfaceFontScale)
                .font(.system(size: model.interfaceFontSize))
                .frame(minWidth: 1_050, minHeight: 700)
        }
    }
}
