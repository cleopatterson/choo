import { initializeApp } from 'firebase/app'
import { getAuth } from 'firebase/auth'
import { initializeFirestore, persistentLocalCache } from 'firebase/firestore'

// `import.meta.env` is only populated by Vite. Outside a Vite build (e.g. the
// design-system preview bundle) it is empty, so fall back to inert placeholders
// that let the modules load without network access. The fallback is all-or-
// nothing: a real build with a missing/misnamed env var must still fail loudly
// at init rather than silently boot against a fake project.
const env = (import.meta.env ?? {}) as Record<string, string | undefined>
const isPreviewBundle = !env.VITE_FIREBASE_API_KEY && !env.VITE_FIREBASE_PROJECT_ID

const firebaseConfig = isPreviewBundle
  ? {
      apiKey: 'preview-only-api-key',
      authDomain: 'preview.firebaseapp.com',
      projectId: 'preview',
      storageBucket: 'preview.appspot.com',
      messagingSenderId: '000000000000',
      appId: '1:000000000000:web:0000000000000000000000',
    }
  : {
      apiKey: env.VITE_FIREBASE_API_KEY,
      authDomain: env.VITE_FIREBASE_AUTH_DOMAIN,
      projectId: env.VITE_FIREBASE_PROJECT_ID,
      storageBucket: env.VITE_FIREBASE_STORAGE_BUCKET,
      messagingSenderId: env.VITE_FIREBASE_MESSAGING_SENDER_ID,
      appId: env.VITE_FIREBASE_APP_ID,
    }

const app = initializeApp(firebaseConfig)
export const auth = getAuth(app)
// IndexedDB persistence: snapshots render instantly from disk on reload,
// then refresh live — no loading state while the network catches up.
export const db = initializeFirestore(app, { localCache: persistentLocalCache() })
