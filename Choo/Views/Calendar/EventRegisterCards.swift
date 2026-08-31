import SwiftUI
import EventKit

// The three event registers from the build spec: FUN cards are loud and ramp up as the
// day approaches, UTILITY cards stay flat and quiet, ROUTINE recurring events are one
// thin line. Bills and todos render as utility variants; device events as routine rows.

private let cardTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.timeStyle = .short
    return f
}()

private let dueDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEE d MMM"
    return f
}()

// MARK: - FUN

struct FunEventCard: View {
    let event: FamilyEvent
    let day: Date
    let attendees: [AnyFamilyMember]
    let tint: CalendarTheme.FunTint

    var body: some View {
        let ramp = RampStage.stage(for: day)

        ZStack(alignment: .topLeading) {
            EmojiSceneView(
                emoji: event.classification?.sceneEmoji ?? [],
                seed: event.id ?? event.title,
                opacity: ramp.sceneOpacity,
                saturation: ramp.sceneSaturation,
                animated: ramp.hasGlow
            )

            VStack(alignment: .leading, spacing: 0) {
                Text(event.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: Color(red: 0.071, green: 0.055, blue: 0.133).opacity(0.6), radius: 4, y: 1)

                Text(timeLine)
                    .font(.system(size: 13.5))
                    .foregroundStyle(CalendarTheme.textDim)
                    .padding(.top, 3)

                countdown(for: ramp)
                    .padding(.top, 10)
            }
            .padding(.trailing, 60)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(minHeight: 112, alignment: .topLeading)
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(tint.gradient, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(ramp.hasGlow ? tint.stroke.opacity(1) : tint.stroke, lineWidth: 1)
        )
        .overlay(alignment: .bottomTrailing) {
            AvatarStack(attendees: attendees, size: 27)
                .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        // Glow as a static blurred shape behind the card — much cheaper than
        // .shadow, which re-derives from the animating card content every frame.
        .background {
            if ramp.hasGlow {
                RoundedRectangle(cornerRadius: 18)
                    .fill(tint.hue.opacity(ramp == .today ? 0.3 : 0.18))
                    .blur(radius: 16)
            }
        }
    }

    private var timeLine: String {
        if event.isAllDay == true {
            return event.spanDayCount >= 1
                ? "\(dueDateFormatter.string(from: event.startDate)) – \(dueDateFormatter.string(from: event.endDate))"
                : "All day"
        }
        return cardTimeFormatter.string(from: event.startDate).lowercased()
    }

    @ViewBuilder
    private func countdown(for ramp: RampStage) -> some View {
        switch ramp {
        case .past:
            EmptyView()
        case .distant:
            Text(ramp.countdownText)
                .font(.custom("Georgia-Italic", size: 12.5))
                .foregroundStyle(CalendarTheme.textFaint)
                .padding(.top, -2)
        case .week, .near:
            Text(ramp.countdownText)
                .font(.system(size: 11.5, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color(red: 0.914, green: 0.835, blue: 1.0))
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(tint.hue.opacity(0.22), in: Capsule())
                .overlay(Capsule().strokeBorder(tint.hue.opacity(0.35), lineWidth: 1))
        case .today:
            TodayChip(tint: tint)
        }
    }
}

/// The "Today! 🎈" gradient chip with a shimmer sweep every 2.8s.
private struct TodayChip: View {
    let tint: CalendarTheme.FunTint
    @State private var sweep = false

    var body: some View {
        Text("Today! 🎈")
            .font(.system(size: 11.5, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(Color(red: 0.992, green: 0.957, blue: 1.0))
            .padding(.horizontal, 11)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.851, green: 0.275, blue: 0.937).opacity(0.32), CalendarTheme.socialHue.opacity(0.3)],
                    startPoint: .leading, endPoint: .trailing
                ),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(Color(red: 0.941, green: 0.671, blue: 0.988).opacity(0.6), lineWidth: 1))
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.28), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: sweep ? geo.size.width : -geo.size.width * 0.6)
                }
                .clipShape(Capsule())
                .allowsHitTesting(false)
            )
            .onAppear {
                guard !UIAccessibility.isReduceMotionEnabled else { return }
                withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: false)) {
                    sweep = true
                }
            }
    }
}

/// 2–3 large emoji, right-weighted, deterministically placed from a seed.
/// Floats only when `animated` (near/today ramp stages) — distant scenes stay
/// static so a screenful of cards doesn't run a screenful of animations.
struct EmojiSceneView: View {
    let emoji: [String]
    let seed: String
    let opacity: Double
    let saturation: Double
    var animated: Bool = false

    @State private var floating = false

    private var seedHash: UInt64 {
        var hash: UInt64 = 5381
        for byte in seed.utf8 { hash = hash &* 33 &+ UInt64(byte) }
        return hash
    }

    var body: some View {
        let hash = seedHash
        ZStack {
            if emoji.indices.contains(0) {
                Text(emoji[0])
                    .font(.system(size: 52))
                    .rotationEffect(.degrees(Double(hash % 21) - 10))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .offset(x: 14, y: floating ? -7 : 0)
                    .animation(floatAnimation(duration: 7), value: floating)
            }
            if emoji.indices.contains(1) {
                Text(emoji[1])
                    .font(.system(size: 28))
                    .rotationEffect(.degrees(Double((hash >> 8) % 25) - 12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: -64, y: floating ? -13 : -6)
                    .animation(floatAnimation(duration: 5.2), value: floating)
            }
            if emoji.indices.contains(2) {
                Text(emoji[2])
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .offset(x: -104, y: -4)
                    .opacity(0.8)
            }
        }
        .shadow(color: Color(red: 0.071, green: 0.055, blue: 0.133).opacity(0.35), radius: 3, y: 2)
        .opacity(opacity)
        .saturation(saturation)
        .allowsHitTesting(false)
        .onAppear {
            guard animated, !UIAccessibility.isReduceMotionEnabled else { return }
            floating = true
        }
    }

    private func floatAnimation(duration: Double) -> Animation? {
        UIAccessibility.isReduceMotionEnabled
            ? nil
            : .easeInOut(duration: duration).repeatForever(autoreverses: true)
    }
}

// MARK: - UTILITY

struct UtilityEventCard: View {
    let event: FamilyEvent
    let day: Date
    let attendees: [AnyFamilyMember]

    var body: some View {
        let paid = event.isPaidOn(day)
        let todoDone = event.isTodo == true && event.isCompleted == true

        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 9) {
                    leadingGlyph(todoDone: todoDone)

                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .strikethrough(todoDone, color: .white.opacity(0.3))

                    if event.isTodo == true, let emoji = event.todoEmoji, !emoji.isEmpty {
                        Text(emoji)
                            .font(.system(size: 13))
                    }

                    if event.isTodo == true && !todoDone {
                        TodoUrgencyBadge(event: event)
                    }
                }

                HStack(spacing: 5) {
                    Text(metaLine(paid: paid, todoDone: todoDone))
                        .font(.system(size: 13))
                        .foregroundStyle(metaColor(paid: paid, todoDone: todoDone))

                    if event.isTodo != true, let freq = event.recurrence {
                        Image(systemName: "repeat")
                            .font(.system(size: 10))
                            .foregroundStyle(CalendarTheme.textFaint)
                        Text(freq.displayName)
                            .font(.system(size: 12))
                            .foregroundStyle(CalendarTheme.textFaint)
                    }

                    if event.reminderEnabled == true {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(CalendarTheme.textFaint)
                    }
                }
                .padding(.leading, 25)
            }

            Spacer(minLength: 8)

            if todoDone || (event.isBill == true && paid) {
                Text(todoDone ? "DONE" : "PAID")
                    .font(.caption2.bold())
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.green.opacity(0.15), in: Capsule())
            } else {
                AvatarStack(attendees: attendees, size: 27)
            }
        }
        .opacity((paid || todoDone) ? 0.6 : 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(CalendarTheme.quietFill, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(CalendarTheme.quietStroke, lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            Capsule()
                .fill(CalendarTheme.utilityBorder(for: event.effectiveSubtype))
                .frame(width: 3)
                .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func leadingGlyph(todoDone: Bool) -> some View {
        if event.isTodo == true {
            Image(systemName: todoDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(todoDone ? .green : .white.opacity(0.25))
        } else {
            Text(glyphEmoji)
                .font(.system(size: 16))
                .saturation(0.75)
                .opacity(0.85)
        }
    }

    private var glyphEmoji: String {
        if event.isBill == true { return "💰" }
        if let glyph = event.classification?.glyph, event.hasFreshClassification, !glyph.isEmpty { return glyph }
        return "🗓"
    }

    private func metaLine(paid: Bool, todoDone: Bool) -> String {
        var parts: [String] = []
        if event.isTodo == true {
            if todoDone {
                parts.append("Done")
            } else if event.todoHasDueDate {
                parts.append("Due \(dueDateFormatter.string(from: event.endDate))")
            } else {
                parts.append("No due date")
            }
        } else if event.isBill == true {
            if let amt = event.amount {
                parts.append(amt.formatted(.currency(code: "AUD")))
            }
            if paid { parts.append("Paid") }
        } else if event.isAllDay == true {
            parts.append("All day")
        } else {
            parts.append(cardTimeFormatter.string(from: event.startDate).lowercased())
        }

        if event.isBill != true && event.isTodo != true, let loc = event.location, !loc.isEmpty {
            parts.append(loc)
        }
        return parts.joined(separator: " · ")
    }

    private func metaColor(paid: Bool, todoDone: Bool) -> Color {
        if todoDone || paid { return .green.opacity(0.8) }
        if event.isTodo == true && event.urgencyState == .overdue { return .red }
        return Color(red: 0.929, green: 0.914, blue: 0.996).opacity(0.55)
    }
}

struct TodoUrgencyBadge: View {
    let event: FamilyEvent

    var body: some View {
        let (label, color): (String, Color) = {
            switch event.urgencyState {
            case .overdue: return ("Overdue", .red)
            case .dueSoon: return ("Due soon", .orange)
            case .active: return event.todoHasDueDate ? ("Active", .cyan) : ("Flexible", Color.white.opacity(0.4))
            case .flexible: return ("Flexible", Color.white.opacity(0.4))
            default: return ("", .clear)
            }
        }()
        if !label.isEmpty {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(color)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(color.opacity(0.15), in: Capsule())
        }
    }
}

// MARK: - ROUTINE

struct RoutineEventRow: View {
    let event: FamilyEvent
    let attendees: [AnyFamilyMember]

    var body: some View {
        HStack(spacing: 10) {
            Text(event.title)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(Color(red: 0.929, green: 0.914, blue: 0.996).opacity(0.55))
                .lineLimit(1)

            Spacer(minLength: 8)

            HStack(spacing: 5) {
                if event.recurrence != nil {
                    Image(systemName: "repeat")
                        .font(.system(size: 10))
                        .opacity(0.6)
                }
                Text(event.isAllDay == true ? "All day" : cardTimeFormatter.string(from: event.startDate).lowercased())
                    .font(.system(size: 12.5))
            }
            .foregroundStyle(CalendarTheme.textFaint)

            if let member = attendees.first {
                MemberAvatarView(name: member.displayName, uid: member.id, emoji: member.emoji, size: 22)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(CalendarTheme.quietFill, in: RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(CalendarTheme.quietStroke, lineWidth: 1)
        )
    }
}

/// Device-calendar events — nothing can be stored on them, so they stay one quiet line
/// with the calendar's colour as a small dot.
struct ExternalEventRow: View {
    let event: EKEvent

    var body: some View {
        let calColor = Color(cgColor: event.calendar.cgColor)

        HStack(spacing: 10) {
            Circle()
                .fill(calColor)
                .frame(width: 7, height: 7)

            Text(event.title ?? "")
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(Color(red: 0.929, green: 0.914, blue: 0.996).opacity(0.55))
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(event.isAllDay ? "All day" : cardTimeFormatter.string(from: event.startDate).lowercased())
                .font(.system(size: 12.5))
                .foregroundStyle(CalendarTheme.textFaint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(CalendarTheme.quietFill, in: RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(CalendarTheme.quietStroke, lineWidth: 1)
        )
    }
}

// MARK: - Shared

/// Overlapping avatar row, row-reversed so the leftmost face is on top.
struct AvatarStack: View {
    let attendees: [AnyFamilyMember]
    var size: CGFloat = 27

    var body: some View {
        HStack(spacing: -8) {
            ForEach(attendees) { member in
                MemberAvatarView(name: member.displayName, uid: member.id, emoji: member.emoji, size: size)
                    .overlay(Circle().stroke(CalendarTheme.avatarRing, lineWidth: 2))
            }
        }
    }
}
