// Home-screen copies of the app run their loaded bundle forever — a new deploy
// never reaches them until a manual refresh. Poll index.html for a new bundle
// hash and reload when one ships (immediately if it's safe, otherwise the next
// time the app is backgrounded).
const CHECK_MS = 5 * 60_000

export function startUpdateCheck() {
  const loaded = document
    .querySelector<HTMLScriptElement>('script[src*="/assets/index-"]')
    ?.getAttribute('src')
  if (!loaded) return // dev server — vite injects source modules, nothing to compare

  let pendingReload = false

  const typing = () => {
    const el = document.activeElement
    return el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement
  }

  const check = async () => {
    try {
      const res = await fetch('/index.html', { cache: 'no-store' })
      if (!res.ok) return
      const next = (await res.text()).match(/\/assets\/index-[\w-]+\.js/)?.[0]
      if (!next || next === loaded) return
      if (document.hidden || !typing()) location.reload()
      else pendingReload = true
    } catch {
      // offline — try again next round
    }
  }

  setInterval(check, CHECK_MS)
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      if (pendingReload) location.reload()
    } else {
      check()
    }
  })
}
