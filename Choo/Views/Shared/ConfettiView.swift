import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var elapsed: TimeInterval = 0

    private let colors: [Color] = [.chooPurple, .pink, .orange, .yellow, .green, .cyan, .red, .mint]
    private let count = 40

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let age = now - particle.createdAt
                    guard age >= 0 else { continue }

                    let gravity: Double = 600
                    let x = size.width / 2 + particle.velocityX * age
                    let y = size.height / 2 + particle.velocityY * age + 0.5 * gravity * age * age
                    let opacity = max(0, 1.0 - age / 2.0)

                    guard opacity > 0 else { continue }

                    let rect = CGRect(
                        x: x - particle.size / 2,
                        y: y - particle.size / 2,
                        width: particle.size,
                        height: particle.isCircle ? particle.size : particle.size * 0.6
                    )

                    context.opacity = opacity
                    if particle.isCircle {
                        context.fill(Circle().path(in: rect), with: .color(particle.color))
                    } else {
                        let rotation = Angle.degrees(age * particle.spin)
                        var rotatedContext = context
                        rotatedContext.translateBy(x: rect.midX, y: rect.midY)
                        rotatedContext.rotate(by: rotation)
                        let centeredRect = CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height)
                        rotatedContext.fill(Rectangle().path(in: centeredRect), with: .color(particle.color))
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            let now = Date.timeIntervalSinceReferenceDate
            particles = (0..<count).map { _ in
                let angle = Double.random(in: -.pi ..< .pi)
                let speed = Double.random(in: 200...500)
                return ConfettiParticle(
                    velocityX: cos(angle) * speed,
                    velocityY: sin(angle) * speed - 300, // bias upward
                    size: CGFloat.random(in: 6...12),
                    color: colors.randomElement()!,
                    isCircle: Bool.random(),
                    spin: Double.random(in: -360...360),
                    createdAt: now
                )
            }
        }
    }
}

private struct ConfettiParticle {
    let velocityX: Double
    let velocityY: Double
    let size: CGFloat
    let color: Color
    let isCircle: Bool
    let spin: Double
    let createdAt: TimeInterval
}
