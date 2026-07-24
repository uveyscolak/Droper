#!/bin/bash
# Dağıtılabilir Droper-Kurulum.dmg üretir.
#
# .dmg içinde: "Droper Kur.command" (çift tıklanır), pakete gömülü kaynak
# (Droper-kaynak.tar.gz — internet gerektirmez) ve görsel "İLK KEZ: sağ tık → Aç"
# talimatı. Kullanım: ./scripts/make-dmg.sh

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

DMG_NAME="Droper-Kurulum"
VOL_NAME="Droper Kurulum"
STAGE=$(mktemp -d /tmp/droper-dmg.XXXXXX)
OUT_DIR="$ROOT/dist"
OUT_DMG="$OUT_DIR/$DMG_NAME.dmg"

temizle() { rm -rf "$STAGE"; }
trap temizle EXIT

echo "▸ Kaynak paketleniyor (kişisel dosyalar hariç)…"
# Gömülü kaynak: sadece derleme için gerekenler. brain/, .claude/, .git yok.
SRC_STAGE="$STAGE/Droper"
mkdir -p "$SRC_STAGE"
for item in Package.swift Package.resolved Sources Tests scripts README.md .gitignore; do
    [ -e "$ROOT/$item" ] && cp -R "$ROOT/$item" "$SRC_STAGE/"
done
# Gömülü kaynakta make-dmg gereksiz; çıkar.
rm -f "$SRC_STAGE/scripts/make-dmg.sh"

echo "▸ .dmg içeriği hazırlanıyor…"
DMG_ROOT="$STAGE/dmgroot"
mkdir -p "$DMG_ROOT"

# Kaynağı tek arşive gömüp .dmg köküne koy.
tar -czf "$DMG_ROOT/Droper-kaynak.tar.gz" -C "$STAGE" Droper

# Çift tıklanacak kurulum dosyası.
cp "$ROOT/dist/Droper Kur.command" "$DMG_ROOT/Droper Kur.command"
chmod +x "$DMG_ROOT/Droper Kur.command"

# Görsel talimat: .dmg açılınca ilk göze çarpan dosya.
cat > "$DMG_ROOT/① BURADAN BAŞLA — OKU.txt" <<'OKU'
╭─────────────────────────────────────────────────────────╮
│                  DROPER KURULUMU                        │
╰─────────────────────────────────────────────────────────╯

  KURULUM İÇİN TEK ADIM:

  1. "Droper Kur.command" dosyasına SAĞ TIKLAYIN
  2. Açılan menüden "Aç" seçin
  3. Çıkan uyarıda tekrar "Aç" düğmesine basın

  (İlk açılışta bu sağ-tık gerekli, çünkü dosya internetten
   geldi. Bir kez yapılır. Düz çift tıklarsanız macOS engeller.)

  Sonrası tamamen otomatik:
    • Gerekli araçlar kontrol edilir (yoksa kurulur)
    • Droper derlenir ve /Applications'a kurulur
    • Uygulama başlar, izin ekranı açılır
    • Terminal penceresi kendiliğinden kapanır

  SON ADIM (ekranda anlatılacak):
  Sistem Ayarları > Gizlilik ve Güvenlik > Erişilebilirlik
  listesinden Droper'ı açın. Bu izin, farenizi sürüklediğinizde
  rafın açılabilmesi için gerekli.

  ─────────────────────────────────────────────────────────
  Sorun olursa: https://github.com/uveyscolak/Droper
OKU

echo "▸ .dmg oluşturuluyor…"
mkdir -p "$OUT_DIR"
rm -f "$OUT_DMG"
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$DMG_ROOT" \
    -ov -format UDZO \
    "$OUT_DMG" >/dev/null

SIZE=$(du -h "$OUT_DMG" | cut -f1)
echo ""
echo "✓ Hazır: $OUT_DMG ($SIZE)"
echo ""
echo "  Dağıtım: bu .dmg dosyasını WhatsApp/e-posta/Drive ile gönderin."
echo "  Karşı taraf: .dmg'ye çift tıklar → içindeki 'Droper Kur.command'a"
echo "  sağ tık → Aç. Gerisi otomatik."
