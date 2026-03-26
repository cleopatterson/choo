interface NavBarProps {
  title: string
  onAdd?: () => void
  onProfile?: () => void
}

export default function NavBar({ title, onAdd, onProfile }: NavBarProps) {
  return (
    <header className="glass border-b border-white/8 flex items-center justify-between px-4 h-12 shrink-0">
      <button
        onClick={onProfile}
        className="text-white/60 text-lg w-8 h-8 flex items-center justify-center"
      >
        👤
      </button>

      <h1 className="font-serif font-semibold text-base">{title}</h1>

      {onAdd ? (
        <button
          onClick={onAdd}
          className="text-white/60 text-lg w-8 h-8 flex items-center justify-center"
        >
          +
        </button>
      ) : (
        <div className="w-8" />
      )}
    </header>
  )
}
