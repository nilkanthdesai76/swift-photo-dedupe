import SwiftUI

@main
struct PhotoDedupeApp: App {
    var body: some Scene {
        WindowGroup("PhotoHashKit — Zero-Heat Duplicate Deduper") {
            ContentView()
                .frame(minWidth: 920, minHeight: 560)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
