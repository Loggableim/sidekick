from __future__ import annotations

import io
import json
from pathlib import Path

from api import routes, space_engine, workspace_isolation
import api.models as models


class _FakeHandler:
    def __init__(self):
        self.status = None
        self.headers = {}
        self.response_headers = []
        self.wfile = io.BytesIO()
        self.rfile = io.BytesIO()

    def send_response(self, status):
        self.status = status

    def send_header(self, key, value):
        self.response_headers.append((key, value))

    def end_headers(self):
        pass

    def body_json(self):
        return json.loads(self.wfile.getvalue().decode("utf-8"))


def test_create_space_initializes_isolated_memory_and_default_soul(monkeypatch, tmp_path):
    monkeypatch.setattr(space_engine, "SPACES_ROOT", tmp_path / "spaces")
    monkeypatch.setattr(space_engine, "_OLD_ROOT", tmp_path / "workspaces")
    space_engine._invalidate_space_cache()

    space = space_engine.create_space("writer-room", name="Writer Room", color="#123456")

    assert space.memory_dir.is_dir()
    assert (space.memory_dir / "MEMORY.md").exists() is False
    assert space.agent_soul_path("default").is_file()
    assert "writer-room" in space.agent_soul_path("default").read_text(encoding="utf-8").lower()


def test_get_or_create_space_backfills_missing_memory_dir(monkeypatch, tmp_path):
    spaces_root = tmp_path / "spaces"
    legacy_root = tmp_path / "workspaces"
    slug = "isolated"
    agent_dir = spaces_root / slug / "agents" / "default"
    agent_dir.mkdir(parents=True, exist_ok=True)
    (agent_dir / "SOUL.md").write_text("space soul", encoding="utf-8")

    monkeypatch.setattr(space_engine, "SPACES_ROOT", spaces_root)
    monkeypatch.setattr(space_engine, "_OLD_ROOT", legacy_root)
    space_engine._invalidate_space_cache()

    space = space_engine.get_or_create_space(slug)

    assert space.memory_dir.is_dir()
    assert space.agent_soul_path("default").read_text(encoding="utf-8") == "space soul"


def test_async_extract_facts_writes_into_session_space_memory(monkeypatch, tmp_path):
    monkeypatch.setattr(space_engine, "SPACES_ROOT", tmp_path / "spaces")
    monkeypatch.setattr(space_engine, "_OLD_ROOT", tmp_path / "workspaces")
    space_engine._invalidate_space_cache()

    class _FakeSession:
        def __init__(self):
            self.archived = True
            self.workspace_slug = "writer-room"
            self.title = "Status"
            self.messages = [
                {"role": "user", "content": "hello"},
                {"role": "assistant", "content": "world"},
            ]

        @staticmethod
        def load(_sid):
            return _FakeSession()

    monkeypatch.setattr(models, "Session", _FakeSession)
    monkeypatch.setattr(routes, "_extract_facts_via_llamacpp", lambda *args, **kwargs: "## fact block\n")

    routes._async_extract_facts("sid-1")

    target_memory = space_engine.get_or_create_space("writer-room").memory_dir / "MEMORY.md"
    default_memory = space_engine.get_or_create_space("default").memory_dir / "MEMORY.md"

    assert target_memory.exists()
    assert "fact block" in target_memory.read_text(encoding="utf-8")
    assert not default_memory.exists()


def test_hybrid_search_reads_active_space_memory_not_root_home(monkeypatch, tmp_path):
    monkeypatch.setattr(space_engine, "SPACES_ROOT", tmp_path / "spaces")
    monkeypatch.setattr(space_engine, "_OLD_ROOT", tmp_path / "workspaces")
    space_engine._invalidate_space_cache()

    active_space = space_engine.get_or_create_space("research")
    (active_space.memory_dir / "MEMORY.md").write_text("Needle fact in space memory\n", encoding="utf-8")

    root_home = tmp_path / "fake-home"
    root_home.mkdir(parents=True, exist_ok=True)
    (root_home / "MEMORY.md").write_text("needle fact in root home\n", encoding="utf-8")

    monkeypatch.setattr(space_engine, "resolve_active_space", lambda: active_space)
    monkeypatch.setattr(routes, "_get_supermemory_client", lambda: None)

    try:
        import api.profiles as profiles
        monkeypatch.setattr(profiles, "get_active_hermes_home", lambda: root_home)
    except Exception:
        pass

    handler = _FakeHandler()
    routes._handle_hybrid_search(handler, {"q": "needle", "limit": 10})
    payload = handler.body_json()

    assert handler.status == 200
    assert payload["hits"]
    contents = [hit["content"] for hit in payload["hits"]]
    assert any("space memory" in content for content in contents)
    assert all("root home" not in content for content in contents)

def test_fresh_install_creates_nova_default_space(monkeypatch, tmp_path):
    monkeypatch.setattr(space_engine, "SPACES_ROOT", tmp_path / "spaces")
    monkeypatch.setattr(space_engine, "_OLD_ROOT", tmp_path / "workspaces")
    space_engine.clear_active_space()
    space_engine._invalidate_space_cache()

    spaces = space_engine.get_all_spaces()

    assert [space.slug for space in spaces] == ["nova"]
    nova = spaces[0]
    assert nova.root.name == "nova"
    assert nova.get_project_dir() is None
    assert nova.memory_dir.is_dir()
    assert nova.agent_soul_path("default").is_file()
    cfg = nova.load_config()
    assert cfg["name"] == "Nova"
    assert cfg["emoji"] == "✨"


def test_resolve_active_space_falls_back_to_nova(monkeypatch, tmp_path):
    monkeypatch.delenv("HERMES_WEBUI_ACTIVE_WORKSPACE", raising=False)
    monkeypatch.setattr(space_engine, "SPACES_ROOT", tmp_path / "spaces")
    monkeypatch.setattr(space_engine, "_OLD_ROOT", tmp_path / "workspaces")
    space_engine.clear_active_space()
    space_engine._invalidate_space_cache()

    active = space_engine.resolve_active_space()

    assert active.slug == "nova"
    assert active.get_project_dir() is None


def test_delete_protects_nova_and_legacy_default(monkeypatch, tmp_path):
    monkeypatch.setattr(space_engine, "SPACES_ROOT", tmp_path / "spaces")
    monkeypatch.setattr(space_engine, "_OLD_ROOT", tmp_path / "workspaces")
    space_engine._invalidate_space_cache()
    space_engine.get_or_create_space("nova")
    space_engine.get_or_create_space("default")

    assert space_engine.delete_space("nova") is False
    assert space_engine.delete_space("default") is False
    assert space_engine.get_space("nova") is not None
    assert space_engine.get_space("default") is not None

def test_legacy_workspace_isolation_fresh_install_uses_nova(monkeypatch, tmp_path):
    monkeypatch.setattr(workspace_isolation, "WORKSPACES_ROOT", tmp_path / "workspaces")
    workspace_isolation.clear_active_workspace()
    workspace_isolation._invalidate_cache()

    workspaces = workspace_isolation.get_all_workspaces()

    assert [workspace.slug for workspace in workspaces] == ["nova"]
    assert workspaces[0].get_project_dir() is None


def test_legacy_workspace_delete_protects_nova_and_default(monkeypatch, tmp_path):
    monkeypatch.setattr(workspace_isolation, "WORKSPACES_ROOT", tmp_path / "workspaces")
    workspace_isolation.clear_active_workspace()
    workspace_isolation._invalidate_cache()
    workspace_isolation.get_or_create_workspace("nova")
    workspace_isolation.get_or_create_workspace("default")

    assert workspace_isolation.delete_workspace("nova") is False
    assert workspace_isolation.delete_workspace("default") is False
    assert workspace_isolation.get_workspace("nova") is not None
    assert workspace_isolation.get_workspace("default") is not None
