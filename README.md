# Klinik Nabız · İlk Yardım Gönüllüleri

Sağlık Bakanlığı onaylı ilk yardım sertifikası olan gönüllülerin yakın çevrelerindeki acil vakalara müdahale etmelerini sağlayan platform.

## Monorepo yapısı

```
ilk_yardim_app/           ← bu dizin (Flutter mobil app)
admin_panel/              ← React dispatcher paneli
firebase/                 ← Firestore rules + Cloud Functions (TypeScript)
legal/                    ← KVKK dokümanları
```

## Mimari

- **Mobil:** Flutter + Provider/Selector + go_router + flutter_map (OSM)
- **Backend:** Firebase (Auth, Firestore, Cloud Functions, FCM, Storage, App Check, Remote Config)
- **Panel:** React + Vite + Tailwind + shadcn/ui + react-leaflet + recharts
- **Dispatcher:** Kendi ekibin; custom claim `role: "dispatcher"`
- **Auth:** Telefon OTP + önceden yüklenmiş `certified_phones` allowlist
- **Lansman:** Türkiye-ready kod, pilot ilçe Kadıköy (Remote Config `enabledDistricts`)

---

## 🚀 Yerel geliştirme (emulator önerilen yol)

En hızlı başlangıç: Firebase Emulator Suite + tek komutluk seed.

### 1. Ön koşullar (tek seferlik)

```bash
# Firebase CLI
npm install -g firebase-tools
firebase login

# Flutter & Node deps
flutter pub get
cd firebase/functions && npm install
cd ../../admin_panel && npm install
```

### 2. Emulator'ü başlat

Repo kökünden:

```bash
firebase emulators:start
```

Bu şunları ayağa kaldırır:
- Auth ........ http://127.0.0.1:9099
- Firestore ... http://127.0.0.1:8080
- Functions ... http://127.0.0.1:5001
- Storage ..... http://127.0.0.1:9199
- Emulator UI . http://127.0.0.1:4000

### 3. Seed'i yükle (başka terminalde)

```bash
cd firebase/functions
npm run seed:emulator
```

Script şunları hazırlar:
- Certified phone: `+905551112233` (dispatcher + gönüllü)
- Certified phone: `+905554445566` (ikinci gönüllü — multi-accept testi için)
- `users/{uid}` + `certified_phones/…` dokümanları
- Kadıköy'de 1 örnek açık vaka
- "Temel Yaşam Desteği" quiz'i (3 soru)

### 4. Mobil app'i emulator'e bağlı çalıştır

```bash
# repo kökünden
flutter run --dart-define=USE_EMULATOR=true
```

Consent ekranı → 3 onay → telefon numarası olarak `+905551112233` gir → Emulator UI'da (`http://127.0.0.1:4000/auth`) gelen SMS kodunu kopyala → giriş.

### 5. Admin panelini emulator'e bağlı çalıştır

`admin_panel/.env.local` oluştur:

```ini
VITE_FB_API_KEY=demo-key
VITE_FB_AUTH_DOMAIN=demo-klinik-nabiz.firebaseapp.com
VITE_FB_PROJECT_ID=demo-klinik-nabiz
VITE_FB_STORAGE_BUCKET=demo-klinik-nabiz.appspot.com
VITE_FB_MESSAGING_SENDER_ID=1234567890
VITE_FB_APP_ID=demo-app-id
VITE_USE_EMULATOR=true
```

(Emulator'de API key ve diğer alanlar doğrulanmıyor — `demo-*` değerleri yeterli.)

```bash
cd admin_panel
npm run dev
```

http://localhost:5173 → `+905551112233` ile giriş yap → dispatcher claim zaten set edildiği için Dashboard açılır. Volunteers tab → diğer kullanıcıya "Dispatcher yap" butonu görünür. Reports tab → 4 KPI kartı + grafikler.

### 6. Test'leri çalıştır

```bash
# Flutter unit testleri (emulator gerekmez)
flutter test

# Backend entegrasyon testleri (Firestore emulator gerekir)
firebase emulators:exec --only firestore \
  "cd firebase/functions && npm test"
```

---

## ☁️ Prod / canlı Firebase'e bağlanmak

### Flutter platform config'lerini üret

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<PROJECT_ID>
```

### Cloud Functions + rules + indexes deploy

```bash
cd firebase/functions && npm install && npm run build
firebase deploy --only firestore:rules,firestore:indexes,functions
```

### İlk dispatcher'ı ata (tavuk-yumurta)

`assignDispatcherRole` callable, arayanın zaten dispatcher olmasını ister. İlk kullanıcıyı bir service account key ile yerel script üzerinden promote et:

```bash
# Firebase Console → Project Settings → Service Accounts → Generate key
# ./service-account.json olarak kaydet (commit ETME)

cd firebase/functions
npm run assign-dispatcher -- <target_uid> /absolute/path/to/service-account.json
```

Sonra o dispatcher admin panel üzerinden başkalarını ekleyebilir (Volunteers → "Dispatcher yap").

### Certified phones listesini yükle

```bash
# Admin panel → Certificates → CSV paste
# veya seed: firebase/seed/certified_phones.example.csv
```

---

## 🎯 Yol haritası

- ✅ Altyapı + mobil scaffold (5 ekran)
- ✅ Admin panel (Dashboard, Emergency, Volunteers, Certificates, Reports)
- ✅ Cloud Functions orkestrasyonu (wave dispatch, multi-accept, 1-saat TTL, close)
- ✅ KVKK dokümanları + in-app markdown viewer
- ✅ Settings (uygunluk, bildirim tercihleri, profil, konum, uygulama bilgisi)
- ✅ Server-authoritative stats + rozet kazanımı
- ✅ Kritik-yol test coverage (AuthProvider + acceptEmergency)
- ⏳ Ürünleştirme (logo varyasyonları, store listing, production App Check)

Detaylı plan: `~/.claude/plans/jiggly-noodling-harp.md`

## Tasarım

"Clinical Pulse" design system — Stitch project `12023846913793716446`. Kurallar:
- **1px border yasak** (tonal layering kullan)
- Primary gradient 135° (`#b7102a` → `#db313f`)
- Inter (Türkçe glyphs için), line-height 1.6
- FAB glassmorphic pulse animasyonlu

## KVKK

- İlk açılışta aydınlatma + açık rıza (bkz. `legal/`)
- Arka plan konum için ayrı gerekçeli dialog
- Hesap silme talebi Settings → "Hesabı sil" (Firestore `account_deletion_requests`)
- VERBİS kaydı + public privacy policy (store onayı gerekliliği)
