import { useEffect } from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useAuthStore } from './stores/auth-store'
import AppShell from './components/layout/AppShell'
import LoginPage from './components/auth/LoginPage'
import SignUpPage from './components/auth/SignUpPage'
import FamilySetupPage from './components/auth/FamilySetupPage'
import CalendarTab from './components/calendar/CalendarTab'
import ShoppingTab from './components/shopping/ShoppingTab'
import ExerciseTab from './components/exercise/ExerciseTab'
import HouseTab from './components/house/HouseTab'
import NotesTab from './components/notes/NotesTab'

export default function App() {
  const { flowState, init } = useAuthStore()

  useEffect(() => {
    const unsubscribe = init()
    return unsubscribe
  }, [])

  if (flowState === 'loading') {
    return (
      <div className="choo-bg flex items-center justify-center h-screen">
        <div className="text-center">
          <h1 className="font-serif text-3xl font-bold text-choo-purple mb-2">Choo</h1>
          <p className="text-white/40 text-sm">Loading...</p>
        </div>
      </div>
    )
  }

  if (flowState === 'login') return <LoginPage />
  if (flowState === 'signUp') return <SignUpPage />
  if (flowState === 'familySetup') return <FamilySetupPage />

  return (
    <BrowserRouter>
      <Routes>
        <Route element={<AppShell />}>
          <Route path="/calendar" element={<CalendarTab />} />
          <Route path="/shopping" element={<ShoppingTab />} />
          <Route path="/exercise" element={<ExerciseTab />} />
          <Route path="/house" element={<HouseTab />} />
          <Route path="/notes" element={<NotesTab />} />
          <Route path="*" element={<Navigate to="/calendar" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}
