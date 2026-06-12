@echo off
setlocal

set CSV_FILE=%1
if "%CSV_FILE%"=="" set CSV_FILE=Liked_Songs.csv

if not exist "%CSV_FILE%" (
    echo Файл %CSV_FILE% не найден.
    echo.
    echo Как скачать плейлист:
    echo   1. Зайди на https://exportify.net и авторизуйся через Spotify
    echo   2. Экспортируй нужный плейлист ^(или Liked Songs^) как CSV
    echo   3. Положи CSV рядом со скриптом и запусти: run.bat имя_файла.csv
    exit /b 1
)

where python >nul 2>nul
if errorlevel 1 (
    echo Python не найден. Установи с https://www.python.org/downloads/
    echo При установке отметь галочку "Add Python to PATH".
    exit /b 1
)

where ffmpeg >nul 2>nul
if errorlevel 1 (
    echo ffmpeg не найден.
    echo Поставь через: winget install ffmpeg
    echo или скачай с https://ffmpeg.org/download.html и добавь в PATH.
    exit /b 1
)

where yt-dlp >nul 2>nul
if errorlevel 1 (
    echo yt-dlp не найден, ставлю через pip...
    python -m pip install -U yt-dlp
)

if not exist venv (
    python -m venv venv
)

call venv\Scripts\activate.bat
pip install -q -r requirements.txt

python download_playlist.py "%CSV_FILE%" downloads

pause
