import SwiftUI
import EventKit

// Non-reactive scroll tracker — mutations don't trigger body re-evaluation
private final class ScrollTracker {
    var visibleDays: Set<Date> = []
}

/// Holds the toolbar month title in its own observable so scroll-driven month
/// changes re-render only the small title button, never the whole tab body.
@Observable
private final class MonthTitleModel {
    var displayedMonth: Date = Calendar.current.startOfDay(for: Date())
}

private struct MonthTitleLabel: View {
    let model: MonthTitleModel
    let isPickerOpen: Bool

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var body: some View {
        HStack(spacing: 4) {
            Text(Self.monthYearFormatter.string(from: model.displayedMonth))
                .font(.system(.headline, design: .serif))
            Image(systemName: isPickerOpen ? "chevron.up" : "chevron.down")
                .font(.caption.bold())
        }
    }
}

struct CalendarTabView: View {
    @Bindable var viewModel: CalendarViewModel
    @Binding var showingProfile: Bool
    @State private var scrollToTodayTrigger = false
    @State private var scrollTracker = ScrollTracker()
    @State private var monthTitle = MonthTitleModel()
    @State private var hasScrolledInitially = false
    @State private var scrollToNewEventDate: Date?
    @State private var pendingScrollDate: Date?
    @State private var animatingDay: Date?
    @State private var showConfetti = false
    @State private var scrollTask: Task<Void, Never>?
    @State private var selectedEventDay: Date = Date()

    /// Update the toolbar month only when the month boundary actually changes.
    private func updateMonthIfNeeded() {
        guard let minDay = scrollTracker.visibleDays.min() else { return }
        let cal = Calendar.current
        if cal.component(.month, from: minDay) != cal.component(.month, from: monthTitle.displayedMonth)
            || cal.component(.year, from: minDay) != cal.component(.year, from: monthTitle.displayedMonth) {
            monthTitle.displayedMonth = minDay
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollViewReader { proxy in
                    List {
                        let days = viewModel.visibleDays
                        let today = Calendar.current.startOfDay(for: Date())

                        ForEach(Array(days.enumerated()), id: \.element) { index, day in
                            if shouldShowMonthHero(for: day, after: index > 0 ? days[index - 1] : nil) {
                                monthHeroRow(for: day)
                            }
                            let items = dayRowItems(for: day, isToday: day == today)
                            if !items.isEmpty {
                                dayGroup(for: day, items: items, isToday: day == today, today: today)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        viewModel.refreshDeviceCalendarCache()
                    }
                    .onChange(of: viewModel.selectedDate) {
                        let target = Calendar.current.startOfDay(for: viewModel.selectedDate)
                        // Delay scroll to let the month picker close first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            withAnimation {
                                let days = viewModel.visibleDays
                                let scrollTarget = days.first(where: { $0 >= target }) ?? days.last ?? target
                                proxy.scrollTo(scrollTarget, anchor: .top)
                            }
                        }
                    }
                    .onChange(of: scrollToTodayTrigger) {
                        let today = Calendar.current.startOfDay(for: Date())
                        withAnimation {
                            proxy.scrollTo(today, anchor: .top)
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
                        viewModel.kickClassificationBackfill()
                        scrollToToday(proxy: proxy, reason: "onAppear")
                    }
                    .onChange(of: viewModel.eventsFingerprint) {
                        viewModel.kickClassificationBackfill()
                    }
                    .onChange(of: viewModel.visibleDays.count) {
                        // Land on today once the first batch of days has loaded.
                        guard !hasScrolledInitially else { return }
                        hasScrolledInitially = true
                        scrollToToday(proxy: proxy, reason: "days loaded")
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
                            MonthTitleLabel(model: monthTitle, isPickerOpen: viewModel.showingMonthPicker)
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
                    claudeService: .shared
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
        }
    }

    // MARK: - Scrolling

    @State private var scrollToTodayTask: Task<Void, Never>?

    private func scrollToToday(proxy: ScrollViewProxy, reason: String) {
        let today = Calendar.current.startOfDay(for: Date())

        scrollToTodayTask?.cancel()
        scrollToTodayTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            withAnimation {
                proxy.scrollTo(today, anchor: .top)
            }
        }
    }

    // MARK: - Month Hero

    /// Heroes mark month boundaries further down the agenda — never the month
    /// you're already in, so today always sits at the top of the screen.
    private func shouldShowMonthHero(for day: Date, after previousDay: Date?) -> Bool {
        let cal = Calendar.current
        if cal.isDate(day, equalTo: Date(), toGranularity: .month) { return false }
        guard let prev = previousDay else { return true }
        return cal.component(.month, from: day) != cal.component(.month, from: prev)
    }

    private func monthHeroRow(for day: Date) -> some View {
        MonthHeroView(monthDate: day)
            .listRowInsets(EdgeInsets(top: 22, leading: 0, bottom: 4, trailing: 0))
            .listRowSeparator(.hidden)
            // Mid-trip heroes keep their art and carry only the ribbon
            .listRowBackground(
                Group {
                    if let trip = viewModel.tripSpan(on: day), trip.position != .start {
                        TripWashBackground(color: CalendarTheme.tripHue, position: trip.position, tintVisible: false)
                    } else {
                        Color.clear
                    }
                }
            )
    }

    // MARK: - Day rows

    private enum DayRowItem: Identifiable {
        case school(SchoolHolidayPeriod)
        case publicHoliday(Holiday)
        case family(FamilyEvent)
        case external(EKEvent)
        case tripContinues(FamilyEvent, isLastDay: Bool)
        case noEvents

        var id: String {
            switch self {
            case .school(let s): return "school-\(s.name)"
            case .publicHoliday(let h): return "holiday-\(h.name)"
            case .family(let e): return "event-\(e.id ?? e.title)"
            case .external(let e): return "ext-\(e.eventIdentifier ?? "")"
            case .tripContinues(let e, _): return "trip-\(e.id ?? e.title)"
            case .noEvents: return "no-events"
            }
        }
    }

    /// Register rank for in-day ordering: the trip's own start-day card leads,
    /// then fun, utility, routine; ties broken by start time.
    private func registerRank(_ event: FamilyEvent, on day: Date) -> Int {
        if event.isTripSpan && viewModel.isTripOccurrenceStart(event, on: day) { return -1 }
        switch event.effectiveRegister {
        case .fun: return 0
        case .utility: return 1
        case .routine: return 2
        }
    }

    private func dayRowItems(for day: Date, isToday: Bool) -> [DayRowItem] {
        // A trip only renders its own card on its start day — after that the bleed carries it
        let dayEvents = viewModel.filteredEvents(for: day)
            .filter { !($0.isTripSpan && !viewModel.isTripOccurrenceStart($0, on: day)) }
            .sorted { a, b in
                let ra = registerRank(a, on: day), rb = registerRank(b, on: day)
                if ra != rb { return ra < rb }
                return a.startDate < b.startDate
            }
        let extEvents = viewModel.externalEvents(for: day)

        var items: [DayRowItem] = []
        if let school = viewModel.schoolHolidayPeriod(on: day) { items.append(.school(school)) }
        if let holiday = viewModel.publicHoliday(on: day) { items.append(.publicHoliday(holiday)) }
        items.append(contentsOf: dayEvents.map { .family($0) })
        items.append(contentsOf: extEvents.map { .external($0) })
        if items.isEmpty, let trip = viewModel.tripSpan(on: day), trip.position != .start {
            // Mid-span trip days with nothing else on still render, so the bleed
            // has a row to run under and the trip stays visible/tappable.
            items.append(.tripContinues(trip.event, isLastDay: trip.position == .end))
        }
        if items.isEmpty && isToday { items.append(.noEvents) }
        return items
    }

    /// One celebration per day keeps the loud purple treatment; later same-day
    /// celebrations quieten to the social tint so the agenda never becomes a wall of noise.
    private func funTint(for event: FamilyEvent, in items: [DayRowItem]) -> CalendarTheme.FunTint {
        let subtype = event.effectiveSubtype
        if subtype != .celebration { return CalendarTheme.funTint(for: subtype) }
        let firstCelebration = items.compactMap { item -> FamilyEvent? in
            if case .family(let e) = item, e.effectiveRegister == .fun, e.effectiveSubtype == .celebration { return e }
            return nil
        }.first
        return firstCelebration?.id == event.id ? .celebration : .social
    }

    @ViewBuilder
    private func dayGroup(for day: Date, items: [DayRowItem], isToday: Bool, today: Date) -> some View {
        let isPast = day < today
        let trip = viewModel.tripSpan(on: day)

        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            VStack(alignment: .leading, spacing: 12) {
                if index == 0 && isToday {
                    TodayRule()
                }
                HStack(alignment: .top, spacing: 12) {
                    if index == 0 {
                        DayGutterView(day: day, isToday: isToday, isPast: isPast)
                    }
                    rowContent(for: item, on: day, items: items)
                        .frame(maxWidth: .infinity)
                }
            }
            .opacity(isPast ? 0.5 : 1)
            .scaleEffect(y: animatingDay == day ? 0.01 : 1, anchor: .top)
            .opacity(animatingDay == day ? 0 : 1)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(
                top: index == 0 ? 16 : 4,
                leading: index == 0 ? 14 : 66,
                bottom: 4,
                trailing: 14
            ))
            .listRowBackground(
                Group {
                    if let trip {
                        TripWashBackground(color: CalendarTheme.tripHue, position: trip.position)
                    } else {
                        Color.clear
                    }
                }
            )
            .modifier(FirstRowMarker(day: day, isFirst: index == 0, scrollTracker: scrollTracker, updateMonth: updateMonthIfNeeded))
        }
    }

    @ViewBuilder
    private func rowContent(for item: DayRowItem, on day: Date, items: [DayRowItem]) -> some View {
        switch item {
        case .school(let school):
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.green)
                    .frame(width: 4, height: 20)
                Text(school.name)
                    .font(.caption)
                    .foregroundStyle(.green)
                Spacer(minLength: 0)
            }

        case .publicHoliday(let holiday):
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.orange)
                    .frame(width: 4, height: 24)
                Text(holiday.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
                Spacer(minLength: 0)
            }

        case .family(let event):
            eventCard(for: event, on: day, items: items)
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

        case .external(let ekEvent):
            ExternalEventRow(event: ekEvent)

        case .tripContinues(let event, let isLastDay):
            HStack(spacing: 6) {
                Text("✈️")
                    .font(.system(size: 12))
                    .opacity(0.7)
                Text(isLastDay ? "\(event.title) — last day" : event.title)
                    .font(.custom("Georgia-Italic", size: 12.5))
                    .foregroundStyle(CalendarTheme.tripHue.opacity(0.7))
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedEventDay = day
                viewModel.selectedEvent = event
            }

        case .noEvents:
            Text("No events")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func eventCard(for event: FamilyEvent, on day: Date, items: [DayRowItem]) -> some View {
        let attendees = attendeeMembers(for: event)
        switch event.effectiveRegister {
        case .fun:
            FunEventCard(event: event, day: day, attendees: attendees, tint: funTint(for: event, in: items))
        case .utility:
            UtilityEventCard(event: event, day: day, attendees: attendees)
        case .routine:
            RoutineEventRow(event: event, attendees: attendees)
        }
    }

    private func attendeeMembers(for event: FamilyEvent) -> [AnyFamilyMember] {
        let uids = event.attendeeUIDs ?? []
        return viewModel.allMembers.filter { uids.contains($0.id) }
    }
}

/// Google-style "now" rule: a dot and a thin line running above today's row.
private struct TodayRule: View {
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(CalendarTheme.accentLilac)
                .frame(width: 6, height: 6)
            Rectangle()
                .fill(CalendarTheme.accentLilac.opacity(0.7))
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}

/// Attaches the day anchor id and scroll tracking to the first row of a day group.
private struct FirstRowMarker: ViewModifier {
    let day: Date
    let isFirst: Bool
    let scrollTracker: ScrollTracker
    let updateMonth: () -> Void

    func body(content: Content) -> some View {
        if isFirst {
            content
                .id(day)
                .onAppear {
                    scrollTracker.visibleDays.insert(day)
                    updateMonth()
                }
                .onDisappear { scrollTracker.visibleDays.remove(day) }
        } else {
            content
        }
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
