import { NavBar } from 'choo-web'

function Bg({ children }: any) {
  return <div className="choo-bg">{children}</div>
}

export const Default = () => (
  <Bg>
    <NavBar title="Calendar" onAdd={() => {}} onProfile={() => {}} />
  </Bg>
)

export const WithoutAddAction = () => (
  <Bg>
    <NavBar title="Account" onProfile={() => {}} />
  </Bg>
)

export const AcrossTabs = () => (
  <Bg>
    <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
      <NavBar title="Calendar" onAdd={() => {}} onProfile={() => {}} />
      <NavBar title="Shopping" onAdd={() => {}} onProfile={() => {}} />
      <NavBar title="Exercise" onAdd={() => {}} onProfile={() => {}} />
      <NavBar title="House" onAdd={() => {}} onProfile={() => {}} />
      <NavBar title="Notes" onAdd={() => {}} onProfile={() => {}} />
    </div>
  </Bg>
)
