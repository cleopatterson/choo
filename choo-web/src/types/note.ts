export interface Note {
  id?: string
  familyId: string
  title: string
  content: string
  createdBy: string
  createdAt: Date
  updatedAt: Date
  isList?: boolean
}
