export type RecurrenceFrequency = 'daily' | 'weekly' | 'fortnightly' | 'monthly' | 'yearly'

export type TodoUrgencyState = 'notStarted' | 'active' | 'dueSoon' | 'overdue' | 'done' | 'flexible'

export interface FamilyEvent {
  id?: string
  familyId: string
  title: string
  startDate: Date
  endDate: Date
  createdBy: string
  attendeeUIDs?: string[]
  isAllDay?: boolean
  location?: string
  recurrenceFrequency?: string
  recurrenceEndDate?: Date
  reminderEnabled?: boolean
  isBill?: boolean
  amount?: number
  isPaid?: boolean
  paidOccurrences?: string[]
  note?: string
  lastModifiedByUID?: string
  googleCalendarEventId?: string
  isTodo?: boolean
  isCompleted?: boolean
  completedDate?: Date
  todoEmoji?: string
}

// --- Helper functions (ported from iOS FamilyEvent) ---

import { startOfDay, addDays, addMonths, differenceInCalendarDays, isSameDay, getMonth, getDate } from 'date-fns'

function occurrenceKey(date: Date): string {
  const d = startOfDay(date)
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

export function isPaidOn(event: FamilyEvent, day: Date): boolean {
  if (!event.isBill) return false
  if (event.recurrenceFrequency) {
    if (event.paidOccurrences) {
      return event.paidOccurrences.includes(occurrenceKey(day))
    }
    return event.isPaid === true
  }
  return event.isPaid === true
}

export function todoHasDueDate(event: FamilyEvent): boolean {
  if (!event.isTodo) return false
  return !isSameDay(event.startDate, event.endDate)
}

export function getUrgencyState(event: FamilyEvent): TodoUrgencyState {
  if (!event.isTodo) return 'active'
  if (event.isCompleted) return 'done'

  const today = startOfDay(new Date())
  const start = startOfDay(event.startDate)

  if (start > today) return 'notStarted'
  if (!todoHasDueDate(event)) return 'flexible'

  const due = startOfDay(event.endDate)
  if (due < today) return 'overdue'

  const twoDaysBefore = addDays(due, -2)
  if (today >= startOfDay(twoDaysBefore)) return 'dueSoon'

  return 'active'
}

function todoShouldAppearOn(event: FamilyEvent, day: Date): boolean {
  if (!event.isTodo) return false
  const dayStart = startOfDay(day)
  const today = startOfDay(new Date())

  if (event.isCompleted) {
    return event.completedDate ? isSameDay(event.completedDate, day) : false
  }

  if (isSameDay(event.startDate, day)) return true
  if (!isSameDay(event.startDate, event.endDate) && isSameDay(event.endDate, day)) return true
  if (isSameDay(dayStart, today) && getUrgencyState(event) === 'overdue') return true

  return false
}

export function occursOn(event: FamilyEvent, day: Date): boolean {
  if (event.isTodo) return todoShouldAppearOn(event, day)

  const dayStart = startOfDay(day)

  // Check recurrence end date
  if (event.recurrenceEndDate && dayStart > startOfDay(event.recurrenceEndDate)) {
    return false
  }

  const freq = event.recurrenceFrequency as RecurrenceFrequency | undefined

  // Non-recurring
  if (!freq) {
    if (event.isAllDay) {
      const eventStart = startOfDay(event.startDate)
      const eventEnd = startOfDay(event.endDate)
      return dayStart >= eventStart && dayStart <= eventEnd
    }
    return isSameDay(event.startDate, day)
  }

  // Recurring: day must be on or after anchor
  const anchor = startOfDay(event.startDate)
  if (dayStart < anchor) return false

  const spanDays = event.isAllDay
    ? Math.max(0, differenceInCalendarDays(startOfDay(event.endDate), anchor))
    : 0

  const daysDiff = differenceInCalendarDays(dayStart, anchor)

  switch (freq) {
    case 'daily':
      return true
    case 'weekly':
      return (daysDiff % 7) <= spanDays
    case 'fortnightly':
      return (daysDiff % 14) <= spanDays
    case 'monthly': {
      // Check nearby monthly occurrences
      const approxMonths = Math.floor(daysDiff / 28)
      for (let m = Math.max(0, approxMonths - 1); m <= approxMonths + 1; m++) {
        const occ = startOfDay(addMonths(anchor, m))
        if (spanDays === 0) {
          if (isSameDay(dayStart, occ)) return true
        } else {
          for (let offset = 0; offset <= spanDays; offset++) {
            if (isSameDay(addDays(occ, offset), dayStart)) return true
          }
        }
      }
      return false
    }
    case 'yearly': {
      if (spanDays === 0) {
        return getMonth(anchor) === getMonth(day) && getDate(anchor) === getDate(day)
      }
      for (let offset = 0; offset <= spanDays; offset++) {
        const d = addDays(anchor, offset)
        if (getMonth(d) === getMonth(day) && getDate(d) === getDate(day)) return true
      }
      return false
    }
    default:
      return false
  }
}
