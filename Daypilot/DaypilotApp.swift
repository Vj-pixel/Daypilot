//
//  DaypilotApp.swift
//

import SwiftUI
import SwiftData
import UserNotifications
import FirebaseCore
import FirebaseAppCheck
import GoogleSignIn

// MARK: - AppAttestProviderFactory
class AppAttestProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        return AppAttestProvider(app: app)
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        
        // Configure Firebase
        FirebaseApp.configure()

        // App Check Provider
        let providerFactory = AppAttestProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)

        // Register UserDefaults defaults so HabitScheduler reads correct values
        // before the user ever opens Settings.
        UserDefaults.standard.register(defaults: [
            "notificationsEnabled": true,
            "darkModeEnabled": true
        ])

        return true
    }
}

// MARK: - Main App
@main
struct DaypilotApp: App {
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @StateObject private var gradientManager = SunsetGradientManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            RootView(
                isAuthenticated: $isAuthenticated,
                hasSeenOnboarding: $hasSeenOnboarding,
                gradientManager: gradientManager
            )
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
        .modelContainer(for: [Daypilot.self, FocusSession.self])
    }

    init() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                print(granted ? "✅ Notification permission granted"
                              : "❌ Notification permission denied")
            }
    }
}

// MARK: - Root View (handles onboarding → auth → app flow)
struct RootView: View {
    @Binding var isAuthenticated: Bool
    @Binding var hasSeenOnboarding: Bool
    @ObservedObject var gradientManager: SunsetGradientManager
    @AppStorage("selectedTheme") private var selectedTheme = "original"

    var body: some View {
        Group {
            if isAuthenticated {
                ContentView()
                    .environmentObject(gradientManager)
            } else if hasSeenOnboarding {
                AuthFlowView {
                    isAuthenticated = true
                }
            } else {
                OnboardingView {
                    hasSeenOnboarding = true
                }
            }
        }
        .tint(AppThemes.find(selectedTheme).accentColor)
        .animation(.easeInOut(duration: 0.4), value: isAuthenticated)
        .animation(.easeInOut(duration: 0.4), value: hasSeenOnboarding)
    }
}

// MARK: - Models
enum UrgencyLevel: String, Codable, CaseIterable {
    case urgent = "Urgent"
    case kindaUrgent = "Kinda Urgent"
    case notUrgent = "Not Urgent"
}

enum TaskStatus: String, CaseIterable, Codable {
    case open = "Open"
    case inProgress = "In Progress"
    case blocked = "Blocked"
    case completed = "Completed"
}

enum TaskType: String, Codable, CaseIterable {
    case task = "Task"
    case habit = "Habit"
    case application = "Application"
}

enum ApplicationStage: String, CaseIterable {
    case found      = "Found"
    case researching = "Researching"
    case inProgress = "In Progress"
    case applied    = "Applied"
    case decision   = "Decision"
}

enum HabitFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case everyOtherDay = "Every Other Day"
    case weekly = "Weekly"
}

@Model
class Daypilot: Identifiable {
    var uuid: UUID = UUID()

    var title: String = ""
    var dueDate: Date?
    var urgencyRaw: String = UrgencyLevel.notUrgent.rawValue
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var notes: String? = nil
    var reminderTime: Date? = nil
    @Relationship(deleteRule: .cascade) var subtasks: [Daypilot] = []
    var parent: Daypilot? = nil
    
    var statusRaw: String = TaskStatus.open.rawValue
    var progress: Int = 0
    
    // Task or Habit
    var typeRaw: String = TaskType.task.rawValue
    var habitFrequencyRaw: String = HabitFrequency.daily.rawValue

    // Habit streak tracking (auto-migrated by SwiftData — both have safe defaults)
    var streakCount: Int = 0
    var lastCompletedDate: Date? = nil

    // Streak freeze inventory and protection state
    var freezeCount: Int = 0
    var streakFreezeActive: Bool = false

    // Source label for imported tasks (e.g., "Canvas", "Calendar")
    var sourceTag: String? = nil

    // User-defined category tag (e.g., "Work", "Health", "Personal")
    var userTag: String? = nil

    // Emoji or image customization
    var taskEmoji: String? = nil
    var attachmentImagePath: String? = nil   // filename relative to Documents dir

    // Completion timestamp (nil for habits, which reset daily via lastCompletedDate)
    var completedAt: Date? = nil

    // Application pipeline stage (used when type == .application)
    var applicationStage: String? = nil

    // Logged Pomodoro focus sessions for this task
    @Relationship(deleteRule: .cascade) var focusSessions: [FocusSession] = []

    var attachmentImage: UIImage? {
        guard let path = attachmentImagePath else { return nil }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(path)
        return UIImage(contentsOfFile: url.path)
    }
    
    // Computed properties
    var urgency: UrgencyLevel {
        get { UrgencyLevel(rawValue: urgencyRaw) ?? .notUrgent }
        set { urgencyRaw = newValue.rawValue }
    }

    var type: TaskType {
        get { TaskType(rawValue: typeRaw) ?? .task }
        set { typeRaw = newValue.rawValue }
    }
    
    var habitFrequency: HabitFrequency {
        get { HabitFrequency(rawValue: habitFrequencyRaw) ?? .daily }
        set { habitFrequencyRaw = newValue.rawValue }
    }
    
    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }

    var stage: ApplicationStage {
        get { ApplicationStage(rawValue: applicationStage ?? "") ?? .found }
        set { applicationStage = newValue.rawValue }
    }

    // Initializer
    init(
        title: String,
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        urgency: UrgencyLevel,
        status: TaskStatus = .open,
        progress: Int = 0,
        type: TaskType = .task,
        habitFrequency: HabitFrequency = .daily,
        streakCount: Int = 0,
        lastCompletedDate: Date? = nil
    ) {
        self.title = title
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.urgencyRaw = urgency.rawValue
        self.statusRaw = status.rawValue
        self.progress = progress
        self.typeRaw = type.rawValue
        self.habitFrequencyRaw = habitFrequency.rawValue
        self.streakCount = streakCount
        self.lastCompletedDate = lastCompletedDate
    }
}

// MARK: - Focus Session

@Model
class FocusSession {
    var uuid: UUID = UUID()
    var startedAt: Date = Date()
    var duration: TimeInterval = 0
    var sessionLabel: String = "Focus"

    init(startedAt: Date = Date(), duration: TimeInterval, sessionLabel: String = "Focus") {
        self.startedAt = startedAt
        self.duration = duration
        self.sessionLabel = sessionLabel
    }
}

