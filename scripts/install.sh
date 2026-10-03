#!/bin/bash
#
# CNCToleQuotation - Script d'installation
# Ubuntu Server 24.04 LTS x64 - Mode offline après installation
#
# Usage : sudo ./scripts/install.sh
#

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# Vérifications préalables
[[ $EUID -eq 0 ]] || err "Ce script doit être exécuté en root (sudo)."
[[ $(uname -m) == "x86_64" ]] || err "Architecture x86_64 requise."

UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "unknown")
log "Détection Ubuntu : $UBUNTU_VERSION"

# Répertoire d'installation
INSTALL_DIR="/opt/cnctolequotation"
APP_USER="cnctole"
APP_GROUP="cnctole"

log "=== Installation de CNCToleQuotation ==="

# --------------------------------------------------
# 1. Utilisateur système
# --------------------------------------------------
if ! id "$APP_USER" &>/dev/null; then
    log "Création de l'utilisateur système $APP_USER..."
    useradd --system --home-dir "$INSTALL_DIR" --shell /usr/sbin/nologin "$APP_USER"
fi

# --------------------------------------------------
# 2. Paquets système
# --------------------------------------------------
log "Mise à jour des index apt (une seule fois)..."
apt-get update -qq

log "Installation des paquets système..."
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    apache2 \
    libapache2-mod-php \
    php \
    php-cli \
    php-mysql \
    php-json \
    php-mbstring \
    php-xml \
    php-curl \
    php-zip \
    php-gd \
    mariadb-server \
    mariadb-client \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    cmake \
    git \
    curl \
    wget \
    unzip \
    libocct-foundation-dev \
    libocct-data-exchange-dev \
    libocct-modeling-data-dev \
    libocct-modeling-algorithms-dev \
    libocct-ocaf-dev \
    libocct-visualization-dev \
    libocct-draw-dev \
    occt-misc \
    libboost-all-dev \
    libfreetype6-dev \
    libgl1-mesa-dev \
    libx11-dev \
    libxi-dev \
    libxmu-dev \
    libfontconfig1-dev \
    > /dev/null

log "Activation des modules Apache..."
a2enmod rewrite headers php > /dev/null || true

# --------------------------------------------------
# 3. Répertoire d'installation
# --------------------------------------------------
log "Préparation du répertoire $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
# On copie le code source depuis le répertoire courant (là où se trouve le script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rsync -a --exclude='.git' --exclude='tmp/*' --exclude='data/uploads/*' \
    "$SCRIPT_DIR/" "$INSTALL_DIR/"

chown -R "$APP_USER:$APP_GROUP" "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"
chmod -R 770 "$INSTALL_DIR/data" "$INSTALL_DIR/logs" "$INSTALL_DIR/tmp"

# --------------------------------------------------
# 4. Environnement Python (venv local)
# --------------------------------------------------
log "Création de l'environnement Python virtuel..."
python3 -m venv "$INSTALL_DIR/venv"
source "$INSTALL_DIR/venv/bin/activate"

log "Installation des packages Python (offline-ready)..."
pip install --upgrade pip wheel setuptools > /dev/null

# Packages Python nécessaires
# Note : pythonocc-core est complexe à installer purement offline.
# On installe d'abord les packages purs Python, puis on documente OCC.
pip install \
    numpy \
    pandas \
    scikit-learn \
    lightgbm \
    joblib \
    scipy \
    > /dev/null

# Tentative d'installation de pythonocc-core (peut échouer selon la version d'OCC)
# Si échec, l'analyse géométrique basculera sur un mode dégradé (bounding box + volume approximatif)
log "Tentative d'installation de pythonocc-core..."
pip install pythonocc-core 2>/dev/null || warn "pythonocc-core non installé automatiquement. Voir docs/INSTALL.md pour compilation manuelle."

deactivate

# --------------------------------------------------
# 5. Base de données
# --------------------------------------------------
log "Configuration de MariaDB..."
systemctl start mariadb
systemctl enable mariadb > /dev/null

# Sécurisation basique + création BDD
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS cnctolequotation CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'cnctole'@'localhost' IDENTIFIED BY 'cnctole_change_me_2024';
GRANT ALL PRIVILEGES ON cnctolequotation.* TO 'cnctole'@'localhost';
FLUSH PRIVILEGES;
EOF

log "Import du schéma SQL..."
mysql -u cnctole -pcnctole_change_me_2024 cnctolequotation < "$INSTALL_DIR/sql/schema.sql"

# Fichier de configuration PHP pour la BDD
cat > "$INSTALL_DIR/api/config.php" <<'PHPEOF'
<?php
/**
 * Configuration de l'application CNCToleQuotation
 * À adapter après installation
 */
return [
    'db' => [
        'host'     => 'localhost',
        'port'     => 3306,
        'name'     => 'cnctolequotation',
        'user'     => 'cnctole',
        'password' => 'cnctole_change_me_2024',
        'charset'  => 'utf8mb4',
    ],
    'paths' => [
        'root'     => '/opt/cnctolequotation',
        'uploads'  => '/opt/cnctolequotation/data/uploads',
        'models'   => '/opt/cnctolequotation/data/models',
        'logs'     => '/opt/cnctolequotation/logs',
        'tmp'      => '/opt/cnctolequotation/tmp',
        'python'   => '/opt/cnctolequotation/venv/bin/python3',
        'geometry' => '/opt/cnctolequotation/core/geometry/analyze.py',
        'predict'  => '/opt/cnctolequotation/core/ml/predict.py',
    ],
    'security' => [
        'max_upload_mb' => 50,
        'allowed_ext'   => ['step', 'stp', 'iges', 'igs'],
    ],
];
PHPEOF

chown "$APP_USER:$APP_GROUP" "$INSTALL_DIR/api/config.php"
chmod 640 "$INSTALL_DIR/api/config.php"

# --------------------------------------------------
# 6. Configuration Apache
# --------------------------------------------------
log "Configuration d'Apache..."

cat > /etc/apache2/sites-available/cnctolequotation.conf <<'APACHEEOF'
<VirtualHost *:80>
    ServerName cnctole.local
    ServerAdmin admin@localhost

    DocumentRoot /opt/cnctolequotation/web

    <Directory /opt/cnctolequotation/web>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # API
    Alias /api /opt/cnctolequotation/api
    <Directory /opt/cnctolequotation/api>
        Options -Indexes
        AllowOverride All
        Require all granted
    </Directory>

    # Sécurité
    <DirectoryMatch "/opt/cnctolequotation/(core|data|sql|scripts|cli|logs|tmp|venv)">
        Require all denied
    </DirectoryMatch>

    ErrorLog ${APACHE_LOG_DIR}/cnctole_error.log
    CustomLog ${APACHE_LOG_DIR}/cnctole_access.log combined

    # PHP
    php_value upload_max_filesize 55M
    php_value post_max_size 60M
    php_value max_execution_time 180
    php_value memory_limit 512M
</VirtualHost>
APACHEEOF

a2dissite 000-default > /dev/null || true
a2ensite cnctolequotation > /dev/null
systemctl reload apache2

# --------------------------------------------------
# 7. Modèle ML initial (basique)
# --------------------------------------------------
log "Génération d'un modèle ML initial de démonstration..."
source "$INSTALL_DIR/venv/bin/activate"
python3 "$INSTALL_DIR/core/ml/create_initial_model.py" || warn "Impossible de créer le modèle initial (fichier manquant pour le moment)."
deactivate

# --------------------------------------------------
# 8. Permissions finales
# --------------------------------------------------
chown -R "$APP_USER:$APP_GROUP" "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"
chmod -R 770 "$INSTALL_DIR/data" "$INSTALL_DIR/logs" "$INSTALL_DIR/tmp"
chmod 640 "$INSTALL_DIR/api/config.php"

# --------------------------------------------------
# Fin
# --------------------------------------------------
log "========================================================"
log " Installation terminée avec succès !"
log "========================================================"
log ""
log " Répertoire          : $INSTALL_DIR"
log " Interface web       : http://<IP-du-serveur>/"
log " API                 : http://<IP-du-serveur>/api/v1/quote"
log " Utilisateur BDD     : cnctole"
log " Mot de passe BDD    : cnctole_change_me_2024  (À CHANGER !)"
log " Token démo API      : demo-token-change-me"
log ""
log " Prochaines étapes :"
log "  1. Changer le mot de passe MariaDB"
log "  2. Générer un vrai token API via l'interface admin"
log "  3. Compiler/installer pythonocc-core si nécessaire (docs/INSTALL.md)"
log "  4. Importer votre historique de commandes dans le module Learning"
log "========================================================"
