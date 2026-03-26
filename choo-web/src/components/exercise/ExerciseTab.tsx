import { useEffect, useMemo, useState } from 'react'
import { format, startOfWeek, eachDayOfInterval, endOfWeek, isToday as isTodayFn } from 'date-fns'
import { useAuthStore } from '../../stores/auth-store'
import { useExerciseStore } from '../../stores/exercise-store'
import { getDayLoad, TIME_SLOT_META, type TimeSlot } from '../../types/exercise'
import NavBar from '../layout/NavBar'
import ProfileSheet from '../layout/ProfileSheet'

const LOAD_COLORS: Record<string, string> = {
  light: 'bg-green-500/20 text-green-400',
  moderate: 'bg-amber-500/20 text-amber-400',
  high: 'bg-orange-500/20 text-orange-400',
  peak: 'bg-red-500/20 text-red-400',
}

const SLOTS: TimeSlot[] = ['morning', 'lunch', 'arvo']

export default function ExerciseTab() {
  const { familyId, user } = useAuthStore()
  const { categories, plan, listen, stopListening } = useExerciseStore()
  const [showProfile, setShowProfile] = useState(false)
  const [selectedDay, setSelectedDay] = useState<number | null>(null)

  const weekStart = useMemo(() => startOfWeek(new Date(), { weekStartsOn: 1 }), [])
  const weekDays = useMemo(() => eachDayOfInterval({
    start: weekStart,
    end: endOfWeek(weekStart, { weekStartsOn: 1 }),
  }), [weekStart])

  useEffect(() => {
    if (familyId && user?.uid) listen(familyId, user.uid, weekStart)
    return () => stopListening()
  }, [familyId, user?.uid])

  // Calculate stats
  const weekMinutes = useMemo(() => {
    if (!plan?.slots) return 0
    const today = new Date().getDay()
    const todayIdx = today === 0 ? 6 : today - 1 // convert to Mon=0
    return Object.entries(plan.slots)
      .filter(([key]) => {
        const dayIdx = parseInt(key.split('_')[0])
        return dayIdx >= todayIdx
      })
      .reduce((sum, [, slot]) => sum + (slot.durationMinutes ?? 0), 0)
  }, [plan])

  const getDayCalories = (dayIdx: number): number => {
    if (!plan?.slots) return 0
    return SLOTS.reduce((sum, slot) => {
      const key = `${dayIdx}_${slot}`
      return sum + (plan.slots[key]?.estimatedCalories ?? 0)
    }, 0)
  }

  // Today's sessions
  const todayIdx = new Date().getDay() === 0 ? 6 : new Date().getDay() - 1
  const todaySessions = SLOTS
    .map((slot) => plan?.slots[`${todayIdx}_${slot}`])
    .filter(Boolean)

  return (
    <>
      <NavBar title="Exercise" onProfile={() => setShowProfile(true)} />

      <div className="p-4 space-y-4">
        {/* Hero card — today */}
        <div className="hero-exercise rounded-2xl p-4 border border-choo-teal/30">
          <div className="text-[10px] text-choo-teal/60 font-bold tracking-wider uppercase mb-1">
            Today · {format(new Date(), 'd MMM')}
          </div>
          {todaySessions.length > 0 ? (
            <>
              <div className="font-serif font-bold text-lg">
                {todaySessions.map((s) => s!.sessionTypeName).join(' & ')}
              </div>
              <div className="text-sm text-white/60 mt-0.5">
                {todaySessions.reduce((s, t) => s + (t!.durationMinutes ?? 0), 0)} min
              </div>
              <div className="flex gap-1.5 mt-2">
                {todaySessions.map((s, i) => (
                  <span key={i} className="pill bg-choo-teal/15 text-choo-teal">
                    {s!.categoryEmoji} {s!.categoryName}
                  </span>
                ))}
              </div>
            </>
          ) : (
            <div className="text-white/40 text-sm">
              {plan?.restDays?.includes(todayIdx) ? '😴 Rest day' : 'No sessions planned'}
            </div>
          )}
        </div>

        {/* Week strip */}
        <div className="flex gap-1.5">
          {weekDays.map((day, i) => {
            const cals = getDayCalories(i)
            const load = cals > 0 ? getDayLoad(cals) : null
            const isRest = plan?.restDays?.includes(i)
            const isToday = isTodayFn(day)
            return (
              <button
                key={i}
                onClick={() => setSelectedDay(selectedDay === i ? null : i)}
                className={`flex-1 py-2 rounded-xl text-center transition-base
                  ${isToday ? 'bg-choo-teal/20 border border-choo-teal/40' : 'glass'}
                  ${selectedDay === i ? 'ring-1 ring-choo-teal' : ''}`}
              >
                <div className="text-[10px] text-white/40">{format(day, 'EEE')}</div>
                <div className={`text-sm font-semibold ${isToday ? 'text-choo-teal' : ''}`}>
                  {format(day, 'd')}
                </div>
                {load && (
                  <div className={`mx-auto mt-1 w-2 h-2 rounded-full ${LOAD_COLORS[load].split(' ')[0]}`} />
                )}
                {isRest && <div className="text-[10px] mt-0.5">😴</div>}
              </button>
            )
          })}
        </div>

        {/* Stats bar */}
        <div className="flex gap-2">
          <div className={`flex-1 glass rounded-xl p-3 text-center ${weekMinutes >= 150 ? 'border border-green-500/30' : ''}`}>
            <div className={`text-lg font-bold ${weekMinutes >= 150 ? 'text-green-400' : ''}`}>{weekMinutes}</div>
            <div className="text-[10px] text-white/40">min / 150 target</div>
          </div>
          <div className="flex-1 glass rounded-xl p-3 text-center">
            <div className="text-lg font-bold">
              {plan ? Object.keys(plan.slots).length : 0}
            </div>
            <div className="text-[10px] text-white/40">sessions</div>
          </div>
        </div>

        {/* Selected day detail */}
        {selectedDay !== null && (
          <div className="glass rounded-xl p-4">
            <div className="text-xs text-white/40 font-bold tracking-wider uppercase mb-3">
              {format(weekDays[selectedDay], 'EEEE d MMM')}
            </div>
            {SLOTS.map((slot) => {
              const assignment = plan?.slots[`${selectedDay}_${slot}`]
              return (
                <div key={slot} className="flex items-center gap-3 py-2 border-b border-white/5 last:border-0">
                  <span className="text-sm">{TIME_SLOT_META[slot].emoji}</span>
                  <span className="text-[10px] text-white/40 w-14">{TIME_SLOT_META[slot].label}</span>
                  {assignment ? (
                    <div className="flex-1">
                      <div className="text-sm font-medium">
                        {assignment.categoryEmoji} {assignment.sessionTypeName}
                      </div>
                      <div className="text-[10px] text-white/40">
                        {assignment.durationMinutes} min
                        {assignment.estimatedCalories && ` · ~${assignment.estimatedCalories} cal`}
                      </div>
                    </div>
                  ) : (
                    <span className="text-xs text-white/20">—</span>
                  )}
                </div>
              )
            })}
          </div>
        )}

        {/* Categories */}
        <div className="space-y-2">
          <div className="text-[10px] text-white/40 font-bold tracking-wider uppercase">Categories</div>
          {categories.map((cat) => (
            <details key={cat.id} className="glass rounded-xl">
              <summary className="p-3 cursor-pointer flex items-center gap-2">
                <span>{cat.emoji}</span>
                <span className="text-sm font-medium flex-1">{cat.name}</span>
                <span className="text-[10px] text-white/30">{cat.sessionTypes.length} types</span>
              </summary>
              <div className="px-3 pb-3 space-y-1.5">
                {cat.sessionTypes.map((st) => (
                  <div key={st.id} className="flex items-center justify-between py-1.5 border-t border-white/5">
                    <div>
                      <div className="text-sm">{st.name}</div>
                      <div className="text-[10px] text-white/40">{st.description}</div>
                    </div>
                    <div className="text-right shrink-0 ml-2">
                      <div className="text-xs text-white/60">{st.durationMinutes} min</div>
                    </div>
                  </div>
                ))}
              </div>
            </details>
          ))}
        </div>
      </div>

      {showProfile && <ProfileSheet onClose={() => setShowProfile(false)} />}
    </>
  )
}
