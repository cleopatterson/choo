export type ChoreFrequency = 'weekly' | 'monthly' | 'quarterly' | 'biannual' | 'yearly'

export const CHORE_FREQUENCY_DAYS: Record<ChoreFrequency, number> = {
  weekly: 7,
  monthly: 30,
  quarterly: 90,
  biannual: 180,
  yearly: 365,
}

export const CHORE_FREQUENCY_META: Record<ChoreFrequency, { name: string; emoji: string }> = {
  weekly: { name: 'Weekly', emoji: '📅' },
  monthly: { name: 'Monthly', emoji: '🗓️' },
  quarterly: { name: 'Quarterly', emoji: '🧹' },
  biannual: { name: 'Every 6 months', emoji: '✨' },
  yearly: { name: 'Yearly', emoji: '🏠' },
}

export interface ChoreType {
  id: string
  name: string
  description: string
  durationMinutes?: number
  frequency?: ChoreFrequency
}

export interface ChoreCategory {
  id?: string
  name: string
  emoji: string
  colorHex: string
  sortOrder: number
  isDefault: boolean
  choreTypes: ChoreType[]
}

export interface ChoreCompletion {
  id?: string
  choreTypeId: string
  choreTypeName: string
  categoryName: string
  completedBy: string
  completedDate: Date
  familyId: string
}

const GRACE_DAYS = 3

export function isChoredue(choreType: ChoreType, completions: ChoreCompletion[]): boolean {
  const freq = choreType.frequency ?? 'weekly'
  const freqDays = CHORE_FREQUENCY_DAYS[freq]
  const latest = completions
    .filter((c) => c.choreTypeId === choreType.id)
    .sort((a, b) => b.completedDate.getTime() - a.completedDate.getTime())[0]
  if (!latest) return true
  const daysSince = Math.floor((Date.now() - latest.completedDate.getTime()) / (1000 * 60 * 60 * 24))
  return daysSince >= freqDays
}

export function isChoreOverdue(choreType: ChoreType, completions: ChoreCompletion[]): boolean {
  const freq = choreType.frequency ?? 'weekly'
  const freqDays = CHORE_FREQUENCY_DAYS[freq]
  const latest = completions
    .filter((c) => c.choreTypeId === choreType.id)
    .sort((a, b) => b.completedDate.getTime() - a.completedDate.getTime())[0]
  if (!latest) return true // never done = overdue
  const daysSince = Math.floor((Date.now() - latest.completedDate.getTime()) / (1000 * 60 * 60 * 24))
  return daysSince >= freqDays + GRACE_DAYS
}
