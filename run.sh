#!/usr/bin/env bash
set -e

CSV_FILE="${1:-Liked_Songs.csv}"

if [ ! -f "$CSV_FILE" ]; then
    echo "Файл $CSV_FILE не найден."
    echo ""
    echo "Как скачать плейлист:"
    echo "  1. Зайди на https://exportify.net и авторизуйся через Spotify"
    echo "  2. Экспортируй нужный плейлист (или Liked Songs) как CSV"
    echo "  3. Положи CSV рядом со скриптом и запусти: ./run.sh имя_файла.csv"
    exit 1
fi

need_pkg() {
    command -v "$1" >/dev/null 2>&1
}

if ! need_pkg ffmpeg || ! need_pkg yt-dlp; then
    echo "Не хватает зависимостей, ставлю..."
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm ffmpeg yt-dlp
    elif command -v apt >/dev/null 2>&1; then
        sudo apt update
        sudo apt install -y ffmpeg yt-dlp
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

source venv/bin/activate
pip install -q -r requirements.txt

python3 download_playlist.py "$CSV_FILE" downloads
