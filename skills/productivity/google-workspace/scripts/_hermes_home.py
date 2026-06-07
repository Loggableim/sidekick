"""Resolve HERMES_HOME for standalone skill scripts.

Skill scripts may run outside the Hermes process (e.g. system Python,
nix env, CI) where ``hermes_constants`` is not importable.  This module
provides the same ``get_sidekick_home()`` and ``display_sidekick_home()``
contracts as ``hermes_constants`` without requiring it on ``sys.path``.

When ``hermes_constants`` IS available it is used directly so that any
future enhancements (profile resolution, Docker detection, etc.) are
picked up automatically.  The fallback path replicates the core logic
from ``hermes_constants.py`` using only the stdlib.

All scripts under ``google-workspace/scripts/`` should import from here
instead of duplicating the ``HERMES_HOME = Path(os.getenv(...))`` pattern.
"""

from __future__ import annotations

import os
from pathlib import Path

try:
    from sidekick_constants import display_sidekick_home as display_sidekick_home
    from sidekick_constants import get_sidekick_home as get_sidekick_home
except (ModuleNotFoundError, ImportError):

    def get_sidekick_home() -> Path:
        """Return the Hermes home directory (default: ~/.sidekick).

        Mirrors ``hermes_constants.get_sidekick_home()``."""
        val = os.environ.get("HERMES_HOME", "").strip()
        return Path(val) if val else Path.home() / ".hermes"

    def display_sidekick_home() -> str:
        """Return a user-friendly ``~/``-shortened display string.

        Mirrors ``hermes_constants.display_sidekick_home()``."""
        home = get_sidekick_home()
        try:
            return "~/" + str(home.relative_to(Path.home()))
        except ValueError:
            return str(home)
