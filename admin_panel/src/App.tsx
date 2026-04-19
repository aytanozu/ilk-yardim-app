import { Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import { Shell } from './components/Shell';
import { Login } from './pages/Login';
import { Dashboard } from './pages/Dashboard';
import { NewEmergency } from './pages/NewEmergency';
import { Volunteers } from './pages/Volunteers';
import { Certificates } from './pages/Certificates';
import { Reports } from './pages/Reports';

function Protected({ children }: { children: React.ReactElement }) {
  const { user, loading } = useAuth();
  if (loading) return <SplashLoading />;
  if (!user) return <Navigate to="/login" replace />;
  return children;
}

function SplashLoading() {
  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="text-sm text-onsurface-variant tracking-widest">
        KLİNİK NABIZ · YÜKLENİYOR…
      </div>
    </div>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route
          element={
            <Protected>
              <Shell />
            </Protected>
          }
        >
          <Route index element={<Dashboard />} />
          <Route path="new" element={<NewEmergency />} />
          <Route path="volunteers" element={<Volunteers />} />
          <Route path="certificates" element={<Certificates />} />
          <Route path="reports" element={<Reports />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AuthProvider>
  );
}
