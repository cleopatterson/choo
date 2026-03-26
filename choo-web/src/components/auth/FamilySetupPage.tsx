import { useState } from 'react'
import { useAuthStore } from '../../stores/auth-store'

export default function FamilySetupPage() {
  const { createFamily, joinFamily, isBusy, error, clearError, signOut } = useAuthStore()
  const [mode, setMode] = useState<'choose' | 'create' | 'join'>('choose')
  const [familyName, setFamilyName] = useState('')
  const [inviteCode, setInviteCode] = useState('')

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault()
    await createFamily(familyName)
  }

  const handleJoin = async (e: React.FormEvent) => {
    e.preventDefault()
    await joinFamily(inviteCode)
  }

  return (
    <div className="choo-bg flex items-center justify-center min-h-screen p-6">
      <div className="w-full max-w-sm">
        <h1 className="font-serif text-3xl font-bold text-center mb-2">Family Setup</h1>
        <p className="text-white/50 text-center text-sm mb-8">
          Create a new family or join an existing one
        </p>

        {error && (
          <p className="text-red-400 text-sm text-center mb-4">{error}</p>
        )}

        {mode === 'choose' && (
          <div className="space-y-3">
            <button
              onClick={() => { clearError(); setMode('create') }}
              className="w-full glass rounded-xl p-4 text-left transition-base hover:bg-white/10"
            >
              <div className="font-semibold text-sm">Create Family</div>
              <div className="text-white/50 text-xs mt-1">Start a new family group</div>
            </button>
            <button
              onClick={() => { clearError(); setMode('join') }}
              className="w-full glass rounded-xl p-4 text-left transition-base hover:bg-white/10"
            >
              <div className="font-semibold text-sm">Join Family</div>
              <div className="text-white/50 text-xs mt-1">Enter an invite code</div>
            </button>
            <button
              onClick={signOut}
              className="w-full text-white/40 text-sm text-center mt-4 py-2"
            >
              Sign Out
            </button>
          </div>
        )}

        {mode === 'create' && (
          <form onSubmit={handleCreate} className="space-y-4">
            <input
              type="text"
              placeholder="Family name"
              value={familyName}
              onChange={(e) => { clearError(); setFamilyName(e.target.value) }}
              className="glass-field"
              autoFocus
            />
            <button
              type="submit"
              disabled={isBusy || !familyName.trim()}
              className="w-full py-3 rounded-xl bg-choo-purple font-semibold text-sm
                         disabled:opacity-40 transition-base"
            >
              {isBusy ? 'Creating...' : 'Create Family'}
            </button>
            <button
              type="button"
              onClick={() => setMode('choose')}
              className="w-full text-white/40 text-sm text-center py-2"
            >
              Back
            </button>
          </form>
        )}

        {mode === 'join' && (
          <form onSubmit={handleJoin} className="space-y-4">
            <input
              type="text"
              placeholder="Invite code"
              value={inviteCode}
              onChange={(e) => { clearError(); setInviteCode(e.target.value.toUpperCase()) }}
              className="glass-field text-center tracking-[0.3em] text-lg"
              maxLength={6}
              autoFocus
            />
            <button
              type="submit"
              disabled={isBusy || inviteCode.length !== 6}
              className="w-full py-3 rounded-xl bg-choo-purple font-semibold text-sm
                         disabled:opacity-40 transition-base"
            >
              {isBusy ? 'Joining...' : 'Join Family'}
            </button>
            <button
              type="button"
              onClick={() => setMode('choose')}
              className="w-full text-white/40 text-sm text-center py-2"
            >
              Back
            </button>
          </form>
        )}
      </div>
    </div>
  )
}
