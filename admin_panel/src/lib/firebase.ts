import { initializeApp } from 'firebase/app';
import {
  connectAuthEmulator,
  getAuth,
  onIdTokenChanged,
  type User,
} from 'firebase/auth';
import {
  connectFirestoreEmulator,
  initializeFirestore,
  persistentLocalCache,
  persistentMultipleTabManager,
} from 'firebase/firestore';
import {
  connectFunctionsEmulator,
  getFunctions,
} from 'firebase/functions';

// Replace with real values in `.env.local`:
// VITE_FB_API_KEY, VITE_FB_AUTH_DOMAIN, VITE_FB_PROJECT_ID,
// VITE_FB_STORAGE_BUCKET, VITE_FB_MESSAGING_SENDER_ID, VITE_FB_APP_ID
const config = {
  apiKey: import.meta.env.VITE_FB_API_KEY ?? 'REPLACE_ME',
  authDomain: import.meta.env.VITE_FB_AUTH_DOMAIN ?? 'REPLACE_ME',
  projectId: import.meta.env.VITE_FB_PROJECT_ID ?? 'REPLACE_ME',
  storageBucket: import.meta.env.VITE_FB_STORAGE_BUCKET ?? 'REPLACE_ME',
  messagingSenderId:
    import.meta.env.VITE_FB_MESSAGING_SENDER_ID ?? 'REPLACE_ME',
  appId: import.meta.env.VITE_FB_APP_ID ?? 'REPLACE_ME',
};

export const app = initializeApp(config);

export const db = initializeFirestore(app, {
  localCache: persistentLocalCache({
    tabManager: persistentMultipleTabManager(),
  }),
});

export const auth = getAuth(app);
export const functions = getFunctions(app, 'europe-west3');

// Emulator wiring: set VITE_USE_EMULATOR=true in `.env.local` (or pass
// via `VITE_USE_EMULATOR=true npm run dev`). Safe to call at module
// load because Firebase SDKs treat idempotent connect* calls as no-ops
// if the same host/port is already set.
const USE_EMULATOR = import.meta.env.VITE_USE_EMULATOR === 'true';
if (USE_EMULATOR) {
  const host = '127.0.0.1';
  // eslint-disable-next-line no-console
  console.info('[emulator] wiring admin panel to Firebase emulator suite');
  connectFirestoreEmulator(db, host, 8080);
  connectAuthEmulator(auth, `http://${host}:9099`, {
    disableWarnings: true,
  });
  connectFunctionsEmulator(functions, host, 5001);
}

export type DispatcherUser = User & { dispatcher: true };

export function onDispatcherChanged(
  cb: (user: DispatcherUser | null) => void,
) {
  return onIdTokenChanged(auth, async (u) => {
    if (!u) return cb(null);
    const token = await u.getIdTokenResult();
    if (token.claims.role === 'dispatcher') {
      cb(Object.assign(u, { dispatcher: true as const }));
    } else {
      cb(null);
    }
  });
}
