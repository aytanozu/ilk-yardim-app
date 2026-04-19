import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from 'react';
import { onDispatcherChanged, type DispatcherUser } from '../lib/firebase';

interface AuthState {
  user: DispatcherUser | null;
  loading: boolean;
}

const Ctx = createContext<AuthState>({ user: null, loading: true });

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({ user: null, loading: true });

  useEffect(() => {
    return onDispatcherChanged((u) => setState({ user: u, loading: false }));
  }, []);

  return <Ctx.Provider value={state}>{children}</Ctx.Provider>;
}

export const useAuth = () => useContext(Ctx);
