import SwiftUI
import EventKit

// Non-reactive scroll tracker — mutations don't trigger body re-evaluation
private final class ScrollTracker {
    var visibleDays: Set<Date> = []
}

struct CalendarTabView: View {
    @Bindable var viewModel: CalendarViewModel
    @Bindable var briefingViewModel: WeeklyBriefingViewModel
    @Binding var showingProfile: Bool
    @State private var scrollToTodayTrigger = false
    @State private var scrollTracker = ScrollTracker()
    @State private var displayedMonth: Date = Calendar.current.startOfDay(for: Date())
    @State private var hasScrolledInitially = false
    @State private var scrollToNewEventDate: Date?
    @State private var pendingScrollDate: Date?
    @State private var animatingDay: Date?
    @State private var showConfetti = false
    @State private var eventIconCache: [String: String?] = [:]
    @State private var scrollTask: Task<Void, Never>?
    @State private var briefingPage = 0
    @State private var selectedEventDay: Date = Date()

    /// Update displayedMonth only when the month boundary actually changes.
    private func updateMonthIfNeeded() {
        guard let minDay = scrollTracker.visibleDays.min() else { return }
        let cal = Calendar.current
        if cal.component(.month, from: minDay) != cal.component(.month, from: displayedMonth)
            || cal.component(.year, from: minDay) != cal.component(.year, from: displayedMonth) {
            displayedMonth = minDay
        }
    }

    private static let dayHeaderFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f
    }()

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollViewReader { proxy in
                    List {
                        let days = viewModel.visibleDays
                        let briefingInsertIndex = days.firstIndex(where: { $0 >= briefingViewModel.weekStart }) ?? 0
                        let preDays = Array(days.prefix(briefingInsertIndex))
                        let postDays = Array(days.suffix(from: briefingInsertIndex).filter { !briefingViewModel.weekDays.contains($0) })

                        let today = Calendar.current.startOfDay(for: Date())

                        // Pre-briefing days (past events before this week)
                        ForEach(Array(preDays.enumerated()), id: \.element) { index, day in
                            if shouldShowMonthBanner(for: day, after: index > 0 ? preDays[index - 1] : nil) {
                                monthBanner(for: day)
                            }
                            let dayEvents = viewModel.filteredEvents(for: day)
                            let extEvents = viewModel.externalEvents(for: day)
                            let holiday = viewModel.publicHoliday(on: day)
                            let school = viewModel.schoolHolidayPeriod(on: day)
                            let isToday = day == today
                            if !dayEvents.isEmpty || !extEvents.isEmpty || holiday != nil || school != nil || isToday {
                                daySection(for: day, dayEvents: dayEvents, externalEvents: extEvents, publicHoliday: holiday, schoolHoliday: school, isToday: isToday, today: today)
                                    .id(day)
                                    .scaleEffect(y: animatingDay == day ? 0.01 : 1, anchor: .top)
                                    .opacity(animatingDay == day ? 0 : 1)
                                    .onAppear { scrollTracker.visibleDays.insert(day); updateMonthIfNeeded() }
                                    .onDisappear { scrollTracker.visibleDays.remove(day) }
                            }
                        }

                        // Briefing card — paged swipe between this week and next week
                        Section {
                            BriefingPagerView(
                                briefingViewModel: briefingViewModel,
                                calendarViewModel: viewModel,
                                selectedPage: $briefingPage
                            )
                        }
                        .id("today-anchor")
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                        // Post-briefing days (future events beyond this week)
                        ForEach(Array(postDays.enumerated()), id: \.element) { index, day in
                            if shouldShowMonthBanner(for: day, after: index > 0 ? postDays[index - 1] : briefingViewModel.weekDays.last) {
                                monthBanner(for: day)
                            }
                            let dayEvents = viewModel.filteredEvents(for: day)
                            let extEvents = viewModel.externalEvents(for: day)
                            let holiday = viewModel.publicHoliday(on: day)
                            let school = viewModel.schoolHolidayPeriod(on: day)
                            let isToday = day == today
                            if !dayEvents.isEmpty || !extEvents.isEmpty || holiday != nil || school != nil || isToday {
                                daySection(for: day, dayEvents: dayEvents, externalEvents: extEvents, publicHoliday: holiday, schoolHoliday: school, isToday: isToday, today: today)
                                    .id(day)
                                    .scaleEffect(y: animatingDay == day ? 0.01 : 1, anchor: .top)
                                    .opacity(animatingDay == day ? 0 : 1)
                                    .onAppear { scrollTracker.visibleDays.insert(day); updateMonthIfNeeded() }
                                    .onDisappear { scrollTracker.visibleDays.remove(day) }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await briefingViewModel.forceRefresh()
                    }
                    .onChange(of: viewModel.selectedDate) {
                        let target = Calendar.current.startOfDay(for: viewModel.selectedDate)
                        // Delay scroll to let the month picker close first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            withAnimation {
                                if briefingViewModel.weekDays.contains(target) {
                                    proxy.scrollTo("today-anchor", anchor: .top)
                                } else {
                                    let days = viewModel.visibleDays
                                    let scrollTarget = days.first(where: { $0 >= target }) ?? days.last ?? target
                                    proxy.scrollTo(scrollTarget, anchor: .top)
                                }
                            }
                        }
                    }
                    .onChange(of: scrollToTodayTrigger) {
                        let today = Calendar.current.startOfDay(for: Date())
                        withAnimation {
                            if briefingViewModel.weekDays.contains(today) {
                                proxy.scrollTo("today-anchor", anchor: .top)
                            } else {
                                proxy.scrollTo(today, anchor: .top)
                            }
                        }
                    }
                    .onChange(of: scrollToNewEventDate) {
                        if let target = scrollToNewEventDate {
                            let day = Calendar.current.startOfDay(for: target)
                            animatingDay = day
                            withAnimation(.easeInOut(duration: 0.4)) {
                                proxy.scrollTo(day, anchor: .center)
                            }
                            Task {
                                try? await Task.sleep(for: .seconds(0.5))
                                showConfetti = true
                                withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                                    animatingDay = nil
                                }
                                try? await Task.sleep(for: .seconds(2.0))
                                showConfetti = false
                            }
                            scrollToNewEventDate = nil
                        }
                    }
                    .onAppear {
                        viewModel.refreshDeviceCalendarCache()
                        briefingPage = 0
                        scrollToToday(proxy: proxy, reason: "onAppear")
                    }
                    .onChange(of: briefingViewModel.headline) {
                        // Only auto-scroll on initial load, not on AI re-generation
                        guard !hasScrolledInitially else { return }
                        hasScrolledInitially = true
                        scrollToToday(proxy: proxy, reason: "briefing loaded")
                    }
                }

                // Month picker overlay — always accessible regardless of scroll position
                if viewModel.showingMonthPicker {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation { viewModel.showingMonthPicker = false }
                        }

                    DatePicker(
                        "Jump to date",
                        selection: $viewModel.selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    .shadow(radius: 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onChange(of: viewModel.selectedDate) {
                        withAnimation { viewModel.showingMonthPicker = false }
                    }
                }
            }
            .chooBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 14) {
                        Button {
                            showingProfile = true
                        } label: {
                            Image(systemName: "person.circle")
                                .opacity(0.6)
                        }

                        Button {
                            withAnimation { viewModel.showingMonthPicker.toggle() }
                        } label: {
                            HStack(spacing: 4) {
                                Text(Self.monthYearFormatter.string(from: displayedMonth))
                                    .font(.system(.headline, design: .serif))
                                Image(systemName: viewModel.showingMonthPicker ? "chevron.up" : "chevron.down")
                                    .font(.caption.bold())
                            }
                        }

                        Button {
                            if viewModel.showingMonthPicker {
                                withAnimation { viewModel.showingMonthPicker = false }
                            }
                            viewModel.scrollToToday()
                            scrollToTodayTrigger.toggle()
                        } label: {
                            TodayDateIcon()
                                .opacity(0.6)
                        }

                        Button {
                            viewModel.showingCalendarSources = true
                        } label: {
                            Image(systemName: (viewModel.hiddenMemberIds.isEmpty && !viewModel.hideBills) ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                                .opacity(0.6)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showingEventForm = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingEventForm, onDismiss: {
                if let date = pendingScrollDate {
                    pendingScrollDate = nil
                    viewModel.selectedDate = date
                    scrollTask?.cancel()
                    scrollTask = Task {
                        let day = Calendar.current.startOfDay(for: date)
                        for _ in 0..<15 {
                            try? await Task.sleep(for: .milliseconds(400))
                            guard !Task.isCancelled else { return }
                            let events = viewModel.filteredEvents(for: day)
                            let hasDay = viewModel.visibleDays.contains(day)
                            if !events.isEmpty && hasDay {
                                scrollToNewEventDate = date
                                break
                            }
                        }
                    }
                }
            }) {
                EventFormView(
                    familyMembers: viewModel.allMembers,
                    currentUserUID: viewModel.currentUserUID,
                    initialDate: scrollTracker.visibleDays.min() ?? viewModel.selectedDate,
                    claudeService: briefingViewModel.claudeService
                ) { title, start, end, attendees, isAllDay, location, recurrenceFrequency, recurrenceEndDate, reminderEnabled, isBill, amount, note, isTodo, todoEmoji in
                    await viewModel.createEvent(
                        title: title,
                        startDate: start,
                        endDate: end,
                        attendeeUIDs: attendees,
                        isAllDay: isAllDay,
                        location: location,
                        recurrenceFrequency: recurrenceFrequency,
                        recurrenceEndDate: recurrenceEndDate,
                        reminderEnabled: reminderEnabled,
                        isBill: isBill,
                        amount: amount,
                        note: note,
                        isTodo: isTodo,
                        todoEmoji: todoEmoji
                    )
                    pendingScrollDate = start
                }
                .presentationBackground(.ultraThinMaterial)
            }
            .sheet(item: $viewModel.selectedEvent) { event in
                EventDetailView(initialEvent: event, viewModel: viewModel, occurrenceDay: selectedEventDay)
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: $viewModel.showingCalendarSources) {
                CalendarSourcesView(viewModel: viewModel, service: viewModel.deviceCalendarService)
                    .presentationBackground(.ultraThinMaterial)
            }
            .overlay {
                if showConfetti {
                    ConfettiView()
                }
            }
            .task {
                await briefingViewModel.load()
            }
            .onChange(of: viewModel.eventsFingerprint) {
                briefingViewModel.onEventsChanged()
            }
        }
    }

    // MARK: - Month Banner

    private func scrollToToday(proxy: ScrollViewProxy, reason: String) {
        let today = Calendar.current.startOfDay(for: Date())
        let days = viewModel.visibleDays
        let briefingInsertIndex = days.firstIndex(where: { $0 >= briefingViewModel.weekStart }) ?? 0
        let preDays = Array(days.prefix(briefingInsertIndex))
        let postDays = Array(days.suffix(from: briefingInsertIndex).filter { !briefingViewModel.weekDays.contains($0) })

        print("[Calendar] scrollToToday (\(reason))")
        print("[Calendar]   visibleDays.count=\(days.count), briefingInsertIndex=\(briefingInsertIndex)")
        print("[Calendar]   preDays.count=\(preDays.count), postDays.count=\(postDays.count)")
        print("[Calendar]   weekStart=\(briefingViewModel.weekStart), weekDays=\(briefingViewModel.weekDays.count)")
        print("[Calendar]   today=\(today), todayInWeek=\(briefingViewModel.weekDays.contains(today))")
        print("[Calendar]   headline='\(briefingViewModel.headline)'")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if briefingViewModel.weekDays.contains(today) {
                print("[Calendar]   -> scrollTo('today-anchor', .top)")
                withAnimation {
                    proxy.scrollTo("today-anchor", anchor: .top)
                }
            } else {
                print("[Calendar]   -> scrollTo(date: \(today), .top)")
                withAnimation {
                    proxy.scrollTo(today, anchor: .top)
                }
            }
        }
    }

    // dayHasContent check is now inlined in ForEach body to avoid double-computing events

    private func shouldShowMonthBanner(for day: Date, after previousDay: Date?) -> Bool {
        guard let prev = previousDay else { return true }
        return Calendar.current.component(.month, from: day) != Calendar.current.component(.month, from: prev)
    }

    private func monthBanner(for date: Date) -> some View {
        let cal = Calendar.current
        let month = cal.component(.month, from: date)
        let theme = monthTheme(for: month)

        return ZStack {
            // Full-bleed gradient wash
            Rectangle()
                .fill(.thinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [theme.color.opacity(0.20), theme.secondaryColor.opacity(0.08), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Scattered decorative icons (left/center to clear main icon on right)
            decorativeIcon(theme.decorativeIcons[0], size: 40, color: theme.color, opacity: 0.12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: 160, y: 8)
            decorativeIcon(theme.decorativeIcons[1], size: 28, color: theme.secondaryColor, opacity: 0.10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .offset(x: 100, y: -10)
            decorativeIcon(theme.decorativeIcons[2], size: 22, color: theme.color, opacity: 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: 40, y: 20)
            decorativeIcon(theme.decorativeIcons[3], size: 18, color: theme.secondaryColor, opacity: 0.06)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .offset(x: -20, y: 16)

            // Main icon as faded decorative element
            decorativeIcon(theme.symbol, size: 50, color: theme.color, opacity: 0.14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .offset(x: -20, y: 0)

            // Main content
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Self.monthYearFormatter.string(from: date))
                        .font(.system(.title, design: .serif).bold())
                        .foregroundStyle(.primary)
                    Text(theme.tagline)
                        .font(.subheadline)
                        .foregroundStyle(theme.color.opacity(0.8))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .clipped()
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func decorativeIcon(_ name: String, size: CGFloat, color: Color, opacity: Double) -> some View {
        let stableRotation = Double(abs(name.hashValue % 30)) - 15
        return Image(systemName: name)
            .font(.system(size: size))
            .foregroundStyle(color.opacity(opacity))
            .rotationEffect(.degrees(stableRotation))
    }

    /// Per-month theme (Southern Hemisphere / Australia). Every month unique — no repeated primary icons.
    private func monthTheme(for month: Int) -> (symbol: String, color: Color, secondaryColor: Color, decorativeIcons: [String], tagline: String) {
        switch month {
        case 1:  return ("sun.max.fill",         .orange, .yellow,  ["umbrella.fill", "drop.fill", "sparkles", "flame.fill"],               "Peak summer")
        case 2:  return ("heart.fill",            .pink,   .red,     ["sparkles", "heart.circle.fill", "star.fill", "gift.fill"],            "Love & late summer")
        case 3:  return ("leaf.fill",             .orange, .brown,   ["wind", "cloud.fill", "cup.and.saucer.fill", "leaf.circle.fill"],      "Autumn begins")
        case 4:  return ("cloud.rain.fill",       .teal,   .gray,    ["umbrella.fill", "drop.fill", "leaf.fill", "wind"],                    "Autumn rains")
        case 5:  return ("flame.fill",            .brown,  .orange,  ["wind", "cloud.fog.fill", "cup.and.saucer.fill", "moon.stars.fill"],   "Cosy autumn")
        case 6:  return ("snowflake",             .cyan,   .blue,    ["cloud.snow.fill", "wind.snow", "thermometer.snowflake", "scarf.fill"],"Winter arrives")
        case 7:  return ("thermometer.snowflake", .blue,   .indigo,  ["snowflake", "cloud.snow.fill", "wind", "moon.fill"],                  "Deep winter")
        case 8:  return ("wind",                  .indigo, .cyan,    ["cloud.fog.fill", "snowflake", "sun.haze.fill", "leaf.fill"],          "Winter's end")
        case 9:  return ("camera.macro",          .pink,   .green,   ["bird.fill", "ladybug.fill", "sparkles", "leaf.fill"],                 "Spring blooms")
        case 10: return ("moon.stars.fill",       .purple, .orange,  ["sparkles", "flame.fill", "star.fill", "wand.and.stars"],              "Halloween")
        case 11: return ("bird.fill",             .green,  .mint,    ["camera.macro", "sun.haze.fill", "leaf.fill", "ladybug.fill"],         "Late spring")
        case 12: return ("gift.fill",             .red,    .green,   ["star.fill", "tree.fill", "sparkles", "bell.fill"],                    "Christmas & summer")
        default: return ("calendar",              .blue,   .purple,  ["star.fill", "sparkles", "circle.fill", "heart.fill"],                 "")
        }
    }

    // MARK: - Day Section

    @ViewBuilder
    private func daySection(for day: Date, dayEvents: [FamilyEvent], externalEvents: [EKEvent], publicHoliday: Holiday?, schoolHoliday: SchoolHolidayPeriod?, isToday: Bool, today: Date) -> some View {
        let isPast = day < today

        Section {
            // School holiday label
            if let school = schoolHoliday {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.green)
                        .frame(width: 4, height: 20)
                    Text(school.name)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .opacity(isPast ? 0.5 : 1)
                .listRowBackground(Color.clear)
            }

            // Public holiday
            if let holiday = publicHoliday {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.orange)
                        .frame(width: 4, height: 24)
                    Text(holiday.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
                .opacity(isPast ? 0.5 : 1)
                .listRowBackground(Color.clear)
            }

            // User events
            if !dayEvents.isEmpty {
                ForEach(dayEvents) { event in
                    eventRow(event, on: day)
                        .opacity(isPast ? 0.5 : 1)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedEventDay = day
                            viewModel.selectedEvent = event
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteEvent(event) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if event.isTodo == true {
                                let done = event.isCompleted == true
                                Button {
                                    if !done {
                                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                                        showConfetti = true
                                    }
                                    Task {
                                        await viewModel.toggleTodoCompleted(event)
                                        if !done {
                                            try? await Task.sleep(for: .seconds(2.0))
                                            showConfetti = false
                                        }
                                    }
                                } label: {
                                    Label(done ? "Undo" : "Done", systemImage: done ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                                }
                                .tint(done ? .orange : .green)
                            } else if event.isBill == true {
                                let paid = event.isPaidOn(day)
                                Button {
                                    if !paid {
                                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                                        showConfetti = true
                                    }
                                    Task {
                                        await viewModel.toggleBillPaid(event, on: day)
                                        if !paid {
                                            try? await Task.sleep(for: .seconds(2.0))
                                            showConfetti = false
                                        }
                                    }
                                } label: {
                                    Label(paid ? "Unpay" : "Paid", systemImage: paid ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                                }
                                .tint(paid ? .orange : .green)
                            }
                        }
                        .listRowBackground(Color.clear)
                }
            }

            // Device calendar events
            ForEach(externalEvents, id: \.eventIdentifier) { ekEvent in
                externalEventRow(ekEvent)
                    .opacity(isPast ? 0.5 : 1)
                    .listRowBackground(Color.clear)
            }

            // "No events" only for today
            if dayEvents.isEmpty && externalEvents.isEmpty && publicHoliday == nil && schoolHoliday == nil && isToday {
                Text("No events")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .listRowBackground(Color.clear)
            }
        } header: {
            HStack(spacing: 8) {
                Text(Self.dayHeaderFormatter.string(from: day))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isToday ? .primary : isPast ? Color.white.opacity(0.35) : Color.white.opacity(0.7))
                if isToday {
                    Text("Today")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.chooPurple, in: Capsule())
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Event Row

    private func eventStripColor(for event: FamilyEvent) -> Color {
        if event.isTodo == true {
            return event.urgencyState == .overdue ? .red : .cyan
        }
        if event.isBill == true { return .primary }
        let uids = event.attendeeUIDs ?? []
        if uids.count == 1 {
            return MemberAvatarView.color(for: uids[0])
        }
        return .chooPurple
    }

    private func eventRow(_ event: FamilyEvent, on day: Date) -> some View {
        let paid = event.isPaidOn(day)
        let todoDone = event.isTodo == true && event.isCompleted == true

        return HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(eventStripColor(for: event))
                .frame(width: 4, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.body)
                        .strikethrough(todoDone, color: .white.opacity(0.3))

                    if event.isTodo == true && !todoDone {
                        todoUrgencyBadge(for: event)
                    }
                }

                HStack(spacing: 4) {
                    if event.isTodo == true {
                        if event.todoHasDueDate {
                            Text(todoDone ? "Done" : "Due \(Self.shortDateFormatter.string(from: event.endDate))")
                                .font(.caption)
                                .foregroundStyle(todoDone ? .green : (event.urgencyState == .overdue ? .red : .secondary))
                        } else {
                            Text(todoDone ? "Done" : "No due date")
                                .font(.caption)
                                .foregroundStyle(todoDone ? .green : .secondary)
                        }
                        if let emoji = event.todoEmoji, !emoji.isEmpty {
                            Text(emoji)
                                .font(.caption)
                        }
                    } else if event.isBill == true {
                        if let amt = event.amount {
                            Text(amt, format: .currency(code: "AUD"))
                                .font(.caption)
                                .foregroundStyle(paid ? .green : .secondary)
                        }
                    } else if event.isAllDay == true {
                        Text("All day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(Self.timeFormatter.string(from: event.startDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if event.isBill != true && event.isTodo != true, let loc = event.location, !loc.isEmpty {
                        Image(systemName: "mappin")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(loc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if event.isTodo != true, let freq = event.recurrence {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(freq.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if event.reminderEnabled == true {
                        Image(systemName: "bell.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if event.isTodo == true {
                if todoDone {
                    Text("DONE")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.green.opacity(0.15), in: Capsule())
                } else {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.2))
                }
            } else if event.isBill == true && paid {
                Text("PAID")
                    .font(.caption2.bold())
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.green.opacity(0.15), in: Capsule())
            } else if event.isBill != true {
                // Attendee avatars
                HStack(spacing: -6) {
                    ForEach(attendeeMembers(for: event)) { member in
                        MemberAvatarView(name: member.displayName, uid: member.id, emoji: member.emoji, size: 24)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                    }
                }
            }
        }
        .overlay(alignment: .trailing) {
            if let icon = eventIcon(for: event) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle((paid || todoDone) ? .green.opacity(0.18) : .white.opacity(0.12))
                    .offset(x: -45)
                    .allowsHitTesting(false)
            }
        }
        .opacity((paid || todoDone) ? 0.6 : 1)
    }

    @ViewBuilder
    private func todoUrgencyBadge(for event: FamilyEvent) -> some View {
        let state = event.urgencyState
        let (label, color): (String, Color) = {
            switch state {
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

    // MARK: - External Event Row

    private func externalEventRow(_ event: EKEvent) -> some View {
        let calColor = Color(cgColor: event.calendar.cgColor)

        return HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(calColor)
                .frame(width: 4, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "")
                    .font(.body)

                HStack(spacing: 4) {
                    if event.isAllDay {
                        Text("All day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(Self.timeFormatter.string(from: event.startDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let loc = event.location, !loc.isEmpty {
                        Image(systemName: "mappin")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(loc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text(event.calendar.title)
                        .font(.caption2)
                        .foregroundStyle(calColor.opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(calColor.opacity(0.15), in: Capsule())
                }
            }

            Spacer()
        }
        .overlay(alignment: .trailing) {
            if let icon = eventIcon(for: event.title ?? "") {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(calColor.opacity(0.09))
                    .offset(x: -10)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Event Icon Matching

    private func eventIcon(for event: FamilyEvent) -> String? {
        if event.isTodo == true {
            return event.isCompleted == true ? "checkmark.circle.fill" : "circle"
        }
        if event.isBill == true {
            return "dollarsign.circle.fill"
        }
        return eventIcon(for: event.title)
    }

    private func eventIcon(for title: String) -> String? {
        if let cached = eventIconCache[title] { return cached }
        let icon = matchEventIcon(for: title)
        eventIconCache[title] = icon
        return icon
    }

    private func matchEventIcon(for title: String) -> String? {
        let lower = title.lowercased()

        // Food & drink
        if lower.containsAny("lunch", "dinner", "brunch", "food", "eat", "restaurant", "breakfast", "bbq", "barbecue", "picnic") { return "fork.knife" }
        if lower.containsAny("coffee", "cafe", "café") { return "cup.and.saucer.fill" }
        if lower.containsAny("cook", "bake", "kitchen") { return "flame.fill" }

        // Social
        if lower.containsAny("birthday", "party") { return "party.popper" }
        if lower.containsAny("meeting", "call", "zoom", "teams") { return "person.2.fill" }
        if lower.containsAny("date", "anniversary", "valentine") { return "heart.fill" }

        // Health
        if lower.containsAny("doctor", "medical", "hospital", "health", "physio", "therapy") { return "cross.case.fill" }
        if lower.containsAny("dentist", "teeth", "orthodont") { return "mouth.fill" }

        // Fitness & sport
        if lower.containsAny("gym", "workout", "exercise", "fitness", "crossfit") { return "dumbbell.fill" }
        if lower.containsAny("run", "jog", "parkrun") { return "figure.run" }
        if lower.containsAny("swim", "pool") { return "figure.pool.swim" }
        if lower.containsAny("soccer", "football", "cricket", "tennis", "basketball", "sport", "game", "match") { return "trophy.fill" }
        if lower.containsAny("walk", "hike", "bush") { return "figure.walk" }
        if lower.containsAny("bike", "cycle", "cycling") { return "bicycle" }
        if lower.containsAny("dance", "ballet") { return "figure.dance" }
        if lower.containsAny("yoga", "pilates", "stretch") { return "figure.mind.and.body" }
        if lower.containsAny("surf") { return "figure.surfing" }

        // Kids & school
        if lower.containsAny("school", "class", "homework", "study", "exam", "test") { return "book.fill" }
        if lower.containsAny("play", "playground", "park") { return "figure.play" }

        // Transport & travel
        if lower.containsAny("pick up", "drop off", "drive", "car") { return "car.fill" }
        if lower.containsAny("travel", "flight", "airport", "fly") { return "airplane" }
        if lower.containsAny("holiday", "vacation") { return "suitcase.fill" }
        if lower.containsAny("beach") { return "beach.umbrella.fill" }

        // Home & errands
        if lower.containsAny("shop", "store", "market", "groceries") { return "cart.fill" }
        if lower.containsAny("clean", "cleaning", "tidy") { return "sparkles" }
        if lower.containsAny("garden", "plant", "mow") { return "leaf.fill" }
        if lower.containsAny("hair", "haircut", "barber") { return "scissors" }
        if lower.containsAny("vet", "pet", "dog", "cat") { return "pawprint.fill" }

        // Entertainment
        if lower.containsAny("movie", "cinema", "film") { return "film.fill" }
        if lower.containsAny("music", "concert", "gig") { return "music.note" }
        if lower.containsAny("photo", "camera") { return "camera.fill" }
        if lower.containsAny("paint", "art", "draw", "craft") { return "paintbrush.fill" }
        if lower.containsAny("book", "read", "library") { return "book.fill" }

        // Work
        if lower.containsAny("work", "office") { return "briefcase.fill" }

        return nil
    }

    private func attendeeMembers(for event: FamilyEvent) -> [AnyFamilyMember] {
        let uids = event.attendeeUIDs ?? []
        return viewModel.allMembers.filter { uids.contains($0.id) }
    }
}

private struct TodayDateIcon: View {
    private var todayNumber: String {
        "\(Calendar.current.component(.day, from: Date()))"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(.primary, lineWidth: 1.2)
                .frame(width: 22, height: 22)

            Text(todayNumber)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .offset(y: 1)
        }
    }
}
