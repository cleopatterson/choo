import { useState } from 'react'
import { useAuthStore } from '../../stores/auth-store'

export default function SignUpPage() {
  const { signUp, isBusy, error, clearError, setFlowState } = useAuthStore()
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    await signUp(name, email, password)
  }

  return (
    <div className="choo-bg flex items-center justify-center min-h-screen p-6">
      <div className="w-full max-w-sm">
        <h1 className="font-serif text-3xl font-bold text-center mb-2">Join Choo</h1>
        <p className="text-white/50 text-center text-sm mb-8">Create your account</p>

        <form onSubmit={handleSubmit} className="space-y-4">
          <input
            type="text"
            placeholder="Your name"
            value={name}
            onChange={(e) => { clearError(); setName(e.target.value) }}
            className="glass-field"
            autoComplete="name"
          />
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
            placeholder="Password (6+ characters)"
            value={password}
            onChange={(e) => { clearError(); setPassword(e.target.value) }}
            className="glass-field"
            autoComplete="new-password"
          />

          {error && (
            <p className="text-red-400 text-sm text-center">{error}</p>
          )}

          <button
            type="submit"
            disabled={isBusy || !name || !email || password.length < 6}
            className="w-full py-3 rounded-xl bg-choo-purple font-semibold text-sm
                       disabled:opacity-40 transition-base"
          >
            {isBusy ? 'Creating account...' : 'Sign Up'}
          </button>
        </form>

        <p className="text-white/40 text-sm text-center mt-6">
          Already have an account?{' '}
          <button
            onClick={() => setFlowState('login')}
            className="text-choo-purple font-medium"
          >
            Sign In
          </button>
        </p>
      </div>
    </div>
  )
}
