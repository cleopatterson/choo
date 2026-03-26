import SwiftUI

struct HouseWeekStripView: View {
    @Bindable var viewModel: HouseViewModel

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
        let chores = viewModel.choresForDay(index)

        VStack(spacing: 4) {
            // Day header
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.dayAbbreviation(for: date))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isToday ? Color.chooRose.opacity(0.6) : (isPast ? .white.opacity(0.3) : .secondary))

                Spacer(minLength: 0)

                if isToday {
                    Text("TODAY")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(Color.chooRose.opacity(0.8))
                        .tracking(0.5)
                } else {
                    Text(viewModel.dayNumber(for: date))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isPast ? .white.opacity(0.3) : .secondary)
                }
            }

            if chores.isEmpty {
                Spacer(minLength: 4)
                Image(systemName: "plus.circle.dashed")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.15))
                    .frame(height: 34)
                Text("Tap to plan")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.2))
                Spacer(minLength: 4)
            } else {
                Spacer(minLength: 2)
                choreContent(chores: chores, isPast: isPast)
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
                                colors: [Color.chooRose.opacity(0.08), .clear],
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
                    isToday ? Color.chooRose.opacity(0.35) : .white.opacity(0.08),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Chore Content

    @ViewBuilder
    private func choreContent(chores: [HouseViewModel.HouseDueItem], isPast: Bool) -> some View {
        let uniqueEmojis = chores.map(\.categoryEmoji)
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }

        HStack(spacing: 4) {
            ForEach(uniqueEmojis, id: \.self) { emoji in
                Text(emoji)
                    .font(.system(size: uniqueEmojis.count > 1 ? 24 : 28))
            }
        }
        .frame(height: 34)

        VStack(spacing: 1) {
            if chores.count == 1 {
                Text(chores[0].choreType.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isPast ? .white.opacity(0.35) : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Text(chores[0].choreType.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isPast ? .white.opacity(0.35) : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text("+ \(chores.count - 1) more")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)

        let overdueCount = chores.filter(\.isOverdue).count
        if overdueCount > 0 {
            Text("\(overdueCount) overdue")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color(hex: "#ef4444"))
        }
    }
}
