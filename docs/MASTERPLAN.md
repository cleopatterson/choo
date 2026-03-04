# Choo — Masterplan

## What Is Choo?

Choo is a family hub app that replaces Cozi — the free, daggy family organiser that Tony and his wife have used for years and merely tolerated. It covers three core use cases the family actually has, wrapped in a visual experience that's genuinely fun to open.

The name "Choo" is playful and punchy. The project's Xcode target is called "WallBoard" (the original working title), but the user-facing brand is **Choo**.

---

## Who Is It For?

**Primary users:** Tony, his wife Alex and Harriet his daughter — a two-parent household with kids.

- **Tony** — plans holidays, manages the calendar, maintains the shopping list, adds events, coordinates logistics.
- **Wife** — manages the calendar, adds events, checks the shared calendar, views shared notes/itineraries.
- **Kids** — represented in the app as "dependents" (non-app family members), shown on calendar events as attendees.

The family also has pets, who can be added as family members for fun but also for practical purposes like haircuts and vet visits 

---

## The Three Use Cases

### 1. Shared Calendar
A single shared family calendar where both parents can:
- Add, edit, and delete events
- See each other's commitments at a glance
- Assign attendees (including kids/dependents)
- View Australian public holidays and NSW school holidays inline
- Pull in device calendar events (iCal, Google Calendar) as read-only overlays
- Get local push notifications for upcoming events
- Get cross-device push notifications when family members create/update/delete events
- Set recurring events (daily, weekly, fortnightly, monthly, yearly)
- Mark bills as paid with a satisfying swipe action — confetti burst + haptic, visual "paid" indicator on the row and detail view

This is **not** for work. It's purely for family logistics: kids' sport, dentist appointments, date nights, holidays, school pickups.

### 2. Shopping / Grocery List

**The list is persistent and cyclical** — it's not a disposable checklist. The same items live on the list week after week. Each weekly shop involves "reactivating" (unchecking) items, not building a list from scratch.

#### Tony's Weekly Workflow
1. **Kitchen walkthrough** — Goes room by room (under bench → sink → pantry) with phone in hand, scanning the list and unchecking items that need restocking. Most pre-shop interaction is *unchecking*, not adding.
2. **Occasional new items** — Sometimes something new is needed (pepper, foil). Tony adds it into the correct aisle group so it's in the right spot at Aldi.
3. **Meal planning** — Checks the weekly meal plan (5-6 meals), unchecks meal ingredients or adds new ones. Currently uses a "meals" heading with meal names (e.g., "tacos") as memory triggers — Tony mentally expands these to ingredients at the store.
4. **Ad-hoc additions throughout the week** — Things that run out (dish soap, toothpaste) get added whenever noticed, so they're not forgotten.

#### Alex's Usage
- Adds specific items (pads, shampoo, laundry powder) without knowing or caring about aisle groups
- Items she adds should land in an "Unsorted" section at the top for Tony to drag into the right aisle later

#### At the Store
- The list functions more as a **memory aid / visual scan** than a strict checklist
- Tony scans for things he might forget, then just gets them
- Checking items off one-by-one felt like a chore in Cozi — reducing friction here matters
- Items are organised by aisle heading to match the store layout

#### Current Features
- Add items in real-time (synced via Firestore)
- Check/uncheck items (checked items sink to bottom of their heading group)
- Organise items under headings (type a name in ALL CAPS to create a heading)
- Reorder items with drag-and-drop
- AI-generated product images next to each item
- Inline add with comma-separated multi-item entry
- Swipe-to-delete, tap-to-rename

#### Future Ideas (Parked)
- **Shopping mode** — a dedicated "at the store" view with larger text, sorted by aisle, easy one-tap check-off, checked items disappear instantly
- **Batch reset / "Start new shop"** — show all checked items and batch-uncheck staples (may need a "staple" concept)
- **Smart meal expansion** — meals section that knows what ingredients each meal needs
- **Temporary lists** — for holidays or special meals (joint creation, disposable)

### 3. Shared Notes / Trip Planning
A central place for shared plans and notes:
- Tony typically plans holidays (e.g., Tasmania trip) and wants to share the itinerary
- Each note is either a **Note** (freeform text) or a **List** (checkable items), chosen at creation time
- **Note mode** — simple text editor for trip plans, ideas, anything freeform
- **List mode** — checkable items with add field, drag-to-reorder, swipe-to-delete, "Clear done" for completed items
- Both parents can create, edit, and delete notes
- Notes sync in real-time, sorted by most recently updated
- Note list shows type icon (note vs checklist) and list previews show first few unchecked items

This replaces using the iOS Notes app for trip planning, keeping everything in one family hub.

---

## Design Aesthetic & Vibe

### The Problem with Cozi
Cozi looks like it was designed in 2011 and never updated. It's functional but joyless — no personality, no delight, no reason to open it beyond necessity.

### The Choo Aesthetic
Choo should feel like the **opposite of Cozi**:

- **Dark mode first** — deep indigo/violet/teal gradient backgrounds, not flat black
- **Glassmorphism** — `.ultraThinMaterial` backgrounds, frosted glass cards, subtle borders
- **Purple brand colour** — `#8B5CF6` (chooPurple) as the accent throughout
- **Playful touches everywhere:**
  - Shimmer effects on shopping list headings
  - AI-generated product images on shopping items
  - Seasonal month banners in the calendar (Australian seasons — summer in Dec/Jan, winter in Jun/Jul)
  - Decorative SF Symbol icons scattered in month headers
  - Auto-matched event icons (birthday → party popper, dentist → tooth, gym → dumbbell)
  - Coloured avatar circles for family members
  - Smooth animations and transitions
- **Material design cues** — toolbar backgrounds use `.ultraThinMaterial`, sheets use `.presentationBackground(.ultraThinMaterial)`
- **Fun to use** — checking off items, adding events, opening tabs should all feel satisfying

### Future Delight Ideas
- Haptic feedback on check-off
- Confetti or particle effects when completing a full shopping list
- Animated transitions between tabs
- Custom app icon options
- Celebration animations for birthdays/special events
- Sound effects (optional)

---

## Technical Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI (iOS 17+) |
| Architecture | MVVM with `@Observable` |
| Backend | Firebase (Auth + Firestore) |
| Real-time sync | Firestore snapshot listeners |
| Auth | Firebase Email/Password |
| Notifications | Local push (UNUserNotificationCenter) + FCM remote push via Cloud Functions |
| Cloud Functions | Firebase Cloud Functions (TypeScript, Node.js 22) — Firestore triggers for push notifications |
| Images | AI-generated via external service |
| Calendar integration | EventKit (read-only device calendars) |
| Siri | App Intents framework (iOS 17+) |
| Share Extension | Separate target, no Firebase dependency |
| Data sharing | App Groups (`group.com.tonywall.wallboard`) |

---

## Timeline & Phases

### Phase 1 — Foundation (Complete, Feb 10)
- Firebase Auth (email/password sign-up, login, sign-out)
- Family creation and invite code system
- Tab navigation skeleton (Calendar, Shopping, Notes, Account)
- Core models and Firestore service
- Basic UI shell

### Phase 2 — Core Features (Complete, Feb 10-11)
- Full shopping list with real-time sync, headings, reorder, AI images
- Full calendar with events, recurrence, attendees, device calendar overlay
- NSW public holidays and school holidays
- Notes CRUD with editor
- Account management (family members, dependents, invite codes)
- Local push notifications for events
- Visual polish (gradients, glassmorphism, month themes, event icons)

### Phase 3 — Extensions & Integrations (In Progress, Feb 11)
- Share Extension (share text from other apps → creates notes)
- Siri App Intents (voice commands to add shopping items and events)
- App Group shared user context
- Shopping tab renamed to "Alan-dino"

### Phase E — Push Notifications (Complete, Feb 18)
- FCM integration with APNs key, AppDelegate, token management
- PushNotificationService for token write/remove/refresh to Firestore
- Firebase Cloud Functions (3 Firestore triggers) for cross-device push on event CRUD
- Notification preferences UI (4 toggles) on Profile tab, persisted to Firestore
- `lastModifiedByUID` on events to prevent self-notifications
- Entitlements and Info.plist configured for remote notifications

### Phase 4 — Polish & Ship (Next)
- Ad hoc distribution to family phones
- Onboarding flow for wife
- Bug fixes from real-world usage
- Performance tuning
- Haptic feedback and micro-interactions
- App icon finalisation

### Phase 5 — Future Enhancements (Backlog)
- Meal planning / recipe integration
- Photo sharing for family
- Widgets (shopping list widget, today's events widget)
- Apple Watch companion
- iCloud backup
- Multiple shopping lists
- Assigned shopping items ("Tony's picking up")
- Location-based reminders ("remind me when I'm near Aldi")

---

## Success Criteria

The app succeeds when:
1. **Both phones have it installed** and Cozi is deleted
2. **Wife actually uses it** — the UX is intuitive enough that she adopts it without training
3. **It's more fun than Cozi** — opening the app feels good, not like a chore
4. **It handles our three use cases** better than Cozi ever did
5. **It's a learning platform** — Tony gains experience shipping a real app to phones, useful for future client work

---

## Guiding Principles

1. **Fun over formal** — This is a family app, not enterprise software. Lean into playfulness.
2. **Ship fast, iterate** — Get it on phones quickly, then polish based on real usage.
3. **Two users, not two million** — Optimise for the family's actual workflows, not hypothetical ones.
4. **Replace Cozi completely** — Every Cozi feature the family actually uses must be covered.
5. **Dark and delightful** — The visual identity should make both users want to open the app.
