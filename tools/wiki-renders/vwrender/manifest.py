"""Incremental renders: entry hashes and the committed manifest (tools/wiki-renders/manifest.json)."""
import hashlib
import json
from pathlib import Path

from . import RENDERER_VERSION


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def entry_hash(entry, override, sizes, version=RENDERER_VERSION):
    payload = {"entry": entry, "override": override or {}, "renderer": version, "sizes": sizes}
    return hashlib.sha256(canonical(payload).encode("utf-8")).hexdigest()


def load(path):
    path = Path(path)
    if not path.is_file():
        return {"rendererVersion": RENDERER_VERSION, "files": {}}
    return json.loads(path.read_text(encoding="utf-8"))


def save(path, data):
    Path(path).write_text(json.dumps(data, sort_keys=True, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")


def orphans(old, current_files):
    """Files of the previous manifest that are no longer dumped (only those: nothing else is ever removed)."""
    return sorted(f for f in old.get("files", {}) if f not in current_files)


def remove_outputs(out_dir, record):
    removed = 0
    for name in record.get("outputs", []):
        p = Path(out_dir) / name
        if p.is_file():
            p.unlink()
            removed += 1
    return removed


def folder_bytes(out_dir):
    return sum(p.stat().st_size for p in Path(out_dir).glob("*.webp"))
