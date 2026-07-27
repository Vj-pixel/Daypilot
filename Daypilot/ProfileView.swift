import SwiftUI
import FirebaseAuth
import PhotosUI
import SwiftData
import GoogleSignIn
import AuthenticationServices
import CryptoKit

// MARK: - Contribution Graph

struct ContributionGraphView: View {
    let daypilots: [Daypilot]
    private let weeks = 18
    private let cellSize: CGFloat = 13
    private let gap: CGFloat = 3
    private let calendar = Calendar.current

    @State private var tooltipDate: Date? = nil

    private var activityByDay: [Date: Int] {
        var dict: [Date: Int] = [:]
        for task in daypilots where task.isCompleted && task.type == .task {
            guard let date = task.completedAt ?? task.dueDate else { continue }
            dict[calendar.startOfDay(for: date), default: 0] += 1
        }
        for habit in daypilots where habit.type == .habit {
            guard let last = habit.lastCompletedDate else { continue }
            dict[calendar.startOfDay(for: last), default: 0] += 1
        }
        return dict
    }

    private var gridColumns: [[Date]] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let currentWeekStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: today)!
        return (0..<weeks).map { weekOffset in
            let start = calendar.date(byAdding: .weekOfYear, value: weekOffset - (weeks - 1), to: currentWeekStart)!
            return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: start)! }
        }
    }

    private func cellColor(for date: Date) -> Color {
        let count = activityByDay[date] ?? 0
        let isFuture = date > calendar.startOfDay(for: Date())
        if isFuture { return Color.white.opacity(0.05) }
        switch count {
        case 0:    return Color.white.opacity(0.09)
        case 1:    return Color.blue.opacity(0.4)
        case 2, 3: return Color.blue.opacity(0.72)
        default:   return Color.blue
        }
    }

    private var monthLabels: [(String, CGFloat)] {
        var labels: [(String, CGFloat)] = []
        var lastMonth = -1
        for (col, week) in gridColumns.enumerated() {
            let month = calendar.component(.month, from: week[0])
            if month != lastMonth {
                let x = CGFloat(col) * (cellSize + gap)
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM"
                labels.append((formatter.string(from: week[0]), x))
                lastMonth = month
            }
        }
        return labels
    }

    private func tooltipText(for date: Date) -> String {
        let count = activityByDay[date] ?? 0
        let dateStr = date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let countStr = count == 0 ? "Nothing done" : count == 1 ? "1 completion" : "\(count) completions"
        return "\(dateStr) · \(countStr)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Tooltip (shown above month labels when a cell is selected)
            if let date = tooltipDate {
                Text(tooltipText(for: date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.18))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 1))
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }

            ZStack(alignment: .topLeading) {
                ForEach(monthLabels, id: \.1) { label, x in
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                        .offset(x: x)
                }
            }
            .frame(height: 14)

            HStack(alignment: .top, spacing: gap) {
                ForEach(0..<gridColumns.count, id: \.self) { col in
                    VStack(spacing: gap) {
                        ForEach(0..<7, id: \.self) { row in
                            let date = gridColumns[col][row]
                            let isSelected = tooltipDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(cellColor(for: date))
                                .frame(width: cellSize, height: cellSize)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2.5)
                                        .stroke(Color.white.opacity(isSelected ? 0.7 : 0), lineWidth: 1.5)
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        tooltipDate = (tooltipDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false)
                                            ? nil : date
                                    }
                                }
                        }
                    }
                }
            }
            .onTapGesture {} // absorb taps on the grid container without dismissing

            HStack {
                Text("Less")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.35))
                ForEach([0, 1, 2, 4], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(level == 0 ? Color.white.opacity(0.09) : Color.blue.opacity(Double(level) * 0.25))
                        .frame(width: 10, height: 10)
                }
                Text("More")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.top, 2)
        }
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @AppStorage("isAuthenticated") private var isAuthenticated = true
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedTheme") private var selectedTheme = "original"

    @Query private var daypilotsUnsorted: [Daypilot]
    private var daypilots: [Daypilot] {
        daypilotsUnsorted.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    @State private var displayName = ""
    @State private var email = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var totalTodos: Int = 0
    @State private var totalCompleted: Int = 0
    @State private var profileImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploadingImage = false
    @State private var showDeleteAccountAlert = false
    @State private var showReauthSheet = false
    @State private var authProvider = ""
    @State private var showTaskHistory = false
    @State private var showWeeklyReview = false

    private var theme: ThemeOption { AppThemes.find(selectedTheme) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.04), theme.color1.opacity(0.55)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                    statsRow
                        .padding(.top, 28)
                    activitySection
                        .padding(.top, 28)
                    streakSection
                        .padding(.top, 20)
                    rankSection
                        .padding(.top, 20)
                    accountSection
                        .padding(.top, 32)
                        .padding(.bottom, 48)
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear(perform: loadUser)
        .onChange(of: daypilots) { _, _ in updateTaskStats() }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { showReauthSheet = true }
        } message: {
            Text("This cannot be undone. All your tasks and data will be permanently deleted.")
        }
        .sheet(isPresented: $showReauthSheet) {
            ReauthenticationSheet(
                email: email,
                authProvider: authProvider,
                onSuccess: deleteAccount,
                onCancel: { showReauthSheet = false }
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let image = profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 90, height: 90)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 42, height: 42)
                                    .foregroundColor(.white.opacity(0.6))
                            )
                    }
                }
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1.5))
                .overlay {
                    if isUploadingImage {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .overlay(ProgressView().progressViewStyle(.circular).tint(.white))
                    }
                }

                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    ZStack {
                        Circle().fill(theme.color1).frame(width: 26, height: 26)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(isUploadingImage)
                .offset(x: 2, y: 2)
            }
            .frame(width: 90, height: 90)
            .onChange(of: selectedItem) { _, newItem in
                if let newItem { Task { await uploadProfileImage(from: newItem) } }
            }
            .padding(.top, 24)

            VStack(spacing: 4) {
                Text(displayName.isEmpty ? "Your Name" : displayName)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                Text(email.isEmpty ? "" : email)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statPill(value: totalTodos, label: "Tasks")
            Divider().frame(height: 32).background(Color.white.opacity(0.12))
            statPill(value: totalCompleted, label: "Completed")
            Divider().frame(height: 32).background(Color.white.opacity(0.12))
            statPill(value: bestHabitStreak, label: "Best Streak")
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func statPill(value: Int, label: String) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Activity Graph

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Activity", icon: "chart.bar.fill")
            ContributionGraphView(daypilots: daypilots)
                .padding(16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    // MARK: - Streaks

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Streaks", icon: "flame.fill")
            HStack(spacing: 12) {
                streakCard(icon: "flame.fill", color: .orange, value: currentTaskStreak, label: "Task streak")
                streakCard(icon: "bolt.fill", color: .yellow, value: bestHabitStreak, label: "Best habit")
            }
        }
    }

    private func streakCard(icon: String, color: Color, value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
            Text("\(value)")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Rank

    private var rankSection: some View {
        let completed = totalCompleted
        let tier = RankSystem.rank(for: completed)
        return VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Rank", icon: "trophy.fill")
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: tier.icon)
                        .font(.system(size: 28))
                        .foregroundColor(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tier.name)
                            .font(.title3.weight(.bold))
                            .foregroundColor(.white)
                        if let nextAt = tier.nextAt {
                            Text("\(nextAt - completed) tasks to next rank")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        } else {
                            Text("Max rank achieved!")
                                .font(.caption)
                                .foregroundColor(.yellow.opacity(0.8))
                        }
                    }
                }
                if let nextAt = tier.nextAt {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: geo.size.width * tier.progress(for: completed), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { showTaskHistory = true } label: {
                    HStack {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        Text("History")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                .sheet(isPresented: $showTaskHistory) { TaskHistoryView() }

                Button { showWeeklyReview = true } label: {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                        Text("Review")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                .sheet(isPresented: $showWeeklyReview) { WeeklyReviewView() }
            }

            Button(action: signOut) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }

            Button(action: { showDeleteAccountAlert = true }) {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Delete Account")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.red.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.red.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.2), lineWidth: 1))
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white.opacity(0.55))
    }

    private var currentTaskStreak: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let completedDays = Set(
            daypilots
                .filter { $0.isCompleted && $0.dueDate != nil && $0.type == .task }
                .map { cal.startOfDay(for: $0.dueDate!) }
        )
        var streak = 0
        var check = today
        while completedDays.contains(check) {
            streak += 1
            check = cal.date(byAdding: .day, value: -1, to: check)!
        }
        return streak
    }

    private var bestHabitStreak: Int {
        daypilots.filter { $0.type == .habit }.map(\.streakCount).max() ?? 0
    }

    // MARK: - Data Methods

    private func loadUser() {
        if let user = Auth.auth().currentUser {
            displayName = user.displayName ?? ""
            email = user.email ?? ""
            authProvider = user.providerData.first?.providerID ?? ""
            if let photoURL = user.photoURL { loadProfileImage(from: photoURL) }
            UserDefaults.standard.set(displayName, forKey: "cachedDisplayName")
        }
        updateTaskStats()
    }

    private func localProfileURL(for userId: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile_\(userId).jpg")
    }

    private func loadProfileImage(from remoteURL: URL) {
        Task {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            let local = localProfileURL(for: userId)
            if let data = try? Data(contentsOf: local), let img = UIImage(data: data) {
                await MainActor.run { self.profileImage = img }
                return
            }
            if let (data, _) = try? await URLSession.shared.data(from: remoteURL),
               let image = UIImage(data: data) {
                await MainActor.run { self.profileImage = image }
                try? data.write(to: local)
            }
        }
    }

    private func uploadProfileImage(from item: PhotosPickerItem) async {
        isUploadingImage = true
        defer { Task { @MainActor in isUploadingImage = false } }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let compressed = image.jpegData(compressionQuality: 0.7) else {
            await MainActor.run {
                alertMessage = "Couldn't load the selected photo. Try again."
                showAlert = true
            }
            return
        }

        await MainActor.run { self.profileImage = image }

        guard let userId = Auth.auth().currentUser?.uid else { return }
        try? compressed.write(to: localProfileURL(for: userId))
    }

    private func updateTaskStats() {
        totalTodos = daypilots.count
        totalCompleted = daypilots.filter { $0.isCompleted }.count
    }

    private func signOut() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        Task {
            do {
                for task in daypilots { modelContext.delete(task) }
                try? modelContext.save()
                try? FileManager.default.removeItem(at: localProfileURL(for: user.uid))
                try await user.delete()
                await MainActor.run { isAuthenticated = false }
            } catch let error as NSError {
                await MainActor.run {
                    if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                        showReauthSheet = true
                    } else {
                        alertMessage = "Failed to delete account: \(error.localizedDescription)"
                        showAlert = true
                    }
                }
            }
        }
    }
}

// MARK: - StatView (kept for compatibility)

struct StatView: View {
    var title: String
    var value: Int?
    var body: some View {
        VStack {
            Text(title).font(.caption).foregroundColor(.white.opacity(0.6))
            Text(value == nil ? "—" : "\(value!)").font(.title3.bold()).foregroundColor(.white)
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: Daypilot.self, inMemory: true)
}

// MARK: - ReauthenticationSheet

// Keeps Apple reauth delegate alive for the duration of the sheet.
private final class AppleReauthCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    let currentNonce: String
    let onSuccess: () -> Void
    let onError: (String) -> Void

    init(nonce: String, onSuccess: @escaping () -> Void, onError: @escaping (String) -> Void) {
        self.currentNonce = nonce
        self.onSuccess = onSuccess
        self.onError = onError
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = cred.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            onError("Failed to retrieve Apple ID token."); return
        }
        let firebaseCred = OAuthProvider.credential(providerID: .apple,
                                                     idToken: idToken,
                                                     rawNonce: currentNonce)
        Auth.auth().currentUser?.reauthenticate(with: firebaseCred) { _, error in
            if let error { self.onError(error.localizedDescription) }
            else { self.onSuccess() }
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        let e = error as NSError
        guard e.code != ASAuthorizationError.canceled.rawValue else { return }
        onError(error.localizedDescription)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }
}

struct ReauthenticationSheet: View {
    let email: String
    let authProvider: String
    var onSuccess: () -> Void
    var onCancel: () -> Void

    @State private var password = ""
    @State private var isAuthenticating = false
    @State private var errorMessage = ""
    @State private var appleCoordinator: AppleReauthCoordinator?
    @Environment(\.dismiss) private var dismiss

    var isPasswordProvider: Bool { authProvider == "password" }
    var providerName: String {
        switch authProvider {
        case "google.com": return "Google"
        case "apple.com":  return "Apple"
        default:           return "your provider"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    Text("Confirm Your Identity")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text(isPasswordProvider
                         ? "Enter your password to delete your account"
                         : "Sign in with \(providerName) to confirm account deletion")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Email").font(.caption).foregroundColor(.white.opacity(0.6))
                    Text(email)
                        .font(.body).foregroundColor(.white)
                        .padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)))

                    if isPasswordProvider {
                        Text("Password").font(.caption).foregroundColor(.white.opacity(0.6)).padding(.top, 8)
                        SecureField("Enter your password", text: $password)
                            .foregroundColor(.white).padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.5), lineWidth: 1.5))
                            )
                    }
                }
                .padding(.horizontal)

                if !errorMessage.isEmpty {
                    Text(errorMessage).font(.caption).foregroundColor(.red).padding(.horizontal)
                }

                VStack(spacing: 12) {
                    Button(action: reauthenticateAndDelete) {
                        if isAuthenticating {
                            ProgressView().progressViewStyle(.circular).tint(.white)
                                .frame(maxWidth: .infinity).frame(height: 20)
                        } else {
                            Text(isPasswordProvider ? "Delete My Account" : "Sign in with \(providerName)")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.red).foregroundColor(.white).cornerRadius(12)
                    .disabled((isPasswordProvider && password.isEmpty) || isAuthenticating)
                    .opacity((isPasswordProvider && password.isEmpty) ? 0.6 : 1.0)

                    Button { dismiss(); onCancel() } label: {
                        Text("Cancel").fontWeight(.semibold)
                            .frame(maxWidth: .infinity).padding().foregroundColor(.white)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.2)))
                    }
                }
                .padding(.horizontal)
                Spacer()
            }
            .background(
                LinearGradient(colors: [Color.black, Color.blue.opacity(0.8)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func reauthenticateAndDelete() {
        errorMessage = ""
        isAuthenticating = true
        if isPasswordProvider {
            guard let user = Auth.auth().currentUser else { isAuthenticating = false; return }
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            user.reauthenticate(with: credential) { _, error in
                isAuthenticating = false
                if let error { errorMessage = error.localizedDescription } else { dismiss(); onSuccess() }
            }
        } else if authProvider == "google.com" {
            reauthWithGoogle()
        } else if authProvider == "apple.com" {
            reauthWithApple()
        } else {
            isAuthenticating = false
            errorMessage = "Re-authentication is not supported for this sign-in method."
        }
    }

    private func reauthWithGoogle() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { isAuthenticating = false; return }

        GIDSignIn.sharedInstance.signIn(withPresenting: root) { result, error in
            isAuthenticating = false
            if let error { errorMessage = error.localizedDescription; return }
            guard let user = result?.user, let idToken = user.idToken?.tokenString else {
                errorMessage = "Google sign-in failed — missing token."; return
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                            accessToken: user.accessToken.tokenString)
            Auth.auth().currentUser?.reauthenticate(with: credential) { _, error in
                if let error { errorMessage = error.localizedDescription }
                else { dismiss(); onSuccess() }
            }
        }
    }

    private func reauthWithApple() {
        let nonce = randomNonceString()
        let coordinator = AppleReauthCoordinator(
            nonce: nonce,
            onSuccess: { dismiss(); onSuccess() },
            onError: { msg in isAuthenticating = false; errorMessage = msg }
        )
        appleCoordinator = coordinator

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = []
        request.nonce = sha256(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = coordinator
        controller.presentationContextProvider = coordinator
        controller.performRequests()
    }
}
