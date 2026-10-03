# API Reference – CNCToleQuotation

## Authentification

Toutes les requêtes doivent inclure l’en-tête :

```
Authorization: Bearer <votre_token>
```

Le token de démonstration après installation est : `demo-token-change-me`

## Endpoint principal

### `POST /api/v1/quote`

Envoie un fichier 3D et obtient une cotation.

#### Request

- Content-Type : `multipart/form-data`
- Champs :
  | Champ | Type | Obligatoire | Description |
  |-------|------|-------------|-------------|
  | `file` | file | Oui | Fichier STEP / STP / IGES / IGS |
  | `material` | string | Non | Code matériau (défaut : AL6061) |
  | `quantity` | int | Non | Quantité (défaut : 1) |
  | `technology` | string | Non | `cnc_milling` / `cnc_turning` / `sheet_metal` |
  | `finish` | string | Non | Finition (défaut : as_machined) |

#### Exemple curl

```bash
curl -X POST http://localhost/api/v1/quote \
  -H "Authorization: Bearer demo-token-change-me" \
  -F "file=@piece.step" \
  -F "material=AL6061" \
  -F "quantity=5" \
  -F "technology=cnc_milling"
```

#### Réponse succès (200)

```json
{
  "success": true,
  "quote_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "technology": "cnc_milling",
  "material": "AL6061",
  "quantity": 5,
  "geometry": {
    "volume_mm3": 12500.5,
    "surface_mm2": 4200.0,
    "bbox_mm": {"x": 80.0, "y": 50.0, "z": 15.0},
    "removed_volume_mm3": 28000.0,
    "min_internal_radius_mm": 1.5,
    "face_count": 24,
    "hole_count": 4,
    "estimated_setups": 2,
    "engine": "opencascade"
  },
  "pricing": {
    "material_cost": 1.52,
    "machining_cost": 18.75,
    "setup_cost": 50.00,
    "finish_cost": 0.00,
    "unit_price": 22.40,
    "total_price": 112.00,
    "currency": "EUR"
  },
  "estimation": {
    "time_min": 25.0,
    "confidence_score": 0.55,
    "model_version": "v0.1.0"
  },
  "dfm_alerts": []
}
```

#### Erreurs courantes

| Code | Signification |
|------|---------------|
| 401 | Token manquant ou invalide |
| 413 | Fichier trop volumineux |
| 415 | Extension non autorisée |
| 422 | Échec analyse géométrique ou ML |
| 503 | Base de données indisponible |

## Matériaux disponibles (après installation)

AL6061, AL7075, S235, SS304, SS316, TI6AL4V, POM, PA6, PEEK
