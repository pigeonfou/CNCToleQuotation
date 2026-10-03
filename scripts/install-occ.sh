#!/bin/bash
#
# CNCToleQuotation – Installation OpenCascade via Miniconda (Option A)
#
# Installe Miniconda dans /opt/miniconda3, crée l'env "pyocc"
# avec pythonocc-core, puis met à jour la config de l'application.
#
# Usage : sudo ./scripts/install-occ.sh
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || err "Exécutez avec sudo."

INSTALL_DIR="/opt/cnctolequotation"
MINICONDA_DIR="/opt/miniconda3"
ENV_NAME="pyocc"
PYTHON_OCC="${MINICONDA_DIR}/envs/${ENV_NAME}/bin/python"

if [[ ! -d "$INSTALL_DIR" ]]; then
    err "CNCToleQuotation n'est pas installé dans $INSTALL_DIR"
fi

# --------------------------------------------------
# 1. Miniconda
# --------------------------------------------------
if [[ ! -x "${MINICONDA_DIR}/bin/conda" ]]; then
    log "Téléchargement et installation de Miniconda..."
    TMP_SH="/tmp/Miniconda3-latest-Linux-x86_64.sh"
    curl -fsSL -o "$TMP_SH" https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    bash "$TMP_SH" -b -p "$MINICONDA_DIR"
    rm -f "$TMP_SH"
    log "Miniconda installé dans $MINICONDA_DIR"
else
    log "Miniconda déjà présent."
fi

export PATH="${MINICONDA_DIR}/bin:$PATH"

# --------------------------------------------------
# 2. Environnement pyocc + pythonocc-core
# --------------------------------------------------
if [[ ! -x "$PYTHON_OCC" ]]; then
    log "Création de l'environnement conda '${ENV_NAME}' (python 3.12)..."
    conda create -y -n "$ENV_NAME" python=3.12
fi

log "Installation de pythonocc-core (conda-forge)..."
conda install -y -n "$ENV_NAME" -c conda-forge pythonocc-core

log "Installation des dépendances ML dans le même env (pour simplicité)..."
"${MINICONDA_DIR}/envs/${ENV_NAME}/bin/pip" install --quiet \
    lightgbm scikit-learn joblib pandas numpy

# --------------------------------------------------
# 3. Test OCC
# --------------------------------------------------
log "Test d'import OpenCascade..."
if ! "$PYTHON_OCC" -c "from OCC.Core.STEPControl import STEPControl_Reader; print('OCC OK')"; then
    err "Import OCC échoué."
fi

# --------------------------------------------------
# 4. Mise à jour de la config PHP
# --------------------------------------------------
CONFIG="${INSTALL_DIR}/api/config.php"
if [[ -f "$CONFIG" ]]; then
    log "Mise à jour de api/config.php (python géométrie + ML → conda)..."
    # Remplace le chemin python du venv par celui de conda
    sed -i "s|'python'\s*=>\s*'[^']*'|'python'   => '${PYTHON_OCC}'|" "$CONFIG"
    # Ajoute geometry_python si absent (rétrocompat)
    if ! grep -q "geometry_python" "$CONFIG"; then
        sed -i "s|'python'\s*=>|'geometry_python' => '${PYTHON_OCC}',\n        'python'   =>|" "$CONFIG"
    fi
    chown cnctole:cnctole "$CONFIG"
    chmod 640 "$CONFIG"
else
    warn "config.php introuvable – mettez à jour manuellement le chemin python."
fi

# Permissions lecture pour www-data (groupe cnctole)
usermod -aG cnctole www-data 2>/dev/null || true
# conda env doit être exécutable
chmod -R a+rX "${MINICONDA_DIR}/envs/${ENV_NAME}" 2>/dev/null || true

log "========================================================"
log " OpenCascade installé avec succès"
log "========================================================"
log " Python OCC : $PYTHON_OCC"
log " Test       : $PYTHON_OCC -c \"from OCC.Core.STEPControl import STEPControl_Reader; print('OK')\""
log ""
log " Relancez une cotation : le champ geometry.engine doit afficher 'opencascade'"
log "========================================================"
