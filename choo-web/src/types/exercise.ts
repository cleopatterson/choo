export type ExerciseIntensity = 'light' | 'moderate' | 'high' | 'peak'
export type TimeSlot = 'morning' | 'lunch' | 'arvo'

export const TIME_SLOT_META: Record<TimeSlot, { label: string; emoji: string }> = {
  morning: { label: 'Morning', emoji: '☀️' },
  lunch: { label: 'Lunch', emoji: '🌤️' },
  arvo: { label: 'Arvo', emoji: '🌅' },
}

export interface ExerciseSlotAssignment {
  sessionTypeId: string
  sessionTypeName: string
  categoryName: string
  categoryEmoji: string
  categoryColorHex: string
  durationMinutes?: number
  estimatedCalories?: number
  intensity?: string
}

export interface ExercisePlan {
  id?: string
  userId: string
  weekStart: Date
  slots: Record<string, ExerciseSlotAssignment> // key: "{day}_{slot}" e.g. "0_morning"
  restDays: number[]
}

export interface SessionType {
  id: string
  name: string
  description: string
  durationMinutes?: number
  estimatedCalories?: number
  intensity?: string
}

export interface ExerciseCategory {
  id?: string
  name: string
  emoji: string
  colorHex: string
  sortOrder: number
  isDefault: boolean
  sessionTypes: SessionType[]
}

export type DayLoad = 'light' | 'moderate' | 'high' | 'peak'

export function getDayLoad(totalCalories: number): DayLoad {
  if (totalCalories < 200) return 'light'
  if (totalCalories < 350) return 'moderate'
  if (totalCalories < 550) return 'high'
  return 'peak'
}

export function exercisePlanDocId(weekStart: Date): string {
  const y = weekStart.getFullYear()
  const m = String(weekStart.getMonth() + 1).padStart(2, '0')
  const d = String(weekStart.getDate()).padStart(2, '0')
  return `week_${y}-${m}-${d}`
}
