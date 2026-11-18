# GitHub yayınlama

## İlk kurulum

1. Public repo oluşturun. GitHub Pages kaynağını **GitHub Actions** yapın.
2. Ed25519 özel anahtarını yalnızca GitHub Actions `AZIK_SIGNING_KEY` secret'ında tutun (32 ham baytın base64 gösterimi).
3. Karşılık gelen 32 baytlık public key'i base64 olarak `config/release.json` içindeki `AZIK_PUBLIC_KEY` alanına ekleyin. Repo ve Pages adreslerini de ayarlayın.
4. Özel anahtarı hiçbir dosyaya, log'a, commit'e veya uygulamaya yazmayın. Güvenli anahtar yedeklemesi ve GitHub hesap kurtarma bakım sorumluluğudur. Anahtar kaybolursa uygulamanın yeni güven anahtarını taşıyan yeni sürümü gerekir.
5. `Publish content` iş akışını `main` dalından çalıştırın.

Bu repoda yayın kanalı yapılandırması kurulmuşsa adımları tekrarlayıp anahtar değiştirmeyin.

## Yeni içerik

- `assets/content/temel.json` dosyasını değiştirin. Her rehberin kaynak, lisans ve tarih alanlarını koruyun; uzman onayı yoksa varmış gibi belirtmeyin.
- `version` sayısını artırın. Aynı içerik sürümünü yeniden kullanmayın.
- PR kontrolü sonrası `main` dalına alın ve `Publish content` çalıştırın.
- İş akışı, değiştirilemez isimli `content-vN` sürümüne `temel.json` ekler. Var olan tag üzerinde tekrar yayınlamayı reddeder.
- Pages `catalog.json`, tam payload baytlarının Ed25519 imzasını taşır. Uygulama yalnızca kendisine gömülü public key ile doğrular.
- Paket şeması ve `minAppBuild` uyumsuzsa yeni uygulama sürümü gerekir. Şu an desteklenen build 1'dir.

Release başarılı, Pages yayını başarısız olursa mevcut release asset'ini değiştirmeyin. Aynı commit/key ile kataloğu tekrar üretip yalnızca Pages'i yeniden yayınlayın veya yeni içerik sürümüyle normal yayın akışını kullanın. Eski, çalışan katalog yerinde kalır.

## Uygulama dağıtımı

`Build desktop and mobile previews` test edilebilir CI artifact'leri üretir. iOS çıktısı imzasızdır; Android debug APK test içindir. Production için mağaza kimlikleri, imzalama/notarization, platform testleri ve dağıtım iş akışı tamamlanmalıdır. Mevcut sürüm uygulama binary'sini otomatik değiştirmez.

## Sınırlar

GitHub Releases dosya başına 2 GiB altı dosya kabul eder. İlk Azık istemcisi daha dar olarak sadece 20 MiB altı JSON metin paketlerini destekler. Harita, video, model ve devam ettirilebilir indirme ayrı bir sonraki aşamadır.

Tarayıcı sürümü yerel uygulamayla aynı depolama garantisini vermez. GitHub Releases cross-origin indirmesi web önizlemesinde devre dışıdır. Güncelleme akışı yerel uygulama içindir.
