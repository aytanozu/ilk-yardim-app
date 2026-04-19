# Klinik Nabız · Operatör Paneli

Sertifikalı ilk yardım gönüllüleri platformunun dispatcher web paneli.

## Kurulum

```bash
npm install
cp .env.example .env.local   # Firebase web config'i doldur
npm run dev
```

## Dispatcher erişimi

Bir kullanıcıya operatör rolü atamak için Cloud Functions altındaki `assignDispatcherRole` HTTPS endpoint'ini kullan:

```bash
curl -X POST https://europe-west3-<PROJECT>.cloudfunctions.net/assignDispatcherRole \
  -H "x-superadmin-token: $SUPERADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"uid":"<firebase_uid>"}'
```

Kullanıcı sonraki login'inde token yenilenir ve panele erişebilir.

## Build + deploy

```bash
npm run build
# Root'taki firebase.json hosting configi ./dist'i public olarak kullanır
cd .. && firebase deploy --only hosting
```
