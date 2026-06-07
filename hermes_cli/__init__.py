"""hermes_cli -> sidekick_cli backward-compat redirect.

This package exists for two reasons:
1. The ``hermes`` CLI command (console_scripts entry point) still exists and
   is referenced in docs, tutorials, and muscle memory.
2. Internal imports from ``cli.py``, ``cron/scheduler.py``, etc. still use
   ``from hermes_cli import ...`` and are forwarded transparently.

Each module in this package re-exports the identically-named module from
:mod:`sidekick_cli`.  New code should import from ``sidekick_cli`` directly.
"""
import sys
from pathlib import Path
import importlib.abc
import importlib.machinery
import importlib.util

_SIDEKICK_DIR = (Path(__file__).resolve().parent.parent / "sidekick_cli").resolve()

# Re-export version so from hermes_cli import __version__ works
from sidekick_cli import __version__  # noqa: E402, F401


class _RedirectFinder(importlib.abc.MetaPathFinder):
    """Map ``hermes_cli.xxx`` imports to ``sidekick_cli.xxx``."""

    def find_spec(self, fullname, _path, target=None):
        if not fullname.startswith("hermes_cli."):
            return None
        if fullname == "hermes_cli.__init__":
            return None  # already loaded
        mapped = "sidekick_cli." + fullname[len("hermes_cli."):]

        # Already loaded under the sidekick name? Reuse it.
        if mapped in sys.modules:
            mod = sys.modules[mapped]
            spec = importlib.machinery.ModuleSpec(fullname, mod.__spec__.loader if mod.__spec__ else None)
            sys.modules[fullname] = mod
            return spec

        # Find and load under both names
        spec = importlib.util.find_spec(mapped)
        if spec is not None:
            module = importlib.util.module_from_spec(spec)
            # Register under BOTH names before exec_module to prevent recursion
            sys.modules[fullname] = module
            sys.modules[mapped] = module
            try:
                spec.loader.exec_module(module)
            except Exception:
                # Clean up on failure
                sys.modules.pop(fullname, None)
                sys.modules.pop(mapped, None)
                raise
            return spec  # Return the original spec — name doesn't matter after sys.modules is set

        return None


# Install the finder before any hermes_cli submodule imports
if not any(isinstance(f, _RedirectFinder) for f in sys.meta_path):
    sys.meta_path.insert(0, _RedirectFinder())
