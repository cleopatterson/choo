# Choo — house conventions

Choo is a family-hub app (calendar, shopping, exercise, house chores, notes) for
one Australian family. **Dark mode only, glassmorphism, phone-first.** There is no
light theme; never build one.

## Wrapping and setup

There is no theme provider. Two rules instead:

1. **Every screen root must carry `class="choo-bg"`.** That class paints the
   purple-into-navy gradient the whole design system assumes. Without it the
   glass surfaces sit on white and the design reads as broken.
2. **`TabBar` is the only component that needs context** — it calls
   `useLocation`/`useNavigate`, so it must be inside a react-router router.
   `MemoryRouter` is exported from the bundle for exactly this:

```jsx
const { TabBar, NavBar, MemoryRouter } = window.ChooWeb

<MemoryRouter initialEntries={['/calendar']}>
  <div className="choo-bg flex flex-col h-screen">
    <NavBar title="Calendar" onAdd={() => {}} onProfile={() => {}} />
    <div className="flex-1 overflow-y-auto p-4">{/* screen content */}</div>
    <TabBar />
  </div>
</MemoryRouter>
```

`EventForm`, `EventDetail`, `NoteEditor` and `ProfileSheet` are **overlay sheets**:
they render `fixed inset-0` and cover the whole viewport. Show one at a time, over
a screen, not side by side.

## The styling idiom

Tailwind v4 utilities, plus this small custom vocabulary. Use these names — do not
invent parallel ones, and do not hand-write the gradients or blur values.

| Class | What it is |
|---|---|
| `choo-bg` | The app background gradient. Goes on the screen root. |
| `glass` | Glass card surface: translucent white, 20px blur, hairline border. |
| `glass-field` | Glass text input / textarea. Already includes padding and radius. |
| `pill` | Small rounded status label. Pair with a tinted colour, e.g. `pill bg-amber-500/15 text-amber-400`. |
| `transition-base` | The standard 0.2s ease transition. |
| `hero-calendar` `hero-shopping` `hero-exercise` `hero-house` | Per-tab hero gradient blocks. |

Brand colours are Tailwind theme colours, so they work with any colour utility:

| Token | Utility examples | Used for |
|---|---|---|
| `choo-purple` (#8B5CF6) | `text-choo-purple`, `bg-choo-purple` | Brand, active state, primary action |
| `choo-amber` (#fb923c) | `text-choo-amber` | Shopping tab |
| `choo-teal` (#4ecdc4) | `text-choo-teal` | Exercise tab |
| `choo-rose` (#C88EA7) | `text-choo-rose` | House tab |

Other conventions worth keeping:

- **Headings are serif**: `font-serif font-bold` (Georgia stack). Body text is the
  system sans stack. Body colour is white; secondary text is `text-white/60`,
  tertiary `text-white/40`.
- **Borders are hairline white**: `border-white/8` for cards, `border-white/12`
  for fields.
- **Destructive actions are tinted, not solid**: `bg-red-500/20 text-red-400`.
- **Radii**: `rounded-xl` for fields and inner cards, `rounded-t-2xl` for the top
  of a bottom sheet.
- Week starts Monday; dates are Australian (`14/02/2026`), money is AUD.

## Where the truth lives

- `_ds/<folder>/styles.css` and the files it `@import`s — the real compiled CSS,
  including every class above. Read it before inventing a style.
- `components/<group>/<Name>/<Name>.prompt.md` — per-component props and usage.
- `components/<group>/<Name>/<Name>.d.ts` — the exact prop contract.
