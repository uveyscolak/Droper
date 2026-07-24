#!/bin/bash
# Droper kurulumu — çift tıklayın, gerisi otomatik.
#
# Bu dosya bir .dmg imajının içinde dağıtılır ve kaynağı kendi yanında taşır.
# Çalışınca: derler, /Applications/Droper.app kurar, başlatır, Erişilebilirlik
# ayarını açar ve bu Terminal penceresini kendiliğinden kapatır.

set -uo pipefail

# Bu script'in bulunduğu klasör (.dmg mount noktası).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

clear

# --- Terminal penceresini sonunda otomatik kapat --------------------------
# Bu script'in TTY'sini baştan yakalarız; kurulum sonunda kaç pencere/sekme
# o TTY'de çalışıyorsa onu kapatırız. Böylece kurulum bitince Sistem Ayarları
# öne gelse bile (Terminal artık "frontmost" olmasa da) doğru pencere kapanır.
BU_TTY="$(/usr/bin/tty 2>/dev/null | sed 's|/dev/||')"

pencereyi_kapat() {
    [ -n "$BU_TTY" ] || return 0
    /usr/bin/osascript >/dev/null 2>&1 <<APPLESCRIPT || true
tell application "Terminal"
    repeat with p in windows
        try
            repeat with s in tabs of p
                if (tty of s) contains "$BU_TTY" then
                    close p saving no
                    exit repeat
                end if
            end repeat
        end try
    end repeat
    if (count of windows) = 0 then quit
end tell
APPLESCRIPT
}

# --- Kaynağı bul: önce .dmg içindeki gömülü kaynak, yoksa GitHub -----------
KAYNAK_DIR=""
WORK_DIR=""

temizle() {
    [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ] && rm -rf "$WORK_DIR"
}
trap temizle EXIT

if [ -f "$HERE/Droper-kaynak.tar.gz" ]; then
    # .dmg salt-okunur; kaynağı yazılabilir geçici klasöre aç.
    WORK_DIR=$(mktemp -d /tmp/droper-kurulum.XXXXXX)
    if tar -xzf "$HERE/Droper-kaynak.tar.gz" -C "$WORK_DIR" 2>/dev/null; then
        KAYNAK_DIR="$WORK_DIR/Droper"
    fi
fi

# Gömülü kaynak yoksa install.sh'i GitHub'dan indirip çalıştır (yedek yol).
if [ -z "$KAYNAK_DIR" ] || [ ! -d "$KAYNAK_DIR" ]; then
    printf "\n  Droper kurulumu başlıyor (kaynak indiriliyor)…\n\n"
    TMP_SCRIPT=$(mktemp /tmp/droper-install.XXXXXX.sh)
    if curl -fsSL "https://raw.githubusercontent.com/uveyscolak/Droper/main/scripts/install.sh" -o "$TMP_SCRIPT" 2>/dev/null; then
        bash "$TMP_SCRIPT"
        DURUM=$?
        rm -f "$TMP_SCRIPT"
        [ "$DURUM" -eq 0 ] && pencereyi_kapat
        exit $DURUM
    fi
    printf "\n  \033[31m✗\033[0m Kaynak bulunamadı ve indirilemedi.\n"
    printf "    İnternet bağlantınızı kontrol edip tekrar deneyin.\n\n"
    printf "  Bu pencereyi kapatabilirsiniz.\n"
    exit 1
fi

# --- Gömülü kaynakla yerel kurulum ----------------------------------------
# install.sh'i klonlamadan, eldeki kaynakla çalışacak şekilde çağır.
export DROPER_KAYNAK_DIR="$KAYNAK_DIR"
bash "$KAYNAK_DIR/scripts/install.sh"
DURUM=$?

if [ "$DURUM" -eq 0 ]; then
    printf "\n  Bu pencere birazdan kendiliğinden kapanacak…\n"
    sleep 3
    pencereyi_kapat
else
    printf "\n  Kurulum tamamlanamadı. Bu pencereyi kapatabilirsiniz.\n"
fi
exit $DURUM
