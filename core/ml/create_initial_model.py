#!/usr/bin/env python3
"""
Crée un modèle LightGBM initial de démonstration.
Utilisé lors de l'installation pour que l'API fonctionne immédiatement.
"""

import os
import sys
import json
from pathlib import Path

import numpy as np
import pandas as pd
from lightgbm import LGBMRegressor
import joblib

# Chemins
ROOT = Path(__file__).resolve().parents[2]
MODELS_DIR = Path(os.environ.get("CNCTOLE_MODELS_DIR", str(ROOT / "data" / "models")))
MODELS_DIR.mkdir(parents=True, exist_ok=True)

def generate_synthetic_data(n=200):
    """Génère un jeu de données synthétiques réalistes pour bootstrap."""
    rng = np.random.RandomState(42)

    data = []
    materials = {
        "AL6061": 1.00,
        "AL7075": 0.85,
        "S235": 0.45,
        "SS304": 0.30,
        "SS316": 0.25,
        "TI6AL4V": 0.15,
        "POM": 1.20,
        "PA6": 1.10,
        "PEEK": 0.60,
    }

    for _ in range(n):
        mat = rng.choice(list(materials.keys()))
        mach = materials[mat]

        volume = rng.uniform(500, 500000)          # mm³
        surface = volume ** (2/3) * rng.uniform(4, 8)
        bbox_x = rng.uniform(10, 300)
        bbox_y = rng.uniform(10, 300)
        bbox_z = rng.uniform(5, 150)
        removed = volume * rng.uniform(1.2, 3.5)
        min_r = rng.uniform(0.5, 5.0)
        max_depth = rng.uniform(5, 80)
        faces = int(rng.uniform(6, 80))
        holes = int(rng.uniform(0, 25))
        setups = int(rng.choice([1, 2, 3, 4], p=[0.1, 0.4, 0.35, 0.15]))
        qty = int(rng.choice([1, 2, 5, 10, 20, 50]))

        # Temps approximatif (minutes)
        base_time = (removed / 1000) / (mach * 40) * 60   # grossier
        time = base_time * (1 + setups * 0.15) * rng.uniform(0.8, 1.3)
        time = max(5.0, time)

        # Prix unitaire approximatif
        material_cost = (volume / 1e9) * 2700 * 5.0 * rng.uniform(0.8, 1.5)  # approx
        machine_cost = (time / 60) * 55
        setup_cost = setups * 25
        unit_price = (material_cost + machine_cost + setup_cost) * 1.25 / max(1, qty**0.3)

        data.append({
            "volume_mm3": volume,
            "surface_mm2": surface,
            "bbox_x_mm": bbox_x,
            "bbox_y_mm": bbox_y,
            "bbox_z_mm": bbox_z,
            "removed_volume_mm3": removed,
            "min_internal_radius_mm": min_r,
            "max_pocket_depth_mm": max_depth,
            "face_count": faces,
            "hole_count": holes,
            "estimated_setups": setups,
            "quantity": qty,
            "machinability": mach,
            "real_time_min": time,
            "real_unit_price": unit_price,
            "material_code": mat,
        })

    return pd.DataFrame(data)


def main():
    print("Génération de données synthétiques...")
    df = generate_synthetic_data(300)

    feature_cols = [
        "volume_mm3", "surface_mm2", "bbox_x_mm", "bbox_y_mm", "bbox_z_mm",
        "removed_volume_mm3", "min_internal_radius_mm", "max_pocket_depth_mm",
        "face_count", "hole_count", "estimated_setups", "quantity", "machinability"
    ]

    X = df[feature_cols]
    y_time = df["real_time_min"]
    y_price = df["real_unit_price"]

    print("Entraînement modèle temps...")
    model_time = LGBMRegressor(
        n_estimators=100,
        learning_rate=0.08,
        max_depth=6,
        num_leaves=31,
        random_state=42,
        verbosity=-1
    )
    model_time.fit(X, y_time)

    print("Entraînement modèle prix...")
    model_price = LGBMRegressor(
        n_estimators=100,
        learning_rate=0.08,
        max_depth=6,
        num_leaves=31,
        random_state=42,
        verbosity=-1
    )
    model_price.fit(X, y_price)

    # Sauvegarde
    version = "v0.1.0"
    model_path = MODELS_DIR / f"model_{version}.joblib"

    payload = {
        "version": version,
        "feature_columns": feature_cols,
        "model_time": model_time,
        "model_price": model_price,
        "algorithm": "lightgbm",
        "train_samples": len(df),
        "notes": "Modèle initial synthétique généré à l'installation"
    }

    joblib.dump(payload, model_path)
    print(f"Modèle sauvegardé : {model_path}")

    # Métadonnées JSON
    meta = {
        "version": version,
        "file": str(model_path.name),
        "algorithm": "lightgbm",
        "train_samples": len(df),
        "feature_columns": feature_cols,
        "created_by": "create_initial_model.py"
    }
    with open(MODELS_DIR / f"model_{version}.json", "w") as f:
        json.dump(meta, f, indent=2)

    print("Modèle initial créé avec succès.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

