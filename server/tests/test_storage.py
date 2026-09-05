"""Tests for storage service."""

from app.services.storage import store_file


def test_store_and_retrieve(tmp_path, monkeypatch):
    mock_settings = type("S", (), {"media_root": str(tmp_path)})()
    monkeypatch.setattr("app.services.storage.settings", mock_settings)
    data = b"fake image data for testing"
    key, sha = store_file(data, prefix="test", ext=".jpg")
    assert key.startswith("test/")
    assert len(sha) == 64
    stored = (tmp_path / key).read_bytes()
    assert stored == data
