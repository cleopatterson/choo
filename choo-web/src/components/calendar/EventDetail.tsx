import { useState } from 'react'
import { format } from 'date-fns'
import { useCalendarStore } from '../../stores/calendar-store'
import { useAuthStore } from '../../stores/auth-store'
import { getUrgencyState, isPaidOn } from '../../types/event'
import type { FamilyEvent } from '../../types/event'
import EventForm from './EventForm'

interface EventDetailProps {
  event: FamilyEvent
  day: Date
  familyId: string
  onClose: () => void
  onDelete: () => void
}

export default function EventDetail({ event, day, familyId, onClose, onDelete }: EventDetailProps) {
  const { profile, user } = useAuthStore()
  const { toggleTodoCompleted, toggleBillPaid } = useCalendarStore()
  const [showEdit, setShowEdit] = useState(false)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)

  const urgency = getUrgencyState(event)
  const paid = isPaidOn(event, day)

  if (showEdit) {
    return (
      <EventForm
        familyId={familyId}
        displayName={profile?.displayName ?? ''}
        userUID={user?.uid ?? ''}
        editEvent={event}
        onClose={() => { setShowEdit(false); onClose() }}
      />
    )
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center" onClick={onClose}>
      <div className="absolute inset-0 bg-black/50" />
      <div
        className="relative glass rounded-t-2xl sm:rounded-2xl w-full max-w-lg p-5 space-y-4"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="w-10 h-1 rounded-full bg-white/20 mx-auto sm:hidden" />

        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex-1">
            <div className="flex items-center gap-2 mb-1">
              {event.todoEmoji && <span className="text-lg">{event.todoEmoji}</span>}
              <h2 className="font-serif font-bold text-lg">{event.title}</h2>
            </div>
            <div className="flex items-center gap-2 flex-wrap">
              {event.isTodo && (
                <span className={`pill ${
                  urgency === 'overdue' ? 'bg-red-500/15 text-red-400' :
                  urgency === 'dueSoon' ? 'bg-amber-500/15 text-amber-400' :
                  urgency === 'done' ? 'bg-green-500/15 text-green-400' :
                  'bg-blue-500/15 text-blue-400'
                }`}>
                  {urgency === 'done' ? 'Done' : urgency === 'overdue' ? 'Overdue' : urgency === 'dueSoon' ? 'Due soon' : 'To-do'}
                </span>
              )}
              {event.isBill && (
                <span className={`pill ${paid ? 'bg-green-500/15 text-green-400' : 'bg-amber-500/15 text-amber-400'}`}>
                  {paid ? 'Paid' : 'Unpaid'}
                </span>
              )}
              {event.recurrenceFrequency && (
                <span className="pill bg-white/6 text-white/50">
                  ↻ {event.recurrenceFrequency}
                </span>
              )}
            </div>
          </div>
          <button onClick={onClose} className="text-white/40 text-lg p-1">✕</button>
        </div>

        {/* Details */}
        <div className="glass rounded-xl p-3.5 space-y-2.5 text-sm">
          <div className="flex items-center gap-2 text-white/70">
            <span className="text-white/30">📅</span>
            {event.isAllDay
              ? format(event.startDate, 'EEE, d MMM yyyy')
              : `${format(event.startDate, 'EEE, d MMM · h:mm a')} – ${format(event.endDate, 'h:mm a')}`
            }
          </div>
          {event.location && (
            <div className="flex items-center gap-2 text-white/70">
              <span className="text-white/30">📍</span>
              {event.location}
            </div>
          )}
          {event.isBill && event.amount && (
            <div className="flex items-center gap-2 text-white/70">
              <span className="text-white/30">💰</span>
              ${event.amount.toFixed(2)}
            </div>
          )}
          {event.note && (
            <div className="text-white/50 text-xs mt-2 pt-2 border-t border-white/8">
              {event.note}
            </div>
          )}
          <div className="text-white/30 text-[10px]">
            Added by {event.createdBy}
          </div>
        </div>

        {/* Actions */}
        <div className="flex gap-2">
          {event.isTodo && (
            <button
              onClick={() => toggleTodoCompleted(familyId, event)}
              className={`flex-1 py-2.5 rounded-xl text-sm font-semibold transition-base
                ${event.isCompleted
                  ? 'bg-white/6 text-white/50'
                  : 'bg-green-500/20 text-green-400 border border-green-500/20'}`}
            >
              {event.isCompleted ? 'Mark Incomplete' : 'Mark Done'}
            </button>
          )}
          {event.isBill && (
            <button
              onClick={() => toggleBillPaid(familyId, event, day)}
              className={`flex-1 py-2.5 rounded-xl text-sm font-semibold transition-base
                ${paid
                  ? 'bg-white/6 text-white/50'
                  : 'bg-green-500/20 text-green-400 border border-green-500/20'}`}
            >
              {paid ? 'Mark Unpaid' : 'Mark Paid'}
            </button>
          )}
          <button
            onClick={() => setShowEdit(true)}
            className="flex-1 py-2.5 rounded-xl bg-white/6 text-white/70 text-sm font-semibold transition-base hover:bg-white/10"
          >
            Edit
          </button>
        </div>

        {/* Delete */}
        {!showDeleteConfirm ? (
          <button
            onClick={() => setShowDeleteConfirm(true)}
            className="w-full text-red-400/60 text-xs text-center py-1"
          >
            Delete event
          </button>
        ) : (
          <div className="flex gap-2">
            <button
              onClick={onDelete}
              className="flex-1 py-2.5 rounded-xl bg-red-500/20 text-red-400 text-sm font-semibold border border-red-500/20"
            >
              Confirm Delete
            </button>
            <button
              onClick={() => setShowDeleteConfirm(false)}
              className="flex-1 py-2.5 rounded-xl bg-white/6 text-white/50 text-sm font-semibold"
            >
              Cancel
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
