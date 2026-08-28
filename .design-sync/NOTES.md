# design-sync notes — Choo

Target project: `Choo Design System` (`aa73a811-02ac-4cb1-a15b-9fe583de0473`)
First sync: 2026-08-28. Shape: `package` (no Storybook).

## What is synced

Only the React web app, `choo-web/`. The iOS SwiftUI app cannot be synced —
Claude Design is React-only.

Scope is deliberately **slim**: 7 reusable-ish components. The 5 big tab pages
(`CalendarTab`, `ShoppingTab`, `ExerciseTab`, `HouseTab`, `NotesTab`) plus
`AppShell`, `SignUpPage` and `FamilySetupPage` are excluded — they are whole
screens the design agent cannot recompose. Add them to `componentSrcMap` and
`ds-entry.ts` if that changes.

## Repo-specific gotchas

- **`choo-web` is an app, not a library.** There is no `dist/` library entry, and
  every component is a `export default`. `choo-web/ds-entry.ts` is a hand-written
  barrel that re-exports them under names, and is passed as `--entry`. Add a line
  there for any component added to `componentSrcMap`.
- **`ds-entry.ts` also re-exports `MemoryRouter` and `useAuthStore`** purely for
  the preview cards. `MemoryRouter` is excluded from the component list via
  `componentSrcMap: {"MemoryRouter": null}`.
- **Firebase used to crash the bundle.** `src/firebase.ts` read
  `import.meta.env.VITE_*`, which is empty outside a Vite build, so esbuild's
  bundle threw `auth/invalid-api-key` at module load and `window.ChooWeb` stayed
  empty. Fixed in the app source by defaulting `import.meta.env` to `{}` and
  falling back to inert placeholder credentials. Do not revert that.
- **Tailwind v4 only compiles the classes it sees.** The app's own
  `dist/assets/index-*.css` therefore contains just the utilities the existing
  screens use — a design agent writing `gap-6` would get nothing. So the bundle's
  stylesheet is built from `choo-web/ds-preview.css`, which imports `globals.css`
  and adds a broad `@source inline(...)` safelist. Built with the Tailwind CLI
  installed in `.ds-sync/` (NOT a repo dependency):
  `node ../.ds-sync/node_modules/@tailwindcss/cli/dist/index.mjs -i ds-preview.css -o dist/ds-styles.css --minify`
  This is the second half of `cfg.buildCmd`. Widen `ds-preview.css` if the design
  agent starts needing utilities that render unstyled.
- **Overlay sheets need a containing block.** `EventForm`, `EventDetail`,
  `NoteEditor` and `ProfileSheet` render `fixed inset-0`. In a preview card that
  collapses the measured document height to 0 (`[RENDER_THIN]` / `[RENDER_BLANK]`).
  Each authored preview wraps them in a sized `div` carrying
  `transform: translateZ(0)`, which makes descendant `position: fixed` resolve
  against that box. Do not remove the transform.
- **Playwright/Chromium is already installed** on this machine at
  `~/Library/Caches/ms-playwright/` (macOS path — NOT `~/.cache/ms-playwright`).

## Known render warns

None. The last run was 7/7 clean, 0 bad / 0 thin / 0 variantsIdentical.

## Deliberately not covered

- Hover, focus, drag and open/close animation states — not statically renderable.
- `EventDetail`'s edit mode (it swaps to `EventForm`) — covered by `EventForm`'s
  own `EditingABill` story instead.

## Re-sync risks

- **Preview data is inlined.** The `FamilyEvent`, `Note` and `UserProfile` objects
  in `.design-sync/previews/*.tsx` are typed `any` and hand-written. If those
  interfaces change in `src/types/`, the previews will keep compiling but may
  render stale or wrong fields. Re-check them on any model change.
- **`ds-entry.ts` rots silently.** Renaming or moving a component file breaks the
  barrel at build time (loud), but *deleting* a component leaves a stale export
  that fails to resolve. Keep it in step with `componentSrcMap`.
- **The CSS safelist is a guess.** `ds-preview.css` covers common Tailwind
  families at common scale values. Anything outside it renders unstyled with no
  error. If a design looks structurally right but visually flat, check the class
  against `ds-bundle/_ds_bundle.css` first.
- **`dist/ds-styles.css` is a build artefact** produced by `cfg.buildCmd`. It is
  not committed. Always run the full `buildCmd` before the converter.
- **Review-sheet crop, not a bug.** `_screenshots/review/*.png` caps each cell's
  height, so tall cards (notably `NoteEditor`) look cut off in the review sheet
  while the real card renders whole. Check `_screenshots/contact-sheet-*.png` or
  `.review.html` before "fixing" a card that looks truncated.
- The Firebase placeholder credentials mean anything in a preview that actually
  calls Firestore or Auth will fail at runtime. Previews are render-only by
  design; do not author a preview that depends on live data.
