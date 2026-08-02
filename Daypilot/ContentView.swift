import SwiftUI
import LocalAuthentication

struct ContentView: View {
    @AppStorage("darkModeEnabled")    private var darkModeEnabled    = true
    @AppStorage("textSizeOption")     private var textSizeOption     = "default"
    @AppStorage("tabOrder")           private var tabOrder           = "tasks,canvas,settings,profile"
    private let pomodoroPlacement = "corner"
    @AppStorage("appLockEnabled")     private var appLockEnabled     = false
    @AppStorage("selectedTheme")      private var selectedTheme      = "original"
    @AppStorage("themeMode")          private var themeMode          = "full"
    @State private var selectedTab    = "tasks"
    @State private var isLocked       = false
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var tabPill

    private var tintColor: Color {
        themeMode == "accent" ? AppThemes.find(selectedTheme).accentColor : .white
    }

    private var dynamicTypeSize: DynamicTypeSize {
        switch textSizeOption {
        case "small":  return .small
        case "large":  return .xLarge
        case "xlarge": return .xxLarge
        default:       return .large
        }
    }

    private var orderedTabIds: [String] {
        var ids = tabOrder.split(separator: ",").map(String.init)
        for id in ["tasks", "canvas", "settings", "profile"] where !ids.contains(id) {
            ids.append(id)
        }
        if pomodoroPlacement == "tab" {
            if !ids.contains("focus") { ids.append("focus") }
        } else {
            ids.removeAll { $0 == "focus" }
        }
        return ids
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(orderedTabIds, id: \.self) { id in
                tabContent(for: id)
                    .tabItem { Label(tabLabel(for: id), systemImage: tabIcon(for: id)) }
                    .tag(id)
            }
        }
        .fontDesign(.rounded)
        .dynamicTypeSize(dynamicTypeSize)
        .tint(tintColor)
        .toolbarBackground(.hidden, for: .tabBar)
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
        .overlay {
            if isLocked && appLockEnabled {
                LockScreenOverlay(theme: AppThemes.find(selectedTheme), onUnlock: authenticate)
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, appLockEnabled { isLocked = true }
            else if phase == .active, appLockEnabled, isLocked { authenticate() }
        }
    }

    private func authenticate() {
        let ctx = LAContext()
        var error: NSError?
        let policy: LAPolicy = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        ctx.evaluatePolicy(policy, localizedReason: "Unlock Daypilot") { success, _ in
            DispatchQueue.main.async { if success { isLocked = false } }
        }
    }

    @ViewBuilder
    private func tabContent(for id: String) -> some View {
        switch id {
        case "tasks":    TasksView()
        case "canvas":   CanvasView()
        case "settings": SettingsView(darkModeEnabled: $darkModeEnabled)
        case "profile":  ProfileView()
        case "focus":    PomodoroView()
        default:         EmptyView()
        }
    }

    private func tabLabel(for id: String) -> String {
        switch id {
        case "tasks":    return "Tasks"
        case "canvas":   return "Canvas"
        case "settings": return "Settings"
        case "profile":  return "Profile"
        case "focus":    return "Focus"
        default:         return id.capitalized
        }
    }

    private func tabIcon(for id: String) -> String {
        switch id {
        case "tasks":    return "checklist"
        case "canvas":   return "books.vertical"
        case "settings": return "gear"
        case "profile":  return "person.circle"
        case "focus":    return "timer"
        default:         return "circle"
        }
    }
}

private struct LockScreenOverlay: View {
    let theme: ThemeOption
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.04), theme.color1.opacity(0.6)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "metronome.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                Text("Daypilot")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                Button(action: onUnlock) {
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                        Text("Unlock")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 36).padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
