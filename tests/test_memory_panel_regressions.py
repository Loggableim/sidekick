from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
PANELS_JS = (REPO / "static" / "panels.js").read_text(encoding="utf-8")


def test_memory_refresh_preserves_special_memory_views():
    assert "_renderSupermemoryView()" in PANELS_JS
    assert "_renderHybridView()" in PANELS_JS
    assert "loadMemory(true)" in PANELS_JS
    assert "_currentMemorySection === 'supermemory'" in PANELS_JS
    assert "_currentMemorySection === 'hybrid'" in PANELS_JS

