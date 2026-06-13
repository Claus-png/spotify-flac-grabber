# spotify-flac-grabber

Скачивает твой плейлист со Spotify (или Liked Songs) в FLAC через YouTube Music.

Spotify закрыл нормальный доступ к метаданным без своего API-ключа, поэтому тут другой путь:

1. Экспортируешь плейлист в CSV через [Exportify](https://exportify.net)
2. Скрипт ищет каждый трек на YouTube Music, проверяет совпадение по артисту/названию
3. Скачивает совпадения через yt-dlp и конвертирует в FLAC

## Зависимости

- Python 3.10+
- yt-dlp
- ffmpeg
- ytmusicapi, rich (ставятся автоматически через requirements.txt)

## Установка и запуск

### Linux

```bash
chmod +x run.sh
./run.sh
```

Откроется текстовое меню. Скрипт сам поставит недостающие зависимости
(через pacman/apt/dnf, что найдёт) и создаст venv.

### Windows

```
run.bat
```

Откроется текстовое меню. Если чего-то не хватает (python, ffmpeg, yt-dlp),
скрипт скажет что поставить.

### Termux (Android)

```bash
pkg update -y
pkg install -y git
termux-setup-storage   # даёт доступ к /sdcard, нужно для MUSIC/MP3_DIR

git clone https://github.com/<your-username>/spotify-flac-grabber.git
cd spotify-flac-grabber
chmod +x run.sh
./run.sh
```

Если чего-то не хватает (python, ffmpeg, yt-dlp), скрипт скажет что поставить.

## Как скачать плейлист

1. Зайди на https://exportify.net, авторизуйся через Spotify
2. Выбери нужный плейлист (или Liked Songs) и нажми Export как CSV
3. Положи CSV рядом со скриптом
4. Запусти `./run.sh имя_файла.csv` (или `run.bat` на винде)
5. Файлы появятся в папке `downloads/`

## Настройки

- `WORKERS` — сколько треков качать параллельно (по умолчанию 4). Меняется через переменную окружения:

```bash
WORKERS=2 ./run.sh Liked_Songs.csv
```

## Что в итоге

В конце выводится таблица: сколько скачано, сколько не найдено, сколько со слабым совпадением (стоит проверить руками — возможно нашёлся не тот трек или другая версия).

## Лицензия

MIT — делай что хочешь.
