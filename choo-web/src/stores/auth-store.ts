import { create } from 'zustand'
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut as firebaseSignOut,
  type User,
} from 'firebase/auth'
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  collection,
  query,
  where,
  getDocs,
  arrayUnion,
  Timestamp,
} from 'firebase/firestore'
import { auth, db } from '../firebase'
import type { UserProfile, Family } from '../types/user'

export type AuthFlowState = 'loading' | 'login' | 'signUp' | 'familySetup' | 'ready'

interface AuthStore {
  flowState: AuthFlowState
  user: User | null
  profile: UserProfile | null
  familyId: string | null
  error: string | null
  isBusy: boolean

  init: () => () => void
  signIn: (email: string, password: string) => Promise<void>
  signUp: (name: string, email: string, password: string) => Promise<void>
  createFamily: (name: string) => Promise<void>
  joinFamily: (inviteCode: string) => Promise<void>
  signOut: () => Promise<void>
  clearError: () => void
  setFlowState: (state: AuthFlowState) => void
}

function generateInviteCode(): string {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'
  return Array.from({ length: 6 }, () => chars[Math.floor(Math.random() * chars.length)]).join('')
}

export const useAuthStore = create<AuthStore>((set, get) => ({
  flowState: 'loading',
  user: null,
  profile: null,
  familyId: null,
  error: null,
  isBusy: false,

  init: () => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (!user) {
        set({ user: null, profile: null, familyId: null, flowState: 'login' })
        return
      }

      set({ user })

      try {
        const snap = await getDoc(doc(db, 'users', user.uid))
        if (snap.exists()) {
          const profile = { id: snap.id, ...snap.data() } as UserProfile
          if (profile.familyId) {
            set({ profile, familyId: profile.familyId, flowState: 'ready' })
          } else {
            set({ profile, flowState: 'familySetup' })
          }
        } else {
          set({ flowState: 'familySetup' })
        }
      } catch (e: any) {
        set({ error: e.message, flowState: 'login' })
      }
    })
    return unsubscribe
  },

  signIn: async (email, password) => {
    set({ isBusy: true, error: null })
    try {
      await signInWithEmailAndPassword(auth, email, password)
    } catch (e: any) {
      set({ error: e.message })
    } finally {
      set({ isBusy: false })
    }
  },

  signUp: async (name, email, password) => {
    set({ isBusy: true, error: null })
    try {
      const cred = await createUserWithEmailAndPassword(auth, email, password)
      const profile: UserProfile = {
        email,
        displayName: name,
        familyId: null,
        role: 'member',
      }
      await setDoc(doc(db, 'users', cred.user.uid), profile)
      set({ profile, flowState: 'familySetup' })
    } catch (e: any) {
      set({ error: e.message })
    } finally {
      set({ isBusy: false })
    }
  },

  createFamily: async (name) => {
    const { user } = get()
    if (!user) return
    set({ isBusy: true, error: null })
    try {
      const inviteCode = generateInviteCode()
      const family: Omit<Family, 'id'> = {
        name,
        adminUID: user.uid,
        memberUIDs: [user.uid],
        inviteCode,
        inviteCodeExpiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      }
      const ref = doc(collection(db, 'families'))
      await setDoc(ref, {
        ...family,
        inviteCodeExpiresAt: Timestamp.fromDate(family.inviteCodeExpiresAt),
      })
      const familyId = ref.id
      await updateDoc(doc(db, 'users', user.uid), { familyId, role: 'admin' })
      set((s) => ({
        profile: s.profile ? { ...s.profile, familyId, role: 'admin' as const } : null,
        familyId,
        flowState: 'ready',
      }))
    } catch (e: any) {
      set({ error: e.message })
    } finally {
      set({ isBusy: false })
    }
  },

  joinFamily: async (inviteCode) => {
    const { user } = get()
    if (!user) return
    set({ isBusy: true, error: null })
    try {
      const q = query(
        collection(db, 'families'),
        where('inviteCode', '==', inviteCode.toUpperCase()),
        where('inviteCodeExpiresAt', '>', Timestamp.now())
      )
      const snap = await getDocs(q)
      if (snap.empty) {
        set({ error: 'Invalid or expired invite code.' })
        return
      }
      const familyDoc = snap.docs[0]
      const familyId = familyDoc.id
      await updateDoc(doc(db, 'families', familyId), {
        memberUIDs: arrayUnion(user.uid),
      })
      await updateDoc(doc(db, 'users', user.uid), { familyId, role: 'member' })
      set((s) => ({
        profile: s.profile ? { ...s.profile, familyId, role: 'member' as const } : null,
        familyId,
        flowState: 'ready',
      }))
    } catch (e: any) {
      set({ error: e.message })
    } finally {
      set({ isBusy: false })
    }
  },

  signOut: async () => {
    try {
      await firebaseSignOut(auth)
      set({ user: null, profile: null, familyId: null, flowState: 'login' })
    } catch (e: any) {
      set({ error: e.message })
    }
  },

  clearError: () => set({ error: null }),
  setFlowState: (flowState) => set({ flowState }),
}))
