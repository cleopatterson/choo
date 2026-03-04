# Choo — Product Requirements Document

## App Overview

**Bundle ID:** `com.tonywall.wallboard`
**Display Name:** Choo (struct is `ChooApp`)
**Platform:** iOS 17.0+
**Language:** Swift 5.10
**Framework:** SwiftUI
**Backend:** Firebase (Auth + Firestore)
**Architecture:** MVVM with `@Observable` macro

---

## File Structure

```
WallBoard/
├── WallBoard.xcodeproj/
│   └── project.pbxproj
├── WallBoard/
│   ├── Info.plist
│   ├── WallBoard.entitlements          # App Groups
│   ├── App/
│   │   ├── WallBoardApp.swift          # @main entry point (struct ChooApp)
│   │   ├── ContentView.swift           # Auth flow router
│   │   └── AppDelegate.swift           # Push notification setup
│   ├── AppIntents/
│   │   ├── AddShoppingItemIntent.swift # Siri: add shopping item
│   │   ├── AddEventIntent.swift        # Siri: add calendar event
│   │   └── ChooShortcuts.swift         # AppShortcutsProvider
│   ├── Models/
│   │   ├── Family.swift                # Family document model
│   │   ├── FamilyEvent.swift           # Calendar event + recurrence logic
│   │   ├── FamilyMember.swift          # Dependent (kid/pet)
│   │   ├── Note.swift                  # Note document model
│   │   ├── NSWHolidays.swift           # Public + school holiday data
│   │   ├── ShoppingItem.swift          # Shopping item model
│   │   ├── ShoppingList.swift          # Shopping list model
│   │   └── UserProfile.swift           # User profile + roles
│   ├── ViewModels/
│   │   ├── AuthViewModel.swift         # Auth flow state machine
│   │   ├── CalendarViewModel.swift     # Calendar logic + device cal
│   │   ├── NotesViewModel.swift        # Notes CRUD wrapper
│   │   └── ShoppingViewModel.swift     # Shopping list logic
│   ├── Views/
│   │   ├── Auth/
│   │   │   ├── LoginView.swift
│   │   │   ├── SignUpView.swift
│   │   │   └── FamilySetupView.swift
│   │   ├── Main/
│   │   │   └── MainTabView.swift       # Tab bar (Calendar, Shopping, Notes, Account)
│   │   ├── Calendar/
│   │   │   ├── CalendarTabView.swift    # Scrolling day list + month banners
│   │   │   ├── EventFormView.swift      # Create/edit event sheet
│   │   │   ├── EventDetailView.swift    # Event detail/edit sheet
│   │   │   └── CalendarSourcesView.swift# Device calendar picker
│   │   ├── Shopping/
│   │   │   ├── ShoppingTabView.swift    # Shopping list UI
│   │   │   └── ShoppingItemsView.swift
│   │   ├── Notes/
│   │   │   ├── NotesTabView.swift       # Notes list
│   │   │   └── NoteEditorView.swift     # Note create/edit sheet
│   │   ├── Account/
│   │   │   └── AccountTabView.swift     # Profile, family, members
│   │   └── Shared/
│   │       ├── ConfettiView.swift        # Confetti particle burst animation
│   │       ├── ErrorBannerView.swift
│   │       ├── LoadingView.swift
│   │       └── MemberAvatarView.swift   # Coloured initial circles
│   ├── Services/
│   │   ├── AuthService.swift            # Firebase Auth wrapper
│   │   ├── FirestoreService.swift       # All Firestore CRUD + listeners
│   │   ├── ImageGenerationService.swift # AI product image generation
│   │   ├── DeviceCalendarService.swift  # EventKit integration
│   │   ├── NotificationService.swift    # Local push notifications
│   │   ├── SharedUserContext.swift      # App Group UserDefaults bridge
│   │   └── PendingShareManager.swift    # Share extension pending queue
│   ├── Extensions/
│   │   ├── Color+WallBoard.swift        # Brand colours + wallboardBackground()
│   │   └── String+Validation.swift      # Input validation helpers
│   └── Resources/
│       ├── Assets.xcassets/
│       └── GoogleService-Info.plist
├── ChooShareExtension/
│   ├── ChooShareExtension.entitlements
│   ├── Info.plist
│   ├── ShareViewController.swift        # Extension entry point
│   └── ShareFormView.swift              # SwiftUI share form
└── docs/
    ├── MASTERPLAN.md
    ├── PRD.md
    └── TASKS.md
```

---

## Firestore Data Model

```
users/{uid}
  ├── displayName: String
  ├── email: String
  ├── familyId: String?
  └── role: "admin" | "member"

families/{familyId}
  ├── name: String
  ├── adminUID: String
  ├── memberUIDs: [String]
  ├── inviteCode: String (6-char alphanumeric)
  ├── inviteCodeExpiresAt: Timestamp
  │
  ├── shoppingLists/{listId}
  │   ├── familyId, name, createdBy, createdAt
  │   └── items/{itemId}
  │       ├── listId, name, isChecked, addedBy
  │       ├── createdAt, heading, sortOrder
  │       └── (heading items use ALL CAPS detection)
  │
  ├── events/{eventId}
  │   ├── familyId, title, startDate, endDate
  │   ├── createdBy, attendeeUIDs[]
  │   ├── isAllDay, location
  │   ├── recurrenceFrequency, recurrenceEndDate
  │   ├── reminderEnabled
  │   ├── isBill, amount, isPaid
  │   └── lastModifiedByUID, note
  │
  ├── notes/{noteId}
  │   ├── familyId, title, content
  │   ├── createdBy, createdAt, updatedAt
  │
  └── dependents/{dependentId}
      ├── familyId, displayName
      ├── type: "person" | "pet"
      └── addedBy
```

---

## Feature Details

### Authentication

**Flow:** Loading → Login ↔ SignUp → FamilySetup → Ready

- Email/password authentication via Firebase Auth
- New users create a family (generates 6-char invite code) or join one via invite code
- Auth state persisted by Firebase SDK
- `AuthViewModel` manages the flow state machine
- On ready: SharedUserContext saves uid/familyId/displayName to App Group for extensions
- On logout: SharedUserContext clears, all listeners stopped

### Calendar

**View:** Scrolling day-by-day list (not a month grid)

- Shows 6 months back + 12 months forward from today
- Auto-scrolls to today on appear
- Month banners with seasonal Australian themes (12 unique themes with right-aligned icons, colours, taglines)
- Every month always shows a banner (1st of each month forced into visibleDays)
- Day sections show: school holidays → public holidays → user events → device calendar events
- Days without content are filtered out (only month banners and days with events/holidays shown)
- Events display: colour strip, title, time/all-day, location, recurrence badge, reminder bell, attendee avatars
- Smart event icons: ~50 keyword matches (e.g., "dentist" → tooth, "birthday" → party popper)
- Tappable month/year header opens graphical date picker for quick navigation
- "Today" button to snap back
- Calendar Sources sheet to toggle device calendars on/off
- Event form: title, date range, all-day toggle, location, attendees picker, recurrence, reminder (default time 9am, auto-focused title)
- **Confetti + scroll animation** — after creating event, scrolls to the day and shows confetti burst
- **Slide-in animation** — new event day slides in from the right with spring animation
- Swipe-to-delete on events
- **Bills** — events with `isBill == true` show amount, due date, and a "Mark as Paid" action
  - Leading swipe reveals green "Paid" button (unpaid bills only)
  - Marking paid triggers confetti burst + success haptic
  - Paid bills show green checkmark badge, green amount text, dimmed row, and `checkmark.circle.fill` decorative icon
  - Event detail view shows paid/unpaid status and a prominent "Mark as Paid" button for unpaid bills
  - Editing a bill preserves its paid status

### Shopping List

**View:** Single shared list with inline add

- One default list per family (auto-created on first use)
- Items sorted by `sortOrder`, grouped under headings
- Checked items sink to bottom of their section
- ALL CAPS input auto-detected as heading (shimmer effect applied)
- AI-generated product images on each non-heading item (via ImageGenerationService)
- Tap item → edit sheet (rename, auto-focused keyboard)
- Swipe-to-delete
- Drag-and-drop reorder (edit mode always active)
- **Inline add field** — appears within the list at the target position (not a floating bar)
- **Smart + button** — inserts at end of the nearest visible heading group
- **Comma-separated entry** — "milk, bread, eggs" creates 3 items
- **Haptic feedback** — medium impact on check-off, light on add field open
- **ID-anchored insertion** — uses `sortedItems` (raw Firestore order) and item IDs for correct placement, avoiding issues from display reordering of checked items
- Navigation title: "Alan-dino" (custom family joke)

### Notes

**View:** List of note cards with editor sheet

- Glass-morphism card rows (`.thinMaterial` with border)
- Shows title, content preview (2 lines), author, relative timestamp
- Tap → full editor with title field and TextEditor
- Create or edit mode based on whether existing note is selected
- Swipe-to-delete
- Real-time sync via Firestore listener

### Account

**View:** Settings-style grouped list

- Profile section: name, email, role
- Family section: family name, invite code (with copy button), expiry, regenerate button (admin only)
- App Members: list of registered users with avatars and admin crown
- Family Members (dependents): kids/pets with avatars, swipe-to-delete, add sheet, **tap-to-edit** (name + type)
- Sign Out with confirmation dialog

### Share Extension

**Target:** `ChooShareExtension` (no Firebase dependency)

- Activated from any app sharing text or web URLs
- Presents SwiftUI form: title (pre-filled from first line) + content
- Warning banner if not logged in (checks SharedUserContext)
- Saves to `PendingShareManager` JSON file in App Group container
- Main app processes pending notes on `didBecomeActive`

### Siri Integration

**Framework:** App Intents (iOS 17+, in-process)

- `AddShoppingItemIntent`: "Add {item} to my Choo list"
- `AddEventIntent`: "Add {title} on {date} to Choo"
- Both read from SharedUserContext for familyId/displayName
- Both write directly to Firestore via raw dict (no model dependency)
- Guard: returns "Please open Choo and sign in first" if no context
- Registered via `ChooShortcuts` AppShortcutsProvider

### Notifications

- Local push notifications for calendar events
- Scheduled on app appear and whenever events change
- Managed by `NotificationService.shared`

### Device Calendar Integration

- Read-only overlay of device calendars (EventKit)
- User can toggle calendars on/off in Calendar Sources sheet
- External events shown with their calendar colour
- Separate from Choo's own events

---

## Visual Design System

### Colours
- **chooPurple:** `#8B5CF6` (primary brand)
- **chooPurpleLight:** lighter variant for backgrounds
- **Background gradient:** deep indigo → muted violet → dark teal, with radial purple glow top-right

### Surfaces
- `.wallboardBackground()` — custom gradient applied to all tab views
- `.ultraThinMaterial` — toolbar backgrounds, sheet presentations, list row backgrounds
- `.thinMaterial` — note cards, glass fields
- `.glassField()` — padded material background with subtle border for text inputs

### Components
- `MemberAvatarView` — coloured circle with initial letter, deterministic colour from UID hash
- `ErrorBannerView` — top-aligned error message with dismiss
- `LoadingView` — centered ProgressView
- `ShimmerModifier` — animated gradient sweep on heading text
- `ConfettiView` — 40-particle burst animation using Canvas + TimelineView, auto-fades over 2 seconds

### Patterns
- All list views use `.scrollContentBackground(.hidden)` to show custom gradient
- All sheets use `.presentationBackground(.ultraThinMaterial)`
- All navigation bars use `.toolbarBackground(.ultraThinMaterial, for: .navigationBar)`
- Dark mode enforced via `.preferredColorScheme(.dark)`

---

## Key Technical Decisions

1. **@Observable over ObservableObject** — iOS 17+ allows the modern `@Observable` macro, cleaner than Combine-based approach
2. **Single FirestoreService** — One service manages all Firestore operations and listeners rather than per-feature services
3. **No Firebase in Share Extension** — Avoids complexity of configuring Firebase in extension process; uses JSON file queue instead
4. **App Intents in main target** — iOS 17+ runs intents in-process, so Firebase is already configured
5. **SharedUserContext via App Group UserDefaults** — Simple key-value bridge between main app and extensions
6. **Client-side recurrence** — `FamilyEvent.occursOn(_:)` computes recurrence locally rather than storing expanded instances
7. **@ObservationIgnored for caching** — computed properties on `@Observable` classes must not write to observed properties (causes infinite re-render loops); cache vars use `@ObservationIgnored`
8. **ID-anchored list insertion** — shopping list insertion uses item IDs and `sortedItems` (raw order) rather than display indices, because `displayItems` reorders checked items to bottom of groups
