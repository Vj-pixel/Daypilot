import SwiftUI
import CoreLocation

// MARK: - Dispatcher

struct ThemeParticleView: View {
    @AppStorage("selectedTheme") private var selectedTheme = "original"

    var body: some View {
        switch selectedTheme {
        case "galaxy":
            GalaxyView()
        case "midnight":
            TwinklingStars()
        case "aurora":
            AuroraWaves()
        case "sakura":
            FallingParticles(cfg: .petals)
        case "ember":
            ZStack {
                SmokeView()
                FallingParticles(cfg: .sparks)
            }
        case "forest":
            FallingParticles(cfg: .leaves)
        case "ocean":
            FallingParticles(cfg: .bubbles)
        case "cyberpunk":
            CyberpunkGrid()
        case "deep":
            SeaCreaturesView()
        case "sage":
            GrowingVines()
        case "stone":
            FallingStones()
        case "amber":
            CometsView()
        case "cute":
            FallingParticles(cfg: .hearts)
        case "tangerine":
            FallingParticles(cfg: .sparkles)
        case "slate":
            FallingParticles(cfg: .dust)
        case "live":
            LiveSkyView()
        default:
            EmptyView()
        }
    }
}

// MARK: - View Extension

extension View {
    func themedBackground(_ gradient: LinearGradient) -> some View {
        background {
            ZStack {
                gradient
                ThemeParticleView()
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Shared PRNG

private struct LCG {
    var state: UInt64
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
    mutating func lerp(_ lo: Double, _ hi: Double) -> Double { lo + next() * (hi - lo) }
}

// MARK: - Galaxy (animated spiral)

private struct GalaxyView: View {

    struct ArmStar {
        let baseAngle: Double
        let r: Double
        let dotAlpha: Double
        let dotR: CGFloat
        let dustAlpha: Double
        let dustR: CGFloat
        let dustColor: Color
    }
    struct BgStar { let x, y: Double; let alpha: Double; let r: CGFloat }

    private let armStars: [ArmStar]
    private let bgStars:  [BgStar]

    init() {
        var rng  = LCG(state: 9901)
        let perArm = 85
        let nebColors: [Color] = [
            Color(red: 0.55, green: 0.32, blue: 0.95),
            Color(red: 0.40, green: 0.58, blue: 1.00),
            Color(red: 0.80, green: 0.62, blue: 1.00),
            Color(red: 0.30, green: 0.20, blue: 0.88),
        ]
        var stars: [ArmStar] = []
        for arm in [0.0, Double.pi] {
            for i in 0..<perArm {
                let t       = Double(i) / Double(perArm)
                let theta   = t * .pi * 3.0
                let scatter = rng.lerp(-0.14, 0.14)
                let rScatt  = rng.lerp(-0.05, 0.05)
                let r       = max(0.05, t * 0.93 + rScatt)
                let inner   = t < 0.18
                let ci      = Int(rng.next() * Double(nebColors.count))
                stars.append(ArmStar(
                    baseAngle: arm + theta + scatter,
                    r:         r,
                    dotAlpha:  rng.lerp(0.50, 0.92),
                    dotR:      CGFloat(rng.lerp(0.5, inner ? 2.2 : 1.5)),
                    dustAlpha: t < 0.85 ? rng.lerp(0.04, 0.10) : 0,
                    dustR:     CGFloat(rng.lerp(6, inner ? 20 : 12)),
                    dustColor: nebColors[ci % nebColors.count]
                ))
            }
        }
        armStars = stars
        bgStars  = (0..<70).map { _ in
            BgStar(x: rng.next(), y: rng.next(),
                   alpha: rng.lerp(0.12, 0.50),
                   r: CGFloat(rng.lerp(0.4, 1.4)))
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { tl in
            Canvas { ctx, size in
                let t   = tl.date.timeIntervalSinceReferenceDate
                let rot = t * 0.016
                let cx  = size.width  * 0.50
                let cy  = size.height * 0.62   // shifted down
                let sc  = min(size.width, size.height) * 0.38
                let ax: CGFloat = 1.00
                let ay: CGFloat = 0.40

                for s in bgStars {
                    ctx.opacity = s.alpha
                    let px = CGFloat(s.x) * size.width
                    let py = CGFloat(s.y) * size.height
                    ctx.fill(Path(ellipseIn: CGRect(x: px - s.r, y: py - s.r,
                                                    width: s.r * 2, height: s.r * 2)),
                             with: .color(.white))
                }

                let dk = sc * 1.12
                ctx.opacity = 0.07
                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx - dk * ax, y: cy - dk * ay,
                                           width: dk * 2 * ax, height: dk * 2 * ay)),
                    with: .color(Color(red: 0.50, green: 0.35, blue: 0.90)))

                for s in armStars where s.dustAlpha > 0 {
                    let ang = s.baseAngle + rot
                    let rx  = CGFloat(s.r) * sc
                    let px  = cx + rx * CGFloat(cos(ang)) * ax
                    let py  = cy + rx * CGFloat(sin(ang)) * ay
                    let dr  = s.dustR
                    ctx.opacity = s.dustAlpha
                    ctx.fill(Path(ellipseIn: CGRect(x: px - dr, y: py - dr,
                                                    width: dr * 2, height: dr * 2)),
                             with: .color(s.dustColor))
                }

                let coreLayers: [(CGFloat, Double, Color)] = [
                    (sc * 0.38, 0.07, Color(red: 0.50, green: 0.32, blue: 0.92)),
                    (sc * 0.22, 0.14, Color(red: 0.68, green: 0.50, blue: 1.00)),
                    (sc * 0.10, 0.30, Color(red: 0.85, green: 0.75, blue: 1.00)),
                    (sc * 0.04, 0.70, Color.white),
                ]
                for (cr, al, col) in coreLayers {
                    ctx.opacity = al
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: cx - cr * ax, y: cy - cr * ay,
                                               width: cr * 2 * ax, height: cr * 2 * ay)),
                        with: .color(col))
                }

                for s in armStars {
                    let ang = s.baseAngle + rot
                    let rx  = CGFloat(s.r) * sc
                    let px  = cx + rx * CGFloat(cos(ang)) * ax
                    let py  = cy + rx * CGFloat(sin(ang)) * ay
                    ctx.opacity = s.dotAlpha
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - s.dotR, y: py - s.dotR,
                                               width: s.dotR * 2, height: s.dotR * 2)),
                        with: .color(.white))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Twinkling Stars (Midnight)

private struct TwinklingStars: View {
    struct TStar {
        let x, y: Double
        let baseAlpha, amp, hz, phase: Double
        let r: CGFloat
    }
    private static let stars: [TStar] = {
        var rng = LCG(state: 777)
        return (0..<90).map { _ in
            let r = CGFloat(rng.lerp(0.5, 1.8))
            return TStar(x: rng.next(), y: rng.next(),
                         baseAlpha: rng.lerp(0.28, 0.65),
                         amp:   rng.lerp(0.06, 0.22),
                         hz:    rng.lerp(0.3, 1.8),
                         phase: rng.lerp(0, .pi * 2),
                         r: r)
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for s in Self.stars {
                    let alpha = max(0, s.baseAlpha + s.amp * sin(t * s.hz + s.phase))
                    let px = CGFloat(s.x) * size.width
                    let py = CGFloat(s.y) * size.height
                    ctx.opacity = alpha
                    ctx.fill(Path(ellipseIn: CGRect(x: px - s.r, y: py - s.r,
                                                    width: s.r * 2, height: s.r * 2)),
                             with: .color(.white))
                    if s.r > 1.3 {
                        let g = s.r * 3.2
                        ctx.opacity = alpha * 0.18
                        ctx.fill(Path(ellipseIn: CGRect(x: px - g, y: py - g,
                                                        width: g * 2, height: g * 2)),
                                 with: .color(.white))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Aurora Waves

private struct AuroraWaves: View {
    private struct Band {
        let yRatio, amp, freq, speed, alpha: Double
        let color: Color
    }
    private let bands: [Band] = [
        Band(yRatio: 0.25, amp: 0.07, freq: 1.5, speed: 0.20, alpha: 0.22,
             color: Color(red: 0.08, green: 0.92, blue: 0.80)),
        Band(yRatio: 0.40, amp: 0.05, freq: 2.0, speed: 0.14, alpha: 0.16,
             color: Color(red: 0.48, green: 0.18, blue: 0.90)),
        Band(yRatio: 0.16, amp: 0.04, freq: 1.2, speed: 0.26, alpha: 0.14,
             color: Color(red: 0.06, green: 0.75, blue: 0.62)),
    ]
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for b in bands {
                    let baseY = b.yRatio * size.height
                    let amp   = b.amp * size.height
                    let steps = max(Int(size.width / 3), 2)
                    var path  = Path()
                    for i in 0...steps {
                        let xf = Double(i) / Double(steps)
                        let y  = baseY + amp * sin(b.freq * .pi * 2 * xf + t * b.speed)
                        let pt = CGPoint(x: xf * size.width, y: y)
                        i == 0 ? path.move(to: pt) : path.addLine(to: pt)
                    }
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.addLine(to: CGPoint(x: 0, y: size.height))
                    path.closeSubpath()
                    ctx.opacity = b.alpha
                    ctx.fill(path, with: .color(b.color))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Shape Paths

private func petalPath(_ s: CGFloat) -> Path {
    Path { p in
        let w = s * 0.44, h = s * 0.60
        p.move(to: CGPoint(x: 0, y: h))
        p.addCurve(to: CGPoint(x: 0, y: -h),
                   control1: CGPoint(x:  w * 1.15, y:  h * 0.45),
                   control2: CGPoint(x:  w * 1.15, y: -h * 0.45))
        p.addCurve(to: CGPoint(x: 0, y: h),
                   control1: CGPoint(x: -w * 0.60, y: -h * 0.45),
                   control2: CGPoint(x: -w * 0.60, y:  h * 0.45))
    }
}

private func leafPath(_ s: CGFloat) -> Path {
    Path { p in
        let w = s * 0.28, h = s * 0.62
        p.move(to: CGPoint(x: 0, y: -h))
        p.addCurve(to: CGPoint(x: 0, y: h),
                   control1: CGPoint(x:  w, y: -h * 0.3),
                   control2: CGPoint(x:  w,  y:  h * 0.3))
        p.addCurve(to: CGPoint(x: 0, y: -h),
                   control1: CGPoint(x: -w,  y:  h * 0.3),
                   control2: CGPoint(x: -w,  y: -h * 0.3))
    }
}

private func heartPath(_ s: CGFloat) -> Path {
    let r = s * 0.40
    return Path { p in
        p.move(to: CGPoint(x: 0, y: s * 0.52))
        p.addCurve(to: CGPoint(x: -r * 2, y: -r * 0.28),
                   control1: CGPoint(x: -r * 0.22, y: s * 0.32),
                   control2: CGPoint(x: -r * 2.00, y: r * 0.38))
        p.addArc(center: CGPoint(x: -r, y: -r * 0.80),
                 radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x:  r, y: -r * 0.80),
                 radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: 0, y: s * 0.52),
                   control1: CGPoint(x:  r * 2.00, y: r * 0.38),
                   control2: CGPoint(x:  r * 0.22, y: s * 0.32))
    }
}

private func sparkPath(_ s: CGFloat) -> Path {
    Path { p in
        let w = s * 0.14, h = s * 0.62
        p.move(to: CGPoint(x: 0, y: -h))
        p.addCurve(to: CGPoint(x: 0, y: h * 0.38),
                   control1: CGPoint(x:  w, y: -h * 0.2),
                   control2: CGPoint(x:  w,  y:  h * 0.1))
        p.addCurve(to: CGPoint(x: 0, y: -h),
                   control1: CGPoint(x: -w,  y:  h * 0.1),
                   control2: CGPoint(x: -w,  y: -h * 0.2))
    }
}

private func sparklePath(_ s: CGFloat) -> Path {
    Path { p in
        let r1 = s * 0.50, r2 = s * 0.14
        for i in 0..<8 {
            let a  = Double(i) * .pi / 4
            let r  = i % 2 == 0 ? r1 : r2
            let pt = CGPoint(x: CGFloat(cos(a)) * r, y: CGFloat(sin(a)) * r)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
    }
}

// MARK: - Particle Config

private enum PConfig {
    case petals, sparks, leaves, bubbles, hearts
    case sparkles, dust

    var count: Int {
        switch self {
        case .petals:   return 22
        case .sparks:   return 24
        case .leaves:   return 20
        case .bubbles:  return 20
        case .hearts:   return 8
        case .sparkles: return 10
        case .dust:     return 12
        }
    }
    var color: Color {
        switch self {
        case .petals:   return Color(red: 1.00, green: 0.74, blue: 0.84)
        case .sparks:   return Color(red: 1.00, green: 0.60, blue: 0.08)
        case .leaves:   return Color(red: 0.28, green: 0.76, blue: 0.22)
        case .bubbles:  return Color(red: 0.48, green: 0.88, blue: 0.96)
        case .hearts:   return Color(red: 1.00, green: 0.62, blue: 0.78)
        case .sparkles: return Color(red: 1.00, green: 0.72, blue: 0.12)
        case .dust:     return Color(red: 0.72, green: 0.82, blue: 0.95)
        }
    }
    var sizeRange: (lo: Double, hi: Double) {
        switch self {
        case .petals:   return (10, 24)
        case .sparks:   return (7,  16)
        case .leaves:   return (10, 22)
        case .bubbles:  return (14, 32)
        case .hearts:   return (9,  20)
        case .sparkles: return (4,  10)
        case .dust:     return (2,   6)
        }
    }
    var risesUp: Bool {
        switch self {
        case .sparks, .bubbles, .dust: return true
        default: return false
        }
    }
    var rotates: Bool {
        switch self {
        case .bubbles, .dust: return false
        default: return true
        }
    }
    var baseAlpha: Double {
        switch self {
        case .bubbles: return 0.70
        default:       return 0.45
        }
    }
    var seed: UInt64 {
        switch self {
        case .petals:   return 101
        case .sparks:   return 202
        case .leaves:   return 303
        case .bubbles:  return 404
        case .hearts:   return 505
        case .sparkles: return 606
        case .dust:     return 808
        }
    }
}

// MARK: - Falling / Rising Particles

private struct FallingParticles: View {

    struct P {
        let startX, speed, sway, swayHz, phase, rotHz: Double
        let size: CGFloat
    }

    let cfg: PConfig
    private let parts: [P]

    init(cfg: PConfig) {
        self.cfg = cfg
        var rng  = LCG(state: cfg.seed)
        let sr   = cfg.sizeRange
        parts = (0..<cfg.count).map { _ in
            P(startX: rng.next(),
              speed:   rng.lerp(0.022, 0.052),
              sway:    rng.lerp(12, 42),
              swayHz:  rng.lerp(0.22, 0.88),
              phase:   rng.lerp(0, .pi * 2),
              rotHz:   cfg.rotates ? rng.lerp(-1.6, 1.6) : 0,
              size:    CGFloat(rng.lerp(sr.lo, sr.hi)))
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            Canvas { ctx, size in
                let t   = tl.date.timeIntervalSinceReferenceDate
                let col = cfg.color

                // Hearts: contrasting color based on hour for visibility
                let hour = Calendar.current.component(.hour, from: tl.date)
                let heartFill: Color = (hour >= 6 && hour < 19)
                    ? Color(red: 0.85, green: 0.10, blue: 0.52)
                    : Color(red: 1.00, green: 0.80, blue: 0.92)

                for p in parts {
                    let prog  = fmod((p.phase / (.pi * 2)) + t * p.speed, 1.0)
                    let rawY  = cfg.risesUp ? (1.0 - prog) : prog
                    let y     = rawY * size.height
                    let x     = p.startX * size.width + sin(t * p.swayHz + p.phase) * p.sway
                    let fade  = sin(max(0, prog) * .pi)
                    let alpha = cfg.baseAlpha * fade

                    switch cfg {

                    case .petals:
                        ctx.drawLayer { c in
                            c.translateBy(x: x, y: y)
                            c.rotate(by: .degrees(t * p.rotHz * 40))
                            c.opacity = alpha
                            c.fill(petalPath(p.size), with: .color(col))
                            c.opacity = alpha * 0.50
                            c.fill(petalPath(p.size * 0.55),
                                   with: .color(Color(red: 1, green: 0.92, blue: 0.96)))
                        }

                    case .leaves:
                        ctx.drawLayer { c in
                            c.translateBy(x: x, y: y)
                            c.rotate(by: .degrees(t * p.rotHz * 40))
                            c.opacity = alpha
                            c.fill(leafPath(p.size), with: .color(col))
                            c.opacity = alpha * 0.55
                            var vein = Path()
                            vein.move(to: CGPoint(x: 0, y: -p.size * 0.58))
                            vein.addLine(to: CGPoint(x: 0,  y:  p.size * 0.58))
                            c.stroke(vein, with: .color(Color(red: 0.15, green: 0.55, blue: 0.10)),
                                     lineWidth: 0.8)
                        }

                    case .hearts:
                        ctx.drawLayer { c in
                            c.translateBy(x: x, y: y)
                            c.rotate(by: .degrees(t * p.rotHz * 30))
                            c.opacity = alpha
                            c.fill(heartPath(p.size), with: .color(heartFill))
                            c.opacity = alpha * 0.40
                            c.stroke(heartPath(p.size), with: .color(.white), lineWidth: 1.0)
                        }

                    case .sparks:
                        ctx.drawLayer { c in
                            c.translateBy(x: x, y: y)
                            c.rotate(by: .degrees(t * p.rotHz * 50))
                            let gr = p.size * 0.45
                            c.opacity = alpha * 0.32
                            c.fill(
                                Path(ellipseIn: CGRect(x: -gr, y: -gr, width: gr*2, height: gr*2)),
                                with: .color(Color(red: 1, green: 0.88, blue: 0.30)))
                            c.opacity = alpha
                            c.fill(sparkPath(p.size), with: .color(col))
                            c.opacity = alpha * 0.85
                            c.fill(
                                Path(ellipseIn: CGRect(x: -p.size*0.12, y: -p.size*0.58,
                                                       width: p.size*0.24, height: p.size*0.24)),
                                with: .color(.white))
                        }

                    case .bubbles:
                        ctx.drawLayer { c in
                            c.translateBy(x: x, y: y)
                            let r    = p.size / 2
                            let circ = Path(ellipseIn: CGRect(x: -r, y: -r, width: r*2, height: r*2))
                            c.opacity = alpha * 0.25
                            c.fill(circ, with: .color(col))
                            c.opacity = alpha * 0.90
                            c.stroke(circ, with: .color(col), lineWidth: 2.2)
                            c.opacity = alpha
                            c.fill(
                                Path(ellipseIn: CGRect(x: -r*0.55, y: -r*0.65,
                                                       width: r*0.40, height: r*0.26)),
                                with: .color(.white))
                        }

                    case .sparkles:
                        ctx.drawLayer { c in
                            c.translateBy(x: x, y: y)
                            c.rotate(by: .degrees(t * p.rotHz * 55))
                            let gr = p.size * 0.50
                            c.opacity = alpha * 0.25
                            c.fill(
                                Path(ellipseIn: CGRect(x: -gr, y: -gr, width: gr*2, height: gr*2)),
                                with: .color(col))
                            c.opacity = alpha
                            c.fill(sparklePath(p.size), with: .color(col))
                            c.opacity = alpha * 0.75
                            c.fill(sparklePath(p.size * 0.48), with: .color(.white))
                        }

                    case .dust:
                        ctx.drawLayer { c in
                            c.translateBy(x: x, y: y)
                            let r  = p.size / 2
                            let gr = r * 3.0
                            c.opacity = alpha * 0.25
                            c.fill(
                                Path(ellipseIn: CGRect(x: -gr, y: -gr, width: gr*2, height: gr*2)),
                                with: .color(col))
                            c.opacity = alpha
                            c.fill(
                                Path(ellipseIn: CGRect(x: -r, y: -r, width: r*2, height: r*2)),
                                with: .color(col))
                            let cr = r * 0.45
                            c.opacity = alpha * 0.75
                            c.fill(
                                Path(ellipseIn: CGRect(x: -cr, y: -cr, width: cr*2, height: cr*2)),
                                with: .color(.white))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Ember Smoke

private struct SmokeView: View {

    // Blobs that churn/bubble anchored at the bottom edge
    struct BottomBlob { let x: Double; let r: CGFloat; let phase, hz: Double }
    // Distinct 3-lobe smoke puffs that rise
    struct RisePuff   { let baseX, speed, sway, swayHz, phase: Double; let r: CGFloat }

    private let blobs: [BottomBlob]
    private let puffs: [RisePuff]

    init() {
        var rng = LCG(state: 1313)
        blobs = (0..<22).map { _ in
            BottomBlob(x:     rng.lerp(0.0, 1.0),
                       r:     CGFloat(rng.lerp(24, 56)),
                       phase: rng.lerp(0, .pi * 2),
                       hz:    rng.lerp(0.12, 0.40))
        }
        puffs = (0..<11).map { _ in
            RisePuff(baseX:  rng.lerp(0.05, 0.95),
                     speed:  rng.lerp(0.010, 0.024),
                     sway:   rng.lerp(6, 20),
                     swayHz: rng.lerp(0.08, 0.22),
                     phase:  rng.lerp(0, .pi * 2),
                     r:      CGFloat(rng.lerp(13, 26)))
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate

                // ── Bottom churning smoke — blobs centered just below the screen ──
                for b in blobs {
                    let x     = CGFloat(b.x) * size.width
                    let pulse = sin(t * b.hz + b.phase)
                    let r     = b.r * CGFloat(1.0 + pulse * 0.10)
                    // Push center below bottom edge so only the top dome peeks up
                    let y     = size.height + r * 0.35 + CGFloat(pulse * 5.0)
                    ctx.opacity = 0.20 + pulse * 0.06
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - r, y: y - r,
                                               width: r * 2, height: r * 1.35)),
                        with: .color(Color(red: 0.10, green: 0.08, blue: 0.06)))
                }

                // ── Rising 3-lobe smoke puffs ────────────────────────────────────
                for pf in puffs {
                    let prog = fmod(pf.phase / (.pi * 2) + t * pf.speed, 1.0)
                    let y    = size.height * CGFloat(1.0 - prog)
                    guard y > size.height * 0.30 else { continue }

                    let x    = CGFloat(pf.baseX) * size.width
                             + CGFloat(sin(t * pf.swayHz + pf.phase) * pf.sway)
                    // Puff expands as it rises
                    let s    = pf.r * CGFloat(0.55 + prog * 1.55)
                    let fromBottom = Double((size.height - y) / (size.height * 0.70))
                    let alpha = min(1.0, fromBottom * 6.0) * (1.0 - fromBottom * 0.86) * 0.44

                    ctx.drawLayer { c in
                        c.translateBy(x: x, y: y)
                        // Main body — wide, slightly squashed ellipse
                        c.opacity = alpha
                        c.fill(
                            Path(ellipseIn: CGRect(x: -s * 0.58, y: -s * 0.40,
                                                   width: s * 1.16, height: s * 0.80)),
                            with: .color(Color(red: 0.24, green: 0.19, blue: 0.14)))
                        // Upper-left shoulder lobe
                        c.opacity = alpha * 0.88
                        c.fill(
                            Path(ellipseIn: CGRect(x: -s * 0.90, y: -s * 0.74,
                                                   width: s * 0.64, height: s * 0.58)),
                            with: .color(Color(red: 0.20, green: 0.16, blue: 0.12)))
                        // Upper-right shoulder lobe
                        c.fill(
                            Path(ellipseIn: CGRect(x:  s * 0.26, y: -s * 0.70,
                                                   width: s * 0.62, height: s * 0.56)),
                            with: .color(Color(red: 0.20, green: 0.16, blue: 0.12)))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Live Weather Service

private final class LiveWeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var cloudFraction: Double = 0.30
    @Published var isRaining: Bool = false

    private let manager = CLLocationManager()
    private var fetched = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard !fetched, let loc = locs.last else { return }
        fetched = true
        let lat = loc.coordinate.latitude, lon = loc.coordinate.longitude
        Task { await fetch(lat: lat, lon: lon) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    @MainActor
    private func fetch(lat: Double, lon: Double) async {
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=weather_code,cloud_cover&forecast_days=1"
        guard let url = URL(string: urlStr),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cur  = json["current"] as? [String: Any] else { return }
        let code  = cur["weather_code"] as? Int    ?? 0
        let cover = cur["cloud_cover"]  as? Double ?? 30
        cloudFraction = cover / 100.0
        isRaining = (51...82).contains(code) || (95...99).contains(code)
    }
}

// MARK: - Live Sky (sun arc + moon + stars + weather clouds)

private struct LiveSkyView: View {

    @StateObject private var weather = LiveWeatherService()

    struct NightStar { let x, y, alpha: Double; let r: CGFloat }
    struct LiveCloud  { let baseX, y, width, speed, phase: Double }

    private static let nightStars: [NightStar] = {
        var rng = LCG(state: 5050)
        return (0..<65).map { _ in
            NightStar(x: rng.next(), y: rng.lerp(0.02, 0.78),
                      alpha: rng.lerp(0.18, 0.55),
                      r: CGFloat(rng.lerp(0.4, 1.5)))
        }
    }()

    private static let clouds: [LiveCloud] = {
        var rng = LCG(state: 8181)
        return (0..<7).map { _ in
            LiveCloud(baseX:  rng.next(),
                      y:     rng.lerp(0.05, 0.40),
                      width: rng.lerp(90, 200),
                      speed: rng.lerp(0.006, 0.014),
                      phase: rng.next())
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { tl in
            Canvas { ctx, size in
                let now  = tl.date
                let t    = now.timeIntervalSinceReferenceDate
                let cal  = Calendar.current
                let hour = cal.component(.hour,   from: now)
                let mins = cal.component(.minute, from: now)
                let tod  = Double(hour) + Double(mins) / 60.0

                // ── Sun ──────────────────────────────────────────────────────────────
                let sunT   = (tod - 6.0) / 14.0
                let clampT = min(max(sunT, 0), 1)
                let sunNX  = 0.08 + clampT * 0.84
                let sunNY  = 0.88 - 4.0 * clampT * (1.0 - clampT) * 0.70
                let sunX   = CGFloat(sunNX) * size.width
                let sunY   = CGFloat(sunNY) * size.height

                var sunAlpha: Double = 1.0
                if tod <= 5.5 || tod >= 20.5 { sunAlpha = 0 }
                else if tod < 6.5            { sunAlpha = tod - 5.5 }
                else if tod > 19.5           { sunAlpha = 20.5 - tod }

                if sunAlpha > 0 {
                    let dist    = abs(clampT - 0.5) * 2
                    let sunCol  = Color(red: 1.0, green: 0.96 - dist * 0.44, blue: 0.75 - dist * 0.58)
                    let sunR    = CGFloat(28 + dist * 14)
                    let cloudOcc = weather.cloudFraction   // how much cloud dims sun
                    let effAlpha = sunAlpha * (1.0 - cloudOcc * 0.65)

                    for (gr, ga) in [(sunR * 5.0, 0.05), (sunR * 3.0, 0.10), (sunR * 1.8, 0.20)] as [(CGFloat, Double)] {
                        ctx.opacity = effAlpha * ga
                        ctx.fill(Path(ellipseIn: CGRect(x: sunX - gr, y: sunY - gr,
                                                        width: gr * 2, height: gr * 2)),
                                 with: .color(sunCol))
                    }

                    let rayRot = t * 0.04
                    for i in 0..<12 {
                        let angle = Double(i) * .pi / 6.0 + rayRot
                        let r1 = Double(sunR) * 1.40
                        let r2 = r1 + Double(sunR) * (i % 2 == 0 ? 0.90 : 0.50)
                        var ray = Path()
                        ray.move(to:    CGPoint(x: sunX + CGFloat(r1 * cos(angle)), y: sunY + CGFloat(r1 * sin(angle))))
                        ray.addLine(to: CGPoint(x: sunX + CGFloat(r2 * cos(angle)), y: sunY + CGFloat(r2 * sin(angle))))
                        ctx.opacity = effAlpha * 0.48
                        ctx.stroke(ray, with: .color(sunCol), lineWidth: 2.0)
                    }

                    ctx.opacity = effAlpha * 0.92
                    ctx.fill(Path(ellipseIn: CGRect(x: sunX - sunR, y: sunY - sunR,
                                                    width: sunR * 2, height: sunR * 2)),
                             with: .color(sunCol))
                    let coreR = sunR * 0.58
                    ctx.opacity = effAlpha
                    ctx.fill(Path(ellipseIn: CGRect(x: sunX - coreR, y: sunY - coreR,
                                                    width: coreR * 2, height: coreR * 2)),
                             with: .color(Color(red: 1.0, green: 0.98, blue: 0.90)))
                }

                // ── Moon + night stars ────────────────────────────────────────────
                var moonAlpha: Double = 1.0
                if tod >= 6.0 && tod <= 19.5      { moonAlpha = 0 }
                else if tod > 19.5 && tod <= 20.5 { moonAlpha = tod - 19.5 }
                else if tod >= 5.0 && tod < 6.0   { moonAlpha = 6.0 - tod }

                if moonAlpha > 0 {
                    let starMult = moonAlpha * (1.0 - weather.cloudFraction * 0.80)
                    for s in Self.nightStars {
                        ctx.opacity = s.alpha * starMult * 0.85
                        let px = CGFloat(s.x) * size.width
                        let py = CGFloat(s.y) * size.height
                        ctx.fill(Path(ellipseIn: CGRect(x: px - s.r, y: py - s.r,
                                                        width: s.r * 2, height: s.r * 2)),
                                 with: .color(.white))
                    }
                    let moonX = size.width * 0.72, moonY = size.height * 0.18
                    let moonR: CGFloat = 25
                    for (gr, ga) in [(moonR * 3.5, 0.10), (moonR * 1.8, 0.25)] as [(CGFloat, Double)] {
                        ctx.opacity = moonAlpha * ga
                        ctx.fill(Path(ellipseIn: CGRect(x: moonX - gr, y: moonY - gr,
                                                        width: gr * 2, height: gr * 2)),
                                 with: .color(.white))
                    }
                    ctx.opacity = moonAlpha * 0.92
                    ctx.fill(Path(ellipseIn: CGRect(x: moonX - moonR, y: moonY - moonR,
                                                    width: moonR * 2, height: moonR * 2)),
                             with: .color(Color(red: 0.96, green: 0.96, blue: 0.88)))
                }

                // ── Drifting clouds ───────────────────────────────────────────────
                let cloudAlpha = weather.cloudFraction * 0.78
                guard cloudAlpha > 0.02 else { return }

                for cloud in Self.clouds {
                    let prog = fmod(cloud.phase + t * cloud.speed, 1.0)
                    let cx   = CGFloat(prog) * (size.width + CGFloat(cloud.width) * 2)
                              - CGFloat(cloud.width)
                    let cy   = CGFloat(cloud.y) * size.height
                    let w    = CGFloat(cloud.width)
                    let h    = w * 0.42

                    ctx.drawLayer { c in
                        c.translateBy(x: cx, y: cy)
                        c.opacity = cloudAlpha

                        // Puffy cloud: overlapping ellipses forming a natural shape
                        let bumps: [(CGFloat, CGFloat, CGFloat)] = [
                            (-w * 0.30, h * 0.10, h * 0.55),
                            (-w * 0.14, -h * 0.10, h * 0.68),
                            ( w * 0.02, -h * 0.22, h * 0.72),
                            ( w * 0.18, -h * 0.08, h * 0.62),
                            ( w * 0.32, h * 0.12, h * 0.50),
                            (0,          h * 0.28, w * 0.50),  // base ellipse
                        ]
                        for (dx, dy, r) in bumps {
                            c.fill(Path(ellipseIn: CGRect(x: dx - r, y: dy - r,
                                                          width: r * 2, height: r * 2)),
                                   with: .color(Color.white))
                        }
                    }
                }

                // ── Rain streaks ──────────────────────────────────────────────────
                if weather.isRaining {
                    var rng = LCG(state: 9292)
                    for _ in 0..<35 {
                        let rx   = rng.next() * Double(size.width)
                        let ry   = fmod(rng.next() + t * 0.45, 1.0) * Double(size.height + 40)
                        let len  = rng.lerp(12, 22)
                        var drop = Path()
                        drop.move(to:    CGPoint(x: CGFloat(rx),        y: CGFloat(ry)))
                        drop.addLine(to: CGPoint(x: CGFloat(rx + len * 0.18), y: CGFloat(ry + len)))
                        ctx.opacity = 0.28
                        ctx.stroke(drop, with: .color(Color(red: 0.72, green: 0.88, blue: 1.0)), lineWidth: 1.0)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Growing Vines (Sage)

private struct GrowingVines: View {
    struct Vine {
        let baseX, ctrlShift, phase, speed: Double
        let leafSeeds: [Double]
    }
    private let vines: [Vine]
    init() {
        var rng = LCG(state: 4242)
        vines = (0..<8).map { _ in
            Vine(baseX:     rng.next(),
                 ctrlShift: rng.lerp(-55, 55),
                 phase:     rng.next(),
                 speed:     rng.lerp(0.020, 0.040),
                 leafSeeds: (0..<5).map { _ in rng.next() })
        }
    }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for vine in vines {
                    let prog   = fmod(vine.phase + t * vine.speed, 1.0)
                    let height = size.height * CGFloat(prog) * 0.88
                    let bx     = CGFloat(vine.baseX) * size.width
                    let sway   = CGFloat(sin(t * 0.22 + vine.phase * .pi * 2) * 18)
                    let tipX   = bx + sway
                    let tipY   = size.height - height

                    var stem = Path()
                    stem.move(to: CGPoint(x: bx, y: size.height))
                    let c1 = CGPoint(x: bx + CGFloat(vine.ctrlShift), y: size.height * 0.60)
                    let c2 = CGPoint(x: tipX - CGFloat(vine.ctrlShift * 0.3), y: tipY + height * 0.35)
                    stem.addCurve(to: CGPoint(x: tipX, y: tipY), control1: c1, control2: c2)

                    let fade = min(1, prog * 5) * (1 - max(0, (prog - 0.80) * 5))
                    ctx.opacity = fade * 0.38
                    ctx.stroke(stem, with: .color(Color(red: 0.14, green: 0.44, blue: 0.16)), lineWidth: 1.6)

                    for (li, lseed) in vine.leafSeeds.prefix(4).enumerated() {
                        let leafT = Double(li + 1) / 5.0
                        guard leafT < prog else { continue }
                        let lx = bx + (tipX - bx) * CGFloat(leafT) + CGFloat(lseed * 16 - 8)
                        let ly = size.height - height * CGFloat(leafT)
                        ctx.drawLayer { c in
                            c.translateBy(x: lx, y: ly)
                            c.rotate(by: .degrees(lseed * 120 - 60))
                            c.opacity = fade * 0.42
                            c.fill(leafPath(CGFloat(lseed * 7 + 7)),
                                   with: .color(Color(red: 0.22, green: 0.60, blue: 0.24)))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Falling Stones (Stone/Mudslide)

private struct FallingStones: View {
    struct Stone {
        let startX, speed, wobble, wobHz, phase, rotHz, seed: Double
        let w, h: CGFloat
    }
    private let stones: [Stone]
    init() {
        var rng = LCG(state: 7171)
        stones = (0..<14).map { _ in
            Stone(startX: rng.next(),
                  speed:  rng.lerp(0.055, 0.110),
                  wobble: rng.lerp(4, 14),
                  wobHz:  rng.lerp(0.60, 1.80),
                  phase:  rng.next(),
                  rotHz:  rng.lerp(-2.5, 2.5),
                  seed:   rng.next(),
                  w: CGFloat(rng.lerp(10, 26)),
                  h: CGFloat(rng.lerp(8, 20)))
        }
    }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for s in stones {
                    let prog = fmod(s.phase + t * s.speed, 1.0)
                    let y    = CGFloat(prog) * (size.height + 40)
                    let x    = CGFloat(s.startX) * size.width
                           + CGFloat(sin(t * s.wobHz + s.phase * .pi * 2) * s.wobble)
                    let fade = sin(max(0, CGFloat(prog)) * .pi)
                    let col  = Color(red: 0.38 + s.seed * 0.12,
                                     green: 0.32 + s.seed * 0.08,
                                     blue:  0.26 + s.seed * 0.06)
                    ctx.drawLayer { c in
                        c.translateBy(x: x, y: y)
                        c.rotate(by: .degrees(t * s.rotHz * 50))
                        c.opacity = Double(fade) * 0.58
                        let sr = min(s.w, s.h) * 0.38
                        c.fill(Path(roundedRect: CGRect(x: -s.w / 2, y: -s.h / 2,
                                                        width: s.w, height: s.h),
                                    cornerRadius: sr),
                               with: .color(col))
                        c.opacity = Double(fade) * 0.22
                        c.fill(Path(ellipseIn: CGRect(x: -s.w * 0.28, y: -s.h * 0.38,
                                                      width: s.w * 0.28, height: s.h * 0.22)),
                               with: .color(.white))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Comets (Amber)

private struct CometsView: View {
    struct Comet {
        let startX, startY, angleDeg, speed, phase, length: Double
    }
    private let comets: [Comet]
    init() {
        var rng = LCG(state: 5656)
        comets = (0..<5).map { _ in
            Comet(startX:   rng.lerp(0.3, 1.0),
                  startY:   rng.lerp(0.0, 0.30),
                  angleDeg: rng.lerp(38, 56),
                  speed:    rng.lerp(0.016, 0.028),
                  phase:    rng.next(),
                  length:   rng.lerp(80, 165))
        }
    }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for comet in comets {
                    let prog   = fmod(comet.phase + t * comet.speed, 1.0)
                    let fade   = sin(min(prog * 8, .pi))
                    guard fade > 0.01 else { continue }

                    let travel  = prog * Double(size.width + size.height) * 0.85
                    let rad     = comet.angleDeg * .pi / 180
                    let headX   = CGFloat(comet.startX * Double(size.width) - cos(rad) * travel)
                    let headY   = CGFloat(comet.startY * Double(size.height) + sin(rad) * travel)
                    let tailX   = headX + CGFloat(cos(rad) * comet.length)
                    let tailY   = headY - CGFloat(sin(rad) * comet.length)

                    var trail = Path()
                    trail.move(to:    CGPoint(x: headX, y: headY))
                    trail.addLine(to: CGPoint(x: tailX, y: tailY))

                    ctx.opacity = fade * 0.28
                    ctx.stroke(trail, with: .color(Color(red: 1.0, green: 0.88, blue: 0.38)), lineWidth: 8)
                    ctx.opacity = fade * 0.55
                    ctx.stroke(trail, with: .color(Color(red: 1.0, green: 0.68, blue: 0.10)), lineWidth: 3)

                    let cR: CGFloat = 4.5, gR: CGFloat = 12
                    ctx.opacity = fade * 0.38
                    ctx.fill(Path(ellipseIn: CGRect(x: headX - gR, y: headY - gR,
                                                   width: gR * 2, height: gR * 2)),
                             with: .color(Color(red: 1.0, green: 0.90, blue: 0.50)))
                    ctx.opacity = fade * 0.92
                    ctx.fill(Path(ellipseIn: CGRect(x: headX - cR, y: headY - cR,
                                                   width: cR * 2, height: cR * 2)),
                             with: .color(.white))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Sea Creatures (Deep theme)

private struct SeaCreaturesView: View {
    struct Jellyfish {
        let xFrac, yFrac, radius, phase, bobSpeed: Double
        let tentacles: [(len: Double, waveAmp: Double, waveHz: Double)]
    }
    struct Fish {
        let xFrac, yFrac, speed, phase, bodyW: Double
        let goRight: Bool
        let colorShift: Double
    }

    private let jellies: [Jellyfish]
    private let fish: [Fish]

    init() {
        var rng = LCG(state: 3939)
        jellies = (0..<4).map { _ in
            Jellyfish(
                xFrac:    rng.next(),
                yFrac:    rng.lerp(0.06, 0.72),
                radius:   rng.lerp(14, 24),
                phase:    rng.next() * .pi * 2,
                bobSpeed: rng.lerp(0.24, 0.42),
                tentacles: (0..<5).map { _ in
                    (len: rng.lerp(1.2, 2.0),
                     waveAmp: rng.lerp(3.0, 7.0),
                     waveHz: rng.lerp(0.8, 1.5))
                }
            )
        }
        fish = (0..<5).map { i in
            Fish(xFrac:      rng.next(),
                 yFrac:      rng.lerp(0.05, 0.88),
                 speed:      rng.lerp(0.028, 0.052),
                 phase:      rng.next(),
                 bodyW:      rng.lerp(18, 34),
                 goRight:    i % 2 == 0,
                 colorShift: rng.lerp(-0.05, 0.05))
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate

                // Fish (background layer)
                for f in fish {
                    let prog = fmod(f.phase + t * f.speed, 1.0)
                    let fadeIn  = min(prog / 0.12, 1.0)
                    let fadeOut = min((1.0 - prog) / 0.12, 1.0)
                    let fade    = fadeIn * fadeOut
                    guard fade > 0.01 else { continue }

                    let x  = CGFloat(f.goRight ? prog : 1.0 - prog) * size.width
                    let y  = CGFloat(f.yFrac) * size.height
                           + CGFloat(sin(t * 0.55 + f.phase * .pi * 2) * 15)
                    let bW = CGFloat(f.bodyW)
                    let bH = bW * 0.40
                    let fishColor = Color(red: 0.42 + f.colorShift,
                                         green: 0.76 + f.colorShift * 0.5,
                                         blue:  0.98)

                    ctx.drawLayer { c in
                        c.opacity = fade * 0.30
                        c.fill(Path(ellipseIn: CGRect(x: x - bW / 2, y: y - bH / 2,
                                                       width: bW, height: bH)),
                               with: .color(fishColor))
                        var tail = Path()
                        if f.goRight {
                            tail.move(to: CGPoint(x: x - bW / 2 + 1, y: y))
                            tail.addLine(to: CGPoint(x: x - bW / 2 - bW * 0.36, y: y - bH * 0.62))
                            tail.addLine(to: CGPoint(x: x - bW / 2 - bW * 0.36, y: y + bH * 0.62))
                        } else {
                            tail.move(to: CGPoint(x: x + bW / 2 - 1, y: y))
                            tail.addLine(to: CGPoint(x: x + bW / 2 + bW * 0.36, y: y - bH * 0.62))
                            tail.addLine(to: CGPoint(x: x + bW / 2 + bW * 0.36, y: y + bH * 0.62))
                        }
                        tail.closeSubpath()
                        c.fill(tail, with: .color(fishColor))
                        let eyeX: CGFloat = f.goRight ? x + bW * 0.20 : x - bW * 0.20
                        c.opacity = fade * 0.55
                        c.fill(Path(ellipseIn: CGRect(x: eyeX - 1.5, y: y - 1.5, width: 3, height: 3)),
                               with: .color(.white))
                    }
                }

                // Jellyfish (foreground)
                for jelly in jellies {
                    let x   = CGFloat(jelly.xFrac) * size.width
                    let y   = CGFloat(jelly.yFrac) * size.height
                          + CGFloat(sin(t * jelly.bobSpeed + jelly.phase) * 20)
                    let r   = CGFloat(jelly.radius)
                    let pulse = 0.26 + sin(t * 0.72 + jelly.phase) * 0.07

                    // Glow halo behind dome
                    let gR = r * 1.6
                    ctx.opacity = max(0, pulse * 0.14)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - gR, y: y - gR * 0.55,
                                                    width: gR * 2, height: gR * 1.1)),
                             with: .color(Color(red: 0.40, green: 0.72, blue: 1.00)))

                    // Dome cap
                    var dome = Path()
                    dome.addArc(center: CGPoint(x: x, y: y), radius: r,
                                startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                    dome.closeSubpath()
                    ctx.opacity = max(0, pulse)
                    ctx.fill(dome, with: .color(Color(red: 0.38, green: 0.70, blue: 1.00)))
                    ctx.opacity = max(0, pulse + 0.24)
                    ctx.stroke(dome, with: .color(Color(red: 0.62, green: 0.90, blue: 1.00)), lineWidth: 1.0)

                    // Inner highlight
                    var hl = Path()
                    hl.addArc(center: CGPoint(x: x - r * 0.18, y: y - r * 0.22),
                              radius: r * 0.36,
                              startAngle: .degrees(205), endAngle: .degrees(335), clockwise: false)
                    ctx.opacity = max(0, pulse * 0.50)
                    ctx.stroke(hl, with: .color(.white), lineWidth: 0.7)

                    // Tentacles
                    let numT = jelly.tentacles.count
                    for (ti, tent) in jelly.tentacles.enumerated() {
                        let tx   = x - r * 0.72 + CGFloat(Double(ti) / Double(numT - 1)) * r * 1.44
                        let tLen = CGFloat(tent.len * Double(r))
                        let w1   = CGFloat(sin(t * tent.waveHz + Double(ti) * 0.9 + jelly.phase) * tent.waveAmp)
                        let w2   = CGFloat(sin(t * tent.waveHz * 0.72 + Double(ti) + jelly.phase + 1.3) * tent.waveAmp * 0.65)
                        var tp = Path()
                        tp.move(to: CGPoint(x: tx, y: y))
                        tp.addCurve(to:      CGPoint(x: tx + w1,       y: y + tLen),
                                    control1: CGPoint(x: tx + w1 * 0.5, y: y + tLen * 0.35),
                                    control2: CGPoint(x: tx + w2,       y: y + tLen * 0.68))
                        ctx.opacity = 0.17
                        ctx.stroke(tp, with: .color(Color(red: 0.52, green: 0.88, blue: 1.00)),
                                   style: StrokeStyle(lineWidth: 0.85, lineCap: .round))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Cyberpunk Grid (with animated scan bar)

private struct CyberpunkGrid: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { tl in
            Canvas { ctx, size in
                let t    = tl.date.timeIntervalSinceReferenceDate
                let step: CGFloat = 36
                var grid = Path()
                var gx: CGFloat = 0
                while gx <= size.width {
                    grid.move(to: CGPoint(x: gx, y: 0))
                    grid.addLine(to: CGPoint(x: gx, y: size.height))
                    gx += step
                }
                var gy: CGFloat = 0
                while gy <= size.height {
                    grid.move(to: CGPoint(x: 0, y: gy))
                    grid.addLine(to: CGPoint(x: size.width, y: gy))
                    gy += step
                }
                ctx.opacity = 0.13
                ctx.stroke(grid,
                           with: .color(Color(red: 0.00, green: 1.00, blue: 0.40)),
                           lineWidth: 0.6)

                let scanY = CGFloat(fmod(t * 0.22, 1.0)) * size.height
                var bar   = Path()
                bar.addRect(CGRect(x: 0, y: scanY, width: size.width, height: 3))
                ctx.opacity = 0.30
                ctx.fill(bar, with: .color(Color(red: 0.00, green: 1.00, blue: 0.40)))
                var glow = Path()
                glow.addRect(CGRect(x: 0, y: max(0, scanY - 18), width: size.width, height: 18))
                ctx.opacity = 0.07
                ctx.fill(glow, with: .color(Color(red: 0.00, green: 1.00, blue: 0.40)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Retrowave Scanlines (scrolling)

private struct RetrowaveScanlines: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15)) { tl in
            Canvas { ctx, size in
                let t       = tl.date.timeIntervalSinceReferenceDate
                let spacing: CGFloat = 5
                let offset  = CGFloat(fmod(t * 10.0, Double(spacing)))
                var path    = Path()
                var y       = offset - spacing
                while y < size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                ctx.opacity = 0.09
                ctx.stroke(path, with: .color(.white), lineWidth: 0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
