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
  getDocs,
  where,
  writeBatch,
  Timestamp,
  type Unsubscribe,
} from 'firebase/firestore'
import { db } from '../firebase'
import type { ShoppingItem, ShoppingList, MealPlan, SupplyItem } from '../types/shopping'
import { mealPlanDocId } from '../types/shopping'

function toItem(id: string, data: any): ShoppingItem {
  return {
    id,
    listId: data.listId,
    name: data.name,
    isChecked: data.isChecked ?? false,
    addedBy: data.addedBy,
    createdAt: data.createdAt?.toDate?.() ?? new Date(),
    isHeading: data.isHeading,
    sortOrder: data.sortOrder,
    sourceRecipeId: data.sourceRecipeId,
    source: data.source,
    cadenceTag: data.cadenceTag,
    aisleOrder: data.aisleOrder,
    supplyItemId: data.supplyItemId,
  }
}

function toSupply(id: string, data: any): SupplyItem {
  return {
    id,
    name: data.name,
    emoji: data.emoji,
    category: data.category,
    cadence: data.cadence,
    aisleOrder: data.aisleOrder ?? 0,
    lastPurchasedDate: data.lastPurchasedDate?.toDate?.(),
    isLow: data.isLow,
  }
}

interface ShoppingStore {
  lists: ShoppingList[]
  items: ShoppingItem[]
  mealPlan: MealPlan | null
  supplies: SupplyItem[]
  defaultListId: string | null
  _unsubs: Unsubscribe[]

  listen: (familyId: string) => void
  stopListening: () => void
  listenToItems: (familyId: string, listId: string) => void
  listenToMealPlan: (familyId: string, weekStart: Date) => void
  listenToSupplies: (familyId: string) => void

  addItem: (familyId: string, listId: string, name: string, addedBy: string) => Promise<void>
  toggleItem: (familyId: string, listId: string, itemId: string, isChecked: boolean) => Promise<void>
  deleteItem: (familyId: string, listId: string, itemId: string) => Promise<void>
  clearChecked: (familyId: string, listId: string) => Promise<void>

  sortedItems: () => ShoppingItem[]
}

export const useShoppingStore = create<ShoppingStore>((set, get) => ({
  lists: [],
  items: [],
  mealPlan: null,
  supplies: [],
  defaultListId: null,
  _unsubs: [],

  listen: (familyId) => {
    get().stopListening()
    const unsubs: Unsubscribe[] = []

    // Listen to shopping lists
    const listsQ = query(collection(db, 'families', familyId, 'shoppingLists'), orderBy('createdAt'))
    const listUnsub = onSnapshot(listsQ, (snap) => {
      const lists = snap.docs.map((d) => ({ id: d.id, ...d.data() } as ShoppingList))
      const listId = lists[0]?.id ?? null
      set({ lists, defaultListId: listId })
      if (listId) {
        get().listenToItems(familyId, listId)
      }
    })
    unsubs.push(listUnsub)

    // Listen to supplies
    get().listenToSupplies(familyId)

    set({ _unsubs: unsubs })
  },

  listenToItems: (familyId, listId) => {
    const q = query(
      collection(db, 'families', familyId, 'shoppingLists', listId, 'items'),
      orderBy('createdAt')
    )
    const unsub = onSnapshot(q, (snap) => {
      const items = snap.docs.map((d) => toItem(d.id, d.data()))
      set({ items })
    })
    set((s) => ({ _unsubs: [...s._unsubs, unsub] }))
  },

  listenToMealPlan: (familyId, weekStart) => {
    const docId = mealPlanDocId(weekStart)
    const unsub = onSnapshot(doc(db, 'families', familyId, 'mealPlans', docId), (snap) => {
      if (snap.exists()) {
        const data = snap.data()
        set({
          mealPlan: {
            id: snap.id,
            familyId: data.familyId,
            weekStart: data.weekStart?.toDate?.() ?? weekStart,
            assignments: data.assignments ?? {},
          },
        })
      } else {
        set({ mealPlan: null })
      }
    })
    set((s) => ({ _unsubs: [...s._unsubs, unsub] }))
  },

  listenToSupplies: (familyId) => {
    const q = query(collection(db, 'families', familyId, 'supplies'), orderBy('name'))
    const unsub = onSnapshot(q, (snap) => {
      const supplies = snap.docs.map((d) => toSupply(d.id, d.data()))
      set({ supplies })
    })
    set((s) => ({ _unsubs: [...s._unsubs, unsub] }))
  },

  stopListening: () => {
    get()._unsubs.forEach((u) => u())
    set({ _unsubs: [], lists: [], items: [], mealPlan: null, supplies: [], defaultListId: null })
  },

  addItem: async (familyId, listId, name, addedBy) => {
    const trimmed = name.trim()
    if (!trimmed) return
    const isHeading = trimmed.length >= 2 && trimmed === trimmed.toUpperCase() && /[A-Z]/.test(trimmed)
    const maxOrder = Math.max(-1, ...get().items.map((i) => i.sortOrder ?? -1))
    await addDoc(collection(db, 'families', familyId, 'shoppingLists', listId, 'items'), {
      listId,
      name: trimmed,
      isChecked: false,
      addedBy,
      createdAt: Timestamp.now(),
      isHeading,
      sortOrder: maxOrder + 1,
    })
  },

  toggleItem: async (familyId, listId, itemId, isChecked) => {
    await updateDoc(doc(db, 'families', familyId, 'shoppingLists', listId, 'items', itemId), { isChecked })
  },

  deleteItem: async (familyId, listId, itemId) => {
    await deleteDoc(doc(db, 'families', familyId, 'shoppingLists', listId, 'items', itemId))
  },

  clearChecked: async (familyId, listId) => {
    const snap = await getDocs(
      query(collection(db, 'families', familyId, 'shoppingLists', listId, 'items'), where('isChecked', '==', true))
    )
    const batch = writeBatch(db)
    snap.docs.forEach((d) => batch.delete(d.ref))
    await batch.commit()
  },

  sortedItems: () => {
    return [...get().items].sort((a, b) => (a.sortOrder ?? Infinity) - (b.sortOrder ?? Infinity))
  },
}))
