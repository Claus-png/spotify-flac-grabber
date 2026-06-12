#!/usr/bin/env python3
import csv
import re
import subprocess
import sys
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from difflib import SequenceMatcher

from ytmusicapi import YTMusic
from rich.console import Console
from rich.progress import Progress, BarColumn, TextColumn, SpinnerColumn, TimeElapsedColumn, TaskProgressColumn
from rich.table import Table
from rich.panel import Panel

CSV_FILE = sys.argv[1] if len(sys.argv) > 1 else "Liked_Songs.csv"
OUTPUT_DIR = sys.argv[2] if len(sys.argv) > 2 else "downloads"
MAX_WORKERS = int(os.environ.get("WORKERS", "4"))
MIN_SCORE = 0.5

console = Console()
ytmusic = YTMusic()

os.makedirs(OUTPUT_DIR, exist_ok=True)


def norm(s):
    s = s.lower()
    s = re.sub(r"\(.*?\)|\[.*?\]", "", s)
    s = re.sub(r"[^a-z0-9 ]", "", s)
    return s.strip()


def score(query_artist, query_title, result):
    title = result.get("title", "")
    artists = " ".join(a["name"] for a in result.get("artists", []) if a.get("name"))
    t_score = SequenceMatcher(None, norm(query_title), norm(title)).ratio()
    a_score = SequenceMatcher(None, norm(query_artist), norm(artists)).ratio()
    return t_score * 0.6 + a_score * 0.4


def find_best(artist, title):
    query = f"{artist} {title}"
    try:
        results = ytmusic.search(query, filter="songs", limit=5)
    except Exception:
        results = []
    if not results:
        return None, 0.0
    best = max(results, key=lambda r: score(artist, title, r))
    return best, score(artist, title, best)


def safe_filename(s):
    return re.sub(r'[\\/*?:"<>|]', "_", s).strip()


def process_track(artist, title, progress, task_id):
    name = f"{artist} - {title}"
    progress.update(task_id, description=f"[yellow]поиск: {name}")

    best, sc = find_best(artist, title)

    if best is None or sc < MIN_SCORE:
        progress.update(task_id, description=f"[red]не найдено: {name}", completed=100)
        return ("not_found", name, sc)

    video_id = best["videoId"]
    found_artist = " ".join(a["name"] for a in best.get("artists", []) if a.get("name"))
    found_title = best.get("title", "")

    out_name = safe_filename(name)
    out_template = os.path.join(OUTPUT_DIR, f"{out_name}.%(ext)s")

    progress.update(task_id, description=f"[cyan]скачивание: {name}", completed=10)

    cmd = [
        "yt-dlp",
        "-x", "--audio-format", "flac",
        "--no-playlist", "--quiet", "--no-warnings",
        "-o", out_template,
        f"https://music.youtube.com/watch?v={video_id}",
    ]

    proc = subprocess.run(cmd, capture_output=True, text=True)

    if proc.returncode != 0:
        progress.update(task_id, description=f"[red]ошибка: {name}", completed=100)
        return ("error", name, proc.stderr.strip()[:200])

    progress.update(task_id, description=f"[green]готово: {name}", completed=100)
    match_info = f"{found_artist} - {found_title}" if sc < 0.95 else None
    return ("ok", name, (sc, match_info))


def load_tracks(csv_path):
    tracks = []
    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            artist = (row.get("Artist Name(s)") or row.get("Artist") or "").strip()
            title = (row.get("Track Name") or row.get("Title") or "").strip()
            if artist and title:
                tracks.append((artist, title))
    return tracks


def main():
    tracks = load_tracks(CSV_FILE)
    total = len(tracks)

    if total == 0:
        console.print("[red]В CSV не найдено треков — проверь названия колонок (Artist Name(s), Track Name).[/red]")
        return

    console.print(Panel.fit(
        f"плейлист: {CSV_FILE}\n"
        f"треков: {total}\n"
        f"потоков: {MAX_WORKERS}\n"
        f"папка: {OUTPUT_DIR}/",
        title="spotify-flac-grabber",
        border_style="magenta",
    ))

    results = {"ok": [], "not_found": [], "error": [], "fuzzy": []}

    progress = Progress(
        SpinnerColumn(style="cyan"),
        TextColumn("[bold blue]{task.description}", justify="left"),
        BarColumn(bar_width=None, complete_style="green", finished_style="bold green"),
        TaskProgressColumn(),
        TimeElapsedColumn(),
        console=console,
        expand=True,
    )

    with progress:
        overall_task = progress.add_task("[bold magenta]всего", total=total)

        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
            futures = {}
            for artist, title in tracks:
                tid = progress.add_task(f"[dim]в очереди: {artist} - {title}", total=100)
                fut = executor.submit(process_track, artist, title, progress, tid)
                futures[fut] = (artist, title)

            for fut in as_completed(futures):
                kind, name, info = fut.result()
                if kind == "ok":
                    sc, match_info = info
                    results["ok"].append(name)
                    if match_info:
                        results["fuzzy"].append((name, match_info, sc))
                elif kind == "not_found":
                    results["not_found"].append(name)
                else:
                    results["error"].append((name, info))
                progress.update(overall_task, advance=1)

    console.print()
    table = Table(title="итоги", border_style="cyan")
    table.add_column("статус", style="bold")
    table.add_column("кол-во", justify="right")

    table.add_row("[green]скачано[/green]", str(len(results["ok"])))
    table.add_row("[yellow]слабое совпадение[/yellow]", str(len(results["fuzzy"])))
    table.add_row("[red]не найдено[/red]", str(len(results["not_found"])))
    table.add_row("[red]ошибки[/red]", str(len(results["error"])))
    console.print(table)

    if results["fuzzy"]:
        console.print("\n[yellow]слабые совпадения (проверь вручную):[/yellow]")
        for name, match_info, sc in results["fuzzy"]:
            console.print(f"  {sc:.2f}  {name}  ->  {match_info}")

    if results["not_found"]:
        console.print("\n[red]не найдено:[/red]")
        for name in results["not_found"]:
            console.print(f"  - {name}")

    if results["error"]:
        console.print("\n[red]ошибки yt-dlp:[/red]")
        for name, err in results["error"]:
            console.print(f"  - {name}: {err}")

    console.print(f"\nготово, файлы лежат в {OUTPUT_DIR}/")


if __name__ == "__main__":
    main()
