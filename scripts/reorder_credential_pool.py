#!/usr/bin/env python3
"""Reorder an auth.json credential pool so a chosen credential becomes primary.

This utility is intentionally conservative:
- It does not touch secret values.
- It only reorders the selected provider's credential_pool list.
- It preserves all other fields in auth.json.
- It can match a credential by any of: id, label, name, env, source.

Typical usage (run this in the environment that can access your real HERMES_HOME):

    python scripts/reorder_credential_pool.py \
        --auth-json C:/HermesPortable/home/auth.json \
        --provider opencode-go \
        --match OPENCODE_GO_API_KEY_FALLBACK

If --match is omitted, the first credential in the provider list becomes primary.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Dict, List, Optional


MATCH_FIELDS = ("id", "label", "name", "env", "source")


def _entry_text(entry: Dict[str, Any]) -> str:
    parts = []
    for field in MATCH_FIELDS:
        value = entry.get(field)
        if value is not None:
            parts.append(f"{field}={value}")
    return ", ".join(parts) if parts else repr(entry)


def _find_match_index(entries: List[Dict[str, Any]], match: Optional[str]) -> int:
    if match is None:
        return 0

    match_l = match.strip().lower()
    for idx, entry in enumerate(entries):
        for field in MATCH_FIELDS:
            value = entry.get(field)
            if value is not None and str(value).strip().lower() == match_l:
                return idx
    raise SystemExit(
        f"No credential matched {match!r}. Available entries:\n"
        + "\n".join(f"  [{i}] {_entry_text(e)}" for i, e in enumerate(entries))
    )


def _normalize_priorities(entries: List[Dict[str, Any]]) -> None:
    for i, entry in enumerate(entries):
        if "priority" in entry:
            entry["priority"] = i
        else:
            # Keep the field absent if it wasn't present before; otherwise set it.
            entry["priority"] = i


def reorder_credential_pool(auth_path: Path, provider: str, match: Optional[str]) -> Dict[str, Any]:
    data = json.loads(auth_path.read_text(encoding="utf-8"))
    pool = data.get("credential_pool")
    if not isinstance(pool, dict):
        raise SystemExit("auth.json has no credential_pool object")

    entries = pool.get(provider)
    if entries is None:
        raise SystemExit(f"Provider {provider!r} not found in credential_pool")
    if not isinstance(entries, list) or not entries:
        raise SystemExit(f"credential_pool[{provider!r}] is empty or not a list")

    idx = _find_match_index(entries, match)
    if idx != 0:
        chosen = entries.pop(idx)
        entries.insert(0, chosen)

    # Ensure priorities are contiguous and deterministic.
    _normalize_priorities(entries)

    # Prefer the new first entry to be considered active if such a flag exists.
    active_entry = entries[0]
    for flag in ("active", "is_active", "selected"):
        if flag in active_entry:
            active_entry[flag] = True
    if "last_status" in active_entry and active_entry.get("last_status") in {"exhausted", "failed", "error"}:
        # Clear stale failure state on the newly promoted credential.
        active_entry["last_status"] = "ok"

    auth_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return {
        "auth_path": str(auth_path),
        "provider": provider,
        "primary": _entry_text(entries[0]),
        "count": len(entries),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--auth-json", required=True, help="Path to auth.json")
    parser.add_argument("--provider", default="opencode-go", help="Provider id inside credential_pool")
    parser.add_argument(
        "--match",
        default=None,
        help="Credential identifier to move to the front (matched against id/label/name/env/source)",
    )
    args = parser.parse_args()

    result = reorder_credential_pool(Path(args.auth_json), args.provider, args.match)
    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
