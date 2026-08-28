import { EventForm } from 'choo-web'

function Backdrop({ children }: any) {
  return (
    <div
      className="choo-bg"
      style={{
        width: 560,
        height: 700,
        position: 'relative',
        transform: 'translateZ(0)',
      }}
    >
      {children}
    </div>
  )
}

const electricityBill: any = {
  id: 'evt-bill',
  familyId: 'wall-family',
  title: 'Origin electricity',
  startDate: new Date('2026-02-14T09:00:00'),
  endDate: new Date('2026-02-14T09:00:00'),
  createdBy: 'Tony',
  isAllDay: true,
  isBill: true,
  amount: 412.6,
  recurrenceFrequency: 'monthly',
  note: 'Direct debit from the joint account.',
}

export const NewEvent = () => (
  <Backdrop>
    <EventForm familyId="wall-family" displayName="Tony" userUID="tony-uid" onClose={() => {}} />
  </Backdrop>
)

export const EditingABill = () => (
  <Backdrop>
    <EventForm
      familyId="wall-family"
      displayName="Tony"
      userUID="tony-uid"
      editEvent={electricityBill}
      onClose={() => {}}
    />
  </Backdrop>
)
