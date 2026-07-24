#!/bin/bash
# Droper kurulumu — bu dosyaya çift tıklayın.
#
# Ne yapar: kurulum script'ini indirir ve çalıştırır. Terminal penceresi açılır,
# ilerlemeyi orada görürsünüz. Sonunda Droper menü çubuğunuza kurulmuş olur.

set -uo pipefail

INSTALL_URL="https://raw.githubusercontent.com/uveyscolak/Droper/main/scripts/install.sh"

clear
printf "\n  Droper kurulumu başlıyor…\n\n"

TMP_SCRIPT=$(mktemp /tmp/droper-install.XXXXXX.sh)
trap 'rm -f "$TMP_SCRIPT"' EXIT

if ! curl -fsSL "$INSTALL_URL" -o "$TMP_SCRIPT"; then
    printf "\n  \033[31m✗\033[0m Kurulum dosyası indirilemedi.\n"
    printf "    İnternet bağlantınızı kontrol edip tekrar deneyin.\n\n"
    printf "  Kapatmak için bu pencerede Enter'a basın."
    read -r _
    exit 1
fi

bash "$TMP_SCRIPT"
DURUM=$?

printf "  Bu pencereyi kapatmak için Enter'a basın."
read -r _
exit $DURUM
