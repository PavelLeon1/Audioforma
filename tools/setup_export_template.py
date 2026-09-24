"""Download only the Windows x86_64 release template from the official Godot TPZ."""

from __future__ import annotations

import struct
import sys
import urllib.request
import zlib
from pathlib import Path


VERSION = "4.7.2.stable"
ARCHIVE_URL = (
    "https://godot-releases.nbg1.your-objectstorage.com/4.7.2-stable/"
    "Godot_v4.7.2-stable_export_templates.tpz"
)
TARGETS = (
    "templates/version.txt",
    "templates/windows_release_x86_64.exe",
)
PROJECT_ROOT = Path(__file__).resolve().parent.parent
DESTINATION = PROJECT_ROOT / ".local" / "godot" / "editor_data" / "export_templates" / VERSION


def archive_size() -> int:
    request = urllib.request.Request(ARCHIVE_URL, method="HEAD")
    with urllib.request.urlopen(request, timeout=60) as response:
        return int(response.headers["Content-Length"])


def read_range(start: int, end: int, size: int) -> bytes:
    request = urllib.request.Request(
        ARCHIVE_URL,
        headers={"Range": f"bytes={start}-{end}"},
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        expected_range = f"bytes {start}-{end}/{size}"
        if response.status != 206 or response.headers.get("Content-Range") != expected_range:
            raise RuntimeError("Сервер не подтвердил запрошенный диапазон архива.")
        data = response.read()
    if len(data) != end - start + 1:
        raise RuntimeError("Получен неполный фрагмент архива.")
    return data


def find_entries(size: int) -> dict[str, tuple[int, int, int, int, int]]:
    tail_start = max(0, size - 131072)
    tail = read_range(tail_start, size - 1, size)
    end_index = tail.rfind(bytes((80, 75, 5, 6)))
    if end_index < 0:
        raise RuntimeError("Не найден конец ZIP-архива.")
    _, disk, directory_disk, disk_count, count, directory_size, directory_offset, _ = struct.unpack_from(
        "<4s4H2IH", tail, end_index
    )
    if disk != 0 or directory_disk != 0 or disk_count != count or directory_offset == 0xFFFFFFFF:
        raise RuntimeError("Формат архива шаблонов не поддерживается.")

    directory = read_range(directory_offset, directory_offset + directory_size - 1, size)
    found: dict[str, tuple[int, int, int, int, int]] = {}
    position = 0
    for _ in range(count):
        fields = struct.unpack_from("<4s6H3I5H2I", directory, position)
        if fields[0] != bytes((80, 75, 1, 2)):
            raise RuntimeError("Повреждён индекс ZIP-архива.")
        name_length, extra_length, comment_length = fields[10:13]
        name = directory[position + 46 : position + 46 + name_length].decode("utf-8")
        if name in TARGETS:
            found[name] = (fields[16], fields[8], fields[9], fields[7], fields[4])
        position += 46 + name_length + extra_length + comment_length
    if set(found) != set(TARGETS):
        raise RuntimeError("В официальном архиве не найдены нужные шаблоны.")
    return found


def extract_entry(name: str, entry: tuple[int, int, int, int, int], size: int) -> bytes:
    offset, compressed_size, expected_size, expected_crc, method = entry
    header = read_range(offset, offset + 29, size)
    fields = struct.unpack("<4s5H3I2H", header)
    if fields[0] != bytes((80, 75, 3, 4)) or fields[3] != method:
        raise RuntimeError(f"Повреждён заголовок файла {name}.")
    data_start = offset + 30 + fields[9] + fields[10]
    compressed = read_range(data_start, data_start + compressed_size - 1, size)
    if method == 0:
        data = compressed
    elif method == 8:
        data = zlib.decompress(compressed, -15)
    else:
        raise RuntimeError(f"Неизвестный метод сжатия файла {name}.")
    if len(data) != expected_size or zlib.crc32(data) != expected_crc:
        raise RuntimeError(f"Не совпала контрольная сумма файла {name}.")
    return data


def main() -> None:
    version_path = DESTINATION / "version.txt"
    template_path = DESTINATION / "windows_release_x86_64.exe"
    if version_path.is_file() and template_path.is_file():
        if version_path.read_text(encoding="ascii").strip() == VERSION and template_path.stat().st_size > 100_000_000:
            print(f"Шаблон уже подготовлен: {template_path}")
            return

    size = archive_size()
    entries = find_entries(size)
    version = extract_entry("templates/version.txt", entries["templates/version.txt"], size)
    if version.decode("ascii").strip() != VERSION:
        raise RuntimeError("Версия архива не совпадает с версией редактора.")
    template = extract_entry("templates/windows_release_x86_64.exe", entries["templates/windows_release_x86_64.exe"], size)

    DESTINATION.mkdir(parents=True, exist_ok=True)
    (DESTINATION / "version.txt.tmp").write_bytes(version)
    (DESTINATION / "windows_release_x86_64.exe.tmp").write_bytes(template)
    (DESTINATION / "version.txt.tmp").replace(version_path)
    (DESTINATION / "windows_release_x86_64.exe.tmp").replace(template_path)
    print(f"Шаблон Godot {VERSION} подготовлен: {template_path}")


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    main()
