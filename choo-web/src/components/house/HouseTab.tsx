import { useEffect, useState } from 'react'
import { useAuthStore } from '../../stores/auth-store'
import { useHouseStore } from '../../stores/house-store'
import { isChoredue, isChoreOverdue, CHORE_FREQUENCY_META, type ChoreType } from '../../types/chore'
import NavBar from '../layout/NavBar'
import ProfileSheet from '../layout/ProfileSheet'

export default function HouseTab() {
  const { familyId, profile } = useAuthStore()
  const { categories, completions, listen, stopListening, markDone } = useHouseStore()
  const [showProfile, setShowProfile] = useState(false)
  const [markingDone, setMarkingDone] = useState<string | null>(null)

  useEffect(() => {
    if (familyId) listen(familyId)
    return () => stopListening()
  }, [familyId])

  const handleMarkDone = async (chore: ChoreType, categoryName: string) => {
    if (!familyId) return
    setMarkingDone(chore.id)
    await markDone(familyId, chore.id, chore.name, categoryName, profile?.displayName ?? '')
    setMarkingDone(null)
  }

  // Stats
  const allChores = categories.flatMap((c) => c.choreTypes)
  const dueCount = allChores.filter((ch) => isChoredue(ch, completions)).length
  const overdueCount = allChores.filter((ch) => isChoreOverdue(ch, completions)).length

  return (
    <>
      <NavBar title="House" onProfile={() => setShowProfile(true)} />

      <div className="p-4 space-y-4">
        {/* Stats bar */}
        <div className="flex gap-2">
          <div className="flex-1 glass rounded-xl p-3 text-center">
            <div className="text-lg font-bold">{dueCount}</div>
            <div className="text-[10px] text-white/40">Due</div>
          </div>
          <div className={`flex-1 glass rounded-xl p-3 text-center ${overdueCount > 0 ? 'border border-red-500/30' : ''}`}>
            <div className={`text-lg font-bold ${overdueCount > 0 ? 'text-red-400' : ''}`}>{overdueCount}</div>
            <div className="text-[10px] text-white/40">Overdue</div>
          </div>
          <div className="flex-1 glass rounded-xl p-3 text-center">
            <div className="text-lg font-bold">{allChores.length}</div>
            <div className="text-[10px] text-white/40">Total</div>
          </div>
        </div>

        {/* Categories with chores */}
        {categories.map((cat) => (
          <details key={cat.id} className="glass rounded-xl" open>
            <summary className="p-3 cursor-pointer flex items-center gap-2">
              <span>{cat.emoji}</span>
              <span className="text-sm font-medium flex-1">{cat.name}</span>
              <span className="text-[10px] text-white/30">
                {cat.choreTypes.filter((ch) => isChoredue(ch, completions)).length} due
              </span>
            </summary>
            <div className="px-3 pb-3 space-y-1">
              {cat.choreTypes.map((chore) => {
                const due = isChoredue(chore, completions)
                const overdue = isChoreOverdue(chore, completions)
                const freq = chore.frequency ?? 'weekly'
                const lastCompletion = completions
                  .filter((c) => c.choreTypeId === chore.id)
                  .sort((a, b) => b.completedDate.getTime() - a.completedDate.getTime())[0]

                return (
                  <div
                    key={chore.id}
                    className="flex items-center gap-3 py-2 border-t border-white/5"
                  >
                    {/* Status dot */}
                    <div className={`w-2 h-2 rounded-full shrink-0 ${
                      overdue ? 'bg-red-400' : due ? 'bg-amber-400' : 'bg-green-400'
                    }`} />

                    {/* Name + info */}
                    <div className="flex-1 min-w-0">
                      <div className="text-sm">{chore.name}</div>
                      <div className="text-[10px] text-white/30">
                        {CHORE_FREQUENCY_META[freq].name}
                        {lastCompletion && ` · Last: ${lastCompletion.completedBy}`}
                      </div>
                    </div>

                    {/* Status pill */}
                    {(due || overdue) && (
                      <span className={`pill ${overdue ? 'bg-red-500/15 text-red-400' : 'bg-amber-500/15 text-amber-400'}`}>
                        {overdue ? 'Overdue' : 'Due'}
                      </span>
                    )}

                    {/* Mark done button */}
                    <button
                      onClick={() => handleMarkDone(chore, cat.name)}
                      disabled={markingDone === chore.id}
                      className="text-[10px] text-choo-rose font-medium px-2 py-1 rounded-lg
                                 hover:bg-choo-rose/10 transition-base disabled:opacity-40"
                    >
                      {markingDone === chore.id ? '...' : 'Done'}
                    </button>
                  </div>
                )
              })}
            </div>
          </details>
        ))}

        {categories.length === 0 && (
          <div className="text-center text-white/30 mt-10">
            <div className="text-4xl mb-3">✅</div>
            <p className="text-sm">No chores set up yet</p>
            <p className="text-xs text-white/20 mt-1">Add categories in the iOS app</p>
          </div>
        )}
      </div>

      {showProfile && <ProfileSheet onClose={() => setShowProfile(false)} />}
    </>
  )
}
