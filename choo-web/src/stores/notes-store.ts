import { create } from 'zustand'
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  addDoc,
  updateDoc,
  deleteDoc,
  doc,
  Timestamp,
  type Unsubscribe,
} from 'firebase/firestore'
import { db } from '../firebase'
import type { Note } from '../types/note'

interface NotesStore {
  notes: Note[]
  _unsub: Unsubscribe | null
  listen: (familyId: string) => void
  stopListening: () => void
  createNote: (familyId: string, title: string, content: string, createdBy: string, isList?: boolean) => Promise<void>
  updateNote: (familyId: string, noteId: string, title: string, content: string) => Promise<void>
  deleteNote: (familyId: string, noteId: string) => Promise<void>
}

function toNote(id: string, data: any): Note {
  return {
    id,
    familyId: data.familyId,
    title: data.title,
    content: data.content,
    createdBy: data.createdBy,
    createdAt: data.createdAt?.toDate?.() ?? new Date(),
    updatedAt: data.updatedAt?.toDate?.() ?? new Date(),
    isList: data.isList ?? false,
  }
}

export const useNotesStore = create<NotesStore>((set, get) => ({
  notes: [],
  _unsub: null,

  listen: (familyId) => {
    get().stopListening()
    const q = query(
      collection(db, 'families', familyId, 'notes'),
      orderBy('updatedAt', 'desc')
    )
    const unsub = onSnapshot(q, (snapshot) => {
      const notes = snapshot.docs.map((d) => toNote(d.id, d.data()))
      set({ notes })
    })
    set({ _unsub: unsub })
  },

  stopListening: () => {
    const { _unsub } = get()
    _unsub?.()
    set({ _unsub: null, notes: [] })
  },

  createNote: async (familyId, title, content, createdBy, isList) => {
    const now = Timestamp.now()
    await addDoc(collection(db, 'families', familyId, 'notes'), {
      familyId,
      title,
      content,
      createdBy,
      createdAt: now,
      updatedAt: now,
      isList: isList ?? false,
    })
  },

  updateNote: async (familyId, noteId, title, content) => {
    await updateDoc(doc(db, 'families', familyId, 'notes', noteId), {
      title,
      content,
      updatedAt: Timestamp.now(),
    })
  },

  deleteNote: async (familyId, noteId) => {
    await deleteDoc(doc(db, 'families', familyId, 'notes', noteId))
  },
}))
