import { useState } from 'react'
import { format } from 'date-fns'
import { useCalendarStore } from '../../stores/calendar-store'
import type { RecurrenceFrequency } from '../../types/event'

interface EventFormProps {
  familyId: string
  displayName: string
  userUID: string
  onClose: () => void
  editEvent?: import('../../types/event').FamilyEvent
}

export default function EventForm({ familyId, displayName, userUID, onClose, editEvent }: EventFormProps) {
  const { createEvent, updateEvent } = useCalendarStore()
  const [title, setTitle] = useState(editEvent?.title ?? '')
  const [startDate, setStartDate] = useState(format(editEvent?.startDate ?? new Date(), "yyyy-MM-dd'T'HH:mm"))
  const [endDate, setEndDate] = useState(format(editEvent?.endDate ?? new Date(), "yyyy-MM-dd'T'HH:mm"))
  const [isAllDay, setIsAllDay] = useState(editEvent?.isAllDay ?? false)
  const [location, setLocation] = useState(editEvent?.location ?? '')
  const [isBill, setIsBill] = useState(editEvent?.isBill ?? false)
  const [amount, setAmount] = useState(editEvent?.amount?.toString() ?? '')
  const [isTodo, setIsTodo] = useState(editEvent?.isTodo ?? false)
  const [recurrence, setRecurrence] = useState<RecurrenceFrequency | ''>(
    (editEvent?.recurrenceFrequency as RecurrenceFrequency) ?? ''
  )
  const [note, setNote] = useState(editEvent?.note ?? '')
  const [saving, setSaving] = useState(false)

  const isEditing = !!editEvent?.id
  const canSave = title.trim().length > 0

  const handleSave = async () => {
    if (!canSave) return
    setSaving(true)

    const start = new Date(startDate)
    const end = new Date(endDate)

    if (isEditing && editEvent) {
      await updateEvent(familyId, {
        ...editEvent,
        title: title.trim(),
        startDate: start,
        endDate: end,
        isAllDay: isAllDay || undefined,
        location: location || undefined,
        isBill: isBill || undefined,
        amount: isBill && amount ? parseFloat(amount) : undefined,
        isTodo: isTodo || undefined,
        recurrenceFrequency: recurrence || undefined,
        note: note || undefined,
        lastModifiedByUID: userUID,
      })
    } else {
      await createEvent(familyId, {
        familyId,
        title: title.trim(),
        startDate: start,
        endDate: end,
        createdBy: displayName,
        isAllDay: isAllDay || undefined,
        location: location || undefined,
        isBill: isBill || undefined,
        amount: isBill && amount ? parseFloat(amount) : undefined,
        isTodo: isTodo || undefined,
        recurrenceFrequency: recurrence || undefined,
        note: note || undefined,
        lastModifiedByUID: userUID,
      })
    }
    setSaving(false)
    onClose()
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center" onClick={onClose}>
      <div className="absolute inset-0 bg-black/50" />
      <div
        className="relative glass rounded-t-2xl sm:rounded-2xl w-full max-w-lg p-5 space-y-4 max-h-[90vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="w-10 h-1 rounded-full bg-white/20 mx-auto sm:hidden" />

        <div className="flex items-center justify-between">
          <button onClick={onClose} className="text-white/50 text-sm">Cancel</button>
          <h2 className="font-serif font-semibold text-sm">{isEditing ? 'Edit Event' : 'New Event'}</h2>
          <button
            onClick={handleSave}
            disabled={!canSave || saving}
            className="text-choo-purple font-semibold text-sm disabled:opacity-40"
          >
            {saving ? 'Saving...' : 'Save'}
          </button>
        </div>

        <input
          type="text"
          placeholder="Title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          className="glass-field text-lg font-semibold"
          autoFocus
        />

        {/* Type toggles */}
        <div className="flex gap-2">
          <button
            onClick={() => { setIsTodo(false); setIsBill(false) }}
            className={`pill transition-base ${!isTodo && !isBill ? 'bg-choo-purple/20 text-choo-purple' : 'bg-white/6 text-white/40'}`}
          >
            Event
          </button>
          <button
            onClick={() => { setIsTodo(true); setIsBill(false) }}
            className={`pill transition-base ${isTodo ? 'bg-choo-purple/20 text-choo-purple' : 'bg-white/6 text-white/40'}`}
          >
            To-do
          </button>
          <button
            onClick={() => { setIsBill(true); setIsTodo(false) }}
            className={`pill transition-base ${isBill ? 'bg-choo-purple/20 text-choo-purple' : 'bg-white/6 text-white/40'}`}
          >
            Bill
          </button>
        </div>

        {/* Dates */}
        <div className="space-y-3">
          <label className="flex items-center gap-3 text-sm text-white/60">
            <input type="checkbox" checked={isAllDay} onChange={(e) => setIsAllDay(e.target.checked)} className="accent-choo-purple" />
            All day
          </label>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-[10px] text-white/40 mb-1 block">Start</label>
              <input
                type={isAllDay ? 'date' : 'datetime-local'}
                value={isAllDay ? startDate.slice(0, 10) : startDate}
                onChange={(e) => setStartDate(isAllDay ? e.target.value + 'T00:00' : e.target.value)}
                className="glass-field text-sm"
              />
            </div>
            <div>
              <label className="text-[10px] text-white/40 mb-1 block">End</label>
              <input
                type={isAllDay ? 'date' : 'datetime-local'}
                value={isAllDay ? endDate.slice(0, 10) : endDate}
                onChange={(e) => setEndDate(isAllDay ? e.target.value + 'T23:59' : e.target.value)}
                className="glass-field text-sm"
              />
            </div>
          </div>
        </div>

        <input
          type="text"
          placeholder="Location (optional)"
          value={location}
          onChange={(e) => setLocation(e.target.value)}
          className="glass-field text-sm"
        />

        {isBill && (
          <input
            type="number"
            placeholder="Amount ($)"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className="glass-field text-sm"
            step="0.01"
          />
        )}

        {/* Recurrence */}
        <div>
          <label className="text-[10px] text-white/40 mb-1 block">Repeat</label>
          <select
            value={recurrence}
            onChange={(e) => setRecurrence(e.target.value as RecurrenceFrequency | '')}
            className="glass-field text-sm"
          >
            <option value="">None</option>
            <option value="daily">Daily</option>
            <option value="weekly">Weekly</option>
            <option value="fortnightly">Fortnightly</option>
            <option value="monthly">Monthly</option>
            <option value="yearly">Yearly</option>
          </select>
        </div>

        <textarea
          placeholder="Note (optional)"
          value={note}
          onChange={(e) => setNote(e.target.value)}
          className="glass-field text-sm min-h-[60px] resize-none"
          rows={2}
        />
      </div>
    </div>
  )
}
