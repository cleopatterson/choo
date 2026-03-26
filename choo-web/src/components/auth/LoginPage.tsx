import { useState } from 'react'
import { useAuthStore } from '../../stores/auth-store'

export default function LoginPage() {
  const { signIn, isBusy, error, clearError, setFlowState } = useAuthStore()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    await signIn(email, password)
  }

  return (
    <div className="choo-bg flex items-center justify-center min-h-screen p-6">
      <div className="w-full max-w-sm">
        <h1 className="font-serif text-3xl font-bold text-center mb-2">Choo</h1>
        <p className="text-white/50 text-center text-sm mb-8">Family hub</p>

        <form onSubmit={handleSubmit} className="space-y-4">
          <input
            type="email"
            placeholder="Email"
            value={email}
            onChange={(e) => { clearError(); setEmail(e.target.value) }}
            className="glass-field"
            autoComplete="email"
          />
          <input
            type="password"
            placeholder="Password"
            value={password}
            onChange={(e) => { clearError(); setPassword(e.target.value) }}
            className="glass-field"
            autoComplete="current-password"
          />

          {error && (
            <p className="text-red-400 text-sm text-center">{error}</p>
          )}

          <button
            type="submit"
            disabled={isBusy || !email || !password}
            className="w-full py-3 rounded-xl bg-choo-purple font-semibold text-sm
                       disabled:opacity-40 transition-base"
          >
            {isBusy ? 'Signing in...' : 'Sign In'}
          </button>
        </form>

        <p className="text-white/40 text-sm text-center mt-6">
          No account?{' '}
          <button
            onClick={() => setFlowState('signUp')}
            className="text-choo-purple font-medium"
          >
            Sign Up
          </button>
        </p>
      </div>
    </div>
  )
}
