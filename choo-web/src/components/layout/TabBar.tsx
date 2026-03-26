import { useLocation, useNavigate } from 'react-router-dom'

const tabs = [
  { path: '/calendar', icon: '📅', label: 'Calendar' },
  { path: '/shopping', icon: '🛒', label: 'Shopping' },
  { path: '/exercise', icon: '🏃', label: 'Exercise' },
  { path: '/house', icon: '✅', label: 'House' },
  { path: '/notes', icon: '📝', label: 'Notes' },
]

export default function TabBar() {
  const location = useLocation()
  const navigate = useNavigate()

  return (
    <nav className="glass border-t border-white/8 flex items-center justify-around px-2 pb-[env(safe-area-inset-bottom)] h-14 shrink-0">
      {tabs.map((tab) => {
        const active = location.pathname.startsWith(tab.path)
        return (
          <button
            key={tab.path}
            onClick={() => navigate(tab.path)}
            className={`flex flex-col items-center gap-0.5 py-1 px-3 transition-base
              ${active ? 'text-choo-purple' : 'text-white/40'}`}
          >
            <span className="text-lg">{tab.icon}</span>
            <span className="text-[10px] font-medium">{tab.label}</span>
          </button>
        )
      })}
    </nav>
  )
}
