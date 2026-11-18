# Azık 🌿

**Bağlantı kesilir. Bilgi yanında kalır.**

Türkçe, açık kaynak, çevrimdışı hazırlık ve yaşam kütüphanesi. Flutter ile Android, iOS, macOS, Windows ve Linux hedeflenir. GitHub Pages üzerindeki web sürümü arayüz önizlemesidir; tam çevrimdışı web uygulaması değildir.

## v0.1.1 — çalışan başlangıç

- Koyu masaüstü arayüzü, kompakt sol menü ve konu bazında rehber kartları.
- Uygulamayla gelen 6 özgün genel hazırlık rehberi; internet bağlantısı gerekmez.
- Türkçe karakterlere toleranslı arama, kategori filtreleri ve kaydedilenler.
- Cihazda saklanan hazırlık kontrol listesi.
- Yerel uygulamalarda SQLite kütüphanesi; web önizlemesinde tarayıcı depolaması.
- GitHub Pages kataloğu → Ed25519 imzası → GitHub Releases paketi → SHA-256 doğrulaması → SQLite transaction ile kurulum.
- Geçersiz paketler ve eski sürüme dönüş reddedilir; başarısız kurulum mevcut verileri bozmaz.
- Hesap, özel sunucu ve analitik yok. Güncelleme kontrolü kullanıcı düğmeye bastığında yapılır.

**Henüz yok:** haritalar, video paketleri, yerel yapay zekâ, FTS5 indeksi, büyük paketlerde kaldığı yerden indirme, arka planda otomatik kontrol, masaüstü uygulama otomatik güncelleyicisi ve mağaza yayınları. İlk sürüm küçük metin paketleriyle sınırlıdır (20 MiB). Arama bu küçük kütüphanede bellekte yapılır.

İçerikler genel hazırlık notlarıdır; uzman incelemesi bekler. Tıbbi müdahale veya afet sırasında karar verme rehberi içermez. Katkı verirken kaynak, lisans ve inceleme durumunu belirtin.

## Çalıştır

Flutter **3.47.8** (Dart 3.13.7) kullanılır.

```sh
flutter pub get
flutter run -d macos --dart-define-from-file=config/release.json
# veya: -d windows, -d linux, -d chrome; mobil için cihaz kimliği
flutter test
flutter analyze
```

`config/release.json` yalnızca herkese açık repo adresini ve imza doğrulama anahtarını içerir. Özel anahtar kod deposuna veya uygulamaya konmaz. Yapılandırma verilmezse kütüphane çalışır, güncelleme kanalı kapalı kalır.

Linux için Flutter'ın GTK geliştirme bağımlılıkları gerekir. Apple cihazlarına imzalı dağıtım kendi geliştirici hesabını ve uygun imzalamayı gerektirir. Repo hiçbir kişisel Apple takım kimliği veya sertifika içermez.

## GitHub üzerinden yönetim

- Kod, rehberler ve çeviriler: pull request ile değişiklik ve inceleme.
- Hatalar ve talepler: Issues; güvenlik bildirimi: SECURITY.md.
- `Checks`: analiz, Flutter testleri, web derlemesi, içerik şema kontrolü.
- `Publish content`: elle tetiklenir; imzalı içerik release'i ve Pages önizlemesini yayınlar.
- `Build desktop and mobile previews`: beş platform için CI artifact üretir. Android debug imzalıdır; iOS imzasızdır. Bunlar mağaza veya son kullanıcıya hazır dağıtım değildir.

İçerik yayınlamak için [yayınlama kılavuzunu](docs/RELEASING.md) izleyin. Uygulama özelliği eklemek yeni uygulama derlemesi gerektirir; içerik güncelleme mekanizması uzaktan kod çalıştırmaz.

## Yapı

```
lib/                  Flutter arayüzü, yerel veri ve güncelleme doğrulaması
assets/content/       Kaynak Türkçe rehberler
scripts/              Paket doğrulama ve imzalama
config/               Herkese açık yayın kanalı yapılandırması
.github/workflows/    Test, derleme, içerik ve Pages yayını
```

## Katkı ve lisans

Kod: [MIT](LICENSE). Özgün rehberler: [CC BY 4.0](CONTENT_LICENSE.md). Harita, video ve model gibi üçüncü taraf materyaller ileride eklenirken kendi lisanslarıyla değerlendirilecek. Kodun açık olması, internette bulunan her içeriği yeniden dağıtma hakkı vermez.

Bu proje Lastbook fikrinden esinlenmiştir; bu başlangıç sürümünde Lastbook kaynak kodu veya içerikleri kopyalanmamıştır. Bağımsız bir projedir.
