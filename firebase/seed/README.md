# Seed Data

Bu klasör geliştirme/test için örnek verileri barındırır.

## Sertifikalı telefonlar (CSV)

`certified_phones.example.csv` — gerçek listeyi `certified_phones.csv` olarak kaydet (.gitignore'da).

Format:
```
phone,fullName,certificateId,certificateType,expiresAt,city,district
+905331234567,Ahmet Test,TR-123,İleri İlkyardım Sertifikası,2027-04-15,istanbul,kadikoy
```

Yüklemek için admin panelinde **Sertifikalar** sekmesini kullan (CSV'yi textarea'ya yapıştır → Yükle).

## Seed Node Script (opsiyonel)

```bash
cd firebase/functions
GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccount.json npx ts-node ../seed/seed_dev.ts
```

Quizler + eğitim içerikleri + örnek 3 emergency ile başlatır.
