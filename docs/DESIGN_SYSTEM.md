# Choo Design System

Reference for all UI patterns, tokens, and interaction conventions. Consult before making any visual or interaction changes.

---

## Colour Tokens

| Token | Hex | Usage |
|-------|-----|-------|
| `chooPurple` | `#8B5CF6` | Brand primary, Calendar tab accent |
| `chooPurpleLight` | lighter variant | Hover/active states |
| `chooAmber` | `#fb923c` | Shopping tab accent |
| `chooTeal` | `#4ecdc4` | Exercise tab accent |
| `chooRose` | `#C88EA7` | House tab accent |

### Tab Accent Mapping (`TabAccent` enum)
- `.calendar` → `chooPurple`
- `.shopping` → `chooAmber`
- `.exercise` → `chooTeal`
- `.house` → `chooRose`

---

## Background

All screens use `.chooBackground()` modifier:
- 3-colour linear gradient (deep indigo → muted violet → dark teal), `.topLeading` → `.bottomTrailing`
- Radial purple glow overlay (`.chooPurple.opacity(0.25)`, top-trailing)
- `.ignoresSafeArea()`

---

## Typography

| Style | Font | Usage |
|-------|------|-------|
| Nav title | `.system(.headline, design: .serif)` | Navigation bar principal |
| Briefing headline | `.system(.title2, design: .serif).bold()` | AI briefing cards |
| Card title | `.subheadline.weight(.semibold)` | Card headers, item names |
| Card subtitle | `.caption2` | Item counts, secondary info |
| Section label | `.caption.bold()` + `.tracking(1.5)` + `.white.opacity(0.4)` | Section headers ("SESSIONS", "JOBS") |
| Badge/pill text | `.system(size: 9, weight: .bold)` or `.caption2.weight(.medium)` | Status pills, tags |
| Body text | `.subheadline` | List item names |
| Fine print | `.caption2` | Timestamps, metadata |

---

## Card Patterns

### Glass Card (standard container)
```swift
.background(
    RoundedRectangle(cornerRadius: 12)
        .fill(.ultraThinMaterial)
)
.overlay(
    RoundedRectangle(cornerRadius: 12)
        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
)
```

### Corner Radii
| Size | Value | Usage |
|------|-------|-------|
| Large | 16 | BriefingCard, HeroCard, recipe cards |
| Standard | 12 | Accordion cards, category cards, inputs |
| Small | 10 | Day cards, secondary containers |
| Accent | 8 | Emoji backgrounds, small badges |

### Accordion Card (expand/collapse)
- Header: emoji in 36×36 rounded-rect (`cornerRadius: 8`) with `accent.opacity(0.2)` bg
- Title: `.subheadline.weight(.semibold)` + subtitle `.caption2`
- Chevron: `"chevron.right"`, `.caption2.weight(.bold)`, `.secondary`
- Rotation: `.rotationEffect(.degrees(isExpanded ? 90 : 0))` with `.animation(.easeInOut(duration: 0.22), value:)`
- Divider below header: `Divider().overlay(.white.opacity(0.06))`
- Header tap: `contentShape(Rectangle()).onTapGesture` (NOT `Button`, to avoid nested-button conflicts)
- No `withAnimation` on toggle (prevents List re-layout jumping)

### Inner sub-card (nested categories)
```swift
.background(Color.white.opacity(0.03))
.clipShape(RoundedRectangle(cornerRadius: 12))
.overlay(
    RoundedRectangle(cornerRadius: 12)
        .strokeBorder(.white.opacity(0.06))
)
```

---

## Shared Components

| Component | File | Props |
|-----------|------|-------|
| `BriefingCardView` | `Views/Shared/BriefingCardView.swift` | `badge, dateRange, headline, summary, accent: TabAccent, isLoading` |
| `HeroCardView<Pills>` | `Views/Shared/HeroCardView.swift` | `label, title, subtitle, emoji, accent: TabAccent, isEmpty, emptyMessage, emojiSize, @ViewBuilder pills` |
| `ErrorBannerView` | `Views/Shared/ErrorBannerView.swift` | `message, onDismiss` |

### HeroCardView Pill Factory
- `.pillBadge(text:)` — white capsule, `.white.opacity(0.1)` bg
- `.coloredPill(text:color:)` — tinted capsule, `color.opacity(0.15)` bg
- `.surfacePill(text:)` — neutral capsule, `.white.opacity(0.06)` bg

---

## Pill / Badge Styling

### Status pill
```swift
Text("Label")
    .font(.system(size: 9, weight: .bold))
    .padding(.horizontal, 7)
    .padding(.vertical, 2)
    .background(color.opacity(0.12))
    .clipShape(Capsule())
    .foregroundStyle(color)
```

### Count badge (circle)
```swift
Text("\(count)")
    .font(.caption2.weight(.bold))
    .foregroundStyle(.secondary)
    .frame(width: 20, height: 20)
    .background(.white.opacity(0.06))
    .clipShape(Circle())
```

### Header stat pill (e.g. "3× this week", "2 low")
```swift
Text("label")
    .font(.caption2.weight(.medium))
    .foregroundStyle(color)
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(color.opacity(0.1), in: Capsule())
```

---

## Interaction Patterns

### Add Flow
- **Toolbar "+"** opens sheet
- Tabs with categories (Shopping, Exercise, House): **2-step flow** — category picker → form
- Tabs without categories (Notes): **direct form**

### Edit Flow
- **Tap row** → edit sheet (pre-populated form, same as add form)
- Exception: Calendar events (read-only from EventKit) → detail sheet

### Delete Flow
- **Swipe-left** on list items → red "Delete" button (`.swipeActions(edge: .trailing, allowsFullSwipe: false)`)
- **Always show confirmation dialog** before deleting
- Detail/action sheets may include a "Delete" button at the bottom (`role: .destructive`) with confirmation
- Dinner long-press clear → confirmation dialog

### Form Sheet Pattern
```swift
NavigationStack {
    Form {
        Section { ... } header: { Text("HEADER") }
        // ... more sections
    }
    .scrollContentBackground(.hidden)
    .navigationTitle("Title")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { ... }
                .disabled(!canSave)
        }
    }
}
.presentationDetents([.medium, .large])
.presentationBackground(.ultraThinMaterial)
```

### Dismiss Conventions
| Context | Pattern |
|---------|---------|
| Forms with unsaved input (add/edit) | "Cancel" in `.cancellationAction` |
| Action sheets / detail views | "Cancel" in `.cancellationAction` |
| Read-only or selection sheets | "Done" in `.confirmationAction` |
| Never use | Custom "X" buttons, drag-only dismiss |

### Confirmation Dialog Template
```swift
.confirmationDialog("Delete \"itemName\"?", isPresented: $showing, titleVisibility: .visible) {
    Button("Delete", role: .destructive) { /* action */ }
}
```

### Day Plan Sheet Pattern (Exercise)
Tap or long-press a day card → opens sheet showing all time slots at a glance:
- Each slot: filled (shows exercise + clear button) or empty ("+ Add session")
- Tapping filled slot → category picker → session picker (replaces)
- Tapping empty slot → same flow (adds)
- Rest day toggle at bottom
- All within one sheet using `@State` navigation (no nested sheets)

---

## Embedded List (for swipe actions inside cards)

When items need swipe actions inside an accordion card, use an embedded `List`:
```swift
List {
    ForEach(items) { item in
        itemRow(item)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) { ... }
    }
}
.listStyle(.plain)
.scrollContentBackground(.hidden)
.scrollDisabled(true)
.frame(height: CGFloat(items.count) * rowHeight)
```

Row heights: ~48pt (compact items), ~56pt (items with subtitle)

---

## Navigation Bar

All tabs use:
```swift
.navigationBarTitleDisplayMode(.inline)
.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        Button { showingProfile = true } label: {
            Image(systemName: "person.circle").opacity(0.6)
        }
    }
    ToolbarItem(placement: .principal) {
        Text("Tab Name")
            .font(.system(.headline, design: .serif))
    }
    ToolbarItem(placement: .topBarTrailing) {
        Button { /* add action */ } label: {
            Image(systemName: "plus")
        }
    }
}
```

---

## Haptic Feedback

| Gesture | Style |
|---------|-------|
| Tap to select/toggle | `UIImpactFeedbackGenerator(style: .light)` |
| Tap to complete/mark done | `UIImpactFeedbackGenerator(style: .medium)` |
| Long press | `UIImpactFeedbackGenerator(style: .medium)` |

---

## Quick Add Row

Used at bottom of accordion cards for inline item creation:
```swift
HStack(spacing: 6) {
    Image(systemName: "plus").font(.caption2)
    Text("Add type").font(.caption)
}
.foregroundStyle(.white.opacity(0.3))
.frame(maxWidth: .infinity)
.padding(.vertical, 10)
```

---

## Empty States

Use system `ContentUnavailableView` for full-tab empty states:
```swift
ContentUnavailableView("No Items", systemImage: "icon.name", description: Text("Tap + to create one."))
```

Use custom inline empty states inside cards:
```swift
VStack(spacing: 8) {
    Text("emoji").font(.system(size: 28))
    Text("Title").font(.subheadline).foregroundStyle(.secondary)
    Text("Subtitle").font(.caption).foregroundStyle(.tertiary)
}
.frame(maxWidth: .infinity)
.padding(.vertical, 20)
```
