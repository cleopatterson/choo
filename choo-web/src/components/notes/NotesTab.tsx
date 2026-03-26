import { useEffect, useState } from 'react'
import { useAuthStore } from '../../stores/auth-store'
import { useNotesStore } from '../../stores/notes-store'
import NavBar from '../layout/NavBar'
import ProfileSheet from '../layout/ProfileSheet'
import NoteEditor from './NoteEditor'
import type { Note } from '../../types/note'

export default function NotesTab() {
  const { familyId, profile } = useAuthStore()
  const { notes, listen, stopListening, deleteNote } = useNotesStore()
  const [showProfile, setShowProfile] = useState(false)
  const [editingNote, setEditingNote] = useState<Note | null>(null)
  const [showEditor, setShowEditor] = useState(false)
  const [deletingId, setDeletingId] = useState<string | null>(null)

  useEffect(() => {
    if (familyId) listen(familyId)
    return () => stopListening()
  }, [familyId])

  const handleDelete = async (note: Note) => {
    if (!familyId || !note.id) return
    setDeletingId(note.id)
    await deleteNote(familyId, note.id)
    setDeletingId(null)
  }

  const formatDate = (date: Date) => {
    return new Intl.DateTimeFormat('en-AU', {
      day: 'numeric',
      month: 'short',
      hour: 'numeric',
      minute: '2-digit',
    }).format(date)
  }

  return (
    <>
      <NavBar
        title="Notes"
        onProfile={() => setShowProfile(true)}
        onAdd={() => { setEditingNote(null); setShowEditor(true) }}
      />

      <div className="p-4 space-y-3">
        {notes.length === 0 && (
          <div className="text-center text-white/30 mt-20">
            <div className="text-4xl mb-3">📝</div>
            <p className="text-sm">No notes yet</p>
            <p className="text-xs text-white/20 mt-1">Tap + to create one</p>
          </div>
        )}

        {notes.map((note) => (
          <div
            key={note.id}
            className="glass rounded-xl p-4 transition-base hover:bg-white/8 cursor-pointer"
            onClick={() => { setEditingNote(note); setShowEditor(true) }}
          >
            <div className="flex items-start justify-between gap-3">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  {note.isList && <span className="text-xs">☑️</span>}
                  <h3 className="text-sm font-semibold truncate">{note.title}</h3>
                </div>
                {note.content && (
                  <p className="text-xs text-white/50 mt-1 line-clamp-2">{note.content}</p>
                )}
                <p className="text-[10px] text-white/30 mt-2">
                  {note.createdBy} · {formatDate(note.updatedAt)}
                </p>
              </div>
              <button
                onClick={(e) => { e.stopPropagation(); handleDelete(note) }}
                disabled={deletingId === note.id}
                className="text-white/20 hover:text-red-400 transition-base text-sm shrink-0 p-1"
              >
                ✕
              </button>
            </div>
          </div>
        ))}
      </div>

      {showEditor && (
        <NoteEditor
          note={editingNote}
          familyId={familyId!}
          displayName={profile?.displayName ?? 'Unknown'}
          onClose={() => setShowEditor(false)}
        />
      )}

      {showProfile && <ProfileSheet onClose={() => setShowProfile(false)} />}
    </>
  )
}
