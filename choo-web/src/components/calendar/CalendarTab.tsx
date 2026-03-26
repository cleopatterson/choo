import { useEffect, useMemo, useState } from 'react'
import { format, addDays, startOfWeek, endOfWeek, eachDayOfInterval, isToday as isTodayFn } from 'date-fns'
import { useAuthStore } from '../../stores/auth-store'
import { useCalendarStore } from '../../stores/calendar-store'
import { occursOn, getUrgencyState, isPaidOn } from '../../types/event'
import type { FamilyEvent } from '../../types/event'
import NavBar from '../layout/NavBar'
import ProfileSheet from '../layout/ProfileSheet'
import EventForm from './EventForm'
import EventDetail from './EventDetail'

export default function CalendarTab() {
  const { familyId, profile, user } = useAuthStore()
  const { events, listen, stopListening, deleteEvent, toggleTodoCompleted, toggleBillPaid } = useCalendarStore()
  const [showProfile, setShowProfile] = useState(false)
  const [showEventForm, setShowEventForm] = useState(false)
  const [selectedEvent, setSelectedEvent] = useState<{ event: FamilyEvent; day: Date } | null>(null)
  const [selectedWeekStart, setSelectedWeekStart] = useState(() =>
    startOfWeek(new Date(), { weekStartsOn: 1 })
  )

  useEffect(() => {
    if (familyId) listen(familyId)
    return () => stopListening()
  }, [familyId])

  // Generate the 7 days of the selected week
  const weekDays = useMemo(() => {
    return eachDayOfInterval({
      start: selectedWeekStart,
      end: endOfWeek(selectedWeekStart, { weekStartsOn: 1 }),
    })
  }, [selectedWeekStart])

  // Get events for each day of the week
  const eventsByDay = useMemo(() => {
    const result: Map<string, FamilyEvent[]> = new Map()
    for (const day of weekDays) {
      const dayKey = format(day, 'yyyy-MM-dd')
      const dayEvents = events
        .filter((e) => occursOn(e, day))
        .sort((a, b) => {
          // Todos first, then by time
          if (a.isTodo && !b.isTodo) return -1
          if (!a.isTodo && b.isTodo) return 1
          return a.startDate.getTime() - b.startDate.getTime()
        })
      result.set(dayKey, dayEvents)
    }
    return result
  }, [events, weekDays])

  const goToPrevWeek = () => setSelectedWeekStart((prev) => addDays(prev, -7))
  const goToNextWeek = () => setSelectedWeekStart((prev) => addDays(prev, 7))
  const goToToday = () => setSelectedWeekStart(startOfWeek(new Date(), { weekStartsOn: 1 }))

  const handleDelete = async (event: FamilyEvent) => {
    if (!familyId || !event.id) return
    await deleteEvent(familyId, event.id)
    setSelectedEvent(null)
  }

  return (
    <>
      <NavBar
        title="Calendar"
        onProfile={() => setShowProfile(true)}
        onAdd={() => setShowEventForm(true)}
      />

      <div className="p-4 space-y-4">
        {/* Week navigation */}
        <div className="flex items-center justify-between">
          <button onClick={goToPrevWeek} className="text-white/40 px-3 py-1 text-lg">&larr;</button>
          <button onClick={goToToday} className="text-sm font-medium text-white/70">
            {format(selectedWeekStart, 'd MMM')} – {format(addDays(selectedWeekStart, 6), 'd MMM yyyy')}
          </button>
          <button onClick={goToNextWeek} className="text-white/40 px-3 py-1 text-lg">&rarr;</button>
        </div>

        {/* Week strip */}
        <div className="flex gap-1.5">
          {weekDays.map((day) => {
            const dayKey = format(day, 'yyyy-MM-dd')
            const dayEvents = eventsByDay.get(dayKey) ?? []
            const isToday = isTodayFn(day)
            return (
              <div
                key={dayKey}
                className={`flex-1 text-center py-2 rounded-xl transition-base cursor-pointer
                  ${isToday ? 'bg-choo-purple/20 border border-choo-purple/40' : 'glass'}`}
                onClick={() => {
                  const el = document.getElementById(`day-${dayKey}`)
                  el?.scrollIntoView({ behavior: 'smooth', block: 'start' })
                }}
              >
                <div className="text-[10px] text-white/40 font-medium">{format(day, 'EEE')}</div>
                <div className={`text-sm font-semibold ${isToday ? 'text-choo-purple' : ''}`}>
                  {format(day, 'd')}
                </div>
                {dayEvents.length > 0 && (
                  <div className="flex justify-center gap-0.5 mt-1">
                    {dayEvents.slice(0, 3).map((_, i) => (
                      <div key={i} className="w-1 h-1 rounded-full bg-choo-purple" />
                    ))}
                  </div>
                )}
              </div>
            )
          })}
        </div>

        {/* Day sections */}
        <div className="space-y-4">
          {weekDays.map((day) => {
            const dayKey = format(day, 'yyyy-MM-dd')
            const dayEvents = eventsByDay.get(dayKey) ?? []
            const isToday = isTodayFn(day)

            return (
              <div key={dayKey} id={`day-${dayKey}`}>
                {/* Day header */}
                <div className="flex items-center gap-2 mb-2">
                  <h3 className={`text-xs font-bold tracking-wider uppercase
                    ${isToday ? 'text-choo-purple' : 'text-white/40'}`}>
                    {isToday ? 'Today' : format(day, 'EEEE')}
                    <span className="text-white/30 ml-1.5 font-medium normal-case">
                      {format(day, 'd MMM')}
                    </span>
                  </h3>
                </div>

                {dayEvents.length === 0 ? (
                  <div className="text-xs text-white/20 pl-1 pb-2">No events</div>
                ) : (
                  <div className="space-y-1.5">
                    {dayEvents.map((event) => (
                      <EventRow
                        key={`${event.id}-${dayKey}`}
                        event={event}
                        day={day}
                        onTap={() => setSelectedEvent({ event, day })}
                        onToggleTodo={() => familyId && toggleTodoCompleted(familyId, event)}
                        onTogglePaid={() => familyId && toggleBillPaid(familyId, event, day)}
                      />
                    ))}
                  </div>
                )}
              </div>
            )
          })}
        </div>
      </div>

      {showEventForm && (
        <EventForm
          familyId={familyId!}
          displayName={profile?.displayName ?? ''}
          userUID={user?.uid ?? ''}
          onClose={() => setShowEventForm(false)}
        />
      )}

      {selectedEvent && (
        <EventDetail
          event={selectedEvent.event}
          day={selectedEvent.day}
          familyId={familyId!}
          onClose={() => setSelectedEvent(null)}
          onDelete={() => handleDelete(selectedEvent.event)}
        />
      )}

      {showProfile && <ProfileSheet onClose={() => setShowProfile(false)} />}
    </>
  )
}

// --- Event Row Component ---

function EventRow({
  event,
  day,
  onTap,
  onToggleTodo,
  onTogglePaid,
}: {
  event: FamilyEvent
  day: Date
  onTap: () => void
  onToggleTodo: () => void
  onTogglePaid: () => void
}) {
  const urgency = getUrgencyState(event)
  const paid = isPaidOn(event, day)

  const timeStr = event.isAllDay
    ? 'All day'
    : format(event.startDate, 'h:mm a')

  const urgencyColor: Record<string, string> = {
    overdue: 'text-red-400',
    dueSoon: 'text-amber-400',
    done: 'text-green-400 line-through',
    flexible: 'text-blue-400',
  }

  return (
    <div
      className="glass rounded-xl px-3.5 py-2.5 flex items-center gap-3 cursor-pointer transition-base hover:bg-white/8"
      onClick={onTap}
    >
      {/* Left indicator */}
      {event.isTodo ? (
        <button
          onClick={(e) => { e.stopPropagation(); onToggleTodo() }}
          className={`w-5 h-5 rounded-md border-2 flex items-center justify-center shrink-0 transition-base
            ${event.isCompleted ? 'bg-green-500/20 border-green-500' : 'border-white/20 hover:border-white/40'}`}
        >
          {event.isCompleted && <span className="text-green-400 text-xs">✓</span>}
        </button>
      ) : event.isBill ? (
        <button
          onClick={(e) => { e.stopPropagation(); onTogglePaid() }}
          className={`text-sm shrink-0 ${paid ? 'opacity-50' : ''}`}
        >
          💰
        </button>
      ) : (
        <div className="w-1.5 h-1.5 rounded-full bg-choo-purple shrink-0" />
      )}

      {/* Content */}
      <div className="flex-1 min-w-0">
        <div className={`text-sm font-medium truncate
          ${event.isTodo ? urgencyColor[urgency] ?? '' : ''}
          ${event.isCompleted ? 'line-through text-white/40' : ''}`}>
          {event.todoEmoji && <span className="mr-1">{event.todoEmoji}</span>}
          {event.title}
        </div>
        <div className="text-[10px] text-white/40 mt-0.5">
          {timeStr}
          {event.location && <span> · {event.location}</span>}
          {event.isBill && event.amount && (
            <span className={paid ? 'line-through' : ''}> · ${event.amount.toFixed(2)}</span>
          )}
        </div>
      </div>

      {/* Right pills */}
      <div className="flex items-center gap-1.5 shrink-0">
        {event.isBill && (
          <span className={`pill ${paid ? 'bg-green-500/15 text-green-400' : 'bg-amber-500/15 text-amber-400'}`}>
            {paid ? 'Paid' : 'Due'}
          </span>
        )}
        {event.isTodo && urgency === 'overdue' && (
          <span className="pill bg-red-500/15 text-red-400">Overdue</span>
        )}
        {event.isTodo && urgency === 'dueSoon' && (
          <span className="pill bg-amber-500/15 text-amber-400">Due soon</span>
        )}
        {event.recurrenceFrequency && (
          <span className="text-[10px] text-white/25">↻</span>
        )}
      </div>
    </div>
  )
}
