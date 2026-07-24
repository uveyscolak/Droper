# Droper

DropOver benzeri macOS menü çubuğu uygulaması. Finder'da dosya sürüklerken fareyi
sallayınca imlecin yanında yüzen bir **raf** açılır; dosyaları rafa bırakır,
farklı klasörlerden art arda biriktirir, hedef klasöre gidince raftan sürükleyip
bırakırsınız. Varsayılan davranış **taşıma**dır (ayarlardan kopyalamaya çevrilebilir).

## Gereksinimler

- macOS 13 veya üzeri (Apple Silicon veya Intel)
- Xcode gerekmez; **Command Line Tools** yeterlidir: `xcode-select --install`

## Kurulum

```bash
git clone https://github.com/uveyscolak/Droper.git
cd Droper
swift build -c release
```

Derlenen binary: `.build/release/Droper`

### Önerilen: Droper.app paketi oluştur

Uygulama olarak çalıştırmak (ve Accessibility iznini uygulamaya vermek) için:

```bash
./scripts/make-app.sh
open /Applications/Droper.app
```

Script, release binary'sini `/Applications/Droper.app` paketine sarar
(Dock'ta görünmeyen menü çubuğu uygulaması olarak).

### Alternatif: doğrudan binary çalıştır

```bash
.build/release/Droper
```

Bu durumda Accessibility izni, uygulamayı başlattığınız uygulamaya
(ör. Terminal) verilmelidir.

## Accessibility izni (zorunlu)

Droper, global fare sürükleme olaylarını izlemek için **Erişilebilirlik** izni ister.
İzin verilmezse sallama algılama çalışmaz.

1. Uygulamayı ilk kez başlatın — sistem izin penceresi açılır.
2. **Sistem Ayarları → Gizlilik ve Güvenlik → Erişilebilirlik** bölümüne gidin.
3. Listede **Droper**'ı (doğrudan binary çalıştırdıysanız **Terminal**'i) bulup açın.
4. Uygulamayı kapatıp yeniden başlatın.

## Kullanım

- **Raf açma:** Finder'da dosya sürüklemeye başlayın; sürükleme ~1 saniye sürünce
  raf imlecin yanında kendiliğinden açılır. Alternatifler: sürüklerken fareyi
  hızlıca sağa-sola sallayın veya **Shift** basılı tutun.
- **Biriktirme:** Dosyaları rafın üzerine bırakın. Başka klasörlerden de aynı rafa
  ekleyebilirsiniz; aynı dosya ikinci kez eklenmez. Öğeler önizlemeli ızgara
  görünümünde listelenir (görseller gerçek küçük resimle).
- **Bırakma:** Hedef klasöre gidin, raftaki öğeyi (veya "☰ Tümünü sürükle"
  etiketiyle hepsini) Finder'a sürükleyin. Dosya taşınır; kopyala modunda
  kopyalanır. Ad çakışmasında üzerine yazılmaz, "ad 2.uzantı" üretilir.
- **Kapanma:** Son öğe dışarı taşınınca raf kendini kapatır. Sürükleme rafa
  uğramadan biterse (vazgeçtiniz ya da dosyayı elle götürdünüz) otomatik açılmış
  boş raf da kendini kapatır. ✕ ile her an kapatabilirsiniz — dosyalara bir şey
  olmaz, onlar zaten yerinde durur. Menüden açtığınız raflar siz kapatana dek durur.
- **Çoklu raf:** Sınırsız; menü çubuğundaki ikon → **Yeni Raf** ile boş raf da açılır.
- **Hata durumu:** Taşınamayan dosya (izin, disk dolu) rafta kalır ve raf üzerinde
  kısa bir hata uyarısı görünür.

## Ayarlar

Menü çubuğu ikonu → **Ayarlar…**

| Ayar | Seçenekler | Varsayılan |
|---|---|---|
| Sallama hassasiyeti | Düşük / Orta / Yüksek | Orta |
| Bırakınca | Taşı / Kopyala | Taşı |
| Sürükleyince otomatik aç (1 sn) | Açık / Kapalı | Açık |
| Shift ile raf açma | Açık / Kapalı | Açık |
| Oturum açılınca başlat | Açık / Kapalı | Kapalı (yalnız .app paketiyle çalışır) |

## Testler

```bash
swift test                              # 20 birim test (ShakeDetector, FileTransfer, ShelfStore)
.build/release/Droper droper-transfer-smoke   # uçtan uca dosya işlemi kanıtı → "SMOKE OK"
```

Not: Xcode'suz kurulumda testler, araç zinciriyle birebir aynı sürümdeki
swift-testing paketini kaynaktan derler (ilk `swift test` bu yüzden uzun sürer).

## Bilinen sınırlar (v1)

- Yalnızca dosya/klasör kabul edilir (metin, URL, web görseli v2 adayı).
- Raf kalıcılığı yok: uygulama kapanınca raflar kaybolur (dosyalar etkilenmez).
- İmzalama/notarizasyon yok; yalnız kendi Mac'inizde derleyip çalıştırmak içindir.
