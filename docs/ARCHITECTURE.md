# Architecture – CNCToleQuotation

## Vue d’ensemble

Application 100 % offline de cotation CNC / tôlerie.

```
Client (site web)
      │
      │  POST /api/v1/quote  (multipart + Bearer token)
      ▼
Apache + mod_php
      │
      ├── api/v1/quote.php          ← point d’entrée
      │         │
      │         ├── core/geometry/analyze.py   (OpenCascade ou fallback)
      │         │
      │         └── core/ml/predict.py         (LightGBM)
      │
      └── MariaDB (features + historique + modèles)
```

## Flux de cotation

1. Authentification Bearer token
2. Validation du fichier (extension, taille)
3. Analyse géométrique (Python + OpenCascade)
4. Prédiction ML (temps + prix)
5. Calcul final (formule configurable)
6. Enregistrement en base
7. Réponse JSON

## Modules

| Module | Langage | Rôle |
|--------|---------|------|
| `api/` | PHP | REST API + auth |
| `core/geometry/` | Python (+ C via OCC) | Extraction de features |
| `core/ml/` | Python | LightGBM train & predict |
| `core/learning/` | Python + PHP | Réentraînement |
| `web/` | PHP + JS vanilla | Interface admin |
| `cli/` | Bash + Python | Outils maintenance |

## Sécurité

- Aucun appel réseau pendant la cotation
- Tokens API stockés en SHA-256
- Processus Python isolés via `shell_exec` contrôlé
- Répertoires sensibles interdits par Apache
- Uploads nettoyés automatiquement

## Extensibilité

- Nouveaux matériaux → table `materials`
- Nouveaux paramètres → table `config`
- Nouveaux modèles → versioning dans `ml_models` + `data/models/`
