#!/usr/bin/env python3
"""
CNCToleQuotation - Module Learning
Réentraîne le modèle LightGBM à partir de la table learning_history.
"""

import sys
import json
import argparse
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd
from lightgbm import LGBMRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
import joblib

ROOT = Path(__file__).resolve().parents[2]
MODELS_DIR = ROOT / "data" / "models"
MODELS_DIR.mkdir(parents=True, exist_ok=True)

# Mapping matériau
MACHINABILITY = {
    "AL6061": 1.00, "AL7075": 0.85, "S235": 0.45,
    "SS304": 0.30, "SS316": 0.25, "TI6AL4V": 0.15,
    "POM": 1.20, "PA6": 1.10, "PEEK": 0.60,
}

FEATURE_COLS = [
    "volume_mm3", "surface_mm2", "bbox_x_mm", "bbox_y_mm", "bbox_z_mm",
    "removed_volume_mm3", "min_internal_radius_mm", "max_pocket_depth_mm",
    "face_count", "hole_count", "estimated_setups", "quantity", "machinability"
]


def load_from_csv(csv_path: str) -> pd.DataFrame:
    df = pd.read_csv(csv_path)
    required = FEATURE_COLS[:-1] + ["real_time_min", "real_unit_price", "material_code"]
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise ValueError(f"Colonnes manquantes dans le CSV : {missing}")
    df["machinability"] = df["material_code"].map(MACHINABILITY).fillna(0.5)
    return df


def load_from_db(db_config: dict) -> pd.DataFrame:
    """Charge les données validées depuis MariaDB."""
    import pymysql  # optionnel – sinon utiliser CSV
    # Pour rester offline et simple, on privilégie le CSV dans la V1
    raise NotImplementedError("Utilisez --csv pour la V1")


def train(df: pd.DataFrame, version: str = None):
    if len(df) < 20:
        raise ValueError("Au moins 20 échantillons validés sont nécessaires pour entraîner.")

    X = df[FEATURE_COLS]
    y_time = df["real_time_min"]
    y_price = df["real_unit_price"]

    X_train, X_test, yt_train, yt_test = train_test_split(X, y_time, test_size=0.2, random_state=42)
    _, _, yp_train, yp_test = train_test_split(X, y_price, test_size=0.2, random_state=42)

    model_time = LGBMRegressor(n_estimators=150, learning_rate=0.07, max_depth=7, num_leaves=40, random_state=42, verbosity=-1)
    model_price = LGBMRegressor(n_estimators=150, learning_rate=0.07, max_depth=7, num_leaves=40, random_state=42, verbosity=-1)

    model_time.fit(X_train, yt_train)
    model_price.fit(X_train, yp_train)

    # Métriques
    pred_t = model_time.predict(X_test)
    pred_p = model_price.predict(X_test)

    metrics = {
        "mae_time": float(mean_absolute_error(yt_test, pred_t)),
        "rmse_time": float(np.sqrt(mean_squared_error(yt_test, pred_t))),
        "r2_time": float(r2_score(yt_test, pred_t)),
        "mae_price": float(mean_absolute_error(yp_test, pred_p)),
        "rmse_price": float(np.sqrt(mean_squared_error(yp_test, pred_p))),
        "r2_price": float(r2_score(yp_test, pred_p)),
        "train_samples": len(df),
        "test_samples": len(X_test),
    }

    if version is None:
        version = "v" + datetime.now().strftime("%Y%m%d_%H%M")

    payload = {
        "version": version,
        "feature_columns": FEATURE_COLS,
        "model_time": model_time,
        "model_price": model_price,
        "algorithm": "lightgbm",
        "train_samples": len(df),
        "metrics": metrics,
        "trained_at": datetime.now().isoformat(),
    }

    model_path = MODELS_DIR / f"model_{version}.joblib"
    joblib.dump(payload, model_path)

    # Active ce modèle
    (MODELS_DIR / "active_model.txt").write_text(version)

    meta = {
        "version": version,
        "file": model_path.name,
        "metrics": metrics,
        "trained_at": payload["trained_at"],
    }
    with open(MODELS_DIR / f"model_{version}.json", "w") as f:
        json.dump(meta, f, indent=2)

    print(json.dumps({"success": True, "version": version, "metrics": metrics}, indent=2))
    return 0


def main():
    parser = argparse.ArgumentParser(description="Réentraîne le modèle CNCToleQuotation")
    parser.add_argument("--csv", required=True, help="Fichier CSV de l'historique validé")
    parser.add_argument("--version", default=None, help="Version du modèle (ex: v1.2.0)")
    args = parser.parse_args()

    df = load_from_csv(args.csv)
    return train(df, args.version)


if __name__ == "__main__":
    sys.exit(main())
