import { initializeApp } from 'firebase/app';
import { getAuth, onIdTokenChanged, type User } from 'firebase/auth';
import {
  initializeFirestore,
  persistentLocalCache,
  persistentMultipleTabManager,
} from 'firebase/firestore';
import { getFunctions } from 'firebase/functions';

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
