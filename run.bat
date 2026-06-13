@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

:banner
cls
echo  ____             _   _  __         _____ _      _   ____
echo / ___| _ __   ___ ^| ^|_(_)/ _^|_   _  ^|  ___^| ^| __ _^| ^|_/ ___^|_ __ __ _ _____
echo \___ \^| '_ \ / _ \^| __^| ^| ^|_^| ^| ^| ^| ^| ^|_  ^| ^|/ _` ^| __\___ \ '__/ _` ^|_  / _ \
echo  ___) ^| ^|_) ^| (_) ^| ^|_^| ^|  _^| ^|_^| ^| ^|  _^| ^| ^| (_^| ^| ^|_ ___) ^| ^| ^| (_^| ^|/ /  __/
echo ^|____/^| .__/ \___/ \__^|_^|_^|  \__, ^| ^|_^|   ^|_^|\__,_^|\__^|____/^|_^|  \__,_/___\___^|
echo       ^|_^|                    ^|___/         grabber
echo.

call :check_deps

:menu
echo.
echo   1) Скачать плейлист (CSV -^> FLAC через YouTube Music)
echo   2) Разложить новые FLAC по библиотеке (+опционально MP3)
echo   3) Установить/обновить зависимости
echo   4) Выход
echo.
set /p choice="Выбери пункт [1-4]: "

if "%choice%"=="1" goto download
if "%choice%"=="2" goto sortflacs
if "%choice%"=="3" goto check_deps
if "%choice%"=="4" goto end
echo Неверный пункт, попробуй ещё раз.
goto menu

:check_deps
where python >nul 2>nul
if errorlevel 1 (
    echo Python не найден. Установи с https://www.python.org/downloads/
    echo При установке отметь галочку "Add Python to PATH".
    pause
    exit /b 1
)

where ffmpeg >nul 2>nul
if errorlevel 1 (
    echo ffmpeg не найден.
    echo Поставь через: winget install ffmpeg
    echo или скачай с https://ffmpeg.org/download.html и добавь в PATH.
    pause
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
pip install -q mutagen
goto :eof

:download
set /p csvfile="Имя CSV-файла [Liked_Songs.csv]: "
if "%csvfile%"=="" set csvfile=Liked_Songs.csv

if not exist "%csvfile%" (
    echo.
    echo Файл %csvfile% не найден.
    echo.
    echo Как скачать плейлист:
    echo   1. Зайди на https://exportify.net и авторизуйся через Spotify
    echo   2. Экспортируй нужный плейлист ^(или Liked Songs^) как CSV
    echo   3. Положи CSV рядом со скриптом и запусти меню заново
    goto menu
)

python download_playlist.py "%csvfile%" downloads
goto menu

:sortflacs
set /p musicdir="Папка с библиотекой MUSIC [%USERPROFILE%\Music]: "
if "%musicdir%"=="" set musicdir=%USERPROFILE%\Music
set MUSIC=%musicdir%

set /p dldir="Папка с новыми FLAC DOWNLOADS [%cd%\downloads]: "
if "%dldir%"=="" set dldir=%cd%\downloads
set DOWNLOADS=%dldir%

set /p conv="Конвертировать новые треки в MP3 для экономии места? (y/n) [n]: "
if /i "%conv%"=="y" (
    set /p mp3dir="Папка для MP3 [%USERPROFILE%\Music_mp3]: "
    if "%mp3dir%"=="" set mp3dir=%USERPROFILE%\Music_mp3
    set MP3_DIR=%mp3dir%

    set /p bitrate="Битрейт MP3 (192k/256k/320k) [256k]: "
    if "%bitrate%"=="" set bitrate=256k
    set MP3_BITRATE=%bitrate%

    set CONVERT_MP3=1
) else (
    set CONVERT_MP3=0
)

python copy_new_flacs.py
goto menu

:end
echo Пока!
exit /b 0
