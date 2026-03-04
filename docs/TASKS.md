# Choo — Task Log

## Completed

### Phase 1 — Foundation (Feb 10, commit `5178b81`)
- [x] Xcode project setup with Firebase SPM (Auth + Firestore)
- [x] Core models: Family, UserProfile, FamilyEvent, Note, ShoppingItem, ShoppingList
- [x] AuthService (Firebase email/password)
- [x] FirestoreService (basic CRUD for users, families)
- [x] AuthViewModel with auth flow state machine (loading → login ↔ signUp → familySetup → ready)
- [x] Login, SignUp, FamilySetup views
- [x] Family creation with invite code generation
- [x] Join family via invite code
- [x] Tab navigation skeleton (Calendar, Shopping, Notes, Account)
- [x] ContentView auth flow router
- [x] AppDelegate for push notification registration
- [x] ErrorBannerView and LoadingView shared components
- [x] Color+WallBoard brand colours and hex initialiser
- [x] String+Validation helpers
- [x] GoogleService-Info.plist configured
- [x] .gitignore

### Phase 2 — Core Features (Feb 10-11, uncommitted)
- [x] **Shopping list** — full implementation with real-time sync, headings (ALL CAPS), check/uncheck, reorder, swipe-to-delete, rename, floating add bar, rapid entry
- [x] **AI product images** — ImageGenerationService, images displayed per shopping item, shimmer loading state
- [x] **ShoppingViewModel** — single default list auto-creation, sorted/grouped display items
- [x] **Calendar** — scrolling day list with 6mo back + 12mo forward, month banners with Australian seasonal themes (12 unique), event rows with colour strips and attendee avatars
- [x] **Smart event icons** — ~50 keyword matches for auto-detecting event type icons
- [x] **Event CRUD** — create/edit/delete events with title, dates, all-day, location, attendees, recurrence (daily/weekly/fortnightly/monthly/yearly), reminders
- [x] **Recurrence engine** — client-side `occursOn(_:)` method handling all frequencies with multi-day span support
- [x] **NSW holidays** — public holidays + school holiday periods displayed inline on calendar
- [x] **Device calendar overlay** — EventKit integration, calendar source picker, external events shown with calendar colours
- [x] **CalendarViewModel** — manages Firestore events, device events, member resolution, date navigation
- [x] **Notes** — list view with glass cards, editor sheet, create/edit/delete, real-time sync
- [x] **NotesViewModel** — wraps FirestoreService for notes CRUD
- [x] **Account tab** — profile info, family details, invite code with copy + regenerate, app members list, dependents (kids/pets) with add/delete
- [x] **Family members (dependents)** — FamilyMember model, Firestore CRUD, add sheet with person/pet type
- [x] **MemberAvatarView** — coloured initial circles with deterministic colours from UID hash
- [x] **Local notifications** — NotificationService scheduling reminders for upcoming events, reschedules on event changes
- [x] **Visual polish** — wallboardBackground gradient, glassmorphism, ultraThinMaterial throughout, dark mode enforced
- [x] **Month themes** — decorative icons, seasonal taglines, gradient washes per month
- [x] **Event detail view** — tappable events open detail/edit sheet
- [x] **Event form** — full form with date pickers, attendee multi-select, recurrence picker, location field
- [x] **Calendar sources view** — toggle device calendars on/off
- [x] **ShoppingItemsView** — additional shopping UI components
- [x] **App icon** — custom AppIcon.png added

### Phase 3 — Extensions & Integrations (Feb 11, uncommitted)
- [x] **SharedUserContext** — App Group UserDefaults bridge for uid, familyId, displayName, defaultShoppingListId
- [x] **PendingShareManager** — JSON file queue in App Group container for share extension
- [x] **Share Extension** — ChooShareExtension target with ShareViewController + ShareFormView, no Firebase dependency
- [x] **Siri intents** — AddShoppingItemIntent + AddEventIntent with AppShortcutsProvider
- [x] **App Groups entitlements** — both main app and extension configured for `group.com.tonywall.wallboard`
- [x] **Pending shares processing** — main app processes pending notes on didBecomeActive
- [x] **SharedUserContext wiring** — ContentView saves/clears on auth state change, ShoppingViewModel saves default list ID
- [x] **project.pbxproj** — extension target, embed phase, target dependency, entitlements build settings
- [x] **Shopping tab rename** — "Shopping" → "Alan-dino"

### Phase D — Calendar Polish (Feb 18, uncommitted)

#### Briefing Card
- [x] **Emoji icons in highlights** — swapped SF Symbols for emojis in "This week highlights" and "Also this week" sections; updated AI prompt, fallback icon mapping, HighlightsCarouselView, AlsoThisWeekView
- [x] **Summary line limit 3 → 4** — BriefingCoverView now allows 4 lines for the AI summary text
- [x] **Event detail: only show attendees going** — "Who's Going" section now filters to only members who are actually attending, instead of listing everyone
- [x] **Attendee avatar colours fixed** — MemberAvatarView was hardcoded to chooPurple; now uses deterministic per-UID colour from the existing color(for:) method
- [x] **Dinner hero tile** — DinnerStripView now shows tonight's dinner as a full-width hero card with large emoji, "TONIGHT" label, and meal name; remaining days are in a compact horizontal scroll below

### Phase C — Batch Updates (Feb 11, uncommitted)

#### Shopping UX
- [x] **Keyboard auto-focus on edit** — tapping heading/item to edit now auto-focuses the TextField via `@FocusState`
- [x] **Comma-separated multi-item add** — typing "milk, bread, eggs" creates 3 separate items
- [x] **Haptic feedback on check-off** — `UIImpactFeedbackGenerator(.medium)` fires when toggling items
- [x] **Inline add field** — replaced floating bottom add bar with inline TextField that appears within the list at the target position
- [x] **Smart + button** — inserts item at end of nearest visible heading group (not just end of list)
- [x] **Spread gesture** — MagnifyGesture to insert between items (works in simulator, unreliable on device — needs alternative approach)
- [x] **ID-anchored insertion** — insertion anchors on item ID + raw sortOrder to prevent wrong-group placement when checked items are reordered in display

#### Calendar
- [x] **Show every month** — 1st of every month always included in visibleDays so month banners always appear
- [x] **Performance caching** — visibleDays cached with `@ObservationIgnored` to prevent infinite re-render loops
- [x] **Confetti on event creation** — ConfettiView.swift (40-particle Canvas + TimelineView burst animation)
- [x] **Scroll-to-new-event** — after creating event, calendar scrolls to the day and item slides in with animation
- [x] **Month banner layout** — main seasonal icons right-aligned, decorative icons repositioned to avoid overlap
- [x] **Event form auto-focus** — keyboard opens and title field focuses immediately when creating an event
- [x] **Default event time 9am** — was incorrectly defaulting to 1am

#### Holidays
- [x] **NSW school holidays corrected** — fixed incorrect dates for 2025-2026 using NSW DOE published term dates
- [x] **2027 school holidays added** — full year of school holiday periods
- [x] **Public holidays fixed** — corrected 2027 Anzac Day, Christmas/Boxing Day observed dates
- [x] **Missing holidays added** — Easter Sunday and Labour Day for 2025-2027

#### Account
- [x] **Edit dependents** — tap-to-edit sheet for family members with name/type editing + delete
- [x] **FirestoreService.updateDependent** — new method for updating dependent name and type

#### Infrastructure
- [x] **Siri registration** — added `ChooShortcuts.updateAppShortcutParameters()` call in WallBoardApp.swift
- [x] **Share extension Info.plist** — fixed missing CFBundleIdentifier and standard keys
- [x] **App icon** — new white train outline on Choo purple (#8B5CF6) background
- [x] **Range crash fixes** — `max(0, spanDays)` guards in CalendarViewModel and FamilyEvent to prevent crash when endDate < startDate
- [x] **New file: ConfettiView.swift** — reusable confetti particle animation in Views/Shared/

### Phase E — Push Notifications (Feb 18, uncommitted)
- [x] **NotificationPreferences model** — `eventCreated`, `eventUpdated`, `eventDeleted`, `shoppingChanges` toggles with nil-means-enabled opt-out semantics
- [x] **UserProfile updated** — added `fcmTokens: [String: String]?` and `notificationPreferences: NotificationPreferences?`
- [x] **FamilyEvent updated** — added `lastModifiedByUID: String?` to prevent self-notifications
- [x] **PushNotificationService** — singleton managing FCM token write/remove to Firestore, notification preferences save
- [x] **AppDelegate** — `UIApplicationDelegate` + `MessagingDelegate` + `UNUserNotificationCenterDelegate`; registers for remote notifications, forwards APNs token to FCM, handles token refresh, displays foreground banners
- [x] **ChooApp wiring** — `@UIApplicationDelegateAdaptor(AppDelegate.self)`, `FirebaseMessaging` import
- [x] **ContentView wiring** — saves FCM token to Firestore when auth state becomes `.ready`
- [x] **AuthViewModel.signOut** — removes FCM token before clearing auth state
- [x] **lastModifiedByUID threading** — `CalendarViewModel.createEvent()` and `updateEvent()` stamp `currentUserUID`; `FirestoreService.createEvent()` accepts optional `lastModifiedByUID`
- [x] **Notification settings UI** — new "Notifications" section in AccountTabView with 4 toggles (New Events, Event Changes, Event Deletions, Shopping List Changes), auto-saves to Firestore, loads from user profile on appear
- [x] **Firebase Cloud Functions** — three Firestore triggers (`onEventCreated`, `onEventUpdated`, `onEventDeleted`) that read family members, check notification preferences, collect FCM tokens (excluding modifier), send multicast push via Firebase Admin SDK
- [x] **Cloud Functions infrastructure** — `functions/` directory with `package.json`, `tsconfig.json`, `src/index.ts`; deployed to `wallboard-4b695` project on Node.js 22
- [x] **Entitlements** — added `aps-environment: development` to `Choo.entitlements`
- [x] **Info.plist** — added `UIBackgroundModes: [remote-notification]`
- [x] **firebase.json + .firebaserc** — project config for Firebase CLI deploy
- [x] **.gitignore** — added `functions/lib/` and `functions/node_modules/`

### Phase F — Notes Rewrite & UI Polish (Feb 20, uncommitted)

#### Notes — Clean Note/List Separation
- [x] **Note vs List type** — new notes show a segmented picker (Note/List) at creation time; type is locked on edit
- [x] **Note mode** — clean TextEditor for freeform content, no checklist toolbar buttons
- [x] **List mode** — checkable items with circle/checkmark toggle, swipe-to-delete, drag-to-reorder, "Add item" field at bottom
- [x] **Clear done button** — section header shows "Clear done" link to bulk-remove completed items in list mode
- [x] **Backward compatible** — list items stored as `- [x]`/`- [ ]` prefixed lines in `content` field; existing notes still work
- [x] **`isList` field persisted** — `createNote` passes `isList: Bool` through ViewModel → FirestoreService → Firestore
- [x] **Auto-focus title** — title field auto-focuses when creating a new note
- [x] **Flush unsaved text on save** — text typed in "Add item" field without pressing Return is included when saving
- [x] **Note ordering fixed** — notes sorted by `updatedAt` descending so newest/recently edited appear at top
- [x] **Type icons in note list** — noteRow shows checklist vs note.text icon to distinguish types
- [x] **Better list preview** — note rows show first 3 unchecked item names + "X/Y done" count instead of just progress
- [x] **Removed NoteLine model** — replaced mixed checklist/text parsing with clean ListItem model

#### Notes — Performance Optimisations
- [x] **Extracted ListItemRowView** — isolated struct per row prevents full-list re-render on each keystroke
- [x] **ForEach($listItems)** — direct bindings via `ForEach($listItems)` instead of `Array(enumerated())` pattern
- [x] **Removed manual Binding closures** — `$item.text` replaces `listItemTextBinding(index:)`
- [x] **Single @FocusState enum** — consolidated two separate `@FocusState` bools into one `Field` enum
- [x] **Symbol transition on toggle** — `.contentTransition(.symbolEffect(.replace))` instead of `withAnimation` wrapping entire form
- [x] **Simplified disabled checks** — `title.isEmpty` instead of `trimmingCharacters` on every render

#### Shopping Tab
- [x] **"Chef's surprise!" placeholder** — hero card shows fun text when a meal has no ingredients (e.g., bitsa, eat out)
- [x] **Hero card alignment** — TONIGHT and date top-aligned; emoji bottom-aligned with subtitle text
- [x] **Removed sparkles icon** — "Chef's surprise!" is plain text to preserve left alignment
- [x] **Softened category headings** — aisle headers toned down: background opacity 0.55→0.2, text opacity reduced, badge restyled with subtle glass look

#### Calendar Tab
- [x] **Toolbar reorganised** — Today and Filter buttons moved to left side alongside month picker; Plus button gets its own spot on the right

#### Note Editor Styling
- [x] **chooBackground on editor** — note editor uses the app's gradient background instead of plain dark material

#### Event Reminders
- [x] **Reminders only for attendees** — local notification reminders now only scheduled for events where the current user is in the attendee list
- [x] **Reminder default off** — `reminderEnabled` defaults to `false` in EventFormView (was `true`)
- [x] **NotificationService attendee filter** — `rescheduleAll` accepts `currentUserUID` and skips events the user isn't attending

#### Avatar Improvements
- [x] **Better colour distribution** — MemberAvatarView hash changed from Unicode scalar sum to djb2 algorithm; family members no longer share the same colour
- [x] **Emoji avatars for dependents** — FamilyMember model gains `emoji: String?` field; MemberAvatarView shows emoji when set instead of initial letter
- [x] **Emoji picker in edit sheet** — AccountTabView edit dependent sheet now includes a 7-column emoji grid (20 options) for setting avatar emoji
- [x] **AnyFamilyMember emoji** — emoji field propagated through CalendarViewModel to all calendar views (CalendarTabView, EventDetailView, EventFormView, CalendarSourcesView)
- [x] **FirestoreService.updateDependent** — persists emoji to Firestore; uses `FieldValue.delete()` when emoji is cleared

### Phase H — Cross-Tab Consistency Round 2 (Mar 2, uncommitted)

#### AI Load Optimisation
- [x] **Stop AI briefing regenerating on tab switch** — `WeeklyBriefingViewModel.load()` and `DinnerPlannerViewModel.load()` now guard with `hasLoadedInitially` so `.task` re-invocations on tab appearance are no-ops after the first load

#### Visual Consistency Across Tabs
- [x] **Consistent card widths** — removed extra `.padding(.horizontal, 12)` and `.padding(.vertical, 8)` from Calendar hero card; added 16pt horizontal list row insets to Shopping tab's DinnerStripView so all tabs match Exercise's 16pt padding
- [x] **Remove "THIS WEEK" heading from Exercise** — `ExerciseWeekStripView` no longer shows the `Text("THIS WEEK")` heading above the day card strip
- [x] **Consistent day card heights** — both Exercise and Shopping day cards now have `.frame(minHeight: 120)` ensuring uniform card height across tabs

#### Calendar Events Merge
- [x] **Unified event carousel** — Calendar briefing card now combines `highlights + otherEvents` into a single sorted carousel with no heading, replacing the three separate sections ("THIS WEEK'S HIGHLIGHTS", "ALSO THIS WEEK", "WEATHER")
- [x] **Weather heading removed** — `WeatherStripView` gains `showHeading: Bool = true` parameter; Calendar passes `false` to hide "WEATHER" / "Sydney" header
- [x] **Conditional heading in HighlightsCarouselView** — heading only renders when non-empty string
- [x] **NextWeekPreviewView updated** — same merge applied: unified carousel, no heading, weather without header, AlsoThisWeekView removed
- [x] **AlsoThisWeekView no longer used in Calendar** — both WeeklyBriefingCardView and NextWeekPreviewView remove AlsoThisWeekView references

### Phase G — Bills: Mark as Paid (Feb 24, uncommitted)
- [x] **`isPaid` field on FamilyEvent** — optional `Bool?` so existing Firestore documents decode as nil (unpaid)
- [x] **`markBillAsPaid()` in CalendarViewModel** — sets `isPaid = true`, stamps `lastModifiedByUID`, persists via Firestore
- [x] **Leading swipe action on bill rows** — green "Paid" button with `checkmark.circle.fill`, only shows for unpaid bills, triggers confetti + success haptic
- [x] **Paid visual indicator on bill rows** — green checkmark badge after amount, amount text turns green, row dimmed to 60% opacity, decorative icon switches from `dollarsign.circle.fill` to `checkmark.circle.fill` (green tint)
- [x] **Paid status in EventDetailView** — "Status: Paid/Unpaid" row with matching icon and colour
- [x] **"Mark as Paid" button in EventDetailView** — prominent green button above delete, only for unpaid bills, with confetti overlay + success haptic
- [x] **Edit preserves paid status** — editing a paid bill carries `isPaid` through to the updated event
- [x] **Non-bill events unaffected** — swipe action and paid UI only appear when `isBill == true`

---

## In Progress — Shopping List UX (Feb 12)

### Bugs
- [ ] **Shopping list insertion accuracy** — inline add field appears in correct group but item sometimes lands in adjacent group; `insertAtNearestGroup` logic rewritten, needs further device testing
- [ ] **Spread gesture alternative** — MagnifyGesture unreliable on device within List; need alternative (long-press row, or dedicated insert button per group)

### Quick Wins
- [ ] **Unsorted section at top** — items added without a group (e.g., by Alex) land in an "Unsorted" section at the top of the list; Tony can drag them into the right aisle group later
- [ ] **Reduce check-off friction** — checking items off at the store felt like a chore in Cozi; consider bigger tap targets, swipe-to-check, or checked items fading/disappearing rather than just sinking
- [ ] **Quick-add for Alex** — default add (+ button / Siri) should put items in the Unsorted section, not require group knowledge

### UX Rethink
- [ ] **Uncheck-centric pre-shop flow** — the primary pre-shop action is *unchecking* previously checked items, not adding. The UI should make bulk unchecking easy (e.g., show checked items prominently during planning, not sunk to the bottom)
- [ ] **Remove spread gesture** — replace with a simpler "insert here" mechanism (per-group + button, or long-press to insert between items)

---

## Planned — Phase 4: Polish & Ship

- [ ] **Ad hoc distribution** — get the app onto Tony's and wife's iPhones
- [ ] **Onboarding** — simple first-run experience for wife (create account, join family)
- [ ] **Bug fixes** — address issues found during real-world usage
- [ ] **Micro-interactions** — animated check marks, smooth list transitions
- [ ] **Performance tuning** — profile and optimise Firestore listener efficiency
- [ ] **Commit & push** — clean up git history, commit Phase 2 + 3 + C changes

---

## Planned — Phase 5: Future Enhancements

### Shopping List
- [ ] **Shopping mode** — dedicated "at the store" view: larger text, aisle-sorted, easy one-tap check, checked items disappear instantly
- [ ] **Batch reset / "Start new shop"** — show all checked items, batch-uncheck staples (may need "staple" tag concept)
- [ ] **Smart meal expansion** — meals section that knows ingredients per meal, auto-adds them
- [ ] **Temporary lists** — for holidays or special one-off meals (joint creation, disposable)
- [ ] **Multiple shopping lists** — separate lists (e.g., "Aldi", "Bunnings")
- [ ] **Assigned items** — tag shopping items to a person ("Tony's picking up")
- [ ] **Export shopping list** — share as text to Messages/WhatsApp

### Other Features
- [ ] **Home screen widgets** — today's events widget, shopping list widget (WidgetKit)
- [ ] **Confetti / celebration effects** — when shopping list is all checked off, on birthdays
- [ ] **Meal planning** — weekly meal planner linked to shopping list
- [ ] **Photo sharing** — family photo feed or album
- [ ] **Apple Watch companion** — quick-glance shopping list and today's events
- [ ] **iCloud backup** — export/import family data
- [ ] **Location-based reminders** — "Remind me when near Aldi"
- [ ] **Custom themes** — let users pick accent colour or background style
- [ ] **Sound effects** — optional satisfying sounds on interactions
- [ ] **Animated tab transitions** — custom tab switching animations
- [ ] **Rich note editor** — markdown or basic formatting in notes
- [ ] **Trip planning mode** — dedicated itinerary builder with day-by-day schedule
- [ ] **Recipe integration** — save recipes and auto-generate shopping items
- [ ] **Family birthday countdown** — prominent countdown to upcoming family birthdays
- [ ] **Drag items between lists** — if multiple lists exist
- [ ] **Dark/light mode toggle** — option to switch (currently dark-only)
- [ ] **Undo support** — undo delete on items and events

---

## Known Issues

- **NaN CoreGraphics warnings** — harmless SwiftUI warnings during animations (shimmer/confetti), no visual impact
- **Keyboard constraint warnings** — standard iOS keyboard layout auto-layout noise, not from our code
- **App Group CFPrefs warning** — `kCFPreferencesAnyUser` container warning on device; SharedUserContext still works
- **Spread gesture on device** — MagnifyGesture conflicts with List scroll gesture on real hardware; works in simulator

---

## Notes

- Only one git commit exists so far (Phase 1). All Phase 2, 3, and C work is uncommitted.
- The project uses `project.yml` (possibly for xcodegen) but the pbxproj is maintained directly.
- The app's display name is "Choo" but the Xcode project/target is "WallBoard" (original working title).
- Shopping tab heading says "Alan-dino" — this is a family personalisation.
