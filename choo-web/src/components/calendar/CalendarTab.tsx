import { useEffect, useMemo, useState } from 'react'
import { format, addDays, addMonths, startOfDay, startOfMonth, isSameDay, isToday as isTodayFn, getMonth } from 'date-fns'
import { useAuthStore } from '../../stores/auth-store'
import { useCalendarStore } from '../../stores/calendar-store'
import {
  occursOn,
  getUrgencyState,
  isPaidOn,
  getRegister,
  getSubtype,
  getRampStage,
  getCountdownText,
  getTripSpanForDay,
  isTripSpan,
  isTripOccurrenceStart,
} from '../../types/event'
import type { FamilyEvent, EventSubtype, RampStage, TripSpanInfo } from '../../types/event'
import NavBar from '../layout/NavBar'
import ProfileSheet from '../layout/ProfileSheet'
import EventForm from './EventForm'
import EventDetail from './EventDetail'

// One scrolling agenda: gutter dates, three visual registers (fun / utility / routine),
// full-bleed month heroes, and the holiday bleed for multi-day trips.
// Mirrors the iOS CalendarTabView redesign; classification is written by iOS.

type FunTint = 'celebration' | 'social' | 'trip'

interface DayBlock {
  kind: 'day'
  day: Date
  events: FamilyEvent[]
  trip: TripSpanInfo | null
}
interface HeroBlock {
  kind: 'hero'
  day: Date
}
type AgendaBlock = DayBlock | HeroBlock

export default function CalendarTab() {
  const { familyId, profile, user } = useAuthStore()
  const { events, listen, stopListening, deleteEvent, toggleTodoCompleted, toggleBillPaid } = useCalendarStore()
  const [showProfile, setShowProfile] = useState(false)
  const [showEventForm, setShowEventForm] = useState(false)
  const [showPast, setShowPast] = useState(false)
  const [selectedEvent, setSelectedEvent] = useState<{ event: FamilyEvent; day: Date } | null>(null)

  useEffect(() => {
    if (familyId) listen(familyId)
    return () => stopListening()
  }, [familyId])

  // Agenda blocks: rendered days (today + any day with events; −6 months when
  // showing past, matching the store's query window, through +6 months), with a
  // month hero before the first day of each month.
  const blocks = useMemo(() => {
    const today = startOfDay(new Date())
    const start = showPast ? addMonths(today, -6) : today
    const end = addMonths(today, 6)
    const result: AgendaBlock[] = []
    let prevRendered: Date | null = null

    for (let day = start; day <= end; day = addDays(day, 1)) {
      const dayEvents = events
        // A trip only renders its own card on its start day — the bleed carries it after that
        .filter((e) => occursOn(e, day) && !(isTripSpan(e) && !isTripOccurrenceStart(e, day)))
        .sort((a, b) => {
          const ra = registerRank(a, day)
          const rb = registerRank(b, day)
          if (ra !== rb) return ra - rb
          return a.startDate.getTime() - b.startDate.getTime()
        })

      const trip = getTripSpanForDay(events, day)
      // Mid-span trip days still render so the bleed has rows to run under
      if (dayEvents.length === 0 && !isSameDay(day, today) && !trip) continue

      // Heroes mark month boundaries further down the agenda — never the month
      // you're already in, so today always sits at the top of the screen.
      const isCurrentMonth = getMonth(day) === getMonth(today) && day.getFullYear() === today.getFullYear()
      if (!isCurrentMonth && (!prevRendered || getMonth(prevRendered) !== getMonth(day))) {
        result.push({ kind: 'hero', day: startOfMonth(day) })
      }
      result.push({ kind: 'day', day, events: dayEvents, trip })
      prevRendered = day
    }
    return result
  }, [events, showPast])

  // Group consecutive day blocks that share a trip so the bleed wraps them as one run.
  // A month hero mid-span splits the run in two.
  const grouped = useMemo(() => {
    const groups: { trip: FamilyEvent | null; blocks: AgendaBlock[] }[] = []
    for (const block of blocks) {
      const trip = block.kind === 'day' ? (block.trip?.event ?? null) : null
      const last = groups[groups.length - 1]
      if (last && last.trip && trip && last.trip.id === trip.id && block.kind === 'day') {
        last.blocks.push(block)
      } else {
        groups.push({ trip, blocks: [block] })
      }
    }
    return groups
  }, [blocks])

  const handleDelete = async (event: FamilyEvent) => {
    if (!familyId || !event.id) return
    await deleteEvent(familyId, event.id)
    setSelectedEvent(null)
  }

  const renderDay = (block: DayBlock) => {
    const isToday = isTodayFn(block.day)
    const firstCelebrationId = block.events.find(
      (e) => getRegister(e) === 'fun' && getSubtype(e) === 'celebration'
    )?.id

    return (
      <div key={format(block.day, 'yyyy-MM-dd')} id={`day-${format(block.day, 'yyyy-MM-dd')}`}>
        {/* Google-style "now" rule above today */}
        {isToday && (
          <div className="flex items-center mb-3" aria-hidden>
            <div className="w-1.5 h-1.5 rounded-full bg-[#c4b5fd] shrink-0" />
            <div className="flex-1 h-px bg-[#c4b5fd]/70" />
          </div>
        )}
        <div className="flex gap-3">
        {/* Day gutter */}
        <div className="w-10 shrink-0 pt-1">
          {isToday ? (
            <div className="w-[30px] h-[30px] rounded-full bg-[#c4b5fd] flex items-center justify-center text-[15px] font-bold text-[#1c1535]">
              {format(block.day, 'd')}
            </div>
          ) : (
            <div className="text-[19px] font-bold leading-none text-white/85">
              {format(block.day, 'd')}
            </div>
          )}
          <div className={`text-[10px] font-bold uppercase tracking-[.08em] mt-[3px] ${isToday ? 'text-[#c4b5fd]/75 pl-[3px]' : 'text-white/35'}`}>
            {format(block.day, 'EEE')}
          </div>
        </div>

        {/* Cards */}
        <div className="flex-1 min-w-0 flex flex-col gap-2">
          {block.events.length === 0 && block.trip && block.trip.position !== 'start' ? (
            <button
              className="flex items-center gap-1.5 pt-1.5 text-left cursor-pointer"
              onClick={() => setSelectedEvent({ event: block.trip!.event, day: block.day })}
            >
              <span className="text-xs opacity-70">✈️</span>
              <span className="font-serif italic text-[12.5px] text-sky-400/70">
                {block.trip.event.title}
                {block.trip.position === 'end' ? ' — last day' : ''}
              </span>
            </button>
          ) : block.events.length === 0 ? (
            <div className="text-xs text-white/20 pt-1.5">No events</div>
          ) : (
            block.events.map((event) => {
              const register = getRegister(event)
              const key = `${event.id}-${format(block.day, 'yyyy-MM-dd')}`
              const onTap = () => setSelectedEvent({ event, day: block.day })
              if (register === 'fun') {
                const subtype = getSubtype(event)
                const tint: FunTint =
                  subtype === 'trip' ? 'trip'
                  : subtype === 'social' ? 'social'
                  : event.id === firstCelebrationId ? 'celebration' : 'social'
                return <FunCard key={key} event={event} day={block.day} tint={tint} onTap={onTap} />
              }
              if (register === 'routine') {
                return <RoutineRow key={key} event={event} onTap={onTap} />
              }
              return (
                <UtilityCard
                  key={key}
                  event={event}
                  day={block.day}
                  onTap={onTap}
                  onToggleTodo={() => familyId && toggleTodoCompleted(familyId, event)}
                  onTogglePaid={() => familyId && toggleBillPaid(familyId, event, block.day)}
                />
              )
            })
          )}
        </div>
        </div>
      </div>
    )
  }

  return (
    <>
      <NavBar
        title="Calendar"
        onProfile={() => setShowProfile(true)}
        onAdd={() => setShowEventForm(true)}
      />

      <div className="px-3.5 pb-6 pt-1 space-y-4">
        {/* Past events toggle — iOS parity for the deleted week navigation */}
        <button
          className="text-[11px] font-semibold uppercase tracking-wider text-white/30 hover:text-white/60 transition-base"
          onClick={() => setShowPast((v) => !v)}
        >
          {showPast ? 'Hide past events' : 'Show past events'}
        </button>

        {grouped.map((group, gi) => {
          const inner = group.blocks.map((block) =>
            block.kind === 'hero' ? <MonthHero key={`hero-${format(block.day, 'yyyy-MM')}`} monthDate={block.day} /> : renderDay(block)
          )
          if (!group.trip) {
            return (
              <div key={gi} className="space-y-4">
                {inner}
              </div>
            )
          }
          // Holiday bleed: wash + left ribbon wrapping the whole run of days
          return (
            <div
              key={gi}
              className="relative -mx-2 px-2 py-1 rounded-2xl space-y-4"
              style={{ background: 'linear-gradient(rgba(56,189,248,.10), rgba(56,189,248,.04))' }}
            >
              <div className="absolute left-0.5 top-2 bottom-2 w-[3px] rounded bg-sky-400/50" />
              {inner}
            </div>
          )
        })}
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

/** Trip start-day card leads, then fun, utility, routine. */
function registerRank(event: FamilyEvent, day: Date): number {
  if (isTripSpan(event) && isTripOccurrenceStart(event, day)) return -1
  const r = getRegister(event)
  return r === 'fun' ? 0 : r === 'utility' ? 1 : 2
}

// --- Month hero ---

const MONTH_THEMES: Record<number, { primary: string; secondary: string; tagline: string }> = {
  0: { primary: '251,146,60', secondary: '253,224,71', tagline: 'Peak summer' },
  1: { primary: '244,114,182', secondary: '248,113,113', tagline: 'Love & late summer' },
  2: { primary: '251,146,60', secondary: '180,83,9', tagline: 'Autumn begins' },
  3: { primary: '45,212,191', secondary: '148,163,184', tagline: 'Autumn rains' },
  4: { primary: '180,83,9', secondary: '251,146,60', tagline: 'Cosy autumn' },
  5: { primary: '34,211,238', secondary: '96,165,250', tagline: 'Winter arrives' },
  6: { primary: '96,165,250', secondary: '129,140,248', tagline: 'Deep winter' },
  7: { primary: '129,140,248', secondary: '34,211,238', tagline: "Winter's end" },
  8: { primary: '45,212,191', secondary: '163,230,53', tagline: 'Spring arrives' },
  9: { primary: '192,132,252', secondary: '251,146,60', tagline: 'Halloween' },
  10: { primary: '74,222,128', secondary: '110,231,183', tagline: 'Late spring' },
  11: { primary: '248,113,113', secondary: '74,222,128', tagline: 'Christmas & summer' },
}

function MonthHero({ monthDate }: { monthDate: Date }) {
  const theme = MONTH_THEMES[getMonth(monthDate)]
  return (
    <div
      className="relative -mx-3.5 h-[168px] overflow-hidden flex items-end"
      style={{
        background: `radial-gradient(120% 90% at 85% -10%, rgba(${theme.primary},.28) 0%, transparent 55%),
          radial-gradient(90% 80% at 10% 110%, rgba(${theme.secondary},.15) 0%, transparent 50%),
          radial-gradient(140% 120% at 50% 50%, rgba(139,92,246,.3) 0%, transparent 70%),
          linear-gradient(160deg, #241b45 0%, #1a1535 60%, #17122b 100%)`,
      }}
    >
      <Bubble size={70} right={44} top={22} delay={0} />
      <Bubble size={42} right={124} top={66} delay={-3} />
      <Bubble size={26} right={30} top={104} delay={-5.5} />
      <div
        className="absolute inset-0 pointer-events-none"
        style={{ background: 'linear-gradient(180deg, rgba(23,18,43,.55) 0%, transparent 30%, transparent 70%, rgba(23,18,43,.75) 100%)' }}
      />
      <div className="relative px-[22px] pb-[18px]">
        <div className="font-serif text-4xl leading-none text-white">{format(monthDate, 'MMMM')}</div>
        <div className="font-serif italic text-[13px] text-[#ede9fe]/65 mt-[5px]">{theme.tagline}</div>
      </div>
    </div>
  )
}

function Bubble({ size, right, top, delay }: { size: number; right: number; top: number; delay: number }) {
  return (
    <div
      className="absolute rounded-full cal-drift"
      style={{
        width: size,
        height: size,
        right,
        top,
        animationDelay: `${delay}s`,
        border: '1px solid rgba(255,255,255,.22)',
        background: `radial-gradient(circle at 32% 28%, rgba(255,255,255,.5) 0%, transparent 45%),
          radial-gradient(circle at 50% 50%, rgba(196,128,255,.2), rgba(139,92,246,.06))`,
      }}
    />
  )
}

// --- FUN cards ---

const FUN_TINTS: Record<FunTint, { background: string; border: string; glow: string; chipBg: string; chipBorder: string }> = {
  celebration: {
    background: 'linear-gradient(115deg, rgba(196,128,255,.2) 0%, rgba(139,92,246,.1) 55%, rgba(255,158,196,.13) 100%)',
    border: 'rgba(196,128,255,.32)',
    glow: 'rgba(196,128,255,.22)',
    chipBg: 'rgba(196,128,255,.22)',
    chipBorder: 'rgba(196,128,255,.35)',
  },
  social: {
    background:
      'radial-gradient(120% 170% at 100% 0%, rgba(251,176,110,.26) 0%, rgba(251,176,110,.06) 55%, transparent 75%), linear-gradient(115deg, rgba(139,92,246,.14), rgba(139,92,246,.08))',
    border: 'rgba(251,176,110,.4)',
    glow: 'rgba(251,176,110,.22)',
    chipBg: 'rgba(251,176,110,.2)',
    chipBorder: 'rgba(251,176,110,.4)',
  },
  trip: {
    background: 'radial-gradient(120% 170% at 100% 0%, rgba(56,189,248,.22) 0%, rgba(56,189,248,.05) 55%, transparent 75%), linear-gradient(115deg, rgba(139,92,246,.14), rgba(139,92,246,.08))',
    border: 'rgba(56,189,248,.35)',
    glow: 'rgba(56,189,248,.2)',
    chipBg: 'rgba(56,189,248,.2)',
    chipBorder: 'rgba(56,189,248,.4)',
  },
}

const SCENE_STYLE: Record<RampStage, { opacity: number; saturate: number }> = {
  past: { opacity: 0.3, saturate: 0.55 },
  distant: { opacity: 0.4, saturate: 0.55 },
  week: { opacity: 0.68, saturate: 0.8 },
  near: { opacity: 0.85, saturate: 1 },
  today: { opacity: 1, saturate: 1 },
}

function FunCard({ event, day, tint, onTap }: { event: FamilyEvent; day: Date; tint: FunTint; onTap: () => void }) {
  const ramp = getRampStage(day)
  const t = FUN_TINTS[tint]
  const scene = SCENE_STYLE[ramp]
  const sceneEmoji = event.classification?.sceneEmoji ?? []
  const glow = ramp === 'today' || ramp === 'near'

  const timeStr = event.isAllDay
    ? getSpanLabel(event)
    : format(event.startDate, 'h:mm a').toLowerCase()

  return (
    <div
      className="relative rounded-[18px] px-[18px] py-5 min-h-[112px] overflow-hidden cursor-pointer"
      style={{
        background: t.background,
        border: `1px solid ${t.border}`,
        boxShadow: glow ? `0 0 ${ramp === 'today' ? 34 : 20}px ${t.glow}` : undefined,
      }}
      onClick={onTap}
    >
      {/* Emoji scene */}
      <div className="absolute inset-0 pointer-events-none" style={{ opacity: scene.opacity, filter: `saturate(${scene.saturate})` }}>
        {sceneEmoji[0] && (
          <span
            className="cal-float absolute text-[52px]"
            style={{ right: -8, top: '50%', translate: '0 -50%', ['--rot' as string]: '-8deg', filter: 'drop-shadow(0 2px 6px rgba(18,14,34,.35))' }}
          >
            {sceneEmoji[0]}
          </span>
        )}
        {sceneEmoji[1] && (
          <span
            className="cal-float absolute text-[28px]"
            style={{ right: 80, top: 6, animationDuration: '5.5s', animationDelay: '-2s', ['--rot' as string]: '10deg', filter: 'drop-shadow(0 2px 6px rgba(18,14,34,.35))' }}
          >
            {sceneEmoji[1]}
          </span>
        )}
        {sceneEmoji[2] && (
          <span className="absolute text-base opacity-80" style={{ right: 124, bottom: 14 }}>
            {sceneEmoji[2]}
          </span>
        )}
      </div>

      <div className="relative pr-14">
        <div className="text-lg font-bold text-white" style={{ textShadow: '0 1px 8px rgba(18,14,34,.6)' }}>
          {event.title}
        </div>
        <div className="text-[13.5px] text-[#ede9fe]/60 mt-[3px]">{timeStr}</div>
        <Countdown ramp={ramp} day={day} tint={t} />
      </div>
    </div>
  )
}

function Countdown({ ramp, day, tint }: { ramp: RampStage; day: Date; tint: { chipBg: string; chipBorder: string } }) {
  if (ramp === 'past') return null
  if (ramp === 'distant') {
    return <div className="font-serif italic text-[12.5px] text-[#ede9fe]/35 mt-2">{getCountdownText(day)}</div>
  }
  if (ramp === 'today') {
    return (
      <span
        className="relative inline-block overflow-hidden mt-2.5 text-[11.5px] font-semibold tracking-[.04em] text-[#fdf4ff] rounded-full px-[11px] py-1"
        style={{
          background: 'linear-gradient(100deg, rgba(217,70,239,.32), rgba(251,176,110,.3))',
          border: '1px solid rgba(240,171,252,.6)',
        }}
      >
        Today! 🎈
        <span
          className="cal-shimmer absolute inset-0"
          style={{ background: 'linear-gradient(100deg, transparent 30%, rgba(255,255,255,.28) 50%, transparent 70%)' }}
        />
      </span>
    )
  }
  return (
    <span
      className="inline-block mt-2.5 text-[11.5px] font-semibold tracking-[.04em] text-[#e9d5ff] rounded-full px-[11px] py-1"
      style={{ background: tint.chipBg, border: `1px solid ${tint.chipBorder}` }}
    >
      {getCountdownText(day)}
    </span>
  )
}

function getSpanLabel(event: FamilyEvent): string {
  if (isSameDay(event.startDate, event.endDate)) return 'All day'
  return `${format(event.startDate, 'EEE d MMM')} – ${format(event.endDate, 'EEE d MMM')}`
}

// --- UTILITY cards ---

const UTILITY_BORDERS: Record<string, string> = {
  health: 'rgba(94,234,212,.5)',
  admin: 'rgba(200,142,167,.5)',
}

function UtilityCard({
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
  const paid = isPaidOn(event, day)
  const urgency = getUrgencyState(event)
  const todoDone = event.isTodo && event.isCompleted
  const subtype = getSubtype(event) as EventSubtype
  const borderLeft = UTILITY_BORDERS[subtype] ?? 'rgba(148,163,184,.45)'

  const glyph = event.isBill
    ? '💰'
    : event.classification && event.classification.classifiedTitle === event.title && event.classification.glyph
      ? event.classification.glyph
      : '🗓'

  const meta: string[] = []
  if (event.isTodo) {
    meta.push(todoDone ? 'Done' : todoHasDue(event) ? `Due ${format(event.endDate, 'EEE d MMM')}` : 'No due date')
  } else if (event.isBill) {
    if (event.amount) meta.push(`$${event.amount.toFixed(2)}`)
    if (paid) meta.push('Paid')
  } else {
    meta.push(event.isAllDay ? 'All day' : format(event.startDate, 'h:mm a').toLowerCase())
    if (event.location) meta.push(event.location)
  }
  if (!event.isTodo && event.recurrenceFrequency) meta.push(`↻ ${event.recurrenceFrequency}`)
  if (event.reminderEnabled) meta.push('🔔')

  return (
    <div
      className={`relative rounded-[18px] px-4 py-3.5 cursor-pointer transition-base ${paid || todoDone ? 'opacity-60' : ''}`}
      style={{ background: 'rgba(139,92,246,.06)', border: '1px solid rgba(139,92,246,.12)', borderLeft: `3px solid ${borderLeft}` }}
      onClick={onTap}
    >
      <div className="flex items-center gap-2 pr-16">
        {event.isTodo ? (
          <button
            onClick={(e) => { e.stopPropagation(); onToggleTodo() }}
            className={`w-4 h-4 rounded-full border-2 flex items-center justify-center shrink-0 transition-base
              ${todoDone ? 'bg-green-500/20 border-green-500' : 'border-white/25 hover:border-white/50'}`}
          >
            {todoDone && <span className="text-green-400 text-[10px] leading-none">✓</span>}
          </button>
        ) : event.isBill ? (
          <button onClick={(e) => { e.stopPropagation(); onTogglePaid() }} className={`text-base shrink-0 ${paid ? 'opacity-50' : ''}`}>
            💰
          </button>
        ) : (
          <span className="text-base shrink-0" style={{ filter: 'saturate(.75)', opacity: 0.85 }}>{glyph}</span>
        )}

        <span className={`text-base font-semibold truncate ${todoDone ? 'line-through text-white/40' : 'text-white'}`}>
          {event.isTodo && event.todoEmoji && <span className="mr-1">{event.todoEmoji}</span>}
          {event.title}
        </span>

        {event.isTodo && !todoDone && urgency !== 'notStarted' && (
          <span
            className={`pill !text-[9px] uppercase shrink-0 ${
              urgency === 'overdue' ? 'bg-red-500/15 text-red-400'
              : urgency === 'dueSoon' ? 'bg-amber-500/15 text-amber-400'
              : 'bg-white/10 text-white/40'
            }`}
          >
            {urgency === 'overdue' ? 'Overdue' : urgency === 'dueSoon' ? 'Due soon' : todoHasDue(event) ? 'Active' : 'Flexible'}
          </span>
        )}
      </div>
      <div className={`text-[13px] mt-[3px] ml-[25px] ${event.isTodo && urgency === 'overdue' && !todoDone ? 'text-red-400' : 'text-[#ede9fe]/55'}`}>
        {meta.join(' · ')}
      </div>

      {(todoDone || (event.isBill && paid)) && (
        <span className="pill bg-green-500/15 text-green-400 absolute right-3.5 top-1/2 -translate-y-1/2">
          {todoDone ? 'Done' : 'Paid'}
        </span>
      )}
    </div>
  )
}

function todoHasDue(event: FamilyEvent): boolean {
  return !isSameDay(event.startDate, event.endDate)
}

// --- ROUTINE rows ---

function RoutineRow({ event, onTap }: { event: FamilyEvent; onTap: () => void }) {
  return (
    <div
      className="flex items-center gap-2.5 rounded-[13px] px-4 py-[11px] cursor-pointer transition-base"
      style={{ background: 'rgba(139,92,246,.06)', border: '1px solid rgba(139,92,246,.12)' }}
      onClick={onTap}
    >
      <span className="flex-1 min-w-0 truncate text-[14.5px] font-medium text-[#ede9fe]/55">{event.title}</span>
      <span className="flex items-center gap-1.5 text-[12.5px] text-[#ede9fe]/35 shrink-0">
        {event.recurrenceFrequency && <span className="opacity-60 text-[11px]">↻</span>}
        {event.isAllDay ? 'All day' : format(event.startDate, 'h:mm a').toLowerCase()}
      </span>
    </div>
  )
}
