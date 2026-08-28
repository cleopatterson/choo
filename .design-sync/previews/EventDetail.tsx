import { EventDetail, useAuthStore } from 'choo-web'

useAuthStore.setState({
  profile: { uid: 'tony-uid', displayName: 'Tony Wall', email: 'tony@wallfamily.com', role: 'parent' },
  user: { uid: 'tony-uid' },
} as any)

function Backdrop({ children }: any) {
  return (
    <div
      className="choo-bg"
      style={{
        width: 560,
        height: 520,
        position: 'relative',
        transform: 'translateZ(0)',
      }}
    >
      {children}
    </div>
  )
}

const swimming: any = {
  id: 'evt-1',
  familyId: 'wall-family',
  title: 'Harriet — swimming lesson',
  startDate: new Date('2026-02-10T16:00:00'),
  endDate: new Date('2026-02-10T16:45:00'),
  createdBy: 'Alex',
  location: 'Ryde Aquatic Centre',
  note: 'Bring the spare goggles.',
}

const bill: any = {
  id: 'evt-2',
  familyId: 'wall-family',
  title: 'Origin electricity',
  startDate: new Date('2026-02-14T09:00:00'),
  endDate: new Date('2026-02-14T09:00:00'),
  createdBy: 'Tony',
  isAllDay: true,
  isBill: true,
  amount: 412.6,
  isPaid: false,
}

const todo: any = {
  id: 'evt-3',
  familyId: 'wall-family',
  title: 'Book the car service',
  todoEmoji: '🚗',
  startDate: new Date('2026-02-02T09:00:00'),
  endDate: new Date('2026-02-09T09:00:00'),
  createdBy: 'Tony',
  isTodo: true,
  isCompleted: false,
}

export const Event = () => (
  <Backdrop>
    <EventDetail event={swimming} day={new Date('2026-02-10T09:00:00')} familyId="wall-family" onClose={() => {}} onDelete={() => {}} />
  </Backdrop>
)

export const Bill = () => (
  <Backdrop>
    <EventDetail event={bill} day={new Date('2026-02-14T09:00:00')} familyId="wall-family" onClose={() => {}} onDelete={() => {}} />
  </Backdrop>
)

export const Todo = () => (
  <Backdrop>
    <EventDetail event={todo} day={new Date('2026-02-05T09:00:00')} familyId="wall-family" onClose={() => {}} onDelete={() => {}} />
  </Backdrop>
)
