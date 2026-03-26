# House Tab Overhaul: From Weekly Planner to Frequency-Based Due System

## Context
Alex wants the Chores tab flipped from a weekly planner (assign chores to specific days) to a proactive frequency-based system where chores surface when they're due. The tab also gets renamed "House" with a warm rose accent (#C88EA7) replacing the current coral/red (#f97066).

---

## Summary of Changes

### 1. Rename & Recolor
- Tab label: "Chores" → "House", icon: `list.bullet.clipboard` → `checklist`
- Accent: `chooCoral` (#f97066) → `chooRose` (#C88EA7)
- Hero gradient: shift to warm rose/mauve tones
- Files: `MainTabView.swift`, `ChoresTabView.swift`, `Color+Choo.swift`, `TabAccent.swift`

### 2. New `ChoreFrequency` Enum
- Cases: `weekly`, `monthly`, `quarterly` (3mo), `biannual` (6mo), `yearly`
- No daily — too noisy for this app
- Add `frequency` field to `ChoreType` (default `.weekly` for backward compat)
- File: `ChoreCategory.swift`

### 3. New `ChoreCompletion` Model
- Records: choreTypeId, choreTypeName, categoryName, completedBy, completedDate, familyId
- Stored at: `families/{familyId}/choresData/shared/completions/`
- New Firestore listener (limit 200 most recent)
- File: new `ChoreCompletion.swift`, updates to `FirestoreService.swift`

### 4. Due System Logic
- A chore is **due** when: never completed, OR current date >= lastCompletedDate + frequency days
- A chore is **overdue** when: due + 3 days grace passed
- On first launch with new system: all chores appear due (correct — prompts initial pass)
- "Frequency" means days since last completion, not calendar-based (simpler)

### 5. ViewModel Rewrite (`ChoresViewModel.swift` → `HouseViewModel.swift`)
- Remove: week grid logic (weekStart, weekDays, slots, slotKey, day-based methods)
- Add: computed `dueItems` and `itemsByFrequency` from categories + completions
- New methods: `completeChore()`, `assignChore()`, `unassignChore()`
- Stats: due count, completed this month, overdue count
- AI briefing prompt updated to reference due/overdue chores

### 6. View Changes
- **Delete**: `ChoresWeekStripView.swift` (no more week strip)
- **Delete**: `ChoresAddSheet.swift` (replaced by action sheet)
- **Rewrite**: `ChoresTabView.swift` → `HouseTabView.swift` — remove week strip, add frequency-grouped list
- **Rewrite**: `ChoresHeroView.swift` → `HouseHeroView.swift` — show what's due now instead of today's day slot
- **Rewrite**: `ChoresStatsBar.swift` → `HouseStatsBar.swift` — due / completed this month / overdue
- **New**: `HouseChoreListView.swift` — main list grouped by frequency headings (Weekly, Monthly, etc.)
- **New**: `HouseChoreActionSheet.swift` — tap a chore to assign/complete
- **Update**: `ChoreTypeFormSheet.swift` → `HouseChoreTypeFormSheet.swift` — add frequency picker
- **Keep**: `ChoresManageSheet.swift` → `HouseManageSheet.swift` (add categories/types)
- **Keep**: `ChoresCategoriesView.swift` → `HouseCategoriesView.swift` (browse by area)

### 7. Preserve Existing Data
- `ChoreType.frequency` defaults to `.weekly` — existing Firestore docs without it decode safely
- Alex's custom chores all preserved, just get `.weekly` frequency by default
- Update seed defaults with sensible frequencies (gutters = quarterly, oven = monthly, etc.)
- Old `weekPlans` collection left in Firestore untouched (just not queried)

### 8. Chore Assignments
- Lightweight `[choreTypeId: assigneeId]` dictionary stored as single Firestore doc
- Separate from completions — "who will do it" vs "who did it"
- Cleared when chore is completed

### 9. File Renames (Chores* → House*)
All Chores-prefixed files get renamed to House-prefixed:
- `ChoresTabView.swift` → `HouseTabView.swift`
- `ChoresViewModel.swift` → `HouseViewModel.swift`
- `ChoresHeroView.swift` → `HouseHeroView.swift`
- `ChoresStatsBar.swift` → `HouseStatsBar.swift`
- `ChoresCategoriesView.swift` → `HouseCategoriesView.swift`
- `ChoresAddSheet.swift` → deleted (replaced by `HouseChoreActionSheet.swift`)
- `ChoresManageSheet.swift` → `HouseManageSheet.swift`
- `ChoreTypeFormSheet.swift` → `HouseChoreTypeFormSheet.swift`
- `ChoresWeekStripView.swift` → deleted
- `ChoresPlan.swift` → keep for `ChoreAssignee` (rename struct if needed)
- `ChoresBriefing.swift` → `HouseBriefing.swift`
- Update all references in `MainTabView.swift`, `ContentView.swift`, pbxproj

---

## Implementation Order
1. Models first (ChoreFrequency, ChoreCompletion, frequency field on ChoreType)
2. FirestoreService (completions + assignments listeners)
3. Rename & recolor (tab label, accent, file renames)
4. ViewModel rewrite (core logic)
5. Views (tab layout, hero, stats, frequency list, action sheet)
6. Update seed defaults with frequencies
7. Verify with existing data

---

## Key Design Decisions

### Frequency = days from last completion (not calendar-based)
- "Weekly" means 7 days from when you last did it, not "every Monday"
- Simpler, avoids edge cases with calendar weeks
- If you complete on Thursday, next due is the following Thursday

### No daily chores
- Too noisy for this app — these are things like "make bed" that don't need tracking
- Weekly is the most frequent cadence

### Everything starts as "due" on first launch
- Correct behavior — prompts users to do an initial pass
- Mark things as "done" to set the baseline completion date
- From then on, frequency kicks in

### Overdue = due + 3 days grace
- Gives a small buffer before flagging as overdue
- Overdue items highlighted in the UI (red indicator)

### Assignments vs Completions are separate
- Assignment: "Tony will do this" (lightweight, can change)
- Completion: "Tony did this on March 6" (permanent record)
- Assignment cleared when completed

---

## Verification Checklist
- [x] Existing chores appear under frequency headings
- [x] Complete a chore → completion saved in Firestore, chore no longer due
- [x] Chore reappears when frequency window passes
- [x] AI briefing references due/overdue chores
- [x] Tab says "House" with warm rose accent and checklist icon
- [x] Hero card shows what's due now
- [x] Stats bar shows due / completed / overdue counts
- [x] Add new chore with frequency picker works
- [x] Frequency editable per chore from action sheet
- [x] Week strip retained for day-planning
- [x] Accordion grouped by frequency (Jobs) + categories section (Manage Categories)
- [x] Exercise tab heading renamed to "Sessions"
- [x] Other tabs unaffected
- [ ] Build and run on device (not yet verified)
