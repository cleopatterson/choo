import { ProfileSheet, useAuthStore } from 'choo-web'

useAuthStore.setState({
  profile: {
    uid: 'tony-uid',
    displayName: 'Tony Wall',
    email: 'tony@wallfamily.com',
    role: 'parent',
  },
} as any)

function Backdrop({ children }: any) {
  return (
    <div
      className="choo-bg"
      style={{
        width: 440,
        height: 520,
        position: 'relative',
        transform: 'translateZ(0)',
      }}
    >
      {children}
    </div>
  )
}

export const Default = () => (
  <Backdrop>
    <ProfileSheet onClose={() => {}} />
  </Backdrop>
)
