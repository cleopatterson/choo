import { create } from 'zustand'
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  doc,
  type Unsubscribe,
} from 'firebase/firestore'
import { db } from '../firebase'
import type { ExerciseCategory, ExercisePlan } from '../types/exercise'
import { exercisePlanDocId } from '../types/exercise'

interface ExerciseStore {
  categories: ExerciseCategory[]
  plan: ExercisePlan | null
  _unsubs: Unsubscribe[]
  listen: (familyId: string, userId: string, weekStart: Date) => void
  stopListening: () => void
}

export const useExerciseStore = create<ExerciseStore>((set, get) => ({
  categories: [],
  plan: null,
  _unsubs: [],

  listen: (familyId, userId, weekStart) => {
    get().stopListening()
    const unsubs: Unsubscribe[] = []

    // Categories
    const catQ = query(
      collection(db, 'families', familyId, 'exerciseData', userId, 'categories'),
      orderBy('sortOrder')
    )
    unsubs.push(onSnapshot(catQ, (snap) => {
      const categories = snap.docs.map((d) => ({ id: d.id, ...d.data() } as ExerciseCategory))
      set({ categories })
    }))

    // Week plan
    const docId = exercisePlanDocId(weekStart)
    unsubs.push(onSnapshot(
      doc(db, 'families', familyId, 'exerciseData', userId, 'weekPlans', docId),
      (snap) => {
        if (snap.exists()) {
          const data = snap.data()
          set({
            plan: {
              id: snap.id,
              userId: data.userId,
              weekStart: data.weekStart?.toDate?.() ?? weekStart,
              slots: data.slots ?? {},
              restDays: data.restDays ?? [],
            },
          })
        } else {
          set({ plan: null })
        }
      }
    ))

    set({ _unsubs: unsubs })
  },

  stopListening: () => {
    get()._unsubs.forEach((u) => u())
    set({ _unsubs: [], categories: [], plan: null })
  },
}))
