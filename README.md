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
- **Panel:** React + Vite + Tailwind + shadcn/ui + react-leaflet
- **Dispatcher:** Kendi ekibin; custom claim `role: "dispatcher"`
- **Auth:** Telefon OTP + önceden yüklenmiş `certified_phones` allowlist
- **Lansman:** Türkiye-ready kod, pilot ilçe Kadıköy (Remote Config `enabledDistricts`)

## İlk kurulum

### 1. Flutter

```bash
flutter pub get
```

### 2. Firebase projesi

Kendi projeni oluştur, sonra:

```bash
# Flutter platformları için firebase_options.dart üretir
dart pub global activate flutterfire_cli
flutterfire configure --project=<PROJECT_ID>

# Cloud Functions
cd firebase/functions && npm install && npm run build
firebase deploy --only firestore:rules,firestore:indexes,functions
```

### 3. Sertifikalı telefon listesi

Test için en az 1 kayıt ekle (emülatör veya live):

```js
// Firestore console → certified_phones → +905XXXXXXXXX
{
  fullName: "Ahmet Test",
  certificateType: "İleri İlkyardım Sertifikası",
  issuer: "Sağlık Bakanlığı Onaylı",
  expiresAt: Timestamp(2027, 1, 1),
  region: { country: "TR", city: "istanbul", district: "kadikoy" },
  roleLabel: "Gönüllü"
}
```

Prod için `firebase/seed/` altına CSV koy + `bulkImportCertifiedPhones` callable ile toplu yükleme.

### 4. Dispatcher atama

```bash
# Cloud Function env'e superadmin token koy
firebase functions:secrets:set SUPERADMIN_TOKEN

# Atama
curl -X POST https://europe-west3-<PROJECT>.cloudfunctions.net/assignDispatcherRole \
  -H "x-superadmin-token: ..." \
  -H "Content-Type: application/json" \
  -d '{"uid":"<dispatcher_firebase_uid>"}'
```

### 5. Çalıştır

```bash
flutter run
```

## Yol haritası

- ✅ Faz 1: Altyapı scaffold
- ✅ Faz 2: Mobil uygulama (5 ekran + auth + harita + FCM)
- ⏳ Faz 3: Admin panel
- ⏳ Faz 4: Cloud Functions orkestrasyonu deploy + E2E test
- ⏳ Faz 5: Ürünleştirme (logo, KVKK, store release)

Detaylı plan: `~/.claude/plans/groovy-greeting-sparrow.md`

## Tasarım

"Clinical Pulse" design system — Stitch project `12023846913793716446`. Kurallar:
- **1px border yasak** (tonal layering kullan)
- Primary gradient 135° (`#b7102a` → `#db313f`)
- Inter (Türkçe glyphs için), line-height 1.6
- FAB glassmorphic pulse animasyonlu

## KVKK

- İlk açılışta aydınlatma + açık rıza (bkz. `legal/`)
- Arka plan konum için ayrı gerekçeli dialog
- "Verilerimi indir" + "Hesabımı sil" Cloud Function üstünden
- VERBİS kaydı + public privacy policy (store onayı gerekliliği)
