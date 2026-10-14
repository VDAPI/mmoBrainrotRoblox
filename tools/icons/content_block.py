# Content block list (IMPORT-GRAFIK 2026-10-14): owner pictures that must never reach Roblox (blood, wounds, gore,
# severed parts; the owner's account was moderated for such uploads). tools/icons/content_block.json lists each file by
# its path in the Graphics folder and the sha256 of its bytes. import_graphics.py and import_ui.py skip a blocked file
# and remove its key from the game art (cell cleared, single picture deleted) even without --prune, so the game keeps
# its fallback. A file whose bytes changed (the owner regenerated it) is imported again with a warning: look at it
# before uploading.
import hashlib
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
BLOCK_FILE = os.path.join(HERE, "content_block.json")


def file_hash(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def load(path=BLOCK_FILE):
    """{relative path (forward slashes): entry {path, sha256, why}}; {} without the file."""
    if not path or not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return {e["path"]: e for e in data.get("files", [])}


def split(entries, src, blocks):
    """Splits mapped entries (tuples whose first field is the file path) into (kept, blocked, warnings).
    blocked: [(entry, why)]; a listed path with other bytes stays in kept and gets a warning."""
    kept, blocked, warnings = [], [], []
    for e in entries:
        rel = os.path.relpath(e[0], src).replace(os.sep, "/")
        b = blocks.get(rel)
        if b is None:
            kept.append(e)
        elif file_hash(e[0]) == b["sha256"]:
            blocked.append((e, b.get("why", "")))
        else:
            kept.append(e)
            warnings.append(f"{rel}: plik z listy blokad treści zmieniony, obejrzyj go przed wgraniem "
                            f"(tools/icons/content_block.json)")
    return kept, blocked, warnings
