import { useState } from 'react'
import { useNotesStore } from '../../stores/notes-store'
import type { Note } from '../../types/note'

interface NoteEditorProps {
  note: Note | null
  familyId: string
  displayName: string
  onClose: () => void
}

export default function NoteEditor({ note, familyId, displayName, onClose }: NoteEditorProps) {
  const { createNote, updateNote } = useNotesStore()
  const [title, setTitle] = useState(note?.title ?? '')
  const [content, setContent] = useState(note?.content ?? '')
  const [isList, setIsList] = useState(note?.isList ?? false)
  const [saving, setSaving] = useState(false)

  const isEditing = !!note?.id
  const canSave = title.trim().length > 0

  const handleSave = async () => {
    if (!canSave) return
    setSaving(true)
    if (isEditing) {
      await updateNote(familyId, note!.id!, title.trim(), content)
    } else {
      await createNote(familyId, title.trim(), content, displayName, isList)
    }
    setSaving(false)
    onClose()
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center" onClick={onClose}>
      <div className="absolute inset-0 bg-black/50" />
      <div
        className="relative glass rounded-t-2xl sm:rounded-2xl w-full max-w-lg p-5 space-y-4 max-h-[85vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="w-10 h-1 rounded-full bg-white/20 mx-auto sm:hidden" />

        <div className="flex items-center justify-between">
          <button onClick={onClose} className="text-white/50 text-sm">Cancel</button>
          <h2 className="font-serif font-semibold text-sm">
            {isEditing ? 'Edit Note' : 'New Note'}
          </h2>
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

        <textarea
          placeholder="Write something..."
          value={content}
          onChange={(e) => setContent(e.target.value)}
          className="glass-field min-h-[200px] resize-none text-sm"
          rows={8}
        />

        {!isEditing && (
          <label className="flex items-center gap-3 text-sm text-white/60">
            <input
              type="checkbox"
              checked={isList}
              onChange={(e) => setIsList(e.target.checked)}
              className="accent-choo-purple"
            />
            Checklist mode
          </label>
        )}
      </div>
    </div>
  )
}
