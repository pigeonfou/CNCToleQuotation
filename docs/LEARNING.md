# Module Learning – CNCToleQuotation

## Objectif

Améliorer en continu la précision du moteur de cotation en réentraînant le modèle LightGBM sur les commandes réellement produites et validées.

## Workflow recommandé

1. **Collecte**  
   Après chaque commande livrée, enregistrer :
   - le fichier STEP original (hash)
   - les features géométriques (déjà stockées dans `quotes`)
   - le **temps réel** machine (minutes)
   - le **prix unitaire réel** facturé

2. **Validation**  
   Insérer ou importer ces données dans la table `learning_history` avec `is_validated = 1`.

3. **Entraînement**  
   ```bash
   cd /opt/cnctolequotation
   source venv/bin/activate
   python3 core/learning/train.py --csv data/history/export_validated.csv --version v1.0.0
   ```

4. **Activation**  
   Le script écrit automatiquement la version dans `data/models/active_model.txt`.

## Format CSV attendu

```csv
volume_mm3,surface_mm2,bbox_x_mm,bbox_y_mm,bbox_z_mm,removed_volume_mm3,min_internal_radius_mm,max_pocket_depth_mm,face_count,hole_count,estimated_setups,quantity,material_code,real_time_min,real_unit_price
12500.5,4200.0,80,50,15,28000,1.5,12,24,4,2,5,AL6061,28.5,24.80
...
```

## Métriques suivies

- MAE (Mean Absolute Error) – temps et prix
- RMSE
- R²

Ces métriques sont stockées dans le fichier `.json` du modèle et dans la table `ml_models`.

## Bonnes pratiques

- Minimum 30–50 pièces validées avant un premier réentraînement sérieux
- Toujours garder les anciens modèles (versioning)
- Comparer les métriques avant d’activer un nouveau modèle en production
- Ne jamais entraîner sur des données non validées (`is_validated = 0`)
