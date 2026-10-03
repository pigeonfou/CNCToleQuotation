#!/bin/bash
# Exporte les données validées de learning_history vers un CSV pour réentraînement
# Usage : ./cli/export_history.sh > data/history/export.csv

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/api/config.php" 2>/dev/null || true

# Lecture directe via mysql (mot de passe à adapter)
mysql -u cnctole -pcnctole_change_me_2024 cnctolequotation -N -B -e "
SELECT
  volume_mm3, surface_mm2, bbox_x_mm, bbox_y_mm, bbox_z_mm,
  removed_volume_mm3, min_internal_radius_mm, max_pocket_depth_mm,
  face_count, hole_count, estimated_setups, quantity,
  material_code, real_time_min, real_unit_price
FROM learning_history
WHERE is_validated = 1
" | sed '1i volume_mm3,surface_mm2,bbox_x_mm,bbox_y_mm,bbox_z_mm,removed_volume_mm3,min_internal_radius_mm,max_pocket_depth_mm,face_count,hole_count,estimated_setups,quantity,material_code,real_time_min,real_unit_price'
