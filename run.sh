#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

# ---------------------------------------------------------------------------
# Установка зависимостей (Linux / Termux)
# ---------------------------------------------------------------------------

need_pkg() {
    command -v "$1" >/dev/null 2>&1
}

install_deps() {
    if ! need_pkg ffmpeg || ! need_pkg yt-dlp; then
        echo "Не хватает зависимостей, ставлю..."
        if [ -n "$TERMUX_VERSION" ] || command -v termux-setup-storage >/dev/null 2>&1; then
            pkg install -y ffmpeg python yt-dlp
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --needed --noconfirm ffmpeg yt-dlp python-mutagen
        elif command -v apt >/dev/null 2>&1; then
            sudo apt update
            sudo apt install -y ffmpeg yt-dlp python3-venv
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y ffmpeg yt-dlp
        else
            echo "Не нашёл пакетный менеджер, поставь ffmpeg и yt-dlp вручную."
            exit 1
        fi
    fi

    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    # shellcheck disable=SC1091
    source venv/bin/activate
    pip install -q -r requirements.txt
    pip install -q mutagen
}

# ---------------------------------------------------------------------------
# Действия
# ---------------------------------------------------------------------------

action_download() {
    read -rp "Имя CSV-файла [Liked_Songs.csv]: " csv
    csv="${csv:-Liked_Songs.csv}"

    if [ ! -f "$csv" ]; then
        echo ""
        echo "Файл $csv не найден."
        echo ""
        echo "Как скачать плейлист:"
        echo "  1. Зайди на https://exportify.net и авторизуйся через Spotify"
        echo "  2. Экспортируй нужный плейлист (или Liked Songs) как CSV"
        echo "  3. Положи CSV рядом со скриптом и запусти меню заново"
        return 1
    fi

    python3 download_playlist.py "$csv" downloads
}

action_sort() {
    echo ""
    read -rp "Папка с библиотекой MUSIC [~/Music]: " music_dir
    read -rp "Папка с новыми FLAC DOWNLOADS [./downloads]: " dl_dir
    read -rp "Конвертировать новые треки в MP3 для экономии места? (y/n) [n]: " conv

    export MUSIC="${music_dir:-$HOME/Music}"
    export DOWNLOADS="${dl_dir:-$(pwd)/downloads}"

    if [[ "$conv" =~ ^[Yy]$ ]]; then
        read -rp "Папка для MP3 [~/Music_mp3]: " mp3_dir
        read -rp "Битрейт MP3 (192k/256k/320k) [256k]: " bitrate
        export CONVERT_MP3=1
        export MP3_DIR="${mp3_dir:-$HOME/Music_mp3}"
        export MP3_BITRATE="${bitrate:-256k}"
    else
        export CONVERT_MP3=0
    fi

    python3 copy_new_flacs.py
}

# ---------------------------------------------------------------------------
# ASCII меню
# ---------------------------------------------------------------------------

print_banner() {
    cat << "EOF"
 ____             _   _  __         _____ _      _   ____
/ ___| _ __   ___ | |_(_)/ _|_   _  |  ___| | __ _| |_/ ___|_ __ __ _ _____
\___ \| '_ \ / _ \| __| | |_| | | | | |_  | |/ _` | __\___ \ '__/ _` |_  / _ \
 ___) | |_) | (_) | |_| |  _| |_| | |  _| | | (_| | |_ ___) | | | (_| |/ /  __/
|____/| .__/ \___/ \__|_|_|  \__, | |_|   |_|\__,_|\__|____/|_|  \__,_/___\___|
      |_|                    |___/         grabber
EOF
}

print_menu() {
    echo ""
    echo "  1) Скачать плейлист (CSV -> FLAC через YouTube Music)"
    echo "  2) Разложить новые FLAC по библиотеке (+опционально MP3)"
    echo "  3) Установить/обновить зависимости"
    echo "  4) Выход"
    echo ""
}

main() {
    clear 2>/dev/null || true
    print_banner

    install_deps

    while true; do
        print_menu
        read -rp "Выбери пункт [1-4]: " choice
        case "$choice" in
            1) action_download ;;
            2) action_sort ;;
            3) install_deps ;;
            4) echo "Пока!"; exit 0 ;;
            *) echo "Неверный пункт, попробуй ещё раз." ;;
        esac
    done
}

main
