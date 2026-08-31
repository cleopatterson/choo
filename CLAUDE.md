# Choo — Family Hub App

## What This Is
Choo is a family hub iOS app (SwiftUI, iOS 17+) with a companion web app. It replaces Cozi for the Wall family (Tony, Alex, Harriet). Firebase backend (Firestore + Cloud Functions).

## Architecture
- **Pattern**: MVVM with `@Observable` (NOT `ObservableObject`)
- **Views**: Use `@Bindable var viewModel` for two-way bindings
- **Data layer**: `FirestoreService` is the single source of truth — all CRUD and snapshot listeners live there
- **AI**: `ClaudeAPIService` for summaries and event parsing (Haiku model); `EventClassificationService` classifies calendar events into visual registers (fun/utility/routine), stored on the event doc as `classification`
- **State**: `@ObservationIgnored` for private state that shouldn't trigger view updates

## 5 Tabs
1. **Calendar** — one scrolling agenda; events, bills, to-dos with recurrence, rendered in three Haiku-classified registers (fun/utility/routine) with month heroes and a holiday bleed for multi-day trips (see "Calendar Agenda" in `docs/DESIGN_SYSTEM.md`). Views in `Choo/Views/Calendar/`
2. **Shopping** — shopping lists, dinner planner, supplies. Views in `Choo/Views/Shopping/`
3. **Exercise** — weekly plan with 3 time slots per day. Views in `Choo/Views/Exercise/`
4. **House** — chores grouped by category with due/overdue tracking. Views in `Choo/Views/House/`
5. **Notes** — notes + bug reports (segmented toggle). Views in `Choo/Views/Notes/`

## Key File Paths
- Models: `Choo/Models/`
- ViewModels: `Choo/ViewModels/`
- Views: `Choo/Views/{TabName}/`
- Shared views: `Choo/Views/Shared/`
- Services: `Choo/Services/`
- Shared (app ↔ widget): `Choo/Shared/`
- Widget extension: `ChooWidget/`
- Web app: `choo-web/src/`
- Cloud Functions: `functions/src/index.ts`
- Design system: `docs/DESIGN_SYSTEM.md`

## Design Conventions
- Dark mode only, glassmorphism (`.ultraThinMaterial`) throughout
- Brand colour: `chooPurple` (#8B5CF6)
- Tab accents: `chooAmber` (#fb923c), `chooTeal` (#4ecdc4), `chooRose` (#C88EA7)
- `.chooBackground()` modifier for gradient backgrounds
- Glass cards: `.fill(.ultraThinMaterial)` + `.strokeBorder(.white.opacity(0.08))`
- Week starts Monday (`cal.firstWeekday = 2`)
- Australian context (NSW holidays, Sydney weather, AUD)

## Widget
- **ChooWidgetExtension** target — iOS home screen widget showing upcoming events/bills/to-dos
- Sizes: small (2x2), medium, large
- Data flow: `FirestoreService` → `WidgetDataWriter` → JSON in App Group (`group.com.tonywall.wallboard`) → widget reads via `WidgetSharedStore`
- Shared model: `Choo/Shared/WidgetSharedData.swift` (target membership: both Choo + ChooWidgetExtension)
- Widget refreshes on events snapshot change + every 30 min via timeline

## When Fixing Bugs
- Read the issue description carefully
- Check `docs/DESIGN_SYSTEM.md` before making UI changes
- Keep fixes minimal — don't refactor surrounding code
- Follow existing patterns in nearby files
- Create a branch and PR with the fix
- Max 5 files changed for a typical bug fix
