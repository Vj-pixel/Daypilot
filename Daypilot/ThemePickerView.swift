// ThemePickerView.swift

import SwiftUI
import Combine

// MARK: - Theme Model

struct ThemeOption: Identifiable {
    let id: String
    let name: String
    let color1: Color
    let color2: Color
    let color3: Color
    let sunriseColors: [Color]
    let dayColors: [Color]
    let sunsetColors: [Color]
    let nightColors: [Color]
    let urgentColor: Color
    let kindaUrgentColor: Color
    let notUrgentColor: Color
    var accentColor: Color { color1 }

    func urgencyColor(for level: UrgencyLevel) -> Color {
        switch level {
        case .urgent:      return urgentColor
        case .kindaUrgent: return kindaUrgentColor
        case .notUrgent:   return notUrgentColor
        }
    }
}

// MARK: - Theme Library

struct AppThemes {
    static let all: [ThemeOption] = [
        // ── Original: bold purple/blue sky, vivid at all hours ──
        ThemeOption(
            id: "original", name: "Original",
            color1: c(0.60,0.10,0.90), color2: c(0.30,0.10,0.80), color3: c(0.10,0.40,1.00),
            sunriseColors: [c(0.90,0.20,0.50), c(1.00,0.55,0.20), c(0.70,0.10,0.80)],
            dayColors:     [c(0.20,0.45,1.00), c(0.00,0.80,1.00), c(0.40,0.10,0.95)],
            sunsetColors:  [c(0.80,0.10,0.60), c(1.00,0.40,0.10), c(0.50,0.00,0.90)],
            nightColors:   [c(0.40,0.00,0.80), c(0.60,0.10,1.00), c(0.20,0.00,0.55)],
            urgentColor: .red, kindaUrgentColor: .orange, notUrgentColor: c(0.10,0.90,1.00)
        ),
        // ── Light: warm sky blues and soft corals, bright even at night ──
        ThemeOption(
            id: "light", name: "Light",
            color1: c(0.40,0.70,1.00), color2: c(1.00,0.55,0.65), color3: c(0.80,0.90,1.00),
            sunriseColors: [c(1.00,0.80,0.55), c(1.00,0.65,0.75), c(0.60,0.80,1.00)],
            dayColors:     [c(0.45,0.75,1.00), c(0.70,0.92,1.00), c(0.90,0.75,1.00)],
            sunsetColors:  [c(1.00,0.45,0.55), c(1.00,0.65,0.30), c(0.80,0.50,1.00)],
            nightColors:   [c(0.30,0.40,0.90), c(0.55,0.50,1.00), c(0.70,0.65,1.00)],
            urgentColor: c(0.95,0.35,0.35), kindaUrgentColor: c(1.00,0.72,0.20), notUrgentColor: c(0.20,0.80,0.65)
        ),
        // ── Midnight: deep navy cosmos, stars at night ──
        ThemeOption(
            id: "midnight", name: "Midnight",
            color1: c(0.10,0.15,0.55), color2: c(0.20,0.20,0.70), color3: c(0.35,0.30,0.85),
            sunriseColors: [c(0.10,0.10,0.45), c(0.25,0.15,0.60), c(0.05,0.05,0.35)],
            dayColors:     [c(0.12,0.18,0.60), c(0.20,0.25,0.75), c(0.08,0.12,0.50)],
            sunsetColors:  [c(0.20,0.10,0.55), c(0.35,0.10,0.65), c(0.10,0.05,0.45)],
            nightColors:   [c(0.05,0.05,0.35), c(0.12,0.12,0.55), c(0.20,0.15,0.65)],
            urgentColor: c(1.00,0.30,0.40), kindaUrgentColor: c(1.00,0.82,0.20), notUrgentColor: c(0.35,0.30,0.85)
        ),
        // ── Deep: dark navy focus — near-black with blue undertone, no distraction ──
        ThemeOption(
            id: "deep", name: "Deep",
            color1: c(0.20,0.38,0.75), color2: c(0.12,0.22,0.55), color3: c(0.28,0.48,0.88),
            sunriseColors: [c(0.18,0.30,0.62), c(0.12,0.20,0.50), c(0.22,0.35,0.70)],
            dayColors:     [c(0.18,0.32,0.68), c(0.10,0.18,0.48), c(0.24,0.40,0.78)],
            sunsetColors:  [c(0.14,0.24,0.55), c(0.10,0.18,0.42), c(0.18,0.28,0.62)],
            nightColors:   [c(0.06,0.08,0.22), c(0.10,0.14,0.32), c(0.04,0.06,0.16)],
            urgentColor: c(0.95,0.30,0.30), kindaUrgentColor: c(0.95,0.72,0.18), notUrgentColor: c(0.20,0.38,0.75)
        ),
        // ── Cyberpunk: electric neons searing against dark grids ──
        ThemeOption(
            id: "cyberpunk", name: "Cyberpunk",
            color1: c(0.00,1.00,0.40), color2: c(1.00,0.95,0.00), color3: c(0.00,0.95,1.00),
            sunriseColors: [c(0.00,0.90,0.20), c(0.80,1.00,0.00), c(0.05,0.08,0.15)],
            dayColors:     [c(0.00,1.00,0.45), c(0.00,0.95,0.95), c(0.90,1.00,0.00)],
            sunsetColors:  [c(1.00,0.00,0.90), c(0.60,0.00,1.00), c(0.10,0.10,0.20)],
            nightColors:   [c(0.00,0.90,0.30), c(1.00,0.00,0.70), c(0.05,0.05,0.18)],
            urgentColor: c(1.00,0.10,0.65), kindaUrgentColor: c(1.00,0.95,0.00), notUrgentColor: c(0.00,1.00,0.40)
        ),
        // ── Sage: muted green forest calm, earthy and grounding ──
        ThemeOption(
            id: "sage", name: "Sage",
            color1: c(0.42,0.62,0.46), color2: c(0.32,0.50,0.36), color3: c(0.55,0.72,0.52),
            sunriseColors: [c(0.50,0.68,0.48), c(0.40,0.58,0.38), c(0.58,0.75,0.52)],
            dayColors:     [c(0.40,0.60,0.44), c(0.32,0.50,0.36), c(0.50,0.68,0.48)],
            sunsetColors:  [c(0.30,0.45,0.32), c(0.24,0.38,0.26), c(0.36,0.52,0.38)],
            nightColors:   [c(0.12,0.20,0.14), c(0.18,0.28,0.20), c(0.08,0.14,0.10)],
            urgentColor: c(0.88,0.28,0.20), kindaUrgentColor: c(0.92,0.72,0.18), notUrgentColor: c(0.42,0.62,0.46)
        ),
        // ── Forest: lush emerald canopy, fireflies at night ──
        ThemeOption(
            id: "forest", name: "Forest",
            color1: c(0.10,0.65,0.20), color2: c(0.25,0.75,0.15), color3: c(0.50,0.80,0.10),
            sunriseColors: [c(0.60,0.88,0.25), c(0.35,0.70,0.15), c(0.80,0.95,0.35)],
            dayColors:     [c(0.12,0.68,0.18), c(0.05,0.55,0.08), c(0.35,0.78,0.12)],
            sunsetColors:  [c(0.25,0.55,0.10), c(0.40,0.42,0.05), c(0.18,0.48,0.10)],
            nightColors:   [c(0.08,0.40,0.10), c(0.15,0.55,0.15), c(0.05,0.28,0.06)],
            urgentColor: c(0.85,0.15,0.10), kindaUrgentColor: c(0.90,0.68,0.15), notUrgentColor: c(0.10,0.65,0.20)
        ),
        // ── Ocean: tropical reef to abyssal blue, vivid bioluminescence at night ──
        ThemeOption(
            id: "ocean", name: "Ocean",
            color1: c(0.00,0.55,0.95), color2: c(0.00,0.80,0.90), color3: c(0.30,0.90,0.95),
            sunriseColors: [c(0.45,0.90,0.95), c(0.00,0.75,0.90), c(0.65,0.95,1.00)],
            dayColors:     [c(0.00,0.55,0.95), c(0.00,0.82,1.00), c(0.20,0.85,0.95)],
            sunsetColors:  [c(0.00,0.40,0.80), c(0.15,0.25,0.70), c(0.00,0.55,0.85)],
            nightColors:   [c(0.00,0.25,0.70), c(0.00,0.45,0.85), c(0.00,0.18,0.55)],
            urgentColor: c(0.95,0.30,0.25), kindaUrgentColor: c(1.00,0.78,0.15), notUrgentColor: c(0.00,0.55,0.95)
        ),
        // ── Stone: warm charcoal, grounding and distraction-free ──
        ThemeOption(
            id: "stone", name: "Stone",
            color1: c(0.58,0.52,0.48), color2: c(0.45,0.40,0.36), color3: c(0.68,0.62,0.56),
            sunriseColors: [c(0.65,0.58,0.52), c(0.55,0.48,0.42), c(0.72,0.65,0.58)],
            dayColors:     [c(0.55,0.50,0.46), c(0.48,0.42,0.38), c(0.62,0.56,0.52)],
            sunsetColors:  [c(0.42,0.36,0.32), c(0.35,0.30,0.26), c(0.50,0.44,0.40)],
            nightColors:   [c(0.14,0.12,0.10), c(0.20,0.18,0.16), c(0.10,0.08,0.06)],
            urgentColor: c(0.90,0.28,0.20), kindaUrgentColor: c(0.90,0.68,0.18), notUrgentColor: c(0.58,0.52,0.48)
        ),
        // ── Amber: golden warm focus, soft candlelight at night ──
        ThemeOption(
            id: "amber", name: "Amber",
            color1: c(0.92,0.70,0.22), color2: c(0.80,0.55,0.12), color3: c(1.00,0.82,0.32),
            sunriseColors: [c(1.00,0.85,0.38), c(0.98,0.75,0.22), c(1.00,0.90,0.42)],
            dayColors:     [c(0.92,0.72,0.24), c(0.85,0.62,0.16), c(1.00,0.80,0.30)],
            sunsetColors:  [c(0.75,0.48,0.10), c(0.62,0.36,0.06), c(0.82,0.52,0.12)],
            nightColors:   [c(0.28,0.16,0.04), c(0.42,0.24,0.06), c(0.20,0.10,0.02)],
            urgentColor: c(0.88,0.18,0.12), kindaUrgentColor: c(0.92,0.70,0.22), notUrgentColor: c(0.28,0.72,0.50)
        ),
        // ── Dusk: twilight purple-blue, calming and immersive ──
        ThemeOption(
            id: "dusk", name: "Dusk",
            color1: c(0.45,0.38,0.80), color2: c(0.28,0.22,0.62), color3: c(0.60,0.52,0.90),
            sunriseColors: [c(0.52,0.42,0.82), c(0.40,0.30,0.68), c(0.62,0.52,0.90)],
            dayColors:     [c(0.42,0.36,0.78), c(0.32,0.26,0.62), c(0.52,0.44,0.84)],
            sunsetColors:  [c(0.35,0.26,0.65), c(0.25,0.18,0.52), c(0.45,0.34,0.72)],
            nightColors:   [c(0.10,0.08,0.28), c(0.18,0.14,0.42), c(0.06,0.05,0.20)],
            urgentColor: c(0.95,0.28,0.42), kindaUrgentColor: c(0.95,0.75,0.20), notUrgentColor: c(0.45,0.38,0.80)
        ),
        // ── Cute: bubblegum pastels, warm cotton candy evening ──
        ThemeOption(
            id: "cute", name: "Cute",
            color1: c(1.00,0.68,0.82), color2: c(0.68,0.95,0.82), color3: c(0.68,0.85,1.00),
            sunriseColors: [c(1.00,0.85,0.68), c(1.00,0.75,0.80), c(1.00,0.88,0.82)],
            dayColors:     [c(0.68,0.85,1.00), c(0.68,0.95,0.82), c(0.85,0.75,1.00)],
            sunsetColors:  [c(1.00,0.58,0.72), c(1.00,0.68,0.48), c(0.98,0.65,0.82)],
            nightColors:   [c(0.65,0.30,0.78), c(0.82,0.25,0.60), c(0.50,0.22,0.68)],
            urgentColor: c(1.00,0.35,0.55), kindaUrgentColor: c(1.00,0.68,0.82), notUrgentColor: c(0.68,0.95,0.82)
        ),
        // ── Aurora: northern lights — teal/mint canopy, violet crown ──
        ThemeOption(
            id: "aurora", name: "Aurora",
            color1: c(0.10,0.88,0.80), color2: c(0.08,0.68,0.62), color3: c(0.55,0.32,0.90),
            sunriseColors: [c(0.20,0.92,0.82), c(0.42,0.88,0.72), c(0.08,0.72,0.65)],
            dayColors:     [c(0.05,0.90,0.78), c(0.12,0.75,0.88), c(0.28,0.95,0.70)],
            sunsetColors:  [c(0.40,0.28,0.88), c(0.10,0.65,0.75), c(0.60,0.18,0.80)],
            nightColors:   [c(0.05,0.18,0.38), c(0.48,0.15,0.82), c(0.08,0.55,0.62)],
            urgentColor: c(1.00,0.30,0.50), kindaUrgentColor: c(1.00,0.80,0.20), notUrgentColor: c(0.10,0.88,0.80)
        ),
        // ── Sakura: cherry blossom — petal pink dawn, deep plum night ──
        ThemeOption(
            id: "sakura", name: "Sakura",
            color1: c(1.00,0.72,0.82), color2: c(0.98,0.55,0.68), color3: c(1.00,0.88,0.92),
            sunriseColors: [c(1.00,0.88,0.78), c(1.00,0.78,0.82), c(0.98,0.90,0.88)],
            dayColors:     [c(1.00,0.75,0.84), c(0.92,0.72,0.95), c(1.00,0.82,0.90)],
            sunsetColors:  [c(0.92,0.42,0.62), c(0.80,0.30,0.58), c(1.00,0.50,0.68)],
            nightColors:   [c(0.45,0.12,0.32), c(0.62,0.18,0.45), c(0.35,0.08,0.25)],
            urgentColor: c(0.85,0.12,0.35), kindaUrgentColor: c(1.00,0.65,0.25), notUrgentColor: c(0.58,0.90,0.78)
        ),
        // ── Ember: glowing coals — amber forge to smouldering dark ──
        ThemeOption(
            id: "ember", name: "Ember",
            color1: c(1.00,0.45,0.08), color2: c(0.92,0.28,0.04), color3: c(1.00,0.68,0.10),
            sunriseColors: [c(1.00,0.78,0.18), c(1.00,0.60,0.10), c(0.95,0.82,0.22)],
            dayColors:     [c(1.00,0.50,0.08), c(0.92,0.38,0.05), c(1.00,0.65,0.12)],
            sunsetColors:  [c(0.85,0.22,0.04), c(0.70,0.14,0.03), c(1.00,0.32,0.05)],
            nightColors:   [c(0.38,0.08,0.02), c(0.58,0.14,0.03), c(0.28,0.05,0.01)],
            urgentColor: c(0.95,0.12,0.05), kindaUrgentColor: c(1.00,0.65,0.10), notUrgentColor: c(0.20,0.75,0.45)
        ),
        // ── Slate: industrial steel-blue, cool and crisp all day ──
        ThemeOption(
            id: "slate", name: "Slate",
            color1: c(0.42,0.55,0.75), color2: c(0.35,0.45,0.62), color3: c(0.56,0.66,0.82),
            sunriseColors: [c(0.55,0.68,0.85), c(0.45,0.58,0.75), c(0.62,0.72,0.88)],
            dayColors:     [c(0.42,0.55,0.75), c(0.48,0.60,0.78), c(0.38,0.50,0.70)],
            sunsetColors:  [c(0.32,0.42,0.62), c(0.28,0.38,0.55), c(0.38,0.45,0.65)],
            nightColors:   [c(0.15,0.20,0.35), c(0.22,0.28,0.45), c(0.10,0.15,0.28)],
            urgentColor: c(0.92,0.28,0.22), kindaUrgentColor: c(0.95,0.72,0.18), notUrgentColor: c(0.42,0.55,0.75)
        ),
        // ── Live: real-time sky — golden dawn, azure day, violet dusk, deep night ──
        ThemeOption(
            id: "live", name: "Live",
            color1: c(0.30,0.62,0.92), color2: c(1.00,0.72,0.25), color3: c(0.12,0.08,0.28),
            sunriseColors: [c(1.00,0.62,0.28), c(0.95,0.42,0.22), c(0.85,0.48,0.42)],
            dayColors:     [c(0.28,0.58,0.90), c(0.42,0.70,0.95), c(0.18,0.48,0.85)],
            sunsetColors:  [c(0.92,0.45,0.18), c(0.72,0.22,0.40), c(0.48,0.18,0.55)],
            nightColors:   [c(0.04,0.04,0.18), c(0.07,0.07,0.28), c(0.02,0.02,0.12)],
            urgentColor: c(0.90,0.20,0.20), kindaUrgentColor: c(1.00,0.72,0.25), notUrgentColor: c(0.28,0.58,0.90)
        ),
        // ── Mono: pure grayscale, timeless and minimal ──
        ThemeOption(
            id: "mono", name: "Mono",
            color1: c(0.80,0.80,0.82), color2: c(0.55,0.55,0.58), color3: c(0.68,0.68,0.70),
            sunriseColors: [c(0.72,0.72,0.75), c(0.62,0.62,0.65), c(0.80,0.80,0.82)],
            dayColors:     [c(0.58,0.58,0.60), c(0.50,0.50,0.52), c(0.65,0.65,0.68)],
            sunsetColors:  [c(0.42,0.42,0.45), c(0.35,0.35,0.38), c(0.48,0.48,0.50)],
            nightColors:   [c(0.12,0.12,0.14), c(0.22,0.22,0.24), c(0.08,0.08,0.10)],
            urgentColor: c(0.88,0.28,0.22), kindaUrgentColor: c(0.80,0.80,0.82), notUrgentColor: c(0.55,0.55,0.58)
        ),
        // ── Tangerine: citrus burst — bright orange/yellow all day ──
        ThemeOption(
            id: "tangerine", name: "Tangerine",
            color1: c(1.00,0.58,0.00), color2: c(1.00,0.78,0.10), color3: c(0.95,0.42,0.00),
            sunriseColors: [c(1.00,0.88,0.20), c(1.00,0.75,0.08), c(0.98,0.82,0.18)],
            dayColors:     [c(1.00,0.60,0.00), c(1.00,0.72,0.05), c(0.95,0.50,0.00)],
            sunsetColors:  [c(0.90,0.35,0.00), c(0.80,0.25,0.02), c(0.95,0.40,0.00)],
            nightColors:   [c(0.42,0.15,0.00), c(0.60,0.22,0.00), c(0.32,0.10,0.00)],
            urgentColor: c(0.92,0.12,0.08), kindaUrgentColor: c(1.00,0.78,0.10), notUrgentColor: c(0.18,0.75,0.48)
        ),
        // ── Galaxy: deep space — indigo void, violet nebula, star-white ──
        ThemeOption(
            id: "galaxy", name: "Galaxy",
            color1: c(0.38,0.20,0.90), color2: c(0.55,0.12,0.75), color3: c(0.88,0.88,1.00),
            sunriseColors: [c(0.32,0.15,0.78), c(0.48,0.10,0.65), c(0.22,0.10,0.58)],
            dayColors:     [c(0.40,0.22,0.92), c(0.28,0.12,0.78), c(0.52,0.18,0.85)],
            sunsetColors:  [c(0.58,0.08,0.72), c(0.75,0.05,0.58), c(0.42,0.08,0.65)],
            nightColors:   [c(0.08,0.04,0.28), c(0.32,0.08,0.62), c(0.05,0.03,0.18)],
            urgentColor: c(1.00,0.25,0.45), kindaUrgentColor: c(0.55,0.12,0.75), notUrgentColor: c(0.38,0.20,0.90)
        ),
    ]

    static func find(_ id: String) -> ThemeOption {
        all.first { $0.id == id } ?? all[0]
    }
}

// Shorthand color constructor for readability above
private func c(_ r: Double, _ g: Double, _ b: Double) -> Color {
    Color(red: r, green: g, blue: b)
}

// MARK: - Theme Card

struct ThemeCard: View {
    let theme: ThemeOption
    let isSelected: Bool
    var accentOnly: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            if accentOnly {
                Circle()
                    .fill(theme.color1)
                    .frame(width: 42, height: 42)
            } else {
                ZStack {
                    Circle()
                        .fill(theme.color3)
                        .frame(width: 30, height: 30)
                        .offset(x: 19)
                    Circle()
                        .fill(theme.color2)
                        .frame(width: 30, height: 30)
                    Circle()
                        .fill(theme.color1)
                        .frame(width: 30, height: 30)
                        .offset(x: -19)
                }
                .frame(width: 72, height: 30)
            }

            Text(theme.name)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(width: 100, height: 100)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.17, green: 0.17, blue: 0.19))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? theme.color1 : Color.clear, lineWidth: 2.5)
        )
        .shadow(
            color: isSelected ? theme.color1.opacity(0.6) : .clear,
            radius: 10, x: 0, y: 0
        )
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Theme Picker View

struct ThemePickerView: View {
    @AppStorage("selectedTheme") private var selectedTheme = "original"
    @AppStorage("themeMode")     private var themeMode     = "full"
    @EnvironmentObject private var gradientManager: SunsetGradientManager

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.12).ignoresSafeArea()

            VStack(spacing: 0) {
                Picker("", selection: $themeMode) {
                    Text("Full Background").tag("full")
                    Text("Accent Only").tag("accent")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .onChange(of: themeMode) { _, _ in
                    gradientManager.updateGradient()
                }

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppThemes.all) { theme in
                            ThemeCard(
                                theme: theme,
                                isSelected: selectedTheme == theme.id,
                                accentOnly: themeMode == "accent"
                            )
                            .onTapGesture {
                                selectedTheme = theme.id
                                gradientManager.updateGradient()
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark)
    }
}

#Preview {
    NavigationStack {
        ThemePickerView()
            .environmentObject(SunsetGradientManager())
    }
}
