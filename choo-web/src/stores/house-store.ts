import { create } from 'zustand'
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  addDoc,
  doc,
  Timestamp,
  type Unsubscribe,
  limit,
} from 'firebase/firestore'
import { db } from '../firebase'
import type { ChoreCategory, ChoreCompletion } from '../types/chore'

interface HouseStore {
  categories: ChoreCategory[]
  completions: ChoreCompletion[]
  assignments: Record<string, string> // choreTypeId -> assigneeUID
  _unsubs: Unsubscribe[]
  listen: (familyId: string) => void
  stopListening: () => void
  markDone: (familyId: string, choreTypeId: string, choreTypeName: string, categoryName: string, completedBy: string) => Promise<void>
}

export const useHouseStore = create<HouseStore>((set, get) => ({
  categories: [],
  completions: [],
  assignments: {},
  _unsubs: [],

  listen: (familyId) => {
    get().stopListening()
    const unsubs: Unsubscribe[] = []

    // Categories
    const catQ = query(
      collection(db, 'families', familyId, 'choresData', 'shared', 'categories'),
      orderBy('sortOrder')
    )
    unsubs.push(onSnapshot(catQ, (snap) => {
      const categories = snap.docs.map((d) => ({ id: d.id, ...d.data() } as ChoreCategory))
      set({ categories })
    }))

    // Completions (last 200)
    const compQ = query(
      collection(db, 'families', familyId, 'choresData', 'shared', 'completions'),
      orderBy('completedDate', 'desc'),
      limit(200)
    )
    unsubs.push(onSnapshot(compQ, (snap) => {
      const completions = snap.docs.map((d) => {
        const data = d.data()
        return {
          id: d.id,
          choreTypeId: data.choreTypeId,
          choreTypeName: data.choreTypeName,
          categoryName: data.categoryName,
          completedBy: data.completedBy,
          completedDate: data.completedDate?.toDate?.() ?? new Date(),
          familyId: data.familyId,
        } as ChoreCompletion
      })
      set({ completions })
    }))

    // Assignments
    unsubs.push(onSnapshot(
      doc(db, 'families', familyId, 'choresData', 'shared', 'assignments', 'current'),
      (snap) => {
        if (snap.exists()) {
          const data = snap.data()
          set({ assignments: data.assignments ?? {} })
        }
      }
    ))

    set({ _unsubs: unsubs })
  },

  stopListening: () => {
    get()._unsubs.forEach((u) => u())
    set({ _unsubs: [], categories: [], completions: [], assignments: {} })
  },

  markDone: async (familyId, choreTypeId, choreTypeName, categoryName, completedBy) => {
    await addDoc(
      collection(db, 'families', familyId, 'choresData', 'shared', 'completions'),
      {
        choreTypeId,
        choreTypeName,
        categoryName,
        completedBy,
        completedDate: Timestamp.now(),
        familyId,
      }
    )
  },
}))
