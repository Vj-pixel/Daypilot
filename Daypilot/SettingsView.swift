// SettingsView.swift

import SwiftUI
import SwiftData
import FirebaseAuth
import UserNotifications

struct SettingsView: View {
    @Binding var darkModeEnabled: Bool
    @EnvironmentObject private var gradientManager: SunsetGradientManager

    @AppStorage("notificationsEnabled")  private var notificationsEnabled  = true
    @AppStorage("selectedTheme")         private var selectedTheme         = "original"
    @AppStorage("themeMode")             private var themeMode             = "full"
    @AppStorage("appLockEnabled")        private var appLockEnabled        = false
    @AppStorage("progressDisplayStyle")  private var progressDisplayStyle  = "segmented"
    @AppStorage("textSizeOption")        private var textSizeOption        = "default"
    @AppStorage("tabOrder")              private var tabOrder              = "tasks,canvas,settings,profile"
    @AppStorage("pomodoroPlacement")     private var pomodoroPlacement     = "corner"

    @Environment(\.modelContext) private var modelContext
    @Query private var daypilots: [Daypilot]

    @State private var showDeleteAlert = false
    @State private var notifAuthStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Appearance
                Section(header: sectionHeader("Appearance")) {
                    NavigationLink(destination: ThemePickerView().environmentObject(gradientManager)) {
                        HStack {
                            Text("Theme")
                                .foregroundColor(.white)
                            Spacer()
                            let theme = AppThemes.find(selectedTheme)
                            HStack(spacing: -6) {
                                Circle().fill(theme.color1).frame(width: 16, height: 16)
                                if themeMode == "full" {
                                    Circle().fill(theme.color2).frame(width: 16, height: 16)
                                    Circle().fill(theme.color3).frame(width: 16, height: 16)
                                }
                            }
                            Text("\(theme.name) · \(themeMode == "accent" ? "Accent" : "Full")")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.leading, 6)
                        }
                    }

                    NavigationLink(destination: ProgressStylePickerView().environmentObject(gradientManager)) {
                        HStack {
                            Text("Progress Style")
                                .foregroundColor(.white)
                            Spacer()
                            Text(progressStyleDisplayName)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    NavigationLink(destination: TextSizePickerView().environmentObject(gradientManager)) {
                        HStack {
                            Text("Text Size")
                                .foregroundColor(.white)
                            Spacer()
                            Text(textSizeDisplayName)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    Toggle("Dark Mode", isOn: $darkModeEnabled)
                        .tint(AppThemes.find(selectedTheme).accentColor)
                        .foregroundColor(.white)
                }
                .listRowBackground(Color.white.opacity(0.10))

                // MARK: Notifications
                Section(header: sectionHeader("Notifications")) {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                        .tint(AppThemes.find(selectedTheme).accentColor)
                        .foregroundColor(.white)
                        .onChange(of: notificationsEnabled) { _, enabled in
                            if enabled {
                                UNUserNotificationCenter.current()
                                    .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                                        DispatchQueue.main.async {
                                            notificationsEnabled = granted
                                            notifAuthStatus = granted ? .authorized : .denied
                                        }
                                    }
                            } else {
                                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                            }
                        }

                    if notifAuthStatus == .denied {
                        Button {
                            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                        } label: {
                            Label("Notifications blocked — open Settings", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .listRowBackground(Color.white.opacity(0.10))
                .task {
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    notifAuthStatus = settings.authorizationStatus
                }

                // MARK: Account
                Section(header: sectionHeader("Account")) {
                    NavigationLink(destination: ChangeEmailView().environmentObject(gradientManager)) {
                        SettingsIconRow(systemImage: "envelope.fill", label: "Change Email", iconColor: .blue)
                    }
                    NavigationLink(destination: ChangePasswordView().environmentObject(gradientManager)) {
                        SettingsIconRow(systemImage: "lock.fill", label: "Change Password", iconColor: .orange)
                    }
                }
                .listRowBackground(Color.white.opacity(0.10))

                // MARK: Data
                Section(header: sectionHeader("Data")) {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Text("Delete All Tasks")
                            .foregroundColor(.red)
                    }
                }
                .listRowBackground(Color.white.opacity(0.10))

                // MARK: Feedback
                Section(header: sectionHeader("Feedback")) {
                    NavigationLink(destination: FeedbackFormView(type: .feature).environmentObject(gradientManager)) {
                        SettingsIconRow(systemImage: "lightbulb.fill", label: "Suggest a Feature", iconColor: .yellow)
                    }
                    NavigationLink(destination: FeedbackFormView(type: .bug).environmentObject(gradientManager)) {
                        SettingsIconRow(systemImage: "ladybug.fill", label: "Report a Bug", iconColor: .red)
                    }
                }
                .listRowBackground(Color.white.opacity(0.10))

                // MARK: Privacy
                Section(header: sectionHeader("Privacy")) {
                    Toggle(isOn: $appLockEnabled) {
                        SettingsIconRow(systemImage: "faceid", label: "App Lock", iconColor: .blue)
                    }
                    .tint(AppThemes.find(selectedTheme).accentColor)
                    if appLockEnabled {
                        Label("Face ID or passcode required when reopening the app.", systemImage: "lock.shield.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .listRowBackground(Color.white.opacity(0.10))

                // MARK: Advanced
                Section(header: sectionHeader("Advanced")) {
                    NavigationLink(destination: TabOrderView(tabOrder: $tabOrder).environmentObject(gradientManager)) {
                        SettingsIconRow(systemImage: "square.grid.2x2", label: "Tab Order", iconColor: .indigo)
                    }
                    Picker(selection: $pomodoroPlacement) {
                        Text("Corner button").tag("corner")
                        Text("Dedicated tab").tag("tab")
                    } label: {
                        HStack {
                            SettingsIconRow(systemImage: "timer", label: "Focus Timer", iconColor: .orange)
                            Spacer()
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white.opacity(0.7))
                }
                .listRowBackground(Color.white.opacity(0.10))
            }
            .scrollContentBackground(.hidden)
            .background {
                ZStack { gradientManager.gradient; ThemeParticleView() }
                    .ignoresSafeArea()
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle("Settings")
            .alert("Are you sure you want to delete all tasks?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) { deleteAllTasks() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var progressStyleDisplayName: String {
        progressDisplayStyle == "topBar" ? "Top Bar" : "Segmented"
    }

    private var textSizeDisplayName: String {
        switch textSizeOption {
        case "small":  return "Small"
        case "large":  return "Large"
        case "xlarge": return "X-Large"
        default:       return "Default"
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .foregroundColor(.white.opacity(0.55))
            .font(.caption.weight(.semibold))
    }

    private func deleteAllTasks() {
        for task in daypilots { modelContext.delete(task) }
        try? modelContext.save()
    }
}

// MARK: - TabOrderView

struct TabOrderView: View {
    @Binding var tabOrder: String
    @EnvironmentObject private var gradientManager: SunsetGradientManager
    @AppStorage("pomodoroPlacement") private var pomodoroPlacement = "corner"
    @State private var tabIds: [String] = []

    private let tabDefs: [String: (label: String, icon: String, color: Color)] = [
        "tasks":    ("Tasks",    "checklist",      .blue),
        "canvas":   ("Canvas",   "books.vertical", .orange),
        "settings": ("Settings", "gear",           .gray),
        "profile":  ("Profile",  "person.circle",  .purple),
        "focus":    ("Focus",    "timer",          .green),
    ]

    var body: some View {
        List {
            Section(header: Text("Drag to reorder your tabs").foregroundColor(.white.opacity(0.55)).font(.caption)) {
                ForEach(tabIds, id: \.self) { id in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(tabDefs[id]?.color ?? .gray)
                                .frame(width: 30, height: 30)
                            Image(systemName: tabDefs[id]?.icon ?? "circle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Text(tabDefs[id]?.label ?? id.capitalized)
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
                .onMove { from, to in
                    tabIds.move(fromOffsets: from, toOffset: to)
                    tabOrder = tabIds.joined(separator: ",")
                }
            }
            .listRowBackground(Color.white.opacity(0.10))
        }
        .scrollContentBackground(.hidden)
        .background { ZStack { gradientManager.gradient; ThemeParticleView() }.ignoresSafeArea() }
        .navigationTitle("Tab Order")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .environment(\.editMode, .constant(.active))
        .onAppear {
            var parsed = tabOrder.split(separator: ",").map(String.init)
            // Include focus tab in the reorder list when it's set as a dedicated tab
            if pomodoroPlacement == "tab" && !parsed.contains("focus") {
                parsed.append("focus")
                tabOrder = parsed.joined(separator: ",")
            } else if pomodoroPlacement != "tab" {
                parsed.removeAll { $0 == "focus" }
            }
            tabIds = parsed.filter { tabDefs[$0] != nil }
        }
    }
}

// MARK: - SettingsIconRow

struct SettingsIconRow: View {
    let systemImage: String
    let label: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(iconColor)
                    .frame(width: 30, height: 30)
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text(label)
                .foregroundColor(.white)
        }
    }
}

// MARK: - ChangeEmailView

struct ChangeEmailView: View {
    @EnvironmentObject private var gradientManager: SunsetGradientManager

    @State private var newEmail = ""
    @State private var currentPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""

    private var currentEmail: String { Auth.auth().currentUser?.email ?? "" }
    private var isPasswordProvider: Bool {
        Auth.auth().currentUser?.providerData.contains { $0.providerID == "password" } ?? false
    }

    var body: some View {
        Form {
            if !isPasswordProvider {
                Section {
                    Text("Email changes are managed through your sign-in provider (Google or Apple).")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.subheadline)
                }
                .listRowBackground(Color.white.opacity(0.10))
            } else {
                Section(header: formHeader("Current Email")) {
                    Text(currentEmail)
                        .foregroundColor(.white.opacity(0.6))
                }
                .listRowBackground(Color.white.opacity(0.10))

                Section(header: formHeader("New Email Address")) {
                    TextField("Enter new email", text: $newEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .foregroundColor(.white)
                }
                .listRowBackground(Color.white.opacity(0.10))

                Section(header: formHeader("Confirm Your Identity")) {
                    SecureField("Current password", text: $currentPassword)
                        .foregroundColor(.white)
                }
                .listRowBackground(Color.white.opacity(0.10))

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage).foregroundColor(.red).font(.caption)
                    }
                    .listRowBackground(Color.white.opacity(0.10))
                }
                if !successMessage.isEmpty {
                    Section {
                        Text(successMessage).foregroundColor(.green).font(.caption)
                    }
                    .listRowBackground(Color.white.opacity(0.10))
                }

                Section {
                    Button {
                        Task { await performUpdate() }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading { ProgressView().tint(.white) }
                            else { Text("Update Email").fontWeight(.semibold).foregroundColor(.white) }
                            Spacer()
                        }
                    }
                    .disabled(isLoading || newEmail.isEmpty || currentPassword.isEmpty)
                }
                .listRowBackground(Color.blue.opacity(0.35))
            }
        }
        .scrollContentBackground(.hidden)
        .background { ZStack { gradientManager.gradient; ThemeParticleView() }.ignoresSafeArea() }
        .navigationTitle("Change Email")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func formHeader(_ title: String) -> some View {
        Text(title).foregroundColor(.white.opacity(0.55)).font(.caption.weight(.semibold))
    }

    private func performUpdate() async {
        isLoading = true; errorMessage = ""; successMessage = ""
        guard let user = Auth.auth().currentUser else { isLoading = false; return }
        do {
            let credential = EmailAuthProvider.credential(withEmail: currentEmail, password: currentPassword)
            try await user.reauthenticate(with: credential)
            try await user.sendEmailVerification(beforeUpdatingEmail: newEmail)
            successMessage = "Verification link sent to \(newEmail). Your email updates after you click it."
            newEmail = ""; currentPassword = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - ChangePasswordView

struct ChangePasswordView: View {
    @EnvironmentObject private var gradientManager: SunsetGradientManager

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""

    private var currentEmail: String { Auth.auth().currentUser?.email ?? "" }
    private var isPasswordProvider: Bool {
        Auth.auth().currentUser?.providerData.contains { $0.providerID == "password" } ?? false
    }

    var body: some View {
        Form {
            if !isPasswordProvider {
                Section {
                    Text("Password changes are managed through your sign-in provider (Google or Apple).")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.subheadline)
                }
                .listRowBackground(Color.white.opacity(0.10))
            } else {
                Section(header: formHeader("Current Password")) {
                    SecureField("Enter current password", text: $currentPassword)
                        .foregroundColor(.white)
                }
                .listRowBackground(Color.white.opacity(0.10))

                Section(header: formHeader("New Password")) {
                    SecureField("New password (min 6 characters)", text: $newPassword)
                        .foregroundColor(.white)
                    SecureField("Confirm new password", text: $confirmPassword)
                        .foregroundColor(.white)
                }
                .listRowBackground(Color.white.opacity(0.10))

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage).foregroundColor(.red).font(.caption)
                    }
                    .listRowBackground(Color.white.opacity(0.10))
                }
                if !successMessage.isEmpty {
                    Section {
                        Text(successMessage).foregroundColor(.green).font(.caption)
                    }
                    .listRowBackground(Color.white.opacity(0.10))
                }

                Section {
                    Button {
                        Task { await performUpdate() }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading { ProgressView().tint(.white) }
                            else { Text("Update Password").fontWeight(.semibold).foregroundColor(.white) }
                            Spacer()
                        }
                    }
                    .disabled(isLoading || currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
                }
                .listRowBackground(Color.orange.opacity(0.35))
            }
        }
        .scrollContentBackground(.hidden)
        .background { ZStack { gradientManager.gradient; ThemeParticleView() }.ignoresSafeArea() }
        .navigationTitle("Change Password")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func formHeader(_ title: String) -> some View {
        Text(title).foregroundColor(.white.opacity(0.55)).font(.caption.weight(.semibold))
    }

    private func performUpdate() async {
        errorMessage = ""; successMessage = ""
        guard newPassword == confirmPassword else { errorMessage = "Passwords don't match."; return }
        guard newPassword.count >= 6 else { errorMessage = "Password must be at least 6 characters."; return }
        isLoading = true
        guard let user = Auth.auth().currentUser else { isLoading = false; return }
        do {
            let credential = EmailAuthProvider.credential(withEmail: currentEmail, password: currentPassword)
            try await user.reauthenticate(with: credential)
            try await user.updatePassword(to: newPassword)
            successMessage = "Password updated successfully."
            currentPassword = ""; newPassword = ""; confirmPassword = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - FeedbackFormView

struct FeedbackFormView: View {
    enum FeedbackType {
        case feature, bug
        var title: String   { self == .bug ? "Report a Bug"       : "Suggest a Feature" }
        var subject: String { self == .bug ? "Bug Report — Taskvibe" : "Feature Request — Taskvibe" }
        var placeholder: String {
            self == .bug
                ? "Describe the bug: what happened, what you expected, and steps to reproduce..."
                : "Describe your feature idea: what it does, how it works, and why it would help..."
        }
        var icon: String  { self == .bug ? "ladybug.fill"   : "lightbulb.fill" }
        var color: Color  { self == .bug ? .red             : Color(red: 1, green: 0.85, blue: 0.1) }
        var textColor: Color { self == .bug ? .white : .black }
    }

    let type: FeedbackType
    @EnvironmentObject private var gradientManager: SunsetGradientManager

    @State private var text = ""
    @State private var showCopied = false
    @State private var showMailComposer = false

    private let recipientEmail = "jawwnnnsmith091@gmail.com"
    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        ZStack {
            ZStack { gradientManager.gradient; ThemeParticleView() }.ignoresSafeArea()

            VStack(spacing: 0) {
                // Icon header
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(type.color.opacity(0.18))
                            .frame(width: 64, height: 64)
                        Image(systemName: type.icon)
                            .font(.system(size: 28))
                            .foregroundColor(type.color)
                    }
                    Text(type.title)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }
                .padding(.top, 24)
                .padding(.bottom, 20)

                // Editor
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .foregroundColor(.white)
                        .padding(12)
                        .frame(minHeight: 180)
                    if isEmpty {
                        Text(type.placeholder)
                            .foregroundColor(.white.opacity(0.3))
                            .font(.body)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal)

                HStack {
                    Spacer()
                    Text("\(text.count) chars")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.trailing)
                        .padding(.top, 4)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 10) {
                    Button(action: sendViaEmail) {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                            Text("Open in Email App")
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isEmpty ? Color.white.opacity(0.15) : type.color)
                        .foregroundColor(isEmpty ? .white.opacity(0.4) : type.textColor)
                        .cornerRadius(14)
                    }
                    .disabled(isEmpty)

                    Button {
                        UIPasteboard.general.string = text
                        withAnimation { showCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showCopied = false }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: showCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            Text(showCopied ? "Copied!" : "Copy to Clipboard")
                        }
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(isEmpty ? 0.05 : 0.10))
                        .foregroundColor(isEmpty ? .white.opacity(0.3) : .white)
                        .cornerRadius(14)
                    }
                    .disabled(isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(type.title)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showMailComposer) {
            MailComposerView(
                subject: type.subject,
                body: text,
                recipient: recipientEmail,
                isPresented: $showMailComposer
            )
        }
    }

    private func sendViaEmail() {
        if MailComposerView.canSend {
            showMailComposer = true
        } else {
            // Fallback to mailto: for third-party mail clients
            guard let subject = type.subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let body = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "mailto:\(recipientEmail)?subject=\(subject)&body=\(body)") else { return }
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Mail Composer Wrapper

import MessageUI

struct MailComposerView: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let recipient: String
    @Binding var isPresented: Bool

    static var canSend: Bool { MFMailComposeViewController.canSendMail() }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(isPresented: $isPresented) }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isPresented: Bool
        init(isPresented: Binding<Bool>) { _isPresented = isPresented }
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            isPresented = false
        }
    }
}

// MARK: - ProgressStylePickerView

struct ProgressStylePickerView: View {
    @AppStorage("progressDisplayStyle") private var progressDisplayStyle = "segmented"
    @AppStorage("selectedTheme")        private var selectedTheme        = "original"
    @EnvironmentObject private var gradientManager: SunsetGradientManager

    private let options: [(id: String, name: String, description: String)] = [
        ("segmented", "Segmented Outline", "Border divided into segments that fill with progress"),
        ("topBar",    "Top Bar",           "Thin bar along the top edge fills left to right"),
    ]

    var body: some View {
        Form {
            Section {
                ForEach(options, id: \.id) { option in
                    Button {
                        progressDisplayStyle = option.id
                    } label: {
                        HStack(spacing: 14) {
                            // Mini card preview
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.ultraThickMaterial)
                                    .frame(width: 64, height: 36)
                                if option.id == "segmented" {
                                    SegmentedOutlineProgress(
                                        progress: 50,
                                        color: AppThemes.find(selectedTheme).accentColor,
                                        cornerRadius: 8
                                    )
                                    .frame(width: 64, height: 36)
                                } else {
                                    TopBarProgress(
                                        progress: 50,
                                        color: AppThemes.find(selectedTheme).accentColor,
                                        cornerRadius: 8
                                    )
                                    .frame(width: 64, height: 36)
                                }
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(option.name)
                                    .foregroundColor(.white)
                                Text(option.description)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Spacer()
                            if progressDisplayStyle == option.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowBackground(Color.white.opacity(0.10))
        }
        .scrollContentBackground(.hidden)
        .background { ZStack { gradientManager.gradient; ThemeParticleView() }.ignoresSafeArea() }
        .navigationTitle("Progress Style")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// MARK: - TextSizePickerView

struct TextSizePickerView: View {
    @AppStorage("textSizeOption") private var textSizeOption = "default"
    @EnvironmentObject private var gradientManager: SunsetGradientManager

    private let options: [(id: String, name: String, description: String, size: CGFloat)] = [
        ("small",   "Small",   "Compact, more content visible",    13),
        ("default", "Default", "Standard system text size",        15),
        ("large",   "Large",   "Easier to read at a glance",       18),
        ("xlarge",  "X-Large", "Maximum readability",              21),
    ]

    var body: some View {
        Form {
            Section {
                ForEach(options, id: \.id) { option in
                    Button {
                        textSizeOption = option.id
                    } label: {
                        HStack(spacing: 14) {
                            Text("Aa")
                                .font(.system(size: option.size, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(option.name)
                                    .foregroundColor(.white)
                                Text(option.description)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Spacer()
                            if textSizeOption == option.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowBackground(Color.white.opacity(0.10))
        }
        .scrollContentBackground(.hidden)
        .background { ZStack { gradientManager.gradient; ThemeParticleView() }.ignoresSafeArea() }
        .navigationTitle("Text Size")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// MARK: - FontPickerView

struct FontPickerView: View {
    @AppStorage("selectedFontDesign") private var selectedFontDesign = "default"
    @EnvironmentObject private var gradientManager: SunsetGradientManager

    private let systemOptions: [(id: String, name: String)] = [
        ("default",    "System Default"),
        ("rounded",    "Rounded"),
        ("serif",      "New York"),
        ("monospaced", "Monospaced"),
    ]

    private let customOptions: [(id: String, name: String, fontName: String)] = [
        ("avenirnext",  "Avenir Next",         "AvenirNext-Regular"),
        ("georgia",     "Georgia",             "Georgia"),
        ("baskerville", "Baskerville",         "Baskerville"),
        ("didot",       "Didot",               "Didot"),
        ("typewriter",  "Typewriter",          "AmericanTypewriter"),
        ("gillsans",    "Gill Sans",           "GillSans"),
    ]

    var body: some View {
        Form {
            Section(header: Text("System Fonts").foregroundColor(.white.opacity(0.55)).font(.caption)) {
                ForEach(systemOptions, id: \.id) { option in
                    fontRow(
                        id: option.id,
                        name: option.name,
                        nameFont: Font.system(.body, design: fontDesign(for: option.id)),
                        previewFont: Font.system(.caption, design: fontDesign(for: option.id))
                    )
                }
            }
            .listRowBackground(Color.white.opacity(0.10))

            Section(header: Text("Custom Fonts").foregroundColor(.white.opacity(0.55)).font(.caption)) {
                ForEach(customOptions, id: \.id) { option in
                    fontRow(
                        id: option.id,
                        name: option.name,
                        nameFont: .custom(option.fontName, size: 17),
                        previewFont: .custom(option.fontName, size: 13)
                    )
                }
            }
            .listRowBackground(Color.white.opacity(0.10))
        }
        .scrollContentBackground(.hidden)
        .background { ZStack { gradientManager.gradient; ThemeParticleView() }.ignoresSafeArea() }
        .navigationTitle("Font Style")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func fontRow(id: String, name: String, nameFont: Font, previewFont: Font) -> some View {
        Button {
            selectedFontDesign = id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .foregroundColor(.white)
                        .font(nameFont)
                    Text("The quick brown fox jumps over the lazy dog")
                        .foregroundColor(.white.opacity(0.5))
                        .font(previewFont)
                }
                Spacer()
                if selectedFontDesign == id {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    private func fontDesign(for id: String) -> Font.Design {
        switch id {
        case "rounded":    return .rounded
        case "serif":      return .serif
        case "monospaced": return .monospaced
        default:           return .default
        }
    }
}
