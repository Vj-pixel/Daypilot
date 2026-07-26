// PomodoroView.swift

import SwiftUI
import AudioToolbox
import ActivityKit

struct PomodoroView: View {
    var linkedTask: Daypilot? = nil

    @AppStorage("pomodoroFocusMinutes")      private var focusMinutes      = 25
    @AppStorage("pomodoroShortBreakMinutes") private var shortBreakMinutes = 5
    @AppStorage("pomodoroLongBreakMinutes")  private var longBreakMinutes  = 15
    @AppStorage("selectedTheme")             private var selectedTheme     = "original"

    @State private var totalSeconds: Int = 25 * 60
    @State private var secondsLeft: Int  = 25 * 60
    @State private var isRunning         = false
    @State private var sessionLabel      = "Focus"
    @State private var showSettings      = false
    @State private var liveActivity: Activity<PomodoroActivityAttributes>? = nil
    @State private var sessionStartTime: Date? = nil

    @Environment(\.modelContext) private var modelContext

    private var theme: ThemeOption { AppThemes.find(selectedTheme) }

    private var presets: [(label: String, minutes: Int)] {
        [("Focus", focusMinutes), ("Short Break", shortBreakMinutes), ("Long Break", longBreakMinutes)]
    }

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(colors: [theme.color1, theme.color2, theme.color3],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                // Header
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("Focus Timer")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                        if let task = linkedTask {
                            Text(task.title)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.75))
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Button { showSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                }

                // Preset chips
                HStack(spacing: 10) {
                    ForEach(presets, id: \.label) { preset in
                        Button {
                            guard !isRunning else { return }
                            switchTo(preset)
                        } label: {
                            Text(preset.label)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(sessionLabel == preset.label ? .black : .white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(sessionLabel == preset.label ? Color.white : Color.white.opacity(0.18))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isRunning)
                    }
                }

                // Countdown ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 12)
                        .frame(width: 180, height: 180)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)

                    VStack(spacing: 2) {
                        Text(timeString)
                            .font(.system(size: 44, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text(sessionLabel.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(2)
                    }
                }

                // Controls
                HStack(spacing: 32) {
                    Button {
                        secondsLeft = totalSeconds
                        isRunning = false
                        sessionStartTime = nil
                        endLiveActivity()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 52, height: 52)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        isRunning.toggle()
                        if isRunning {
                            if sessionStartTime == nil { sessionStartTime = Date() }
                            startLiveActivity()
                        } else {
                            pauseLiveActivity()
                        }
                    } label: {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(theme.color1)
                            .frame(width: 64, height: 64)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        let idx = presets.firstIndex(where: { $0.label == sessionLabel }) ?? 0
                        switchTo(presets[(idx + 1) % presets.count])
                        isRunning = false
                        endLiveActivity()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 52, height: 52)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 32)
        }
        .onReceive(ticker) { _ in
            guard isRunning, secondsLeft > 0 else {
                if isRunning && secondsLeft == 0 { handleTimerEnd() }
                return
            }
            secondsLeft -= 1
            updateLiveActivity()
        }
        .sheet(isPresented: $showSettings) {
            timerSettingsSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: focusMinutes) { _, val in
            guard !isRunning, sessionLabel == "Focus" else { return }
            totalSeconds = val * 60
            secondsLeft  = val * 60
        }
        .onChange(of: shortBreakMinutes) { _, val in
            guard !isRunning, sessionLabel == "Short Break" else { return }
            totalSeconds = val * 60
            secondsLeft  = val * 60
        }
        .onChange(of: longBreakMinutes) { _, val in
            guard !isRunning, sessionLabel == "Long Break" else { return }
            totalSeconds = val * 60
            secondsLeft  = val * 60
        }
    }

    // MARK: - Timer Settings Sheet

    private var timerSettingsSheet: some View {
        ZStack {
            LinearGradient(colors: [theme.color1, theme.color2, theme.color3],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Timer Durations")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.top, 28)

                VStack(spacing: 16) {
                    timerRow(label: "Focus", icon: "brain.head.profile", minutes: $focusMinutes, range: 1...90)
                    timerRow(label: "Short Break", icon: "cup.and.saucer.fill", minutes: $shortBreakMinutes, range: 1...30)
                    timerRow(label: "Long Break", icon: "moon.fill", minutes: $longBreakMinutes, range: 1...60)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }

    private func timerRow(label: String, icon: String, minutes: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundColor(.white)
                .font(.subheadline.weight(.medium))
            Spacer()
            Stepper("\(minutes.wrappedValue) min", value: minutes, in: range)
                .foregroundColor(.white)
                .labelsHidden()
            Text("\(minutes.wrappedValue) min")
                .foregroundColor(.white.opacity(0.85))
                .font(.subheadline.weight(.semibold))
                .frame(width: 54, alignment: .trailing)
        }
        .padding(14)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(secondsLeft) / Double(totalSeconds)
    }

    private var timeString: String {
        String(format: "%02d:%02d", secondsLeft / 60, secondsLeft % 60)
    }

    private func switchTo(_ preset: (label: String, minutes: Int)) {
        sessionLabel  = preset.label
        totalSeconds  = preset.minutes * 60
        secondsLeft   = preset.minutes * 60
    }

    private func handleTimerEnd() {
        if sessionLabel == "Focus", let task = linkedTask {
            let session = FocusSession(
                startedAt: sessionStartTime ?? Date().addingTimeInterval(-TimeInterval(totalSeconds)),
                duration: TimeInterval(totalSeconds),
                sessionLabel: "Focus"
            )
            task.focusSessions.append(session)
            modelContext.insert(session)
            try? modelContext.save()
        }
        sessionStartTime = nil
        isRunning = false
        AudioServicesPlaySystemSound(1005)
        HapticEngine.notification(.success)
        endLiveActivity()
        let idx  = presets.firstIndex(where: { $0.label == sessionLabel }) ?? 0
        switchTo(presets[(idx + 1) % presets.count])
    }

    // MARK: - Live Activity

    private func startLiveActivity() {
        guard #available(iOS 16.2, *) else { return }
        let info = ActivityAuthorizationInfo()
        guard info.areActivitiesEnabled else { return }
        endLiveActivity()
        let attrs = PomodoroActivityAttributes(taskTitle: linkedTask?.title ?? "")
        let state = PomodoroActivityAttributes.ContentState(
            secondsLeft: secondsLeft,
            totalSeconds: totalSeconds,
            sessionLabel: sessionLabel,
            isRunning: true
        )
        liveActivity = try? Activity.request(attributes: attrs, contentState: state, pushType: nil)
    }

    private func pauseLiveActivity() {
        guard #available(iOS 16.2, *) else { return }
        let state = PomodoroActivityAttributes.ContentState(
            secondsLeft: secondsLeft,
            totalSeconds: totalSeconds,
            sessionLabel: sessionLabel,
            isRunning: false
        )
        Task { await liveActivity?.update(using: state) }
    }

    private func updateLiveActivity() {
        guard #available(iOS 16.2, *) else { return }
        let state = PomodoroActivityAttributes.ContentState(
            secondsLeft: secondsLeft,
            totalSeconds: totalSeconds,
            sessionLabel: sessionLabel,
            isRunning: isRunning
        )
        Task { await liveActivity?.update(using: state) }
    }

    private func endLiveActivity() {
        guard #available(iOS 16.2, *) else { return }
        Task { await liveActivity?.end(dismissalPolicy: .immediate) }
        liveActivity = nil
    }
}
