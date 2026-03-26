import { create } from 'zustand'
import {
  collection,
  query,
  where,
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
import type { FamilyEvent } from '../types/event'

function toEvent(id: string, data: any): FamilyEvent {
  return {
    id,
    familyId: data.familyId,
    title: data.title,
    startDate: data.startDate?.toDate?.() ?? new Date(),
    endDate: data.endDate?.toDate?.() ?? new Date(),
    createdBy: data.createdBy,
    attendeeUIDs: data.attendeeUIDs,
    isAllDay: data.isAllDay,
    location: data.location,
    recurrenceFrequency: data.recurrenceFrequency,
    recurrenceEndDate: data.recurrenceEndDate?.toDate?.(),
    reminderEnabled: data.reminderEnabled,
    isBill: data.isBill,
    amount: data.amount,
    isPaid: data.isPaid,
    paidOccurrences: data.paidOccurrences,
    note: data.note,
    lastModifiedByUID: data.lastModifiedByUID,
    googleCalendarEventId: data.googleCalendarEventId,
    isTodo: data.isTodo,
    isCompleted: data.isCompleted,
    completedDate: data.completedDate?.toDate?.(),
    todoEmoji: data.todoEmoji,
  }
}

interface CalendarStore {
  events: FamilyEvent[]
  _unsub: Unsubscribe | null
  listen: (familyId: string) => void
  stopListening: () => void
  createEvent: (familyId: string, event: Omit<FamilyEvent, 'id'>) => Promise<void>
  updateEvent: (familyId: string, event: FamilyEvent) => Promise<void>
  deleteEvent: (familyId: string, eventId: string) => Promise<void>
  toggleTodoCompleted: (familyId: string, event: FamilyEvent) => Promise<void>
  toggleBillPaid: (familyId: string, event: FamilyEvent, day: Date) => Promise<void>
}

export const useCalendarStore = create<CalendarStore>((set, get) => ({
  events: [],
  _unsub: null,

  listen: (familyId) => {
    get().stopListening()
    const sixMonthsAgo = new Date()
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6)

    const q = query(
      collection(db, 'families', familyId, 'events'),
      where('startDate', '>', Timestamp.fromDate(sixMonthsAgo)),
      orderBy('startDate')
    )
    const unsub = onSnapshot(q, (snapshot) => {
      const events = snapshot.docs.map((d) => toEvent(d.id, d.data()))
      set({ events })
    })
    set({ _unsub: unsub })
  },

  stopListening: () => {
    get()._unsub?.()
    set({ _unsub: null, events: [] })
  },

  createEvent: async (familyId, event) => {
    const data: any = { ...event }
    data.startDate = Timestamp.fromDate(event.startDate)
    data.endDate = Timestamp.fromDate(event.endDate)
    if (event.recurrenceEndDate) data.recurrenceEndDate = Timestamp.fromDate(event.recurrenceEndDate)
    if (event.completedDate) data.completedDate = Timestamp.fromDate(event.completedDate)
    await addDoc(collection(db, 'families', familyId, 'events'), data)
  },

  updateEvent: async (familyId, event) => {
    if (!event.id) return
    const data: any = { ...event }
    delete data.id
    data.startDate = Timestamp.fromDate(event.startDate)
    data.endDate = Timestamp.fromDate(event.endDate)
    if (event.recurrenceEndDate) data.recurrenceEndDate = Timestamp.fromDate(event.recurrenceEndDate)
    if (event.completedDate) data.completedDate = Timestamp.fromDate(event.completedDate)
    else data.completedDate = null
    await updateDoc(doc(db, 'families', familyId, 'events', event.id), data)
  },

  deleteEvent: async (familyId, eventId) => {
    await deleteDoc(doc(db, 'families', familyId, 'events', eventId))
  },

  toggleTodoCompleted: async (familyId, event) => {
    if (!event.id || !event.isTodo) return
    const wasCompleted = event.isCompleted === true
    await updateDoc(doc(db, 'families', familyId, 'events', event.id), {
      isCompleted: !wasCompleted,
      completedDate: wasCompleted ? null : Timestamp.now(),
    })
  },

  toggleBillPaid: async (familyId, event, day) => {
    if (!event.id || !event.isBill) return
    if (event.recurrenceFrequency) {
      const key = `${day.getFullYear()}-${String(day.getMonth() + 1).padStart(2, '0')}-${String(day.getDate()).padStart(2, '0')}`
      const occs = event.paidOccurrences ?? []
      const updated = occs.includes(key) ? occs.filter((k) => k !== key) : [...occs, key]
      await updateDoc(doc(db, 'families', familyId, 'events', event.id), { paidOccurrences: updated })
    } else {
      await updateDoc(doc(db, 'families', familyId, 'events', event.id), { isPaid: !(event.isPaid === true) })
    }
  },
}))
