# Kişisel Verilerin İşlenmesine İlişkin Aydınlatma Metni

_KVKK Madde 10 kapsamında_

## Veri Sorumlusu

**Klinik Nabız** uygulamasını işleten [Şirket Adı / Dernek Adı] ("**Klinik Nabız**", "**biz**"), Kanun kapsamında veri sorumlusudur. Adres, ticaret sicil bilgileri ve iletişim:

- İletişim: `support@klinik-nabiz.app`
- VERBİS kaydı: [numara eklenecek]

## İşlenen Kişisel Veriler

Hizmetlerimizi sunabilmek amacıyla aşağıdaki veri kategorilerini işliyoruz:

| Kategori | Örnekler | Hassasiyet |
|----------|----------|------------|
| Kimlik | Ad, soyad | Sıradan |
| İletişim | Cep telefonu (E.164) | Hassas |
| Mesleki yeterlilik | İlk yardım sertifika numarası, tipi, geçerlilik | Özel nitelikli (sağlık) |
| Konum | Gerçek zamanlı GPS, arka plan konumu | Hassas |
| Müdahale verisi | Katıldığınız vakalara ilişkin zaman damgaları, bulunduğunuz konum, müdahale sayısı | Hassas |
| Sosyal paylaşımlar | Paylaştığınız hikayeler, fotoğraflar, yorumlar | Sıradan |
| Cihaz | Push bildirim tokeni (FCM), cihaz modeli, işletim sistemi sürümü | Sıradan |

## İşleme Amaçları

- Size en yakın acil çağrıları göstermek ve bildirmek
- Sertifikanızın geçerliliğini doğrulamak
- Müdahale kayıtlarınızı tutmak, rozet ve eğitim puanınızı hesaplamak
- Dispatcher ekibinin olay yönetimi için sizinle iletişim kurabilmesi
- Yasal saklama yükümlülüklerimizi yerine getirmek
- Uygulama güvenliğini ve dolandırıcılığı önlemek

## Hukuki Sebep

- **Açık rıza** (KVKK md. 5/1, 6/2): Özel nitelikli sağlık verisi (sertifika) ve hassas konum verisi
- **Bir sözleşmenin kurulması veya ifası** (md. 5/2-c): Uygulama kullanım sözleşmesi
- **Hukuki yükümlülük** (md. 5/2-ç): Yasal saklama süreleri
- **Meşru menfaat** (md. 5/2-f): Dolandırıcılık ve suistimal önleme

## Aktarım

| Alıcı | Amaç | Yurt dışına aktarım |
|-------|------|---------------------|
| Google Firebase (auth, Firestore, FCM, Storage, Functions) | Veri barındırma, anlık bildirim | Evet (AB sunucusu — europe-west3) |
| OpenStreetMap / Nominatim | Adres geocoding | Evet (AB) |
| Dispatcher ekibimiz (operatör) | Çağrı eşleştirme | Hayır |

Yurt dışı aktarımlar, KVKK md. 9 uyarınca açık rızanız veya yeterli koruma önlemli standart sözleşmeler çerçevesinde yapılır.

## Saklama Süreleri

- **Aktif hesap verisi**: Üyelik süresince
- **Gerçek zamanlı konum geçmişi**: 30 gün (sonra anonimleştirilir veya silinir)
- **Müdahale/vaka kayıtları**: 2 yıl (yasal saklama) — sonra anonimleştirilir
- **Sosyal paylaşımlar**: Hesap silinse dahi anonimleştirilerek arşivlenir
- **Cihaz bildirim tokeni**: Hesap pasife alınana veya cihaz çıkış yapana dek

## Haklarınız

KVKK md. 11 kapsamında, aşağıdaki haklara sahipsiniz:

- Kişisel verilerinizin işlenip işlenmediğini öğrenme
- İşleme amacını ve bunların amacına uygun kullanılıp kullanılmadığını öğrenme
- Yurt içinde / yurt dışında aktarıldığı üçüncü kişileri bilme
- Eksik veya yanlış işlenmiş ise düzeltilmesini isteme
- Silinmesini veya yok edilmesini isteme
- Otomatik sistemlerle analiz sonucunda aleyhinize bir sonuç çıkmasına itiraz etme
- Kanuna aykırı işleme nedeniyle uğradığınız zararın giderilmesini talep etme

Taleplerinizi uygulama içinde **Profil → Gizlilik** menüsündeki "Verilerimi İndir" ve "Hesabımı Sil" araçlarıyla veya `support@klinik-nabiz.app` adresine yazılı başvuruyla iletebilirsiniz. En geç 30 gün içinde yanıt veririz.

---

_Son güncelleme: **2026-04-19**_
