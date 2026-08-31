export type RecurrenceFrequency = 'daily' | 'weekly' | 'fortnightly' | 'monthly' | 'yearly'

export type TodoUrgencyState = 'notStarted' | 'active' | 'dueSoon' | 'overdue' | 'done' | 'flexible'

export type EventRegister = 'fun' | 'utility' | 'routine'

export type EventSubtype = 'celebration' | 'social' | 'trip' | 'health' | 'errand' | 'admin' | 'recurring'

/** Haiku classification stored on the event doc (written by iOS; web only renders it). */
export interface EventClassification {
  register: string
  subtype: string
  glyph: string
  sceneEmoji: string[]
  confidence: number
  classifiedTitle: string
  classifiedAt?: Date
}

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
  classification?: EventClassification
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

// --- Classification helpers (mirror of iOS FamilyEvent) ---

function hasFreshClassification(event: FamilyEvent): boolean {
  return event.classification?.classifiedTitle === event.title
}

const REGISTERS: EventRegister[] = ['fun', 'utility', 'routine']
const SUBTYPES: EventSubtype[] = ['celebration', 'social', 'trip', 'health', 'errand', 'admin', 'recurring']

/** Rendering register with local validation — mirrors iOS `effectiveRegister`. */
export function getRegister(event: FamilyEvent): EventRegister {
  if (event.isBill || event.isTodo) return 'utility'
  const c = event.classification
  if (c && hasFreshClassification(event) && REGISTERS.includes(c.register as EventRegister) && c.confidence >= 0.6) {
    if (c.register === 'routine' && !event.recurrenceFrequency) return 'utility'
    return c.register as EventRegister
  }
  if (event.recurrenceFrequency === 'weekly' || event.recurrenceFrequency === 'fortnightly') return 'routine'
  return 'utility'
}

export function getSubtype(event: FamilyEvent): EventSubtype {
  const c = event.classification
  if (c && hasFreshClassification(event) && SUBTYPES.includes(c.subtype as EventSubtype)) {
    return c.subtype as EventSubtype
  }
  return 'errand'
}

export function getSpanDayCount(event: FamilyEvent): number {
  if (!event.isAllDay) return 0
  return Math.max(0, differenceInCalendarDays(startOfDay(event.endDate), startOfDay(event.startDate)))
}

/** A classified multi-day trip — drives the holiday bleed. */
export function isTripSpan(event: FamilyEvent): boolean {
  return getRegister(event) === 'fun' && getSubtype(event) === 'trip' && getSpanDayCount(event) >= 1
}

export type TripSpanPosition = 'start' | 'middle' | 'end'

export interface TripSpanInfo {
  event: FamilyEvent
  position: TripSpanPosition
}

/** Whether this day is the first day of a trip occurrence — occurrence-aware,
 * so later occurrences of a recurring trip get a start day too. */
export function isTripOccurrenceStart(event: FamilyEvent, day: Date): boolean {
  return !occursOn(event, addDays(day, -1))
}

/** The trip whose span covers this day, if any. Earliest-starting trip wins overlaps. */
export function getTripSpanForDay(events: FamilyEvent[], day: Date): TripSpanInfo | null {
  const trips = events
    .filter((e) => isTripSpan(e) && occursOn(e, day))
    .sort((a, b) => a.startDate.getTime() - b.startDate.getTime())
  const trip = trips[0]
  if (!trip) return null
  const position: TripSpanPosition = isTripOccurrenceStart(trip, day)
    ? 'start'
    : !occursOn(trip, addDays(day, 1))
      ? 'end'
      : 'middle'
  return { event: trip, position }
}

// --- Anticipation ramp (pure date math, FUN cards only) ---

export type RampStage = 'distant' | 'week' | 'near' | 'today' | 'past'

export function getRampStage(eventDay: Date, today: Date = new Date()): RampStage {
  const days = differenceInCalendarDays(startOfDay(eventDay), startOfDay(today))
  if (days < 0) return 'past'
  if (days === 0) return 'today'
  if (days <= 2) return 'near'
  if (days <= 13) return 'week'
  return 'distant'
}

const NUMBER_WORDS = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten']

/** Countdown copy: whispers spell numbers ("two weeks away…"), chips use digits ("in 6 days"). */
export function getCountdownText(eventDay: Date, today: Date = new Date()): string {
  const days = differenceInCalendarDays(startOfDay(eventDay), startOfDay(today))
  if (days <= 0) return 'Today! 🎈'
  if (days === 1) return 'tomorrow'
  if (days <= 13) return `in ${days} days`
  const weeks = Math.round(days / 7)
  const word = NUMBER_WORDS[weeks] ?? String(weeks)
  return `${word} weeks away…`
}
