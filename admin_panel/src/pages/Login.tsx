import { useState } from 'react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { useNavigate } from 'react-router-dom';
import { auth } from '../lib/firebase';

export function Login() {
  const [email, setEmail] = useState('');
  const [pw, setPw] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const nav = useNavigate();

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErr(null);
    setLoading(true);
    try {
      const cred = await signInWithEmailAndPassword(auth, email, pw);
      const token = await cred.user.getIdTokenResult();
      if (token.claims.role !== 'dispatcher') {
        setErr('Bu hesabın operatör yetkisi yok.');
        await auth.signOut();
        return;
      }
      nav('/');
    } catch (error) {
      setErr('Giriş başarısız. Bilgileri kontrol edin.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-8 bg-surface">
      <div className="card w-full max-w-sm p-8">
        <div className="text-xs tracking-[0.3em] text-primary font-bold">
          KLİNİK NABIZ
        </div>
        <h1 className="text-2xl font-bold mt-1 mb-6">Operatör Girişi</h1>
        <form onSubmit={submit} className="space-y-4">
          <div>
            <label className="label-field">E-posta</label>
            <input
              className="input-field"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>
          <div>
            <label className="label-field">Şifre</label>
            <input
              className="input-field"
              type="password"
              value={pw}
              onChange={(e) => setPw(e.target.value)}
              required
            />
          </div>
          {err && <div className="text-error text-sm">{err}</div>}
          <button
            type="submit"
            className="btn-primary w-full"
            disabled={loading}
          >
            {loading ? 'Giriş Yapılıyor…' : 'Giriş Yap'}
          </button>
        </form>
        <p className="text-xs text-onsurface-variant mt-6 leading-relaxed">
          Sadece operatör rolü atanmış hesaplar panele erişebilir. Destek için
          sistem yöneticinize başvurun.
        </p>
      </div>
    </div>
  );
}
