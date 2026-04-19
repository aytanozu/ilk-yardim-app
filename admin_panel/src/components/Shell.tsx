import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { signOut } from 'firebase/auth';
import { auth } from '../lib/firebase';
import { useAuth } from '../context/AuthContext';

export function Shell() {
  const { user } = useAuth();
  const nav = useNavigate();

  const handleSignOut = async () => {
    await signOut(auth);
    nav('/login');
  };

  return (
    <div className="min-h-screen grid grid-cols-[220px_1fr]">
      <aside className="bg-surface-lowest shadow-ambient flex flex-col">
        <div className="p-5 border-b border-transparent">
          <div className="text-xs tracking-[0.3em] text-primary font-bold">
            KLİNİK NABIZ
          </div>
          <div className="text-sm text-onsurface-variant tracking-wide">
            Operatör Paneli
          </div>
        </div>

        <nav className="flex-1 p-3 space-y-1">
          {[
            { to: '/', label: 'Gösterge Paneli', icon: '⌂' },
            { to: '/new', label: 'Yeni Çağrı', icon: '+' },
            { to: '/volunteers', label: 'Gönüllüler', icon: '◉' },
            { to: '/certificates', label: 'Sertifikalar', icon: '✓' },
            { to: '/registrations', label: 'Başvurular', icon: '☑' },
            { to: '/aeds', label: 'AED Kayıtları', icon: '⚕' },
            { to: '/reports', label: 'Raporlar', icon: '≡' },
            { to: '/audit', label: 'Denetim Kaydı', icon: '⎙' },
          ].map((i) => (
            <NavLink
              key={i.to}
              to={i.to}
              end={i.to === '/'}
              className={({ isActive }) =>
                `flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm
                 ${isActive
                   ? 'bg-primary-fixed text-primary font-semibold'
                   : 'text-onsurface hover:bg-surface-low'}`
              }
            >
              <span className="w-5 text-center">{i.icon}</span>
              {i.label}
            </NavLink>
          ))}
        </nav>

        <div className="p-4 text-xs text-onsurface-variant border-t border-transparent">
          <div className="mb-2 truncate">{user?.email ?? ''}</div>
          <button onClick={handleSignOut} className="btn-ghost w-full justify-start">
            Çıkış yap
          </button>
        </div>
      </aside>

      <main className="overflow-hidden">
        <Outlet />
      </main>
    </div>
  );
}
