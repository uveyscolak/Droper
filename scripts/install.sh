#!/bin/bash
# Droper — tek komutla kurulum.
#
# Kullanım:
#   curl -fsSL https://raw.githubusercontent.com/uveyscolak/Droper/main/scripts/install.sh | bash
#
# Ne yapar: Command Line Tools'u kontrol eder (yoksa kurdurur), kaynağı indirir,
# derler, /Applications/Droper.app olarak kurar ve Erişilebilirlik ayarlarını açar.

set -uo pipefail

REPO_URL="https://github.com/uveyscolak/Droper.git"
APP_PATH="/Applications/Droper.app"
WORK_DIR=""

# Renkler (terminal desteklemiyorsa boş).
if [ -t 1 ]; then
    BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
    RED=$'\033[31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
    BOLD=""; GREEN=""; YELLOW=""; RED=""; DIM=""; RESET=""
fi

adim()  { printf "\n%s▸ %s%s\n" "$BOLD" "$1" "$RESET"; }
tamam() { printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
bilgi() { printf "  %s%s%s\n" "$DIM" "$1" "$RESET"; }
uyari() { printf "  %s!%s %s\n" "$YELLOW" "$RESET" "$1"; }

hata() {
    printf "\n%s✗ Kurulum tamamlanamadı%s\n  %s\n\n" "$RED" "$RESET" "$1" >&2
    printf "  Yardım için: https://github.com/uveyscolak/Droper/issues\n\n" >&2
    exit 1
}

temizle() {
    [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ] && rm -rf "$WORK_DIR"
}
trap temizle EXIT

printf "\n%s╭────────────────────────────────────────╮%s\n" "$BOLD" "$RESET"
printf "%s│  Droper — kurulum                      │%s\n" "$BOLD" "$RESET"
printf "%s│  Sürükle-bırak rafı, menü çubuğunda    │%s\n" "$BOLD" "$RESET"
printf "%s╰────────────────────────────────────────╯%s\n" "$BOLD" "$RESET"

# --- 1) Sistem kontrolü -----------------------------------------------------

adim "Sistem kontrol ediliyor"

[ "$(uname)" = "Darwin" ] || hata "Droper yalnızca macOS'ta çalışır."

MACOS_VERSION=$(sw_vers -productVersion)
MACOS_MAJOR=${MACOS_VERSION%%.*}
if [ "$MACOS_MAJOR" -lt 13 ]; then
    hata "macOS 13 (Ventura) veya üzeri gerekiyor. Bu Mac'te macOS $MACOS_VERSION var."
fi
tamam "macOS $MACOS_VERSION"

# --- 2) Command Line Tools --------------------------------------------------

adim "Geliştirici araçları kontrol ediliyor"

if xcode-select -p >/dev/null 2>&1 && command -v swift >/dev/null 2>&1; then
    tamam "Command Line Tools kurulu"
else
    uyari "Command Line Tools kurulu değil — Apple'ın kurulum penceresi açılacak."
    bilgi "Açılan pencerede 'Yükle' deyin. Birkaç GB indirilecek (5-15 dakika)."
    bilgi "Kurulum bitince bu pencere kendiliğinden devam edecek."

    xcode-select --install >/dev/null 2>&1 || true

    printf "\n  Bekleniyor"
    BEKLENEN=0
    while ! (xcode-select -p >/dev/null 2>&1 && command -v swift >/dev/null 2>&1); do
        sleep 10
        BEKLENEN=$((BEKLENEN + 10))
        printf "."
        if [ "$BEKLENEN" -ge 1800 ]; then
            printf "\n"
            hata "Command Line Tools kurulumu 30 dakikada tamamlanmadı.
  Kurulumu elle tamamlayıp bu script'i tekrar çalıştırın."
        fi
    done
    printf "\n"
    tamam "Command Line Tools kuruldu"
fi

SWIFT_VERSION=$(swift --version 2>/dev/null | head -1 | sed 's/.*Swift version \([0-9.]*\).*/\1/')
bilgi "Swift $SWIFT_VERSION"

# --- 3) Kaynağı hazırla -----------------------------------------------------
# Kaynak iki yoldan gelebilir:
#  a) DROPER_KAYNAK_DIR ayarlıysa (.dmg içindeki gömülü kaynak) — indirme yok.
#  b) Değilse GitHub'dan klonlanır (curl | bash yolu).

if [ -n "${DROPER_KAYNAK_DIR:-}" ] && [ -d "$DROPER_KAYNAK_DIR" ]; then
    adim "Droper hazırlanıyor"
    cd "$DROPER_KAYNAK_DIR" || hata "Kaynak klasörüne girilemedi."
    WORK_DIR=$(mktemp -d /tmp/droper-log.XXXXXX)
    tamam "Kaynak pakete gömülü — indirmeye gerek yok"
else
    adim "Droper indiriliyor"
    WORK_DIR=$(mktemp -d /tmp/droper-kurulum.XXXXXX) || hata "Geçici klasör oluşturulamadı."
    if ! git clone --depth 1 "$REPO_URL" "$WORK_DIR/Droper" >/dev/null 2>&1; then
        hata "Kaynak indirilemedi. İnternet bağlantınızı kontrol edin."
    fi
    tamam "Kaynak indirildi"
    cd "$WORK_DIR/Droper" || hata "Kaynak klasörüne girilemedi."
fi

# --- 4) Derle ---------------------------------------------------------------

adim "Derleniyor"
bilgi "Bu adım 1-3 dakika sürebilir."

# Dağıtım modu: test hedefi/bağımlılığı tanımlanmaz → hiçbir paket indirilmez.
export DROPER_DIST=1

if ! swift build -c release > "$WORK_DIR/build.log" 2>&1; then
    printf "\n%s Derleme çıktısının son satırları:%s\n" "$DIM" "$RESET" >&2
    tail -20 "$WORK_DIR/build.log" >&2
    hata "Derleme başarısız oldu. Yukarıdaki çıktıyı issue'ya ekleyebilirsiniz."
fi
tamam "Derleme tamam"

# --- 5) Dosya işlemlerini doğrula -------------------------------------------

adim "Dosya işlemleri doğrulanıyor"

SMOKE_OUTPUT=$(.build/release/Droper droper-transfer-smoke 2>&1)
if [ "$SMOKE_OUTPUT" != "SMOKE OK" ]; then
    hata "Dosya taşıma testi geçmedi: $SMOKE_OUTPUT"
fi
tamam "Taşıma, kopyalama ve ad çakışması testi geçti"

# --- 6) Uygulamayı kur ------------------------------------------------------

adim "Uygulama kuruluyor"

if [ -d "$APP_PATH" ]; then
    bilgi "Önceki sürüm bulundu, kapatılıyor…"
    osascript -e 'tell application "Droper" to quit' >/dev/null 2>&1 || true
    pkill -x Droper >/dev/null 2>&1 || true
    sleep 1
fi

if ! ./scripts/make-app.sh >/dev/null 2>&1; then
    hata "Uygulama /Applications klasörüne kurulamadı. Yönetici izniniz olmayabilir."
fi
[ -d "$APP_PATH" ] || hata "Uygulama beklenen yerde oluşmadı: $APP_PATH"
tamam "Kuruldu: $APP_PATH"

# --- 7) Başlat ve izin iste -------------------------------------------------

adim "Droper başlatılıyor"

open "$APP_PATH" || hata "Uygulama başlatılamadı."
sleep 2
tamam "Droper çalışıyor — menü çubuğunda tepsi ikonunu göreceksiniz"

adim "Son adım: Erişilebilirlik izni"
printf "
  Droper'ın dosya sürüklemenizi fark edebilmesi için bu izin %sgerekli%s.
  Şimdi Sistem Ayarları açılıyor:

    1. Listede %sDroper%s'ı bulun
    2. Yanındaki anahtarı %saçın%s
    3. Sorulursa şifrenizi girin

  İzni verdikten sonra Droper birkaç saniye içinde kendiliğinden çalışmaya
  başlar — yeniden açmanıza gerek yok.
" "$BOLD" "$RESET" "$BOLD" "$RESET" "$BOLD" "$RESET"

sleep 3
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true

printf "
%s╭────────────────────────────────────────╮%s
%s│  Kurulum tamamlandı                    │%s
%s╰────────────────────────────────────────╯%s

  %sNasıl kullanılır:%s

  • Finder'da dosyaları seçip sürüklemeye başlayın
  • Bir saniye sonra imlecinizin yanında raf açılır
  • Dosyaları rafın üzerine bırakın
  • Hedef klasöre gidin, raftan sürükleyip bırakın
  • Dosyalar oraya %staşınır%s (menü çubuğu → Ayarlar'dan
    kopyalamaya çevirebilirsiniz)

  Menü çubuğundaki tepsi ikonundan yeni raf açabilir,
  ayarlara girebilir ve uygulamadan çıkabilirsiniz.

" "$GREEN" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET" "$BOLD" "$RESET" "$BOLD" "$RESET"
