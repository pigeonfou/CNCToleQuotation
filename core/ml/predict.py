#!/usr/bin/env python3
"""
CNCToleQuotation - Prédiction ML
Lit un JSON de features sur stdin ou en argument, retourne le temps et le prix estimés.
"""

import sys
import json
import os
from pathlib import Path

import joblib
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
MODELS_DIR = ROOT / "data" / "models"

# Mapping matériau → machinability (doit rester synchronisé avec la BDD)
MACHINABILITY = {
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


def load_active_model():
    """Charge le modèle actif (le plus récent ou celui indiqué)."""
    # Cherche d'abord un fichier active_model.txt
    active_file = MODELS_DIR / "active_model.txt"
    if active_file.exists():
        version = active_file.read_text().strip()
        model_path = MODELS_DIR / f"model_{version}.joblib"
        if model_path.exists():
            return joblib.load(model_path), version

    # Sinon prend le plus récent
    candidates = sorted(MODELS_DIR.glob("model_v*.joblib"), reverse=True)
    if not candidates:
        raise FileNotFoundError("Aucun modèle ML trouvé dans data/models/")

    model_path = candidates[0]
    version = model_path.stem.replace("model_", "")
    return joblib.load(model_path), version


def predict(features: dict) -> dict:
    model_data, version = load_active_model()

    feature_cols = model_data["feature_columns"]
    model_time = model_data["model_time"]
    model_price = model_data["model_price"]

    # Construction du vecteur de features
    mat = features.get("material_code", "AL6061")
    mach = MACHINABILITY.get(mat, 0.5)

    row = {
        "volume_mm3": float(features.get("volume_mm3", 10000)),
        "surface_mm2": float(features.get("surface_mm2", 5000)),
        "bbox_x_mm": float(features.get("bbox_x_mm", 50)),
        "bbox_y_mm": float(features.get("bbox_y_mm", 50)),
        "bbox_z_mm": float(features.get("bbox_z_mm", 20)),
        "removed_volume_mm3": float(features.get("removed_volume_mm3", 15000)),
        "min_internal_radius_mm": float(features.get("min_internal_radius_mm", 1.0)),
        "max_pocket_depth_mm": float(features.get("max_pocket_depth_mm", 15)),
        "face_count": int(features.get("face_count", 10)),
        "hole_count": int(features.get("hole_count", 2)),
        "estimated_setups": int(features.get("estimated_setups", 2)),
        "quantity": int(features.get("quantity", 1)),
        "machinability": mach,
    }

    X = np.array([[row[c] for c in feature_cols]])

    time_pred = float(model_time.predict(X)[0])
    price_pred = float(model_price.predict(X)[0])

    # Bornes de sécurité
    time_pred = max(2.0, time_pred)
    price_pred = max(5.0, price_pred)

    # Score de confiance très simplifié (basé sur la version)
    confidence = 0.55 if version.startswith("v0.") else 0.75

    return {
        "success": True,
        "model_version": version,
        "estimated_time_min": round(time_pred, 2),
        "estimated_unit_price": round(price_pred, 2),
        "confidence_score": confidence,
        "features_used": row
    }


def main():
    if len(sys.argv) > 1:
        # Fichier JSON en argument
        with open(sys.argv[1]) as f:
            features = json.load(f)
    else:
        # stdin
        features = json.load(sys.stdin)

    try:
        result = predict(features)
        print(json.dumps(result, ensure_ascii=False))
        sys.exit(0)
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
