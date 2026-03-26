import { Outlet } from 'react-router-dom'
import TabBar from './TabBar'

export default function AppShell() {
  return (
    <div className="choo-bg flex flex-col h-screen">
      <div className="flex-1 overflow-y-auto">
        <Outlet />
      </div>
      <TabBar />
    </div>
  )
}
