#!/bin/bash
#
# Script de réparation Apache pour CNCToleQuotation
# À exécuter si la page par défaut d'Apache s'affiche au lieu de l'application
#
# Usage : sudo ./scripts/fix-apache.sh
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || err "Ce script doit être exécuté avec sudo."

INSTALL_DIR="/opt/cnctolequotation"

if [[ ! -d "$INSTALL_DIR/web" ]]; then
    err "Le répertoire $INSTALL_DIR/web n'existe pas. L'installation est-elle complète ?"
fi

log "Désactivation du site Apache par défaut..."
a2dissite 000-default.conf 2>/dev/null || a2dissite 000-default 2>/dev/null || true

log "Écriture de la configuration CNCToleQuotation..."
cat > /etc/apache2/sites-available/cnctolequotation.conf <<'EOF'
<VirtualHost *:80>
    ServerAdmin admin@localhost
    ServerName cnctolequotation
    ServerAlias *

    DocumentRoot /opt/cnctolequotation/web

    <Directory /opt/cnctolequotation/web>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        DirectoryIndex index.php index.html
    </Directory>

    Alias /api /opt/cnctolequotation/api
    <Directory /opt/cnctolequotation/api>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <DirectoryMatch "^/opt/cnctolequotation/(core|data|sql|scripts|cli|logs|tmp|venv)">
        Require all denied
    </DirectoryMatch>

    ErrorLog ${APACHE_LOG_DIR}/cnctole_error.log
    CustomLog ${APACHE_LOG_DIR}/cnctole_access.log combined

    <IfModule mod_php.c>
        php_value upload_max_filesize 55M
        php_value post_max_size 60M
        php_value max_execution_time 180
        php_value memory_limit 512M
    </IfModule>
</VirtualHost>
EOF

log "Activation des modules nécessaires..."
a2enmod rewrite headers 2>/dev/null || true

log "Activation du site cnctolequotation..."
a2ensite cnctolequotation.conf 2>/dev/null || a2ensite cnctolequotation 2>/dev/null || true

log "Vérification de la configuration Apache..."
if apache2ctl configtest; then
    systemctl reload apache2
    log "Apache rechargé avec succès."
else
    err "La configuration Apache contient des erreurs."
fi

echo ""
log "=============================================="
log " Réparation terminée."
log " Ouvrez maintenant : http://<IP-du-serveur>/"
log "=============================================="
echo ""
log "Si le problème persiste, vérifiez :"
echo "  ls -la /opt/cnctolequotation/web/"
echo "  cat /etc/apache2/sites-enabled/*"
echo "  tail -50 /var/log/apache2/cnctole_error.log"
echo "  tail -50 /var/log/apache2/error.log"
