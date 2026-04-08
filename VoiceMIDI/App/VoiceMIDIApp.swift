import SwiftUI

@main
struct VoiceMIDIApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 700, minHeight: 500)
                .onAppear {
                    appState.start()
                }
                .onDisappear {
                    appState.stop()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About VoiceMIDI") {}
            }
        }
    }
}
