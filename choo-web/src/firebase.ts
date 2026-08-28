import { initializeApp } from 'firebase/app'
import { getAuth } from 'firebase/auth'
import { getFirestore } from 'firebase/firestore'

// `import.meta.env` is only populated by Vite. Outside a Vite build (e.g. the
// design-system preview bundle) it is empty, so fall back to inert placeholders
// that let the modules load without network access.
const env = (import.meta.env ?? {}) as Record<string, string | undefined>

const firebaseConfig = {
  apiKey: env.VITE_FIREBASE_API_KEY ?? 'preview-only-api-key',
  authDomain: env.VITE_FIREBASE_AUTH_DOMAIN ?? 'preview.firebaseapp.com',
  projectId: env.VITE_FIREBASE_PROJECT_ID ?? 'preview',
  storageBucket: env.VITE_FIREBASE_STORAGE_BUCKET ?? 'preview.appspot.com',
  messagingSenderId: env.VITE_FIREBASE_MESSAGING_SENDER_ID ?? '000000000000',
  appId: env.VITE_FIREBASE_APP_ID ?? '1:000000000000:web:0000000000000000000000',
}

const app = initializeApp(firebaseConfig)
export const auth = getAuth(app)
export const db = getFirestore(app)
