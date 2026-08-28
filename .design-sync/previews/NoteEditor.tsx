import { NoteEditor } from 'choo-web'

function Backdrop({ children }: any) {
  return (
    <div
      className="choo-bg"
      style={{
        width: 560,
        height: 640,
        position: 'relative',
        transform: 'translateZ(0)',
      }}
    >
      {children}
    </div>
  )
}

const shoppingNote: any = {
  id: 'note-1',
  familyId: 'wall-family',
  title: 'Beach house packing list',
  content: 'Sunscreen\nBeach towels\nHarriet’s goggles\nPhone chargers\nEsky + ice bricks',
  createdBy: 'Alex',
  createdAt: new Date('2026-01-12T09:00:00'),
  updatedAt: new Date('2026-01-12T09:00:00'),
  isList: true,
}

export const NewNote = () => (
  <Backdrop>
    <NoteEditor note={null} familyId="wall-family" displayName="Tony" onClose={() => {}} />
  </Backdrop>
)

export const EditingAList = () => (
  <Backdrop>
    <NoteEditor note={shoppingNote} familyId="wall-family" displayName="Alex" onClose={() => {}} />
  </Backdrop>
)
