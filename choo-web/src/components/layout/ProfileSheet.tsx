import { useAuthStore } from '../../stores/auth-store'

interface ProfileSheetProps {
  onClose: () => void
}

export default function ProfileSheet({ onClose }: ProfileSheetProps) {
  const { profile, signOut } = useAuthStore()

  const handleSignOut = async () => {
    await signOut()
    onClose()
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center" onClick={onClose}>
      <div className="absolute inset-0 bg-black/50" />
      <div
        className="relative glass rounded-t-2xl sm:rounded-2xl w-full max-w-sm p-6 space-y-4 mb-0 sm:mb-0"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="w-10 h-1 rounded-full bg-white/20 mx-auto sm:hidden" />

        <h2 className="font-serif font-bold text-lg text-center">Account</h2>

        <div className="glass rounded-xl p-4 space-y-2">
          <div className="text-sm font-medium">{profile?.displayName}</div>
          <div className="text-xs text-white/50">{profile?.email}</div>
          <div className="text-xs text-white/40 capitalize">Role: {profile?.role}</div>
        </div>

        <button
          onClick={handleSignOut}
          className="w-full py-3 rounded-xl bg-red-500/20 text-red-400 font-semibold text-sm
                     border border-red-500/20 transition-base hover:bg-red-500/30"
        >
          Sign Out
        </button>

        <button
          onClick={onClose}
          className="w-full text-white/40 text-sm text-center py-2"
        >
          Close
        </button>
      </div>
    </div>
  )
}
