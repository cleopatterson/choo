import SwiftUI

struct ExerciseWeekStripView: View {
    @Bindable var viewModel: ExerciseViewModel

    private var allDays: [(index: Int, date: Date)] {
        Array(viewModel.weekDays.enumerated())
            .map { (index: $0.offset, date: $0.element) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(allDays, id: \.index) { day in
                            dayCard(index: day.index, date: day.date)
                                .id(day.index)
                                .onTapGesture {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    viewModel.selectedDayIndex = day.index
                                }
                                .onLongPressGesture {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    viewModel.selectedDayIndex = day.index
                                }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .onAppear {
                    if let firstUpcoming = allDays.first(where: { !viewModel.isPast($0.date) }) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(firstUpcoming.index, anchor: .leading)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Day Card

    @ViewBuilder
    private func dayCard(index: Int, date: Date) -> some View {
        let isPast = viewModel.isPast(date)
        let isToday = viewModel.isToday(date)
        let isRest = viewModel.restDays.contains(index)
        let sessions = viewModel.sessionsForDay(index)

        VStack(spacing: 4) {
            // Day header — day left, badge or date right
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.dayAbbreviation(for: date))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isToday ? Color(hex: "#4ecdc4").opacity(0.6) : (isPast ? .white.opacity(0.3) : .secondary))

                Spacer(minLength: 0)

                if isToday {
                    Text("TODAY")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(Color(hex: "#4ecdc4").opacity(0.8))
                        .tracking(0.5)
                } else {
                    Text(viewModel.dayNumber(for: date))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isPast ? .white.opacity(0.3) : .secondary)
                }
            }

            if isRest {
                // Rest day — centered emoji + label
                Spacer(minLength: 4)
                Text("😴")
                    .font(.system(size: 28))
                    .frame(height: 34)
                Text("Rest")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
                Spacer(minLength: 4)
            } else if sessions.isEmpty {
                // Empty day — add button
                Spacer(minLength: 4)
                Image(systemName: "plus")
                    .font(.body)
                    .foregroundStyle(isPast ? .white.opacity(0.08) : .white.opacity(0.15))
                    .frame(height: 34)
                Text("Add")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(isPast ? 0.15 : 0.3))
                Spacer(minLength: 4)
            } else {
                // Sessions — centered emoji(s) + title(s)
                Spacer(minLength: 2)
                sessionContent(sessions: sessions, isPast: isPast)
                Spacer(minLength: 2)
            }
        }
        .frame(width: 120)
        .frame(minHeight: 120)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .opacity(isPast ? 0.5 : 1.0)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)

                if isToday {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#4ecdc4").opacity(0.08), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isToday ? Color(hex: "#4ecdc4").opacity(0.35) : .white.opacity(0.08),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Session Content (centered emoji + titles)

    @ViewBuilder
    private func sessionContent(sessions: [(timeSlot: TimeSlot, assignment: ExerciseSlotAssignment)], isPast: Bool) -> some View {
        // Centered emoji row
        let uniqueEmojis = sessions.map(\.assignment.categoryEmoji)
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }

        HStack(spacing: 4) {
            ForEach(uniqueEmojis, id: \.self) { emoji in
                Text(emoji)
                    .font(.system(size: uniqueEmojis.count > 1 ? 24 : 28))
            }
        }
        .frame(height: 34)

        // Stacked titles
        VStack(spacing: 1) {
            ForEach(Array(sessions.enumerated()), id: \.offset) { idx, session in
                if idx > 0 {
                    Text("&")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                        .tracking(1)
                }
                Text(session.assignment.sessionTypeName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isPast ? .white.opacity(0.35) : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}
