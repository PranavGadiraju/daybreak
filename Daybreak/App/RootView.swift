import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.authorization == .approved, model.isOnboardingComplete {
                MainTabView()
            } else {
                OnboardingFlow()
            }
        }
        .animation(.default, value: model.isOnboardingComplete)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.horizon") }
            JournalView()
                .tabItem { Label("Journal", systemImage: "book.closed") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
