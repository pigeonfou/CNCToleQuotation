#!/bin/bash
#
# Corrige les permissions pour que Apache (www-data) puisse
# - lire config.php, les modèles ML
# - écrire dans tmp/, uploads/, logs/
# - exécuter le venv Python
#
# Usage : sudo ./scripts/fix-permissions.sh
#

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Exécutez avec sudo"; exit 1; }

INSTALL_DIR="/opt/cnctolequotation"
APP_USER="cnctole"
APP_GROUP="cnctole"

if [[ ! -d "$INSTALL_DIR" ]]; then
    echo "Installation introuvable : $INSTALL_DIR"
    exit 1
fi

echo "[INFO] Ajout de www-data au groupe $APP_GROUP..."
usermod -aG "$APP_GROUP" www-data 2>/dev/null || true

echo "[INFO] Application des permissions..."
chown -R "$APP_USER:$APP_GROUP" "$INSTALL_DIR"

chmod -R 755 "$INSTALL_DIR"

# Écriture pour le groupe (Apache via groupe cnctole)
chmod -R 770 "$INSTALL_DIR/data/uploads" "$INSTALL_DIR/tmp" "$INSTALL_DIR/logs" 2>/dev/null || true

# Lecture modèles / historique
chmod -R 750 "$INSTALL_DIR/data/models" "$INSTALL_DIR/data/history" 2>/dev/null || true

# Config API lisible par le groupe
if [[ -f "$INSTALL_DIR/api/config.php" ]]; then
    chown "$APP_USER:$APP_GROUP" "$INSTALL_DIR/api/config.php"
    chmod 640 "$INSTALL_DIR/api/config.php"
fi

# Venv et core exécutables / lisibles
chmod -R 755 "$INSTALL_DIR/venv" "$INSTALL_DIR/core" 2>/dev/null || true

echo "[INFO] Redémarrage d'Apache..."
systemctl restart apache2

echo "[OK] Permissions corrigées."
echo "    Test : sudo -u www-data cat $INSTALL_DIR/data/models/active_model.txt"
