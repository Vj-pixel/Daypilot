// TasksView.swift

import SwiftUI
import UIKit
import SwiftData
import UserNotifications
import UniformTypeIdentifiers
import AudioToolbox
import PhotosUI
import WidgetKit

// MARK: - Haptic Engine

struct HapticEngine {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

// MARK: - Typing Text

struct TypingText: View {
    let fullText: String
    var speed: Double = 0.032

    @State private var displayed = ""
    @State private var charIndex = 0

    var body: some View {
        Text(displayed)
            .onAppear { restart() }
            .onChange(of: fullText) { restart() }
    }

    private func restart() {
        displayed = ""
        charIndex = 0
        scheduleNext()
    }

    private func scheduleNext() {
        guard charIndex < fullText.count else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + speed) {
            let idx = fullText.index(fullText.startIndex, offsetBy: charIndex)
            displayed.append(fullText[idx])
            charIndex += 1
            scheduleNext()
        }
    }
}

// MARK: - Glass TextField Style

extension View {
    func glassFieldStyle(cornerRadius: CGFloat = 12) -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}

// MARK: - Tag Color Store

struct TagColorStore {
    static let palette: [(key: String, color: Color)] = [
        ("red",    .red),
        ("orange", .orange),
        ("yellow", .yellow),
        ("green",  Color(red: 0.2, green: 0.75, blue: 0.3)),
        ("blue",   .blue),
        ("purple", .purple),
        ("pink",   Color(red: 0.9, green: 0.3, blue: 0.5)),
        ("gray",   Color.white.opacity(0.35))
    ]

    static func color(for tag: String) -> Color {
        guard let data = UserDefaults.standard.data(forKey: "tagColors"),
              let dict = try? JSONDecoder().decode([String: String].self, from: data),
              let key = dict[tag],
              let entry = palette.first(where: { $0.key == key }) else {
            return Color.white.opacity(0.22)
        }
        return entry.color
    }

    static func set(_ colorKey: String, for tag: String) {
        var dict = all()
        dict[tag] = colorKey
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: "tagColors")
        }
    }

    static func all() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: "tagColors"),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return dict
    }
}

// MARK: - Search Scope

enum SearchScope: String, CaseIterable {
    case all = "All"
    case today = "Today"
    case thisWeek = "This Week"
    case byTag = "By Tag"
}

// MARK: - StatusRing (progress arc only — icon moved to corner badge)

struct StatusRing: View {
    let progress: Int
    let color: Color
    let onTap: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.25), lineWidth: 5)
            Circle()
                .trim(from: 0, to: CGFloat(progress) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
        .frame(width: 38, height: 38)
        .contentShape(Circle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Status Corner Badge (tiny icon, top-right of card, tasks only)

struct StatusCornerBadge: View {
    let status: TaskStatus
    let color: Color

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(4)
            .background(Circle().fill(.ultraThinMaterial))
    }

    private var iconName: String {
        switch status {
        case .open:       return "minus"
        case .inProgress: return "clock.fill"
        case .blocked:    return "xmark.circle.fill"
        case .completed:  return "checkmark.circle.fill"
        }
    }
}

// MARK: - Progress Overlay Views

struct SegmentedOutlineProgress: View {
    let progress: Int
    let color: Color
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, r = cornerRadius
            let perimeter = 2 * (w - 2*r) + 2 * (h - 2*r) + 2 * .pi * r
            let slotLen  = perimeter / 16
            let dashLen  = slotLen * 0.72
            let gapLen   = slotLen * 0.28
            ZStack {
                RoundedRectangle(cornerRadius: r)
                    .stroke(Color.white.opacity(0.15),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round,
                                              dash: [dashLen, gapLen]))
                RoundedRectangle(cornerRadius: r)
                    .trim(from: 0, to: CGFloat(max(0, min(100, progress))) / 100)
                    .stroke(color,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round,
                                              dash: [dashLen, gapLen]))
                    .animation(.easeInOut(duration: 0.35), value: progress)
            }
        }
    }
}

struct TopBarProgress: View {
    let progress: Int
    let color: Color
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 4)
                Rectangle()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(max(0, min(100, progress))) / 100,
                           height: 4)
                    .animation(.easeInOut(duration: 0.35), value: progress)
            }
        }
        .frame(height: 4)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: cornerRadius, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: cornerRadius
            )
        )
    }
}

// MARK: - Future Habit Stripes (diagonal hatch pattern for locked habits)

struct FutureHabitStripes: View {
    var body: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = 13
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                ctx.stroke(path, with: .color(.gray.opacity(0.22)), lineWidth: 1.5)
                x += spacing
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Habit Fire Effect

struct HabitFlameEffect: View {
    var body: some View {
        ZStack {
            // Deep ember wash — red-hot at base, clears upward
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.10, blue: 0.0).opacity(0.70),
                    Color(red: 1.0, green: 0.38, blue: 0.0).opacity(0.36),
                    Color(red: 1.0, green: 0.58, blue: 0.0).opacity(0.14),
                    Color.clear
                ],
                startPoint: .bottom, endPoint: .top
            )

            // 30-fps triangular flame field
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSinceReferenceDate

                    // Back layer — large slow triangular orange/red flames
                    for i in 0 ..< 30 {
                        let fi = Double(i)
                        let speed = 0.34 + (fi.truncatingRemainder(dividingBy: 5)) * 0.10
                        let phase = (t * speed + fi * 0.141).truncatingRemainder(dividingBy: 1.0)
                        let baseX = size.width * (fi / 29.0)
                        let lean = CGFloat(sin(t * 1.9 + fi * 1.27)) * 14
                        let riseMax = size.height * CGFloat(0.62 + (fi.truncatingRemainder(dividingBy: 7)) * 0.054)
                        let cy = size.height - CGFloat(phase) * riseMax
                        let cx = min(max(baseX, 4), size.width - 4)
                        let h = CGFloat((1 - phase) * 30 + 8)
                        let w = h * 0.52
                        let alpha = (phase < 0.20 ? phase / 0.20 : (1 - phase)) * 0.82
                        let hue = 0.016 + phase * 0.072

                        // Triangular flame: pointed tip, curved sides, round base
                        var flame = Path()
                        flame.move(to: CGPoint(x: cx + lean * 0.35, y: cy - h))
                        flame.addQuadCurve(to: CGPoint(x: cx + w * 0.50, y: cy),
                                           control: CGPoint(x: cx + w * 0.68 + lean * 0.2, y: cy - h * 0.20))
                        flame.addQuadCurve(to: CGPoint(x: cx - w * 0.50, y: cy),
                                           control: CGPoint(x: cx, y: cy + h * 0.07))
                        flame.addQuadCurve(to: CGPoint(x: cx + lean * 0.35, y: cy - h),
                                           control: CGPoint(x: cx - w * 0.68 + lean * 0.2, y: cy - h * 0.20))
                        flame.closeSubpath()

                        ctx.opacity = alpha
                        ctx.fill(flame, with: .color(Color(hue: hue, saturation: 1.0, brightness: 1.0)))
                    }

                    // Front layer — small fast yellow-white triangular cores
                    for i in 0 ..< 18 {
                        let fi = Double(i)
                        let phase = (t * 0.95 + fi * 0.197).truncatingRemainder(dividingBy: 1.0)
                        let baseX = size.width * (fi / 17.0)
                        let lean = CGFloat(sin(t * 4.6 + fi * 2.4)) * 6
                        let riseMax = size.height * 0.38
                        let cy = size.height - CGFloat(phase) * riseMax
                        let cx = min(max(baseX, 4), size.width - 4)
                        let h = CGFloat((1 - phase) * 13 + 3)
                        let w = h * 0.48

                        var core = Path()
                        core.move(to: CGPoint(x: cx + lean * 0.2, y: cy - h))
                        core.addQuadCurve(to: CGPoint(x: cx + w * 0.5, y: cy),
                                          control: CGPoint(x: cx + w * 0.62, y: cy - h * 0.18))
                        core.addQuadCurve(to: CGPoint(x: cx - w * 0.5, y: cy),
                                          control: CGPoint(x: cx, y: cy + h * 0.06))
                        core.addQuadCurve(to: CGPoint(x: cx + lean * 0.2, y: cy - h),
                                          control: CGPoint(x: cx - w * 0.62, y: cy - h * 0.18))
                        core.closeSubpath()

                        ctx.opacity = (1 - phase) * 0.95
                        ctx.fill(core, with: .color(Color(hue: 0.122, saturation: 0.38, brightness: 1.0)))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Streak Fire Badge (static, post-animation)

struct StreakFireBadge: View {
    let count: Int

    private let cols = 3
    private let maxDots = 9

    private var displayCount: Int { min(count, maxDots) }
    private var overflow: Int    { max(0, count - maxDots) }
    private var rows: Int        { max(1, (displayCount + cols - 1) / cols) }

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            ForEach(0 ..< rows, id: \.self) { row in
                HStack(spacing: 1) {
                    let start = row * cols
                    let end   = min(start + cols, displayCount)
                    ForEach(start ..< end, id: \.self) { _ in
                        Text("🔥").font(.system(size: 14))
                    }
                }
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.trailing, 1)
            }
        }
        .padding(5)
        .background(Color.black.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

// MARK: - Habit Ice Effect

struct HabitIceEffect: View {
    @State private var shimmer = false

    var body: some View {
        ZStack {
            // Frosted ice fill — blue-white, semi-opaque (you can still read the card)
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.60, green: 0.91, blue: 1.00).opacity(0.50),
                        Color(red: 0.84, green: 0.97, blue: 1.00).opacity(0.24),
                        Color(red: 0.55, green: 0.88, blue: 1.00).opacity(0.46)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))

            // Crystal facets, ice cracks, and specular highlights
            Canvas { ctx, size in

                // ── Crystalline facets (sin-seeded, fully deterministic) ──
                for i in 0 ..< 60 {
                    let fi = Double(i)
                    let cx = (sin(fi * 1.713 + 0.419) * 0.5 + 0.5) * Double(size.width)
                    let cy = (sin(fi * 2.317 + 1.173) * 0.5 + 0.5) * Double(size.height)
                    let radius = 7.0 + (sin(fi * 3.731) * 0.5 + 0.5) * 14.0
                    let sides = 4 + Int((sin(fi * 5.129) * 0.5 + 0.5) * 4)
                    let isLight = sin(fi * 4.371) > 0

                    var path = Path()
                    for s in 0 ..< sides {
                        let angle = Double(s) / Double(sides) * .pi * 2 + fi * 0.443
                        let r = radius * (0.60 + (sin(fi * 2.871 + Double(s)) * 0.5 + 0.5) * 0.40)
                        let px = cx + cos(angle) * r
                        let py = cy + sin(angle) * r
                        if s == 0 { path.move(to: CGPoint(x: px, y: py)) }
                        else      { path.addLine(to: CGPoint(x: px, y: py)) }
                    }
                    path.closeSubpath()
                    ctx.opacity = 0.05 + (sin(fi * 3.113) * 0.5 + 0.5) * 0.10
                    ctx.fill(path, with: .color(isLight ? .white : Color(red: 0.5, green: 0.9, blue: 1.0)))
                }

                // ── Ice cracks ────────────────────────────────────────────
                let cracks: [[(Double, Double)]] = [
                    [(0.11, 0.07), (0.25, 0.22), (0.39, 0.16), (0.53, 0.34)],
                    [(0.70, 0.05), (0.62, 0.20), (0.76, 0.33), (0.68, 0.49)],
                    [(0.04, 0.56), (0.20, 0.48), (0.36, 0.65), (0.50, 0.57)],
                    [(0.79, 0.52), (0.91, 0.67), (0.76, 0.80), (0.88, 0.93)],
                    [(0.42, 0.71), (0.56, 0.61), (0.67, 0.78), (0.83, 0.88)],
                    [(0.47, 0.10), (0.42, 0.26), (0.58, 0.21)],
                    [(0.18, 0.82), (0.30, 0.91), (0.23, 0.96)],
                    [(0.60, 0.40), (0.72, 0.50), (0.68, 0.60)],
                ]
                for crack in cracks {
                    var path = Path()
                    for (idx, pt) in crack.enumerated() {
                        let p = CGPoint(x: pt.0 * Double(size.width), y: pt.1 * Double(size.height))
                        if idx == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    }
                    ctx.opacity = 0.38
                    ctx.stroke(path, with: .color(.white),
                               style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
                }

                // ── Specular highlights (bright spots simulating refraction) ──
                for i in 0 ..< 12 {
                    let fi = Double(i)
                    let hx = (sin(fi * 2.173 + 0.531) * 0.5 + 0.5) * Double(size.width)
                    let hy = (sin(fi * 1.971 + 1.837) * 0.5 + 0.5) * Double(size.height)
                    let hr = 3.0 + (sin(fi * 3.413) * 0.5 + 0.5) * 10.0
                    ctx.opacity = 0.22
                    ctx.fill(Path(ellipseIn: CGRect(x: hx - hr / 2, y: hy - hr / 2,
                                                    width: hr, height: hr)),
                             with: .color(.white))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Outer ice-block border — thick (7 pt), white-cyan gradient, shimmers
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.93),
                            Color(red: 0.50, green: 0.88, blue: 1.00).opacity(0.85),
                            Color.white.opacity(0.70),
                            Color(red: 0.30, green: 0.75, blue: 1.00).opacity(0.92),
                            Color.white.opacity(0.82)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 7
                )
                .opacity(shimmer ? 1.0 : 0.62)

            // Inner ring — creates the illusion of a thick ice wall
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.white.opacity(shimmer ? 0.50 : 0.20), lineWidth: 2)
                .padding(6)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Action Hint View (unified, replaces four separate backgrounds)

struct ActionHintView: View {
    let icon: String
    let label: String
    let tint: Color
    let isTriggered: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [tint, tint.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .scaleEffect(isTriggered ? 1.10 : 0.84)
                .opacity(isTriggered ? 1.0 : 0.78)
                .animation(.spring(response: 0.22, dampingFraction: 0.65), value: isTriggered)
            )
    }
}

// MARK: - Task Content View

struct TaskContentView: View {
    let task: Daypilot
    let dragOffset: CGSize
    let isCrumpled: Bool
    let isDragging: Bool
    let showingAction: Bool
    let onStatusChange: (TaskStatus) -> Void
    /// When viewing a habit on a specific calendar date, pass that date so we
    /// show the occurrence date rather than the habit's original start date.
    var occurrenceDate: Date? = nil
    var isFutureHabit: Bool = false

    @AppStorage("selectedTheme")       private var selectedTheme       = "original"
    @AppStorage("progressDisplayStyle") private var progressDisplayStyle = "segmented"
    @Environment(\.modelContext) private var modelContext
    @State private var isExpanded = false
    @State private var animatedFireActive: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Emoji overrides the status ring when set
                if let emoji = task.taskEmoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.system(size: 30))
                        .frame(width: 38, height: 38)
                } else if task.type == .task {
                    StatusRing(progress: task.progress, color: ringColor) {
                        let all = TaskStatus.allCases
                        let idx = all.firstIndex(of: task.status) ?? 0
                        onStatusChange(all[(idx + 1) % all.count])
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(task.title)
                            .font(.headline)
                        sourceTagBadge
                        userTagBadge
                    }

                    let displayDate = (task.type == .habit ? occurrenceDate : nil) ?? task.dueDate
                    if let due = displayDate {
                        Text("Due: \(due.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    if task.type == .habit {
                        let doneToday = HabitScheduler.isDoneToday(task)
                        HStack(spacing: 6) {
                            Text(task.habitFrequency.rawValue)
                                .font(.caption2)
                                .foregroundColor(.blue)
                            if task.streakCount > 0 {
                                Text("🔥 \(task.streakCount) day streak")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                        if task.streakFreezeActive {
                            Text("🧊 Streak frozen")
                                .font(.caption2)
                                .foregroundColor(.cyan)
                        } else if task.freezeCount > 0 {
                            Text("🧊 ×\(task.freezeCount)")
                                .font(.caption2)
                                .foregroundColor(.cyan.opacity(0.85))
                        }
                        if doneToday {
                            Text("✓ Done for today")
                                .font(.caption2)
                                .foregroundColor(.green.opacity(0.85))
                        }
                        if isFutureHabit {
                            Text("Available tomorrow")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }

                    Text(task.urgency.rawValue)
                        .font(.caption2)
                        .foregroundColor(.primary.opacity(0.6))

                    if !task.subtasks.isEmpty {
                        let done = task.subtasks.filter(\.isCompleted).count
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
                                Text("\(done)/\(task.subtasks.count) subtask\(task.subtasks.count == 1 ? "" : "s")")
                                    .font(.caption2)
                                if done == task.subtasks.count {
                                    Image(systemName: "checkmark").font(.caption2)
                                }
                            }
                            .foregroundColor(done == task.subtasks.count ? .green.opacity(0.75) : .white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }

                    // Attachment image thumbnail
                    if let img = task.attachmentImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.top, 2)
                    }
                }

                Spacer()
            }
            .padding(16)

            if isExpanded && !task.subtasks.isEmpty {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 12)

                VStack(spacing: 2) {
                    ForEach(task.subtasks.sorted { !$0.isCompleted && $1.isCompleted }) { sub in
                        HStack(spacing: 10) {
                            Button {
                                sub.isCompleted.toggle()
                                updateProgressFromSubtasks()
                                try? modelContext.save()
                                HapticEngine.impact(.light)
                            } label: {
                                Image(systemName: sub.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(sub.isCompleted ? .green.opacity(0.8) : .white.opacity(0.35))
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)

                            Text(sub.title)
                                .font(.subheadline)
                                .foregroundColor(sub.isCompleted ? .white.opacity(0.35) : .white)
                                .strikethrough(sub.isCompleted, color: .white.opacity(0.3))

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.22), .white.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                if isFutureHabit {
                    FutureHabitStripes()
                }
            }
        )
        .overlay(alignment: .top) {
            if task.type == .task && progressDisplayStyle == "topBar" {
                TopBarProgress(progress: task.progress, color: ringColor, cornerRadius: 12)
                    .padding(.horizontal, 5)
                    .padding(.top, 4)
            }
        }
        .overlay(
            ZStack(alignment: .topTrailing) {
                if task.type == .habit {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(effectiveRingColor, lineWidth: 3)
                } else if progressDisplayStyle == "segmented" {
                    SegmentedOutlineProgress(progress: task.progress, color: ringColor, cornerRadius: 12)
                        .padding(4)
                }
                if task.type == .task {
                    StatusCornerBadge(status: task.status, color: ringColor)
                        .padding(6)
                }
                // Static streak badge — shown once animated fire settles
                if isOnFire && !animatedFireActive {
                    StreakFireBadge(count: task.streakCount)
                        .padding(6)
                }
            }
        )
        .overlay {
            if isOnFire && animatedFireActive {
                HabitFlameEffect()
            } else if isFrozen {
                HabitIceEffect()
            }
        }
        .shadow(
            color: isOnFire && animatedFireActive ? .red.opacity(0.72) : isFrozen ? .cyan.opacity(0.75) : .black.opacity(0.10),
            radius: isOnFire && animatedFireActive ? 26 : isFrozen ? 26 : 10,
            x: 0, y: (isOnFire && animatedFireActive) || isFrozen ? 0 : 5
        )
        .shadow(
            color: isOnFire && animatedFireActive ? .orange.opacity(0.48) : isFrozen ? Color(red: 0.6, green: 0.9, blue: 1.0).opacity(0.48) : .white.opacity(0.10),
            radius: (isOnFire && animatedFireActive) || isFrozen ? 11 : 1,
            x: 0, y: (isOnFire && animatedFireActive) || isFrozen ? 0 : 1
        )
        .scaleEffect(taskScale)
        .rotationEffect(.degrees(taskRotation))
        .opacity(showingAction ? 0.3 : cardOpacity)
        .offset(dragOffset)
        .onAppear {
            guard task.type == .habit, isOnFire, let last = task.lastCompletedDate else { return }
            let elapsed = Date().timeIntervalSince(last)
            guard elapsed < 4 else { return }
            animatedFireActive = true
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0.1, 4 - elapsed)) {
                withAnimation(.easeOut(duration: 1.5)) { animatedFireActive = false }
            }
        }
        .onChange(of: task.lastCompletedDate) { _, newDate in
            guard task.type == .habit, let newDate else { return }
            guard Date().timeIntervalSince(newDate) < 5 else { return }
            withAnimation { animatedFireActive = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeOut(duration: 1.5)) { animatedFireActive = false }
            }
        }
    }

    private var ringColor: Color { AppThemes.find(selectedTheme).urgencyColor(for: task.urgency) }

    private var effectiveRingColor: Color {
        guard task.type == .habit else { return ringColor }
        if isFrozen { return .cyan }
        if isOnFire { return .orange }
        return ringColor
    }

    private var isOnFire: Bool {
        task.type == .habit && task.streakCount >= 1 && !task.streakFreezeActive
    }

    private var isFrozen: Bool {
        task.type == .habit && task.streakFreezeActive
    }

    private func updateProgressFromSubtasks() {
        let total = task.subtasks.count
        guard total > 0 else { return }
        let done = task.subtasks.filter(\.isCompleted).count
        let raw = Int((Double(done) / Double(total)) * 100)
        task.progress = [0, 25, 50, 75, 100].min(by: { abs($0 - raw) < abs($1 - raw) }) ?? raw
    }

    @ViewBuilder
    private var userTagBadge: some View {
        if let tag = task.userTag, !tag.isEmpty {
            Text(tag)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(TagColorStore.color(for: tag))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var sourceTagBadge: some View {
        if let tag = task.sourceTag, !tag.isEmpty {
            let color: Color = tag == "Canvas" ? Color(red: 0.88, green: 0.28, blue: 0.08)
                             : tag == "Calendar" ? .green : .blue
            Text(tag)
                .font(.caption2.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color)
                .clipShape(Capsule())
        }
    }

    private var taskScale: CGFloat {
        isDragging ? 0.97 : 1.0
    }

    private var taskRotation: Double { 0 }

    private var cardOpacity: Double {
        if isFutureHabit { return 0.55 }
        if isOnFire || isFrozen { return 1.0 }
        return task.type == .habit && HabitScheduler.isDoneToday(task) ? 0.45 : 1.0
    }
}


// MARK: - Draggable Task View

struct DraggableTaskView: View {
    let task: Daypilot
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onComplete: () -> Void
    let onStatusChange: (TaskStatus) -> Void
    var occurrenceDate: Date? = nil
    var isFutureHabit: Bool = false

    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @State private var readyToDelete = false
    @State private var readyToComplete = false
    @State private var readyToEdit = false
    @State private var readyToShare = false
    @State private var showFutureHabitAlert = false
    @State private var isBeingDeleted = false

    // Raised thresholds prevent accidental triggers on short swipes.
    // Diagonal conflicts are resolved by checking horizontal before vertical.
    private let deleteThreshold: CGFloat  = -130
    private let completeThreshold: CGFloat =  130
    private let editThreshold: CGFloat    = -95
    private let shareThreshold: CGFloat   =  95

    var body: some View {
        ZStack(alignment: .leading) {
            // Action hint revealed as the card slides
            activeHint

            TaskContentView(
                task: task,
                dragOffset: dragOffset,
                isCrumpled: false,
                isDragging: isDragging,
                showingAction: anyActionReady,
                onStatusChange: onStatusChange,
                occurrenceDate: occurrenceDate,
                isFutureHabit: isFutureHabit
            )
            .scaleEffect(isBeingDeleted ? 0.75 : 1.0)
            .opacity(isBeingDeleted ? 0.0 : 1.0)
            .animation(.easeIn(duration: 0.28), value: isBeingDeleted)
            .animation(.interactiveSpring(response: 0.30, dampingFraction: 0.80), value: dragOffset)
            .gesture(createDragGesture())
            .contextMenu {
                if !isFutureHabit {
                    Button("Edit") { onEdit() }
                    Button("Complete") { onComplete() }
                    Button("Delete", role: .destructive) { onDelete() }
                    Button { presentShareSheet() } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }

            if isFutureHabit {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(minWidth: 350, maxWidth: 350, minHeight: 100)
                    .onTapGesture { showFutureHabitAlert = true }
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
        .alert("Not Yet!", isPresented: $showFutureHabitAlert) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("This habit isn't available yet. Check back next time!")
        }
        .onChange(of: readyToDelete)   { _, v in if v { HapticEngine.impact(.rigid) } }
        .onChange(of: readyToComplete) { _, v in if v { HapticEngine.impact(.medium) } }
        .onChange(of: readyToEdit)     { _, v in if v { HapticEngine.impact(.light) } }
        .onChange(of: readyToShare)    { _, v in if v { HapticEngine.impact(.soft) } }
    }

    private var anyActionReady: Bool {
        readyToDelete || readyToComplete || readyToEdit || readyToShare
    }

    @ViewBuilder
    private var activeHint: some View {
        if readyToDelete {
            ActionHintView(icon: "trash.fill", label: "Delete", tint: .red, isTriggered: readyToDelete)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else if readyToComplete {
            ActionHintView(icon: "checkmark.circle.fill", label: "Complete", tint: .green, isTriggered: readyToComplete)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else if readyToEdit {
            ActionHintView(icon: "pencil.circle.fill", label: "Edit", tint: .blue, isTriggered: readyToEdit)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else if readyToShare {
            ActionHintView(icon: "square.and.arrow.up.fill", label: "Share", tint: .purple, isTriggered: readyToShare)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    // MARK: - Gesture

    private func createDragGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in handleDragChanged(value) }
            .onEnded { value in handleDragEnded(value) }
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        guard !isFutureHabit else {
            showFutureHabitAlert = true
            return
        }
        // Only allow horizontal OR vertical drag to prevent diagonal conflicts
        let tx = value.translation.width
        let ty = value.translation.height
        let isHorizontal = abs(tx) >= abs(ty)

        // Stiffer resistance past threshold (0.2 factor instead of 0.3)
        var t = CGSize.zero
        if isHorizontal {
            t.width = tx < deleteThreshold
                ? deleteThreshold   + (tx - deleteThreshold)   * 0.2
                : tx > completeThreshold
                    ? completeThreshold + (tx - completeThreshold) * 0.2
                    : tx
        } else {
            t.height = ty < editThreshold
                ? editThreshold  + (ty - editThreshold)  * 0.2
                : ty > shareThreshold
                    ? shareThreshold + (ty - shareThreshold) * 0.2
                    : ty
        }

        dragOffset = t
        isDragging = true

        withAnimation(.easeOut(duration: 0.12)) {
            readyToDelete   = isHorizontal && tx < deleteThreshold
            readyToComplete = isHorizontal && tx > completeThreshold
            readyToEdit     = !isHorizontal && ty < editThreshold
            readyToShare    = !isHorizontal && ty > shareThreshold
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        guard !isFutureHabit else { return }
        isDragging = false
        if      readyToDelete   { performDeleteAction() }
        else if readyToComplete { performCompleteAction() }
        else if readyToEdit     { performEditAction() }
        else if readyToShare    { performShareAction() }
        else                    { snapBack() }
    }

    private func performDeleteAction() {
        HapticEngine.notification(.error)
        AudioServicesPlaySystemSound(1117)
        withAnimation(.easeIn(duration: 0.30)) {
            isBeingDeleted = true
            dragOffset = CGSize(width: -450, height: dragOffset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.31) { onDelete(); resetAllStates() }
    }

    private func performCompleteAction() {
        HapticEngine.notification(.success)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            dragOffset = CGSize(width: 450, height: dragOffset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { onComplete(); resetAllStates() }
    }

    private func performEditAction() {
        snapBack()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { onEdit() }
    }

    private func performShareAction() {
        snapBack()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { presentShareSheet() }
    }

    private func snapBack() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { resetAllStates() }
    }

    private func resetAllStates() {
        dragOffset = .zero
        isBeingDeleted = false
        readyToDelete = false; readyToComplete = false
        readyToEdit = false; readyToShare = false
    }

    private func presentShareSheet() {
        let dueText: String
        if let due = task.dueDate {
            dueText = due.formatted(date: .abbreviated, time: .shortened)
        } else {
            dueText = "No due date"
        }
        let text = "📋 \(task.title)\n\(task.urgency.rawValue) · Due \(dueText)"
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        if let popover = vc.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        top.present(vc, animated: true)
    }
}

// MARK: - Animation Modifier

struct DragAnimationModifier: ViewModifier {
    let isDragging: Bool

    func body(content: Content) -> some View {
        content
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isDragging)
    }
}

// MARK: - Task Row View

struct TaskRowView: View {
    let task: Daypilot
    let disappearingTaskID: UUID?
    @Binding var newTaskIDs: Set<UUID>
    let onDelete: (Daypilot) -> Void
    let onEdit: (Daypilot) -> Void
    let onComplete: (Daypilot) -> Void
    let onStatusChange: (Daypilot, TaskStatus) -> Void
    var occurrenceDate: Date? = nil

    private var isFutureHabit: Bool {
        guard task.type == .habit, let occ = occurrenceDate else { return false }
        return Calendar.current.compare(occ, to: Date(), toGranularity: .day) == .orderedDescending
    }

    @State private var bounceScale: CGFloat = 0.72
    @State private var bounceOpacity: Double = 0
    @State private var bounceOffset: CGFloat = -18

    var body: some View {
        DraggableTaskView(
            task: task,
            onDelete: { onDelete(task) },
            onEdit: { onEdit(task) },
            onComplete: { onComplete(task) },
            onStatusChange: { status in onStatusChange(task, status) },
            occurrenceDate: occurrenceDate,
            isFutureHabit: isFutureHabit
        )
        .scaleEffect(bounceScale)
        .opacity(bounceOpacity)
        .offset(y: bounceOffset)
        .onAppear { handleTaskAppearance() }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private func handleTaskAppearance() {
        if newTaskIDs.contains(task.uuid) {
            HapticEngine.impact(.light)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.58)) {
                    bounceScale = 1.0
                    bounceOpacity = 1.0
                    bounceOffset = 0
                    _ = newTaskIDs.remove(task.uuid)
                }
            }
        } else {
            bounceScale = 1.0
            bounceOpacity = 1.0
            bounceOffset = 0
        }
    }
}

// MARK: - Form Button

struct FormActionButton: View {
    let title: String
    let colors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                .cornerRadius(10)
        }
    }
}

// MARK: - Backplan Templates

struct BackplanTemplates {
    enum Category { case essay, test, lab, project, general }

    static func category(for title: String) -> Category {
        let t = title.lowercased()
        if t.contains("essay") || t.contains("paper") || t.contains("draft") || t.contains("write") || t.contains("report") { return .essay }
        if t.contains("test") || t.contains("exam") || t.contains("quiz") || t.contains("midterm") || t.contains("final") { return .test }
        if t.contains("lab") || t.contains("experiment") { return .lab }
        if t.contains("project") || t.contains("presentation") || t.contains("slides") || t.contains("demo") { return .project }
        return .general
    }

    static func steps(for title: String, daysUntilDue: Int) -> [String] {
        let raw: [String]
        switch category(for: title) {
        case .essay:
            raw = ["Brainstorm & outline", "Write first draft", "Revise draft", "Proofread & finalize"]
        case .test:
            raw = ["Review notes", "Make study guide", "Practice problems", "Final review"]
        case .lab:
            raw = ["Review procedure", "Gather materials", "Run experiment", "Analyze data & write up"]
        case .project:
            raw = ["Define scope", "Research & gather assets", "Build draft", "Review & polish"]
        case .general:
            raw = ["Plan approach", "Start work", "Check progress", "Complete & review"]
        }
        guard raw.count > 1 else { return raw }
        return raw.enumerated().map { i, step in
            let day = max(1, Int((Double(i) / Double(raw.count - 1)) * Double(daysUntilDue)))
            return "Day \(day): \(step)"
        }
    }
}

// MARK: - Crunch Alert Banner

struct CrunchAlertBanner: View {
    let count: Int
    let onSprint: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                .font(.system(size: 17))
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("Crunch ahead")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text("\(count) tasks due in the next 48 hours")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
            }
            Spacer()
            Button("Sprint", action: onSprint)
                .font(.caption.weight(.bold))
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.3), lineWidth: 1))
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}

// MARK: - Task Form View

struct TaskFormView: View {
    @Binding var isPresented: Bool
    @Binding var toDoTitle: String
    @Binding var selectedDate: Date
    @Binding var selectedUrgency: UrgencyLevel
    @Binding var showEmptyTitleAlert: Bool
    @Binding var selectedType: TaskType
    @Binding var selectedHabitFrequency: HabitFrequency
    @Binding var selectedStatus: TaskStatus
    @Binding var selectedProgress: Int
    @Binding var taskEmoji: String
    @Binding var attachmentImagePath: String?
    @Binding var userTag: String
    @Binding var notes: String
    @Binding var pendingSubtaskTitles: [String]
    @Binding var reminderEnabled: Bool
    @Binding var reminderTime: Date
    @Binding var applicationStage: String

    var onSave: () -> Void
    var isEditing: Bool = false
    var isTypeLocked: Bool = false
    var task: Daypilot? = nil

    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedTheme") private var selectedTheme = "original"
    private var theme: ThemeOption { AppThemes.find(selectedTheme) }

    @StateObject private var voiceRecorder = VoiceTaskRecorder()
    @State private var showAdvancedOptions = false
    @State private var showEmojiPicker = false
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var attachmentPreview: UIImage? = nil
    @State private var parsedDetails: ParsedTaskDetails? = nil
    @State private var newSubtaskTitle: String = ""

    private let commonEmojis = ["🏋️","🧘","🏃","🚴","🍎","💧","📚","✏️","💡","🎯","🧹","💰","🎵","🎨","🌿","😴","🧠","❤️","🌟","⚡","🔥","🏆","🧪","💻","📱","🗓","🍳","🚿","🌅","🎉"]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── Simple (always visible) ──────────────────────────────
                if !isTypeLocked {
                    Picker("Type", selection: $selectedType) {
                        ForEach(TaskType.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                }

                HStack(spacing: 8) {
                    TextField("Enter task name", text: $toDoTitle)
                        .glassFieldStyle()
                    Button {
                        voiceRecorder.toggle { text in
                            toDoTitle = text
                        }
                    } label: {
                        Image(systemName: voiceRecorder.isRecording ? "waveform.circle.fill" : "mic.circle")
                            .font(.system(size: 28))
                            .foregroundColor(voiceRecorder.isRecording ? .red : theme.accentColor)
                            .symbolEffect(.pulse, isActive: voiceRecorder.isRecording)
                    }
                    .buttonStyle(.plain)
                    .alert("Microphone Access Required", isPresented: $voiceRecorder.denied) {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
                .onChange(of: toDoTitle) { _, val in
                        guard !val.isEmpty else { parsedDetails = nil; return }
                        Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            let result = NLTaskParser.parse(val)
                            await MainActor.run {
                                if result.detectedDate != nil || result.detectedUrgency != nil {
                                    parsedDetails = result
                                } else {
                                    parsedDetails = nil
                                }
                            }
                        }
                    }

                if let parsed = parsedDetails {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars").font(.caption)
                        if let d = parsed.detectedDate {
                            Text(d.formatted(.dateTime.weekday().month().day()))
                                .font(.caption.weight(.medium))
                        }
                        if let u = parsed.detectedUrgency {
                            Text("· \(u.rawValue)").font(.caption)
                        }
                        Spacer()
                        Button("Apply") {
                            if let d = parsed.detectedDate { selectedDate = d }
                            if let u = parsed.detectedUrgency { selectedUrgency = u }
                            toDoTitle = parsed.cleanTitle
                            parsedDetails = nil
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(theme.accentColor)
                        Button { parsedDetails = nil } label: {
                            Image(systemName: "xmark").font(.caption2)
                        }
                        .foregroundColor(.white.opacity(0.4))
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Application stage picker
                if selectedType == .application {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pipeline Stage")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Picker("Stage", selection: $applicationStage) {
                            ForEach(ApplicationStage.allCases, id: \.rawValue) { stage in
                                Text(stage.rawValue).tag(stage.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                DatePicker(
                    selectedType == .application ? "Deadline" : "Due Date",
                    selection: $selectedDate,
                    displayedComponents: [.date, .hourAndMinute]
                )

                // Backplan chip — offered for tasks with a due date > 3 days out
                if selectedType == .task,
                   !toDoTitle.trimmingCharacters(in: .whitespaces).isEmpty,
                   let days = Calendar.current.dateComponents([.day], from: Date(), to: selectedDate).day,
                   days >= 3 {
                    let steps = BackplanTemplates.steps(for: toDoTitle, daysUntilDue: days)
                    if pendingSubtaskTitles.isEmpty {
                        Button {
                            withAnimation { pendingSubtaskTitles = steps }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "wand.and.stars").font(.caption)
                                Text("Generate \(days)-day plan (\(steps.count) steps)")
                                    .font(.caption.weight(.medium))
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption2)
                            }
                            .foregroundColor(theme.accentColor)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(theme.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

                // Application auto-subtask offer
                if selectedType == .application, pendingSubtaskTitles.isEmpty {
                    Button {
                        withAnimation {
                            pendingSubtaskTitles = [
                                "Research eligibility & requirements",
                                "Draft personal statement",
                                "Request recommendation letters",
                                "Prepare supporting materials",
                                "Review & submit application"
                            ]
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "wand.and.stars").font(.caption)
                            Text("Auto-fill application checklist")
                                .font(.caption.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2)
                        }
                        .foregroundColor(.purple)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // ── Advanced (collapsible) ───────────────────────────────
                DisclosureGroup(isExpanded: $showAdvancedOptions) {
                    VStack(spacing: 16) {

                        // Urgency
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Urgency")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Picker("Urgency", selection: $selectedUrgency) {
                                ForEach(UrgencyLevel.allCases, id: \.self) { Text($0.rawValue) }
                            }
                            .pickerStyle(.segmented)
                        }

                        // Habit frequency (only for habits)
                        if selectedType == .habit {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Frequency")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                ForEach(HabitFrequency.allCases, id: \.self) { freq in
                                    Button {
                                        selectedHabitFrequency = freq
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(freq.rawValue).fontWeight(.medium)
                                                Text(descriptionFor(freq))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            if selectedHabitFrequency == freq {
                                                Image(systemName: "checkmark").foregroundColor(.accentColor)
                                            }
                                        }
                                        .padding(10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedHabitFrequency == freq
                                                      ? Color.accentColor.opacity(0.12) : Color.clear)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            // Reminder time
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle(isOn: $reminderEnabled) {
                                    Label("Daily Reminder", systemImage: "bell.fill")
                                        .font(.subheadline)
                                }
                                .tint(theme.accentColor)
                                if reminderEnabled {
                                    DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                        .datePickerStyle(.graphical)
                                        .tint(theme.accentColor)
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: reminderEnabled)
                        }

                        // Status + Progress (editing tasks only)
                        if isEditing && selectedType == .task {
                            HStack {
                                Text("Status").foregroundColor(.secondary)
                                Spacer()
                                Button(selectedStatus.rawValue) {
                                    let all = TaskStatus.allCases
                                    let idx = all.firstIndex(of: selectedStatus) ?? 0
                                    selectedStatus = all[(idx + 1) % all.count]
                                }
                                .buttonStyle(.bordered)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Progress").font(.subheadline).foregroundColor(.secondary)
                                Picker("Progress", selection: $selectedProgress) {
                                    Text("0%").tag(0); Text("25%").tag(25)
                                    Text("50%").tag(50); Text("75%").tag(75)
                                    Text("100%").tag(100)
                                }
                                .pickerStyle(.segmented)
                                .tint(theme.urgencyColor(for: selectedUrgency))
                            }
                        }

                        // Emoji & photo
                        HStack(spacing: 12) {
                            Button { showEmojiPicker.toggle() } label: {
                                HStack(spacing: 6) {
                                    Text(taskEmoji.isEmpty ? "😊" : taskEmoji).font(.system(size: 22))
                                    Text(taskEmoji.isEmpty ? "Add emoji" : "Change emoji")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color.white.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showEmojiPicker) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Pick an emoji").font(.headline).padding(.top, 8)
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                                        ForEach(commonEmojis, id: \.self) { emoji in
                                            Button { taskEmoji = emoji; showEmojiPicker = false } label: {
                                                Text(emoji).font(.system(size: 28))
                                            }.buttonStyle(.plain)
                                        }
                                    }
                                    TextField("Custom emoji", text: $taskEmoji)
                                        .glassFieldStyle().font(.title)
                                        .onChange(of: taskEmoji) { _, v in if v.count > 2 { taskEmoji = String(v.prefix(2)) } }
                                    Button("Clear emoji") { taskEmoji = ""; showEmojiPicker = false }
                                        .font(.caption).foregroundColor(.red).padding(.bottom, 8)
                                }
                                .padding(.horizontal).frame(minWidth: 260)
                                .presentationCompactAdaptation(.popover)
                            }

                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                HStack(spacing: 6) {
                                    if let preview = attachmentPreview {
                                        Image(uiImage: preview).resizable().scaledToFill()
                                            .frame(width: 28, height: 28)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    } else {
                                        Image(systemName: "photo.badge.plus").font(.system(size: 18))
                                    }
                                    Text(attachmentPreview == nil ? "Add photo" : "Change photo")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color.white.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .onChange(of: selectedPhoto) { _, item in
                                guard let item else { return }
                                Task {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let image = UIImage(data: data) {
                                        let filename = "task-attach-\(UUID().uuidString).jpg"
                                        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                                            .appendingPathComponent(filename)
                                        if let jpeg = image.jpegData(compressionQuality: 0.7) {
                                            try? jpeg.write(to: url)
                                            await MainActor.run { attachmentImagePath = filename; attachmentPreview = image }
                                        }
                                    }
                                }
                            }

                            if attachmentPreview != nil {
                                Button {
                                    attachmentPreview = nil; attachmentImagePath = nil; selectedPhoto = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.red.opacity(0.7))
                                }.buttonStyle(.plain)
                            }
                        }

                        // Category tag
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Category (optional)")
                                .font(.subheadline).foregroundColor(.secondary)
                            let suggestions = ["Work", "Personal", "Health", "Study", "Finance", "Fitness"]
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(suggestions, id: \.self) { s in
                                        let tagColor = TagColorStore.color(for: s)
                                        Button { userTag = userTag == s ? "" : s } label: {
                                            Text(s)
                                                .font(.caption.weight(.semibold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 10).padding(.vertical, 5)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(userTag == s ? tagColor : tagColor.opacity(0.3))
                                                )
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                            TextField("Or type a custom tag…", text: $userTag)
                                .glassFieldStyle().font(.callout)

                            // Color picker for the current tag
                            if !userTag.isEmpty {
                                HStack(spacing: 10) {
                                    Text("Tag color:").font(.caption2).foregroundColor(.secondary)
                                    ForEach(TagColorStore.palette, id: \.key) { entry in
                                        let isCurrent = TagColorStore.all()[userTag] == entry.key
                                        Button {
                                            TagColorStore.set(entry.key, for: userTag)
                                        } label: {
                                            Circle()
                                                .fill(entry.color)
                                                .frame(width: 22, height: 22)
                                                .overlay(Circle().stroke(Color.white, lineWidth: isCurrent ? 2.5 : 0))
                                                .shadow(color: .black.opacity(0.2), radius: 2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Advanced Options")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                }

                // ── Notes ────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.subheadline).foregroundColor(.secondary)
                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("Add details, links, context…")
                                .foregroundColor(.white.opacity(0.28))
                                .font(.callout)
                                .padding(.leading, 5)
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $notes)
                            .font(.callout)
                            .frame(minHeight: 72, maxHeight: 140)
                            .scrollContentBackground(.hidden)
                    }
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.18), lineWidth: 1))
                }

                // ── Subtasks ──────────────────────────────────────────────
                if selectedType == .task {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Subtasks")
                            .font(.subheadline).foregroundColor(.secondary)

                        // Existing subtasks (edit mode)
                        if isEditing, let task, !task.subtasks.isEmpty {
                            VStack(spacing: 6) {
                                ForEach(task.subtasks) { sub in
                                    HStack(spacing: 10) {
                                        Button {
                                            sub.isCompleted.toggle()
                                            try? modelContext.save()
                                        } label: {
                                            Image(systemName: sub.isCompleted ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(sub.isCompleted ? .green : .white.opacity(0.4))
                                        }
                                        .buttonStyle(.plain)
                                        Text(sub.title)
                                            .font(.callout)
                                            .foregroundColor(sub.isCompleted ? .white.opacity(0.4) : .white)
                                            .strikethrough(sub.isCompleted)
                                        Spacer()
                                        Button {
                                            modelContext.delete(sub)
                                            try? modelContext.save()
                                        } label: {
                                            Image(systemName: "xmark").font(.caption2).foregroundColor(.white.opacity(0.3))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Color.white.opacity(0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }

                        // Pending subtasks (creation mode)
                        if !isEditing && !pendingSubtaskTitles.isEmpty {
                            VStack(spacing: 6) {
                                ForEach(Array(pendingSubtaskTitles.enumerated()), id: \.offset) { idx, title in
                                    HStack(spacing: 10) {
                                        Image(systemName: "circle")
                                            .foregroundColor(.white.opacity(0.3))
                                            .font(.system(size: 14))
                                        Text(title)
                                            .font(.callout)
                                            .foregroundColor(.white)
                                        Spacer()
                                        Button {
                                            pendingSubtaskTitles.remove(at: idx)
                                        } label: {
                                            Image(systemName: "xmark").font(.caption2).foregroundColor(.white.opacity(0.3))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Color.white.opacity(0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }

                        // Add subtask input
                        HStack(spacing: 8) {
                            TextField("Add subtask…", text: $newSubtaskTitle)
                                .glassFieldStyle()
                                .submitLabel(.done)
                                .onSubmit { commitSubtask() }
                            Button { commitSubtask() } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(newSubtaskTitle.isEmpty ? .white.opacity(0.25) : theme.accentColor)
                            }
                            .buttonStyle(.plain)
                            .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }

                // ── Actions ──────────────────────────────────────────────
                FormActionButton(title: isEditing ? "Update" : "Add",
                                colors: [theme.accentColor, theme.color2, theme.color3]) {
                    handleSave()
                }
                .alert("Please enter a task name", isPresented: $showEmptyTitleAlert) {
                    Button("OK", role: .cancel) {}
                }

                FormActionButton(title: "Cancel",
                                colors: [.red.opacity(0.8), theme.accentColor.opacity(0.5)]) {
                    isPresented = false
                }
            }
            .padding()
            .padding(.bottom, 16)
        }
        .onAppear {
            if isEditing { showAdvancedOptions = true }
            if let path = attachmentImagePath {
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(path)
                attachmentPreview = UIImage(contentsOfFile: url.path)
            }
        }
    }

    private func handleSave() {
        if toDoTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            showEmptyTitleAlert = true
        } else {
            onSave()
        }
    }

    private func commitSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if isEditing, let parent = task {
            let sub = Daypilot(title: trimmed, urgency: .notUrgent, type: .task)
            sub.parent = parent
            parent.subtasks.append(sub)
            modelContext.insert(sub)
            try? modelContext.save()
        } else {
            pendingSubtaskTitles.append(trimmed)
        }
        newSubtaskTitle = ""
        HapticEngine.impact(.light)
    }

    private func descriptionFor(_ freq: HabitFrequency) -> String {
        switch freq {
        case .daily:         return "Every day — builds strong routines"
        case .everyOtherDay: return "Every 2 days — balanced recovery"
        case .weekly:        return "Once a week — low-frequency goals"
        }
    }
}

// MARK: - Day Navigator

struct DayNavigatorView: View {
    @Binding var selectedDate: Date?
    @AppStorage("selectedTheme") private var selectedTheme = "original"

    private var theme: ThemeOption { AppThemes.find(selectedTheme) }
    private var displayDate: Date { selectedDate ?? Calendar.current.startOfDay(for: Date()) }

    private var dateLabel: String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        let mmdd = f.string(from: displayDate)
        if cal.isDateInToday(displayDate)     { return "Today, \(mmdd)" }
        if cal.isDateInYesterday(displayDate) { return "Yesterday, \(mmdd)" }
        let df = DateFormatter()
        df.dateFormat = "EEEE, MM/dd"
        return df.string(from: displayDate)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                let cal = Calendar.current
                if let prev = cal.date(byAdding: .day, value: -1, to: displayDate) {
                    selectedDate = cal.startOfDay(for: prev)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.accentColor)
                    .frame(width: 40, height: 40)
                    .background(theme.accentColor.opacity(0.18))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(dateLabel)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)

            Spacer()

            if !Calendar.current.isDateInToday(displayDate) {
                Button("Today") {
                    selectedDate = Calendar.current.startOfDay(for: Date())
                }
                .font(.caption.weight(.bold))
                .foregroundColor(theme.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.accentColor.opacity(0.18))
                .clipShape(Capsule())
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 40, height: 40)
            }

            Button {
                let cal = Calendar.current
                if let next = cal.date(byAdding: .day, value: 1, to: displayDate) {
                    selectedDate = cal.startOfDay(for: next)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.accentColor)
                    .frame(width: 40, height: 40)
                    .background(theme.accentColor.opacity(0.18))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .onAppear {
            if selectedDate == nil {
                selectedDate = Calendar.current.startOfDay(for: Date())
            }
        }
    }
}

// MARK: - Confetti

private struct ConfettiPieceView: View {
    let x: CGFloat
    let color: Color
    let size: CGFloat
    let speed: Double
    let delay: Double
    let totalSpin: Double
    let screenHeight: CGFloat

    @State private var y: CGFloat = -30
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1.0

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: size, height: size * 1.5)
            .rotationEffect(.degrees(rotation))
            .position(x: x, y: y)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: speed).delay(delay)) {
                    y = screenHeight + 40
                    rotation = totalSpin
                }
                withAnimation(.linear(duration: 0.35).delay(delay + speed * 0.72)) {
                    opacity = 0
                }
            }
    }
}

struct ConfettiView: View {
    var count: Int = 55
    private let palette: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .white]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    ConfettiPieceView(
                        x: CGFloat.random(in: 0...geo.size.width),
                        color: palette[i % palette.count],
                        size: CGFloat.random(in: 6...14),
                        speed: Double.random(in: 0.9...1.6),
                        delay: Double.random(in: 0...0.45),
                        totalSpin: Double.random(in: 200...420),
                        screenHeight: geo.size.height
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Streak Share Card (solid gradient — ImageRenderer can't capture UIKit blur)

struct StreakShareCardView: View {
    let streak: Int
    let habitName: String
    let theme: ThemeOption

    private var milestoneEmoji: String {
        switch streak {
        case 3: return "🌱"; case 7: return "🔥"; case 14: return "💪"
        case 30: return "⭐"; case 60: return "🌟"; case 100: return "💎"
        case 365: return "🏆"; default: return "🔥"
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [theme.color1, theme.color2, theme.color3],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 14) {
                Text(milestoneEmoji).font(.system(size: 64))
                Text("\(streak)")
                    .font(.system(size: 80, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Day Streak")
                    .font(.title.weight(.bold)).foregroundColor(.white)
                if !habitName.isEmpty {
                    Text(habitName)
                        .font(.headline).foregroundColor(.white.opacity(0.75))
                }
                Divider().background(Color.white.opacity(0.3)).padding(.horizontal, 40)
                HStack(spacing: 6) {
                    Image(systemName: "metronome.fill")
                    Text("Daypilot")
                }
                .font(.subheadline.weight(.medium)).foregroundColor(.white.opacity(0.6))
            }
            .padding(32)
        }
        .frame(width: 340, height: 380)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}

// MARK: - Celebration Overlay

struct CelebrationOverlay: View {
    let streak: Int
    let habitName: String
    let onDismiss: () -> Void

    @AppStorage("selectedTheme") private var selectedTheme = "original"
    @State private var cardScale: CGFloat = 0.65
    @State private var cardOpacity: Double = 0

    private var theme: ThemeOption { AppThemes.find(selectedTheme) }

    private var milestoneEmoji: String {
        switch streak {
        case 3:   return "🌱"
        case 7:   return "🔥"
        case 14:  return "💪"
        case 30:  return "⭐"
        case 60:  return "🌟"
        case 100: return "💎"
        case 365: return "🏆"
        default:  return "🔥"
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            ConfettiView(count: 60)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(milestoneEmoji)
                    .font(.system(size: 72))
                Text("\(streak)")
                    .font(.system(size: 82, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Day Streak!")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                if !habitName.isEmpty {
                    Text(habitName)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.72))
                }

                Button {
                    shareStreakCard()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24).padding(.vertical, 10)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Text("Tap anywhere to continue")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.top, 2)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .shadow(color: .black.opacity(0.35), radius: 32, x: 0, y: 12)
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
            .padding(.horizontal, 28)
        }
        .onAppear {
            HapticEngine.notification(.success)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.68)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { onDismiss() }
        }
    }

    private func shareStreakCard() {
        let card = StreakShareCardView(streak: streak, habitName: habitName, theme: theme)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        guard let img = renderer.uiImage else { return }
        let vc = UIActivityViewController(activityItems: [img], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        if let pop = vc.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        top.present(vc, animated: true)
        HapticEngine.impact(.light)
    }
}

// MARK: - Main Tasks View

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var gradientManager: SunsetGradientManager
    @State private var animatedGradient: LinearGradient = SunsetGradientManager.gradient(for: Date())
    @Query(sort: \Daypilot.dueDate, order: .forward, animation: .default) private var daypilots: [Daypilot]

    @State private var currentDate = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // Day navigator state
    @State private var selectedCalendarDate: Date? = Calendar.current.startOfDay(for: Date())

    // Form state
    @State private var isSheetShowing = false
    @State private var toDoTitle = ""
    @State private var selectedDate = Date()
    @State private var selectedUrgency = UrgencyLevel.notUrgent
    @State private var disappearingTaskID: UUID?
    @State private var editingTask: Daypilot? = nil
    @State private var isEditingSheetShowing = false
    @State private var showEmptyTitleAlert = false
    @State private var newTaskIDs: Set<UUID> = []
    @State private var selectedStatus: TaskStatus = .open
    @State private var selectedProgress: Int = 0
    @State private var selectedType: TaskType = .task
    @State private var selectedHabitFrequency: HabitFrequency = .daily
    @State private var habitDeleteTarget: Daypilot? = nil
    @State private var showHabitDeleteDialog = false
    @State private var formEmoji: String = ""
    @State private var formAttachmentImagePath: String? = nil
    @State private var formUserTag: String = ""
    @State private var formNotes: String = ""
    @State private var pendingSubtaskTitles: [String] = []
    @State private var formReminderEnabled: Bool = false
    @State private var formReminderTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var formApplicationStage: String = ApplicationStage.found.rawValue
    @State private var isSearching: Bool = false
    @State private var searchText: String = ""
    @State private var selectedTagFilter: String? = nil
    @State private var isPomodoroShowing = false
    @State private var pomodoroTask: Daypilot? = nil
    @State private var searchScope: SearchScope = .all
    @AppStorage("pomodoroPlacement") private var pomodoroPlacement = "corner"
    @AppStorage("selectedTheme") private var selectedTheme = "original"
    private var theme: ThemeOption { AppThemes.find(selectedTheme) }
    private var cachedDisplayName: String { UserDefaults.standard.string(forKey: "cachedDisplayName") ?? "" }

    // Streak celebration
    @State private var streakMilestone: Int? = nil
    @State private var celebrationHabitName: String = ""

    // Freeze awarded toast
    @State private var showFreezeAwardedToast = false

    // Undo-delete
    @State private var pendingDeleteTask: Daypilot? = nil
    @State private var deleteUndoJob: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()
                ThemeParticleView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                mainContent
            }
        }
        .overlay {
            if let milestone = streakMilestone {
                CelebrationOverlay(streak: milestone, habitName: celebrationHabitName) {
                    withAnimation(.easeOut(duration: 0.22)) { streakMilestone = nil }
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .overlay(alignment: .bottom) {
            if pendingDeleteTask != nil {
                UndoDeleteToast { undoPendingDelete() }
                    .padding(.bottom, 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(50)
            }
        }
        .overlay(alignment: .top) {
            if showFreezeAwardedToast {
                FreezeAwardedToast()
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(48)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: pendingDeleteTask != nil)
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: showFreezeAwardedToast)
        .onAppear {
            animatedGradient = SunsetGradientManager.gradient(for: currentDate)
            checkAndApplyStreakFreezes()
        }
        .onReceive(timer) { input in
            withAnimation(.easeInOut(duration: 1.2)) {
                animatedGradient = SunsetGradientManager.gradient(for: input)
            }
            currentDate = input
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            withAnimation(.easeInOut(duration: 1.2)) {
                animatedGradient = SunsetGradientManager.gradient(for: currentDate)
            }
            currentDate = Date()
            checkAndApplyStreakFreezes()
            for habit in daypilots where habit.type == .habit && habit.habitFrequency == .everyOtherDay {
                HabitScheduler.schedule(habit)
            }
        }
    }

    private var backgroundGradient: some View {
        Rectangle().fill(gradientManager.gradient)
    }

    private var crunchWindowTasks: [Daypilot] {
        let now = Date()
        guard let cutoff = Calendar.current.date(byAdding: .hour, value: 48, to: now) else { return [] }
        return daypilots.filter { task in
            guard (task.type == .task || task.type == .application),
                  !task.isCompleted,
                  let due = task.dueDate else { return false }
            return due > now && due <= cutoff
        }
    }

    private func habitOccursOn(_ task: Daypilot, date: Date) -> Bool {
        HabitScheduler.occursOn(task, date: date)
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if !crunchWindowTasks.isEmpty {
                CrunchAlertBanner(count: crunchWindowTasks.count) {
                    pomodoroTask = crunchWindowTasks.first
                    isPomodoroShowing = true
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            DayNavigatorView(selectedDate: $selectedCalendarDate)

            // Inline search bar (only when active)
            if isSearching {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.5))
                    TextField("Search tasks & habits", text: $searchText)
                        .foregroundColor(.white)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.5))
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.18), lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                .transition(.move(edge: .top).combined(with: .opacity))

                searchScopeBar

                if searchScope == .byTag || searchScope == .all, !allUserTags.isEmpty {
                    tagFilterBar
                }
            }

            if shouldShowEmptyState {
                emptyStateView
            } else {
                tasksList
            }
        }
        .navigationTitle("Today's Tasks")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 14) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isSearching.toggle()
                            if !isSearching { searchText = ""; searchScope = .all; selectedTagFilter = nil }
                        }
                    } label: {
                        Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                            .foregroundColor(.white)
                    }
                    Menu {
                        Button {
                            resetForm()
                            selectedType = .task
                            isSheetShowing = true
                        } label: {
                            Label("New Task", systemImage: "checkmark.circle")
                        }
                        Button {
                            resetForm()
                            selectedType = .habit
                            isSheetShowing = true
                        } label: {
                            Label("New Habit", systemImage: "repeat.circle")
                        }
                        Button {
                            resetForm()
                            selectedType = .application
                            formApplicationStage = ApplicationStage.found.rawValue
                            isSheetShowing = true
                        } label: {
                            Label("New Application", systemImage: "doc.badge.plus")
                        }
                        Button {
                            isPomodoroShowing = true
                        } label: {
                            Label("Focus Timer", systemImage: "timer")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .bold))
                    }
                }
            }
        }
        .sheet(isPresented: $isSheetShowing) {
            addTaskSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $isEditingSheetShowing) {
            editTaskSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $isPomodoroShowing) {
            PomodoroView(linkedTask: pomodoroTask)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .confirmationDialog(
            "Remove this habit?",
            isPresented: $showHabitDeleteDialog,
            titleVisibility: .visible
        ) {
            Button("Skip today only") {
                if let h = habitDeleteTarget { skipHabitToday(h) }
                habitDeleteTarget = nil
            }
            Button("Delete habit entirely", role: .destructive) {
                if let h = habitDeleteTarget { deleteTask(h) }
                habitDeleteTarget = nil
            }
            Button("Cancel", role: .cancel) { habitDeleteTarget = nil }
        } message: {
            Text("You can skip it for today, or remove it permanently.")
        }
    }

    private var shouldShowEmptyState: Bool {
        filteredAndSortedDaypilots.isEmpty && disappearingTaskID == nil
    }

    private var searchScopeBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchScope.allCases, id: \.self) { scope in
                    Button {
                        searchScope = scope
                        if scope != .byTag { selectedTagFilter = nil }
                    } label: {
                        Text(scope.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(searchScope == scope ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(searchScope == scope ? Color.white : Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allUserTags, id: \.self) { tag in
                    let tagColor = TagColorStore.color(for: tag)
                    let isSelected = selectedTagFilter == tag
                    Button {
                        selectedTagFilter = isSelected ? nil : tag
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(tagColor)
                                .frame(width: 8, height: 8)
                            Text(tag)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isSelected ? tagColor.opacity(0.5) : Color.white.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? tagColor : Color.clear, lineWidth: 1.5)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            selectedCalendarDate != nil ? "No tasks for this day" : "Nothing to do yet!",
            systemImage: selectedCalendarDate != nil ? "calendar.badge.exclamationmark" : "checkmark.circle.fill"
        )
        .foregroundColor(.white)
    }

    private var tasksList: some View {
        let regularTasks = filteredAndSortedDaypilots.filter { $0.type == .task }
        let applications = filteredAndSortedDaypilots.filter { $0.type == .application }
        let habits = filteredAndSortedDaypilots
            .filter { $0.type == .habit }
            .sorted { a, b in
                let aDone = Calendar.current.isDateInToday(a.lastCompletedDate ?? Date.distantPast)
                let bDone = Calendar.current.isDateInToday(b.lastCompletedDate ?? Date.distantPast)
                if aDone == bDone { return false }
                return !aDone
            }

        return List {
            if !regularTasks.isEmpty {
                Section("Tasks") {
                    ForEach(regularTasks, id: \.uuid) { toDo in
                        taskRow(for: toDo)
                    }
                }
            }
            if !applications.isEmpty {
                Section("Applications") {
                    ForEach(applications, id: \.uuid) { toDo in
                        taskRow(for: toDo)
                    }
                }
            }
            if !habits.isEmpty {
                Section("Habits") {
                    ForEach(habits, id: \.uuid) { toDo in
                        taskRow(for: toDo)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.clear)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func taskRow(for toDo: Daypilot) -> some View {
        let occ: Date? = (toDo.type == .habit && selectedCalendarDate != nil)
            ? selectedCalendarDate
            : nil
        TaskRowView(
            task: toDo,
            disappearingTaskID: disappearingTaskID,
            newTaskIDs: $newTaskIDs,
            onDelete: handleDeleteRequest,
            onEdit: startEditing,
            onComplete: markTaskDone,
            onStatusChange: updateTaskStatus,
            occurrenceDate: occ
        )
        .background(Color.clear)
    }

    private var filteredAndSortedDaypilots: [Daypilot] {
        var base = daypilots.filter {
            ($0.parent == nil) &&
            (!$0.isCompleted || $0.uuid == disappearingTaskID) &&
            $0.uuid != pendingDeleteTask?.uuid
        }

        // Search filter
        if !searchText.isEmpty {
            base = base.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        // Search scope filter
        let cal = Calendar.current
        switch searchScope {
        case .today:
            base = base.filter { task in
                guard let due = task.dueDate else { return false }
                return cal.isDateInToday(due)
            }
        case .thisWeek:
            let weekOut = cal.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            base = base.filter { task in
                guard let due = task.dueDate else { return false }
                return due >= cal.startOfDay(for: Date()) && due <= weekOut
            }
        case .byTag:
            if let tag = selectedTagFilter {
                base = base.filter { $0.userTag == tag }
            }
        case .all:
            // User-tag filter still applies when not in byTag scope
            if let tag = selectedTagFilter {
                base = base.filter { $0.userTag == tag }
            }
        }

        if let day = selectedCalendarDate {
            return base.filter { task in
                if task.type == .habit { return habitOccursOn(task, date: day) }
                guard let due = task.dueDate else { return false }
                return cal.isDate(due, inSameDayAs: day)
            }
        }
        return base.sorted { !$0.isCompleted && $1.isCompleted }
    }

    private var allUserTags: [String] {
        Array(Set(daypilots.compactMap(\.userTag).filter { !$0.isEmpty })).sorted()
    }

    private var addTaskSheet: some View {
        TaskFormView(
            isPresented: $isSheetShowing,
            toDoTitle: $toDoTitle,
            selectedDate: $selectedDate,
            selectedUrgency: $selectedUrgency,
            showEmptyTitleAlert: $showEmptyTitleAlert,
            selectedType: $selectedType,
            selectedHabitFrequency: $selectedHabitFrequency,
            selectedStatus: $selectedStatus,
            selectedProgress: $selectedProgress,
            taskEmoji: $formEmoji,
            attachmentImagePath: $formAttachmentImagePath,
            userTag: $formUserTag,
            notes: $formNotes,
            pendingSubtaskTitles: $pendingSubtaskTitles,
            reminderEnabled: $formReminderEnabled,
            reminderTime: $formReminderTime,
            applicationStage: $formApplicationStage,
            onSave: addTask,
            isTypeLocked: true
        )
    }

    private var editTaskSheet: some View {
        TaskFormView(
            isPresented: $isEditingSheetShowing,
            toDoTitle: $toDoTitle,
            selectedDate: $selectedDate,
            selectedUrgency: $selectedUrgency,
            showEmptyTitleAlert: $showEmptyTitleAlert,
            selectedType: $selectedType,
            selectedHabitFrequency: $selectedHabitFrequency,
            selectedStatus: $selectedStatus,
            selectedProgress: $selectedProgress,
            taskEmoji: $formEmoji,
            attachmentImagePath: $formAttachmentImagePath,
            userTag: $formUserTag,
            notes: $formNotes,
            pendingSubtaskTitles: .constant([]),
            reminderEnabled: $formReminderEnabled,
            reminderTime: $formReminderTime,
            applicationStage: $formApplicationStage,
            onSave: updateTask,
            isEditing: true,
            task: editingTask
        )
    }

    // MARK: - Task Actions

    private func markTaskDone(_ task: Daypilot) {
        withAnimation {
            if task.type == .habit {
                let newStreak = HabitScheduler.updatedStreak(for: task)
                task.streakCount = newStreak
                task.streakFreezeActive = false
                task.lastCompletedDate = Date()
                task.isCompleted = false
                cancelNotification(for: task)
                scheduleHabitNotifications(for: task)
                HapticEngine.impact(.heavy)
                let milestones = [3, 7, 14, 30, 60, 100, 365]
                if milestones.contains(newStreak) {
                    celebrationHabitName = task.title
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation { streakMilestone = newStreak }
                    }
                }
                let freezeMilestones: Set<Int> = [1, 3, 5, 7, 9]
                if freezeMilestones.contains(newStreak) {
                    task.freezeCount += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            showFreezeAwardedToast = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                            withAnimation { showFreezeAwardedToast = false }
                        }
                    }
                }
            } else {
                task.isCompleted = true
                task.completedAt = Date()
                disappearingTaskID = task.uuid
                cancelNotification(for: task)
            }
            try? modelContext.save()
        }
        writeWidgetSnapshot()

        if task.type == .task {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { disappearingTaskID = nil }
            }
        }
    }

    private func checkAndApplyStreakFreezes() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var changed = false
        for habit in daypilots where habit.type == .habit {
            guard let last = habit.lastCompletedDate else { continue }
            let lastDay = cal.startOfDay(for: last)
            let daysDiff = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
            guard daysDiff > 1 else { continue }
            if habit.streakFreezeActive {
                // If they missed another day after the freeze, the streak truly breaks
                if daysDiff > 2 {
                    habit.streakFreezeActive = false
                    habit.streakCount = 0
                    changed = true
                }
            } else if daysDiff == 2 && habit.streakCount > 0 && habit.freezeCount > 0 {
                // Missed exactly yesterday — auto-apply a freeze
                habit.freezeCount -= 1
                habit.streakFreezeActive = true
                changed = true
            } else if daysDiff >= 2 && habit.streakCount > 0 {
                // Missed one or more days with no freeze — break the streak
                habit.streakCount = 0
                changed = true
            }
        }
        if changed { try? modelContext.save() }
    }

    private func handleDeleteRequest(_ task: Daypilot) {
        if task.type == .habit {
            habitDeleteTarget = task
            showHabitDeleteDialog = true
        } else {
            initiateDelete(task)
        }
    }

    // Buffers the delete with a 3.5s undo window before committing.
    private func initiateDelete(_ task: Daypilot) {
        deleteUndoJob?.cancel()
        if let prev = pendingDeleteTask { commitDelete(prev) }
        withAnimation { pendingDeleteTask = task }
        deleteUndoJob = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 3_500_000_000)
                commitDelete(task)
                withAnimation { pendingDeleteTask = nil }
            } catch { /* cancelled by undo */ }
        }
    }

    private func commitDelete(_ task: Daypilot) {
        cancelNotification(for: task)
        modelContext.delete(task)
        try? modelContext.save()
        writeWidgetSnapshot()
    }

    private func undoPendingDelete() {
        deleteUndoJob?.cancel()
        deleteUndoJob = nil
        withAnimation { pendingDeleteTask = nil }
        HapticEngine.impact(.light)
    }

    // Used by the habit-delete confirmation dialog (no undo needed — user already confirmed).
    private func deleteTask(_ task: Daypilot) {
        commitDelete(task)
    }

    private func skipHabitToday(_ task: Daypilot) {
        // Mark as done for today without incrementing the streak
        withAnimation {
            task.lastCompletedDate = Date()
            try? modelContext.save()
        }
    }

    private func startEditing(_ task: Daypilot) {
        editingTask = task
        toDoTitle = task.title
        selectedDate = task.dueDate ?? Date()
        selectedUrgency = task.urgency
        selectedStatus = task.status
        let steps = [0, 25, 50, 75, 100]
        selectedProgress = steps.min(by: { abs($0 - task.progress) < abs($1 - task.progress) }) ?? 0
        selectedType = task.type
        selectedHabitFrequency = task.habitFrequency
        formEmoji = task.taskEmoji ?? ""
        formAttachmentImagePath = task.attachmentImagePath
        formUserTag = task.userTag ?? ""
        formNotes = task.notes ?? ""
        formApplicationStage = task.applicationStage ?? ApplicationStage.found.rawValue
        if let rt = task.reminderTime {
            formReminderEnabled = true
            formReminderTime = rt
        } else {
            formReminderEnabled = false
        }
        isEditingSheetShowing = true
    }

    private func resetForm() {
        toDoTitle = ""
        selectedDate = Date()
        selectedUrgency = .notUrgent
        editingTask = nil
        selectedStatus = .open
        selectedProgress = 0
        selectedType = .task
        selectedHabitFrequency = .daily
        formEmoji = ""
        formAttachmentImagePath = nil
        formUserTag = ""
        formNotes = ""
        pendingSubtaskTitles = []
        formReminderEnabled = false
        formReminderTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
        formApplicationStage = ApplicationStage.found.rawValue
    }

    private func addTask() {
        guard !toDoTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
            showEmptyTitleAlert = true
            return
        }
        let newTask = Daypilot(
            title: toDoTitle,
            isCompleted: false,
            dueDate: selectedDate,
            urgency: selectedUrgency,
            status: selectedStatus,
            progress: selectedProgress,
            type: selectedType,
            habitFrequency: selectedHabitFrequency
        )
        if !formEmoji.isEmpty { newTask.taskEmoji = formEmoji }
        newTask.attachmentImagePath = formAttachmentImagePath
        newTask.userTag = formUserTag.isEmpty ? nil : formUserTag
        newTask.notes = formNotes.isEmpty ? nil : formNotes
        newTask.reminderTime = formReminderEnabled ? formReminderTime : nil
        if selectedType == .application { newTask.applicationStage = formApplicationStage }
        modelContext.insert(newTask)
        for title in pendingSubtaskTitles {
            let sub = Daypilot(title: title, urgency: .notUrgent, type: .task)
            sub.parent = newTask
            newTask.subtasks.append(sub)
            modelContext.insert(sub)
        }
        do {
            try modelContext.save()
            if newTask.type == .habit {
                scheduleHabitNotifications(for: newTask)
            } else {
                HabitScheduler.scheduleTaskReminder(newTask)
            }
            newTaskIDs.insert(newTask.uuid)
            isSheetShowing = false
            HapticEngine.impact(.light)
            writeWidgetSnapshot()
        } catch {
            print("Failed to save new task: \(error)")
        }
    }

    private func updateTask() {
        guard let task = editingTask else { return }
        cancelNotification(for: task)
        task.title = toDoTitle
        task.dueDate = selectedDate
        task.urgency = selectedUrgency
        task.status = selectedStatus
        task.progress = selectedProgress
        task.type = selectedType
        task.habitFrequency = selectedHabitFrequency
        task.taskEmoji = formEmoji.isEmpty ? nil : formEmoji
        task.attachmentImagePath = formAttachmentImagePath
        task.userTag = formUserTag.isEmpty ? nil : formUserTag
        task.notes = formNotes.isEmpty ? nil : formNotes
        task.reminderTime = formReminderEnabled ? formReminderTime : nil
        if task.type == .application { task.applicationStage = formApplicationStage }
        do {
            try modelContext.save()
            if task.type == .habit {
                scheduleHabitNotifications(for: task)
            } else {
                HabitScheduler.scheduleTaskReminder(task)
            }
            isEditingSheetShowing = false
            editingTask = nil
            HapticEngine.impact(.light)
            writeWidgetSnapshot()
        } catch {
            print("Failed to update task: \(error)")
        }
    }

    private func updateTaskStatus(_ task: Daypilot, _ status: TaskStatus) {
        task.status = status
        try? modelContext.save()
    }

    // MARK: - Notifications

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error { print("Notification permission denied: \(error.localizedDescription)") }
        }
    }

    private func scheduleHabitNotifications(for task: Daypilot) {
        HabitScheduler.schedule(task)
    }

    private func cancelNotification(for task: Daypilot) {
        HabitScheduler.cancel(task)
    }

    // MARK: - Widget Snapshot

    private func writeWidgetSnapshot() {
        guard let defaults = UserDefaults(suiteName: "group.com.daypilot.shared") else { return }
        let todayTasksJSON = daypilots
            .filter { !$0.isCompleted && $0.type == .task }
            .prefix(5)
            .map { ["title": $0.title, "urgency": $0.urgency.rawValue, "emoji": $0.taskEmoji ?? ""] }
        let bestStreak = daypilots.filter { $0.type == .habit }.map(\.streakCount).max() ?? 0
        let habitsDoneToday = daypilots.filter {
            $0.type == .habit && Calendar.current.isDateInToday($0.lastCompletedDate ?? .distantPast)
        }.count
        if let data = try? JSONSerialization.data(withJSONObject: todayTasksJSON) {
            defaults.set(data, forKey: "widgetTasks")
        }
        defaults.set(bestStreak, forKey: "widgetBestStreak")
        defaults.set(habitsDoneToday, forKey: "widgetHabitsDoneToday")
        defaults.set(UserDefaults.standard.string(forKey: "selectedTheme") ?? "original", forKey: "widgetTheme")
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Undo Delete Toast

struct UndoDeleteToast: View {
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text("Task deleted")
                .font(.subheadline)
                .foregroundColor(.white)
            Button("Undo") { onUndo() }
                .font(.subheadline.weight(.bold))
                .foregroundColor(.yellow)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 16, y: 4)
    }
}

// MARK: - Freeze Awarded Toast

struct FreezeAwardedToast: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("🧊")
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Streak Freeze Earned!")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text("Miss a day and your streak stays safe")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.cyan.opacity(0.45), lineWidth: 1))
        .shadow(color: .cyan.opacity(0.30), radius: 14, y: 4)
    }
}
