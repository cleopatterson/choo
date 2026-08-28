import SwiftUI
import EventKit

// Non-reactive scroll tracker — mutations don't trigger body re-evaluation
private final class ScrollTracker {
    var visibleDays: Set<Date> = []
}

struct CalendarTabView: View {
    @Bindable var viewModel: CalendarViewModel
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

    private static let dayShortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d"
        return f
    }()

    /// "TODAY · FRI 28" on today, otherwise "SAT 29".
    private func dayHeaderLabel(for day: Date, isToday: Bool) -> String {
        let short = Self.dayShortFormatter.string(from: day).uppercased()
        return isToday ? "TODAY · \(short)" : short
    }

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
                        let today = Calendar.current.startOfDay(for: Date())

                        ForEach(Array(days.enumerated()), id: \.element) { index, day in
                            if shouldShowMonthBanner(for: day, after: index > 0 ? days[index - 1] : nil) {
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
                        scrollToToday(proxy: proxy, reason: "onAppear")
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

    // MARK: - Month Banner

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

    // dayHasContent check is now inlined in ForEach body to avoid double-computing events

    private func shouldShowMonthBanner(for day: Date, after previousDay: Date?) -> Bool {
        guard let prev = previousDay else { return true }
        return Calendar.current.component(.month, from: day) != Calendar.current.component(.month, from: prev)
    }

    private func monthBanner(for date: Date) -> some View {
        let month = Calendar.current.component(.month, from: date)

        return VStack(alignment: .leading, spacing: 2) {
            Text(Self.monthYearFormatter.string(from: date))
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(.white)
            Text(monthTagline(for: month))
                .font(.system(size: 13))
                .foregroundStyle(Self.accentLilac.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    /// Per-month theme (Southern Hemisphere / Australia). Every month unique — no repeated primary icons.
    /// The season line under the month name — Australian seasons.
    private func monthTagline(for month: Int) -> String {
        switch month {
        case 1:  return "Peak summer"
        case 2:  return "Love & late summer"
        case 3:  return "Autumn begins"
        case 4:  return "Autumn rains"
        case 5:  return "Cosy autumn"
        case 6:  return "Winter arrives"
        case 7:  return "Deep winter"
        case 8:  return "Winter's end"
        case 9:  return "Spring blooms"
        case 10: return "Halloween"
        case 11: return "Late spring"
        case 12: return "Christmas & summer"
        default: return ""
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
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
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
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
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
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }

            // Device calendar events
            ForEach(externalEvents, id: \.eventIdentifier) { ekEvent in
                externalEventRow(ekEvent)
                    .opacity(isPast ? 0.5 : 1)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            // "No events" only for today
            if dayEvents.isEmpty && externalEvents.isEmpty && publicHoliday == nil && schoolHoliday == nil && isToday {
                Text("No events")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        } header: {
            Text(dayHeaderLabel(for: day, isToday: isToday))
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(isToday ? Self.accentLilac : .white.opacity(isPast ? 0.25 : 0.4))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textCase(nil)
                .padding(.leading, 2)
                .padding(.top, 20)
                .padding(.bottom, 2)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
        }
        // Belt and braces: no rules between events, days or months.
        .listRowSeparator(.hidden)
        .listSectionSeparator(.hidden)
    }

    // MARK: - Event Row

    private func eventRow(_ event: FamilyEvent, on day: Date) -> some View {
        let paid = event.isPaidOn(day)
        let todoDone = event.isTodo == true && event.isCompleted == true

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 15, weight: .semibold))
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
                if let glyph = eventIcon(for: event) {
                    Image(systemName: glyph)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                }

                // Attendee avatars
                HStack(spacing: -8) {
                    ForEach(attendeeMembers(for: event)) { member in
                        MemberAvatarView(name: member.displayName, uid: member.id, emoji: member.emoji, size: 26)
                            .overlay(Circle().stroke(Self.avatarRing, lineWidth: 2))
                    }
                }
            }
        }
        .opacity((paid || todoDone) ? 0.6 : 1)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Self.eventCardFill, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Self.eventCardStroke, lineWidth: 1)
        )
    }

    // MARK: - 9b palette

    /// rgba(150,110,250,.45) — bright enough to hold its own on the gradient.
    private static let eventCardFill = Color(red: 0.588, green: 0.431, blue: 0.980).opacity(0.45)
    /// rgba(206,193,255,.4)
    private static let eventCardStroke = Color(red: 0.808, green: 0.757, blue: 1.0).opacity(0.4)
    /// rgba(232,226,255,.85) — the meta line under an event title.
    private static let eventMetaColor = Color(red: 0.910, green: 0.886, blue: 1.0).opacity(0.85)
    /// #c4b5fd — today's day header and the month season line.
    private static let accentLilac = Color(red: 0.769, green: 0.710, blue: 0.992)
    /// #372a63 — the ring separating overlapping faces from the card.
    private static let avatarRing = Color(red: 0.216, green: 0.165, blue: 0.388)

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

        return HStack(spacing: 12) {
            Capsule()
                .fill(calColor)
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title ?? "")
                    .font(.system(size: 15, weight: .semibold))

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
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.vertical, 13)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
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
