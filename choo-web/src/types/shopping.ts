export type ShoppingItemSource = 'manual' | 'cadence' | 'meal'

export interface ShoppingItem {
  id?: string
  listId: string
  name: string
  isChecked: boolean
  addedBy: string
  createdAt: Date
  isHeading?: boolean
  sortOrder?: number
  sourceRecipeId?: string
  source?: ShoppingItemSource
  cadenceTag?: string
  aisleOrder?: number
  supplyItemId?: string
}

export interface ShoppingList {
  id?: string
  familyId: string
  name: string
  createdBy: string
  createdAt: Date
}

export interface MealAssignment {
  recipeId: string
  recipeName: string
  recipeIcon: string
}

export interface MealPlan {
  id?: string
  familyId: string
  weekStart: Date
  assignments: Record<string, MealAssignment> // "0"-"6" Mon=0..Sun=6
}

export type SupplyCategory = 'coldGoods' | 'breakfast' | 'pantry' | 'cleaning'
export type SupplyCadence = 'weekly' | 'fortnightly' | 'monthly' | 'quarterly' | 'adHoc'
export type SupplyStatus = 'ok' | 'due' | 'low'

export const SUPPLY_CATEGORY_META: Record<SupplyCategory, { name: string; emoji: string; sort: number }> = {
  coldGoods: { name: 'Cold Goods', emoji: '🧊', sort: 0 },
  breakfast: { name: 'Breakfast', emoji: '🥣', sort: 1 },
  pantry: { name: 'Pantry', emoji: '🥫', sort: 2 },
  cleaning: { name: 'Cleaning', emoji: '🧹', sort: 3 },
}

export const SUPPLY_CADENCE_DAYS: Record<SupplyCadence, number> = {
  weekly: 7,
  fortnightly: 14,
  monthly: 30,
  quarterly: 90,
  adHoc: Infinity,
}

export interface SupplyItem {
  id?: string
  name: string
  emoji?: string
  category: SupplyCategory
  cadence: SupplyCadence
  aisleOrder: number
  lastPurchasedDate?: Date
  isLow?: boolean
}

export function getSupplyStatus(item: SupplyItem): SupplyStatus {
  if (item.isLow) return 'low'
  if (!item.lastPurchasedDate) return 'due'
  const daysSince = Math.floor((Date.now() - item.lastPurchasedDate.getTime()) / (1000 * 60 * 60 * 24))
  if (daysSince >= SUPPLY_CADENCE_DAYS[item.cadence]) return 'due'
  return 'ok'
}

export function mealPlanDocId(weekStart: Date): string {
  const y = weekStart.getFullYear()
  const m = String(weekStart.getMonth() + 1).padStart(2, '0')
  const d = String(weekStart.getDate()).padStart(2, '0')
  return `week_${y}-${m}-${d}`
}
