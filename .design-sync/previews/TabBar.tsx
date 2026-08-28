import { TabBar, MemoryRouter } from 'choo-web'

function Phone({ route, children }: any) {
  return (
    <MemoryRouter initialEntries={[route]}>
      <div className="choo-bg" style={{ height: 160, display: "flex", flexDirection: "column", justifyContent: "flex-end" }}>
        {children}
      </div>
    </MemoryRouter>
  )
}

export const CalendarActive = () => (
  <Phone route="/calendar">
    <TabBar />
  </Phone>
)

export const ShoppingActive = () => (
  <Phone route="/shopping">
    <TabBar />
  </Phone>
)

export const NotesActive = () => (
  <Phone route="/notes">
    <TabBar />
  </Phone>
)
