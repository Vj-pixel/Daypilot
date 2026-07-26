import SwiftUI
import SwiftData

struct WeeklyReviewView: View {
    @Query private var allTasks: [Daypilot]
    @AppStorage("selectedTheme") private var selectedTheme = "original"
    @Environment(\.dismiss) private var dismiss

    private var theme: ThemeOption { AppThemes.find(selectedTheme) }

    private var weekInterval: DateInterval {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return DateInterval(start: start, duration: 7 * 86400)
    }

    private var completedThisWeek: [Daypilot] {
        allTasks.filter { $0.isCompleted && $0.parent == nil &&
            weekInterval.contains($0.completedAt ?? $0.createdAt) }
    }

    private var habitsCompletedThisWeek: [Daypilot] {
        allTasks.filter { task in
            guard task.type == .habit, let last = task.lastCompletedDate else { return false }
            return weekInterval.contains(last)
        }
    }

    private var tasksByDay: [(String, Int)] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        var counts = [Int: Int]()
        for task in completedThisWeek {
            let weekday = cal.component(.weekday, from: task.completedAt ?? task.createdAt)
            counts[weekday, default: 0] += 1
        }
        for habit in habitsCompletedThisWeek {
            if let last = habit.lastCompletedDate {
                let weekday = cal.component(.weekday, from: last)
                counts[weekday, default: 0] += 1
            }
        }
        return (1...7).compactMap { wd -> (String, Int)? in
            guard let date = cal.date(from: DateComponents(weekday: wd)) else { return nil }
            return (formatter.string(from: date), counts[wd] ?? 0)
        }
    }

    private var bestDay: String {
        tasksByDay.max(by: { $0.1 < $1.1 })?.0 ?? "—"
    }

    private var topStreak: Daypilot? {
        allTasks.filter { $0.type == .habit && $0.streakCount > 0 }
            .max(by: { $0.streakCount < $1.streakCount })
    }

    private var focusSecondsThisWeek: TimeInterval {
        allTasks
            .flatMap { $0.focusSessions }
            .filter { $0.sessionLabel == "Focus" && weekInterval.contains($0.startedAt) }
            .map(\.duration)
            .reduce(0, +)
    }

    private var focusTimeLabel: String {
        let minutes = Int(focusSecondsThisWeek) / 60
        guard minutes > 0 else { return "0m" }
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private var maxBarValue: Int {
        max(tasksByDay.map(\.1).max() ?? 1, 1)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(white: 0.04), theme.color1.opacity(0.4)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // Stat cards
                        HStack(spacing: 12) {
                            statCard(value: "\(completedThisWeek.count)", label: "Tasks Done", icon: "checkmark.circle.fill", color: .green)
                            statCard(value: "\(habitsCompletedThisWeek.count)", label: "Habits Hit", icon: "flame.fill", color: .orange)
                        }

                        HStack(spacing: 12) {
                            statCard(value: focusTimeLabel, label: "Focus Time", icon: "brain.head.profile", color: .purple)
                            statCard(value: bestDay, label: "Best Day", icon: "star.fill", color: theme.accentColor)
                        }

                        if let top = topStreak {
                            statCard(value: "\(top.streakCount)d streak", label: top.title, icon: "bolt.fill", color: .yellow)
                        }

                        // Daily bar chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Activity This Week")
                                .font(.headline).foregroundColor(.white)
                            HStack(alignment: .bottom, spacing: 8) {
                                ForEach(tasksByDay, id: \.0) { day, count in
                                    VStack(spacing: 4) {
                                        if count > 0 {
                                            Text("\(count)")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(count > 0 ? theme.accentColor : Color.white.opacity(0.1))
                                            .frame(height: max(8, CGFloat(count) / CGFloat(maxBarValue) * 100))
                                        Text(day)
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(height: 130, alignment: .bottom)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Completed task list
                        if !completedThisWeek.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Completed This Week")
                                    .font(.headline).foregroundColor(.white)
                                ForEach(completedThisWeek.prefix(10)
                                    .sorted { $0.createdAt > $1.createdAt }) { task in
                                    HStack(spacing: 10) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green.opacity(0.7))
                                        Text((task.taskEmoji.map { $0 + " " } ?? "") + task.title)
                                            .font(.callout).foregroundColor(.white).lineLimit(1)
                                        Spacer()
                                        if let tag = task.userTag {
                                            Text(tag).font(.caption2)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(theme.accentColor.opacity(0.2))
                                                .clipShape(Capsule())
                                                .foregroundColor(theme.accentColor)
                                        }
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Color.white.opacity(0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }

                        if completedThisWeek.isEmpty && habitsCompletedThisWeek.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.system(size: 44)).foregroundColor(.white.opacity(0.2))
                                Text("Nothing completed yet this week.\nTime to get started!")
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white.opacity(0.4))
                                    .font(.subheadline)
                            }
                            .padding(.top, 40)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Weekly Review")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(theme.accentColor)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(color).font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.title2.weight(.bold)).foregroundColor(.white)
                Text(label).font(.caption).foregroundColor(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
