export type UserRole = 'admin' | 'member'

export interface UserProfile {
  id?: string
  email: string
  displayName: string
  familyId: string | null
  role: UserRole
}

export interface Family {
  id?: string
  name: string
  adminUID: string
  memberUIDs: string[]
  inviteCode: string
  inviteCodeExpiresAt: Date
}

export interface FamilyMember {
  id?: string
  familyId: string
  displayName: string
  type: 'person' | 'pet'
  addedBy: string
  emoji?: string
}
