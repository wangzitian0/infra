"""Layer definitions and configuration."""

from dataclasses import dataclass
from typing import Literal

Engine = Literal["terraform", "terragrunt"]


@dataclass
class Layer:
    """Infrastructure layer configuration."""

    name: str
    path: str
    engine: Engine
    order: int
    state_key: str | None = None


LAYERS: dict[str, Layer] = {
    "bootstrap": Layer(
        name="bootstrap",
        path="bootstrap",
        engine="terraform",
        order=1,
        state_key="k3s/terraform.tfstate",
    ),
    "platform": Layer(
        name="platform",
        path="platform",
        engine="terragrunt",
        order=2,
    ),
    "data-staging": Layer(
        name="data-staging",
        path="envs/staging/data",
        engine="terragrunt",
        order=3,
    ),
    "data-prod": Layer(
        name="data-prod",
        path="envs/prod/data",
        engine="terragrunt",
        order=4,
    ),
}


def get_layer(name: str) -> Layer | None:
    """Get layer by name."""
    return LAYERS.get(name)


def get_layers_by_order() -> list[Layer]:
    """Get all layers sorted by deployment order."""
    return sorted(LAYERS.values(), key=lambda l: l.order)


def detect_layers_from_paths(changed_paths: list[str]) -> list[Layer]:
    """Detect which layers are affected by changed file paths."""
    affected = set()
    for path in changed_paths:
        for layer in LAYERS.values():
            if path.startswith(layer.path):
                affected.add(layer.name)
    return [LAYERS[name] for name in affected]
