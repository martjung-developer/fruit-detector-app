"""Configuration defaults and environment overrides."""

import importlib

from fruitq import config


def test_config_defaults(monkeypatch) -> None:
    for name in ("IMG_SIZE", "BATCH_SIZE", "EPOCHS", "SEED", "PORT"):
        monkeypatch.delenv(name, raising=False)
    importlib.reload(config)
    assert config.IMG_SIZE == 224
    assert config.BATCH_SIZE == 16
    assert config.EPOCHS == 15
    assert config.SEED == 42
    assert config.API_PORT == 8001


def test_config_environment_override(monkeypatch) -> None:
    monkeypatch.setenv("PORT", "8002")
    monkeypatch.setenv("IMG_SIZE", "192")
    reloaded = importlib.reload(config)
    assert reloaded.API_PORT == 8002
    assert reloaded.IMG_SIZE == 192
    monkeypatch.delenv("PORT")
    monkeypatch.delenv("IMG_SIZE")
    importlib.reload(config)
