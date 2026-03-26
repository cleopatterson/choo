import { useEffect, useState, useMemo } from 'react'
import { startOfWeek } from 'date-fns'
import { useAuthStore } from '../../stores/auth-store'
import { useShoppingStore } from '../../stores/shopping-store'
import { getSupplyStatus, SUPPLY_CATEGORY_META, type SupplyItem, type SupplyCategory } from '../../types/shopping'
import NavBar from '../layout/NavBar'
import ProfileSheet from '../layout/ProfileSheet'

const DAY_LABELS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

export default function ShoppingTab() {
  const { familyId, profile } = useAuthStore()
  const store = useShoppingStore()
  const { listen, stopListening, defaultListId, addItem, toggleItem, deleteItem, clearChecked, listenToMealPlan } = store
  const items = store.sortedItems()
  const { mealPlan, supplies } = store

  const [showProfile, setShowProfile] = useState(false)
  const [newItemName, setNewItemName] = useState('')
  const [showSupplies, setShowSupplies] = useState(false)

  const weekStart = useMemo(() => startOfWeek(new Date(), { weekStartsOn: 1 }), [])

  useEffect(() => {
    if (familyId) {
      listen(familyId)
      listenToMealPlan(familyId, weekStart)
    }
    return () => stopListening()
  }, [familyId])

  const handleAddItem = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!familyId || !defaultListId || !newItemName.trim()) return
    await addItem(familyId, defaultListId, newItemName, profile?.displayName ?? '')
    setNewItemName('')
  }

  const unchecked = items.filter((i) => !i.isChecked && !i.isHeading)
  const checked = items.filter((i) => i.isChecked)

  // Group supplies by category
  const suppliesByCategory = useMemo(() => {
    const groups: Record<string, SupplyItem[]> = {}
    for (const s of supplies) {
      if (!groups[s.category]) groups[s.category] = []
      groups[s.category].push(s)
    }
    return groups
  }, [supplies])

  return (
    <>
      <NavBar title="Shopping" onProfile={() => setShowProfile(true)} />

      <div className="p-4 space-y-4">
        {/* Dinner strip */}
        {mealPlan && (
          <div className="glass rounded-2xl p-3">
            <div className="text-[10px] text-white/40 font-bold tracking-wider uppercase mb-2">
              This week's dinners
            </div>
            <div className="flex gap-1.5 overflow-x-auto">
              {DAY_LABELS.map((label, i) => {
                const assignment = mealPlan.assignments[String(i)]
                return (
                  <div key={i} className="flex-1 min-w-[50px] text-center">
                    <div className="text-[9px] text-white/30 mb-1">{label}</div>
                    <div className="text-lg">{assignment?.recipeIcon ?? '·'}</div>
                    <div className="text-[9px] text-white/50 truncate mt-0.5">
                      {assignment?.recipeName ?? ''}
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        )}

        {/* Add item */}
        <form onSubmit={handleAddItem} className="flex gap-2">
          <input
            type="text"
            placeholder="Add item (ALL CAPS = heading)"
            value={newItemName}
            onChange={(e) => setNewItemName(e.target.value)}
            className="glass-field flex-1 text-sm"
          />
          <button
            type="submit"
            disabled={!newItemName.trim()}
            className="px-4 rounded-xl bg-choo-purple font-semibold text-sm disabled:opacity-40"
          >
            +
          </button>
        </form>

        {/* Shopping items */}
        <div className="space-y-1">
          {items.map((item) => {
            if (item.isHeading) {
              return (
                <div key={item.id} className="pt-3 pb-1">
                  <div className="text-[10px] text-white/40 font-bold tracking-wider uppercase">
                    {item.name}
                  </div>
                </div>
              )
            }
            return (
              <div
                key={item.id}
                className={`glass rounded-xl px-3.5 py-2.5 flex items-center gap-3 transition-base
                  ${item.isChecked ? 'opacity-40' : ''}`}
              >
                <button
                  onClick={() => familyId && defaultListId && item.id && toggleItem(familyId, defaultListId, item.id, !item.isChecked)}
                  className={`w-5 h-5 rounded-md border-2 flex items-center justify-center shrink-0 transition-base
                    ${item.isChecked ? 'bg-green-500/20 border-green-500' : 'border-white/20'}`}
                >
                  {item.isChecked && <span className="text-green-400 text-xs">✓</span>}
                </button>
                <span className={`text-sm flex-1 ${item.isChecked ? 'line-through text-white/40' : ''}`}>
                  {item.name}
                </span>
                {item.cadenceTag && (
                  <span className="pill bg-choo-amber/15 text-choo-amber">{item.cadenceTag}</span>
                )}
                <button
                  onClick={() => familyId && defaultListId && item.id && deleteItem(familyId, defaultListId, item.id)}
                  className="text-white/20 hover:text-red-400 transition-base text-sm p-1"
                >
                  ✕
                </button>
              </div>
            )
          })}
        </div>

        {/* Stats + clear */}
        {checked.length > 0 && (
          <div className="flex items-center justify-between">
            <span className="text-xs text-white/40">
              {unchecked.length} remaining · {checked.length} done
            </span>
            <button
              onClick={() => familyId && defaultListId && clearChecked(familyId, defaultListId)}
              className="text-xs text-choo-purple font-medium"
            >
              Clear done items
            </button>
          </div>
        )}

        {/* Supplies toggle */}
        <button
          onClick={() => setShowSupplies(!showSupplies)}
          className="w-full glass rounded-xl p-3 flex items-center justify-between"
        >
          <span className="text-sm font-medium">Supplies</span>
          <span className="text-white/40 text-xs">
            {supplies.filter((s) => getSupplyStatus(s) !== 'ok').length} due · {showSupplies ? '▲' : '▼'}
          </span>
        </button>

        {/* Supplies section */}
        {showSupplies && (
          <div className="space-y-3">
            {(Object.keys(SUPPLY_CATEGORY_META) as SupplyCategory[]).map((cat) => {
              const catSupplies = suppliesByCategory[cat]
              if (!catSupplies?.length) return null
              return (
                <div key={cat} className="glass rounded-xl p-3">
                  <div className="text-[10px] text-white/40 font-bold tracking-wider uppercase mb-2">
                    {SUPPLY_CATEGORY_META[cat].emoji} {SUPPLY_CATEGORY_META[cat].name}
                  </div>
                  <div className="space-y-1.5">
                    {catSupplies.map((supply) => {
                      const status = getSupplyStatus(supply)
                      return (
                        <div key={supply.id} className="flex items-center gap-2 text-sm">
                          <span>{supply.emoji ?? '•'}</span>
                          <span className="flex-1">{supply.name}</span>
                          <span className={`pill ${
                            status === 'low' ? 'bg-red-500/15 text-red-400' :
                            status === 'due' ? 'bg-amber-500/15 text-amber-400' :
                            'bg-green-500/15 text-green-400'
                          }`}>
                            {status === 'ok' ? 'OK' : status === 'due' ? 'Due' : 'Low'}
                          </span>
                        </div>
                      )
                    })}
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>

      {showProfile && <ProfileSheet onClose={() => setShowProfile(false)} />}
    </>
  )
}
