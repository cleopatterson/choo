# Auto-Plan: AI-Generated Weekly Plans

## The Idea

When a new week starts, the AI automatically generates plans for dinners, exercise, and chores. No wizard, no planner button, no blank screen. You open the tab and your week is already there. Adjustments happen through the existing tap-to-swap, tap-to-remove interactions — no new UI needed.

---

## How It Works

The auto-plan runs **once per week, on first app open on or after Monday**, and never again until the following week. It will never overwrite a plan you've already tweaked. One API call per tab. The response populates the existing week plan models that feed the week strip views.

**Relationship to AI briefing:** The auto-plan and the AI briefing are independent systems. The auto-plan populates the week data (meals, workouts, chores). The existing AI briefing reads whatever's in the week — auto-planned or manually entered, it doesn't know or care — and generates its summary on its own schedule. Auto-plan fills the data, briefing summarises it. No special integration needed.

**Model choice:** Start with **Haiku for all three tabs**. The prompts are structured with clear rules and JSON output, which Haiku handles well. If chore plan quality isn't good enough (the urgency × importance × seasonality reasoning is the most demanding), upgrade chores to **Sonnet** while keeping Haiku for dinners and exercise. The API call architecture is identical — just swap the model string per tab. Sonnet is ~15x more expensive per call, so only escalate where the reasoning quality justifies it.

**Trigger logic:**

1. `WeekPlanManager` stores a `lastAutoPlanWeek` date in UserDefaults (the Monday of the week it last ran)
2. On `scenePhase` becoming `.active`, check: is `lastAutoPlanWeek` before this week's Monday?
3. If yes → this is the first open of a new week. Check each tab: is the week plan empty for this week?
4. Only auto-plan tabs where the plan is **completely empty** — if the user has already manually added anything (even one meal or one workout), skip that tab entirely
5. Set `lastAutoPlanWeek` to this week's Monday. Done. Won't fire again until next Monday.

**Key rule:** The auto-plan never runs mid-week, never overwrites, never re-generates. Once it's fired (or been skipped because you already started planning manually), it's done for the week. Your plan is yours.

**Fallback:** If the API call fails (offline, rate-limited), the week strip stays empty and the user plans manually as they do today. The briefing card says "Couldn't auto-plan this week — add meals/workouts/chores manually." The auto-plan will **not retry** later in the week — it respects the once-per-week rule. If you want a plan after a failed auto-plan, you add things manually.

---

## Three AI Personalities

### Dinners — Household Coordinator

**Scope:** Plans for the whole household. Tony is the cook.

**What the AI knows:**
- EventKit calendar for the week (all family members)
- Meal library with prep times
- Completion history — which meals were cooked and when
- Learned habits (e.g. Sunday roast pattern)

**How it plans:**
1. Scan calendar for evenings where Tony is out → mark as **Fend night** (Alex sorts herself out)
2. Scan for evenings where everyone is out → mark as **Out**
3. For remaining cook nights, estimate evening free time from calendar gaps
4. Assign meals: exclude anything cooked in the last 7 days, prioritise meals not cooked in 14+ days, match prep time to available evening time, avoid same category back-to-back
5. Honour habits — if Sunday roast has been consistent for 3+ weeks, keep it

**Tweaking:** Tap a day card in the strip → meal library picker opens (existing interaction). Tap to swap, long-press to clear. Same as current design.

---

### Exercise — Personal Coach

**Scope:** Personal to each user. Each device runs its own copy of the app — Tony's phone gets Tony's plan, Alex's phone gets Alex's plan. No shared user system needed.

**What the AI knows:**
- Exercise persona (set during onboarding, stored locally in UserDefaults)
- Workout library with durations and categories (grows over time as user adds types)
- Last week's plan — the specific sessions assigned to each day
- Completion history from HealthKit + manual entries
- EventKit calendar for time slot conflicts

**Onboarding (first run only):**
The first time the exercise tab opens, before any auto-plan runs, the user sees a one-time setup question. This sets the AI's approach for all future weeks.

> **How would you describe your exercise routine?**
> - 💪 **I have a set routine** — *Routine mode.* The AI learns your fixed schedule and only varies the flexible parts (e.g. which yoga type goes on which day). Everything else stays locked.
> - 🎯 **I exercise sometimes, want more structure** — *Guided mode.* The AI suggests a balanced week based on what you've been doing, filling gaps and adding variety.
> - 🌱 **I want to start moving more** — *Coaching mode.* The AI builds you up gradually — starting easy and adding volume week by week based on what you actually complete.

This choice is stored in **UserDefaults** on the device. Changeable anytime in Settings → Exercise → Coaching Style. Each person on their own device picks independently.

**How it plans — Routine mode:**

The user has a fixed weekly structure. The AI reads last week's plan to understand the recurring pattern, then replicates it for the new week with two adjustments:

1. **Vary the flexible slots.** For categories where the user has multiple session types (e.g. yoga library with Yin, Vinyasa, Power, Morning Stretch, etc.), the AI picks different sessions from last week for variety. It reads last week's assignments and avoids repeating the same type on the same day. It also considers recovery pairing — gentler sessions after hard training days.
2. **Resolve calendar conflicts.** Check EventKit for clashes with morning/lunch slots. Move conflicting sessions to the next available slot on the same day.

The AI receives last week's full plan as context and the workout library. It returns this week's plan with the variable sessions swapped for variety. The fixed structure (which categories go on which days, which slots) comes from last week — the AI doesn't reinvent the schedule, it just refreshes the parts that should change.

**How it plans — Coaching mode:**

Completely different problem. The user is building a habit, not confirming one.

1. Look at completion rates over the last 2–4 weeks
2. If the user hit last week's target → increment by 1 session or ~15 min
3. If the user missed 50%+ of last week's target → keep the same target, don't increase
4. Select workouts that provide variety and space high-impact sessions with recovery days
5. Never schedule two hard sessions back-to-back for a newer exerciser
6. Place in available calendar slots, preferring the user's emerging patterns (if they always do Tuesday, keep Tuesday)

**How it plans — Guided mode:**
A middle ground. The AI suggests a balanced week based on recent activity, fills gaps (e.g. no flexibility work in 2 weeks → adds yoga), but doesn't do the progressive overload ramp of coaching mode. More "here's a good week" than "here's your programme."

**Tweaking (all modes):** The auto-plan is a starting point. Tap a day card → time slot picker opens (existing interaction). Tap a workout chip to swap or remove. Tap an empty slot to add from the library. All the same interactions already designed into the exercise tab. The AI suggests, the user has final say.

---

### Chores — Pragmatic Project Manager

**Scope:** Plans for the whole household. Assigns to Tony, Alex, Kids, or Family.

**What the AI knows:**
- Chore library with cadence, estimated time, default person, importance level
- Completion history — when each chore was last done
- EventKit calendar for free time per day
- Season (derived from date, Southern Hemisphere)

**How it plans:**
1. Calculate **free chore time per day** from calendar — weekday evenings are usually 0, weekends are the main window
2. Calculate **total weekly budget** (realistic hours available)
3. Score each chore: `urgency × importance × seasonal_adjustment`
   - **Urgency:** days overdue / days until due. Overdue items score highest
   - **Importance:** Health/safety (pool chemicals) > Core weekly (vacuum, bathrooms) > Maintenance (hedges) > Nice-to-have (windows)
   - **Seasonal adjustment:** Lawns in winter = relaxed cadence. Gutters before winter = urgency bump. Pool chemicals = no seasonal adjustment (always critical)
4. Select chores that fit within the weekly budget, highest score first
5. Place on days with available time, respecting default person assignments
6. **Fixed-day items** (bins on collection day) are placed first
7. **Deferred items** are tracked — shown in a "Can wait" section below the strip with reasoning

**Tweaking:** Tap a day card → chore picker opens with person assignment (existing interaction). Tap a chip to reassign or remove. Tap "+ Add" on deferred items to pull them back into the plan.

---

## AI Prompts

### Dinner System Prompt

```
You are a household dinner coordinator. You help plan what to cook each week 
based on who's home, available cooking time, and meal variety.

You receive a JSON context with:
- cook_nights: which nights the cook is home and available
- evening_free_minutes: estimated free time per night (from calendar)
- meal_library: all meals with prep_time_minutes and last_cooked_days_ago
- habit_patterns: recurring meals (e.g. Sunday roast)

Respond with JSON only:
{
  "plan": [
    {"day": "Mon", "meal_id": "omelette"},
    {"day": "Fri", "status": "fend"},
    ...
  ]
}

Rules:
1. Never suggest a meal longer than the evening's free time
2. Exclude meals cooked in the last 7 days
3. Prioritise meals not cooked in 14+ days
4. No same-category meals on consecutive nights
5. Honour habit patterns (3+ consecutive weeks = habit)
6. Mark nights where cook is out as "fend"
7. Mark nights where everyone is out as "out"
```

### Exercise — Routine Mode

```
You are generating this week's exercise plan for someone with an 
established routine. Their schedule structure is fixed — your job is 
to replicate last week's structure but vary the flexible sessions 
for freshness and recovery-aware pairing.

You receive:
- last_week_plan: the full plan from last week (day, slot, category, session_id)
- workout_library: all available session types per category
- calendar_conflicts: any events that clash with usual exercise slots

Respond with JSON only:
{
  "plan": [
    {"day": "Mon", "slots": [
      {"slot": "Morning", "category": "yoga", "session_id": "vinyasa"},
      {"slot": "Afternoon", "category": "strength", "session_id": "upper"}
    ]},
    ...
  ],
  "conflicts": [
    {"day": "Thu", "slot": "Morning", "moved_to": "Lunch", "reason": "Calendar clash"}
  ]
}

Rules:
1. Replicate last week's structure — same categories on same days, same slots
2. For categories with multiple session types, vary the selection from last week
3. Don't assign the same session type on consecutive days
4. Prefer gentler sessions (Yin, stretching) on days with heavy complementary training
5. If a slot has a calendar conflict, move to the next available slot that day
6. If no slot is available, drop the session and include in conflicts
7. Weekend and rest day patterns should carry over unchanged
```

### Exercise — Coaching Mode

```
You are a personal fitness coach helping someone build an exercise habit.
Celebrate consistency over intensity. Never guilt or pressure.

You receive:
- journey_week: which week of the programme (1-ongoing)
- weekly_completions: sessions completed per week for the last 6 weeks
- calendar_events: this week's events with times
- workout_library: all available session types per category
- fitness_level: beginner / intermediate

Respond with JSON only:
{
  "plan": [
    {"day": "Mon", "slots": [
      {"slot": "Morning", "category": "yoga", "session_id": "gentle-yoga"}
    ]},
    ...
  ],
  "target_sessions": 3,
  "target_minutes": 90
}

Rules:
1. Never increase by more than 1 session or 15 minutes week-over-week
2. If user missed 50%+ of last week's target, keep the same target
3. At least 1 rest day between high-impact sessions
4. Favour variety for beginners
5. Place workouts in available calendar slots
6. Build on emerging patterns — if the user consistently does Tuesdays, keep Tuesday
```

### Chores System Prompt

```
You are a pragmatic household project manager. You prioritise honestly 
and defer what can wait. You never over-commit.

You receive:
- chore_library: each with cadence_days, last_done_days_ago, 
  estimated_minutes, default_person, importance (health/core/maintenance/nice-to-have)
- free_time_per_day: minutes available for chores per day (from calendar)
- season: current season (Southern Hemisphere)
- typical_weekly_hours: average chore time over last 4 weeks

Respond with JSON only:
{
  "week_type": "lighter",
  "budget_hours": 2,
  "plan": [
    {"day": "Mon", "chore_id": "bins", "person": "Tony", "reason": "Tuesday collection"},
    {"day": "Sat", "chore_id": "mow", "person": "Tony", "reason": "2d overdue, autumn growth slow"},
    ...
  ],
  "deferred": [
    {"chore_id": "hedges", "reason": "8 days left, next weekend lighter"},
    ...
  ],
  "briefing": "Summary with week_type, total time, key reasoning"
}

Rules:
1. Health/safety items (pool chemicals) are never deferred
2. Fixed-day items (bins) always placed on collection day
3. Seasonal adjustment: lawns winter = 21-28d cadence, summer = 14d
4. Total assigned time must not exceed budget_hours
5. Balance fairly between household members
6. Explain every deferral
7. Score: urgency × importance × seasonal_adjustment — highest scores first
```

---

## Context JSON Structure

Sent as the user message in each Haiku API call. The system prompt is tab-specific (above). The context is assembled by each tab's ViewModel from shared data stores.

```json
{
  "week_start": "2026-03-17",
  "days": [
    {
      "day": "Mon",
      "date": "2026-03-17",
      "calendar_events": [
        {"title": "Team standup", "start": "17:00", "end": "17:30"}
      ],
      "evening_free_minutes": 30,
      "morning_free": true,
      "chore_free_minutes": 0
    }
  ],
  "season": "autumn",
  "library": { },
  "history": { },
  "persona": "routine"
}
```

The `library` and `history` objects are tab-specific. Each ViewModel assembles its own context from the shared EventKit, HealthKit, and CoreData stores.

---

## API Cost

- **3 calls per week maximum** — one per tab, fired once on Monday first open, never again
- **0 calls for tweaking** — all adjustments happen through existing UI interactions, no AI involved
- **0 additional calls for briefing** — the briefing system is independent and runs on its own schedule
- Start with Haiku for all three (~$0.001 per call). If chores needs Sonnet, that one tab costs ~$0.015 per call
- Prompt caching on system prompts (identical across sessions)
- Absolute worst case: 3 calls on Monday morning. That's it for the entire week.

---

## Build Order

1. `WeekPlanManager` — trigger logic (`lastAutoPlanWeek` in UserDefaults, empty-plan check, once-per-week enforcement)
2. Context JSON assembly in each tab's ViewModel
3. Dinner auto-plan with Haiku (simplest — one meal per day, no slots)
4. Chores auto-plan with Haiku (adds urgency scoring, person assignment, deferrals). **Test plan quality here** — if chore reasoning isn't sharp enough, swap to Sonnet for this tab only
5. Exercise onboarding screen (persona selection, stored in UserDefaults)
6. Exercise auto-plan — routine mode (pattern detection + conflict resolution)
7. Exercise auto-plan — coaching mode (progressive overload, journey tracking)

Each step is independently shippable. The tabs work without auto-plan (manual flow remains), so this is purely additive. The existing AI briefing system doesn't need any changes — it already reads whatever's in the week plan and generates its summary independently.
