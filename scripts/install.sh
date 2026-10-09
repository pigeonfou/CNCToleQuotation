#!/usr/bin/env bash
# Fresh standalone installation only; OneForAll has its own installer.
set -euo pipefail
umask 027
[[ $EUID -eq 0 ]] || { echo 'Exécuter avec sudo.' >&2; exit 1; }
source /etc/os-release
[[ $ID == ubuntu && ( $VERSION_ID == 24.04 || $VERSION_ID == 26.04 ) && $(uname -m) == x86_64 ]] || { echo 'Ubuntu 24.04/26.04 x86_64 requis.' >&2; exit 1; }
INSTALL_DIR=/opt/cnctolequotation
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
[[ ! -e $INSTALL_DIR/api/config.php && ! -e /etc/apache2/sites-available/cnctolequotation.conf ]] || { echo 'Installation existante : sauvegarder et utiliser la procédure de mise à jour, sans réimporter le schéma.' >&2; exit 1; }
read -r -s -p 'Mot de passe admin (12 caractères minimum) : ' ADMIN_PASSWORD; echo
read -r -s -p 'Confirmer : ' ADMIN_CONFIRM; echo
[[ ${#ADMIN_PASSWORD} -ge 12 && $ADMIN_PASSWORD == "$ADMIN_CONFIRM" ]] || { echo 'Mot de passe invalide.' >&2; exit 1; }
unset ADMIN_CONFIRM
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apache2 apache2-utils libapache2-mod-php php-cli php-mysql php-mbstring php-xml php-curl php-zip php-gd mariadb-server mariadb-client python3 python3-venv build-essential git curl ca-certificates rsync openssl libgomp1
id cnctole >/dev/null 2>&1 || useradd --system --home-dir "$INSTALL_DIR" --shell /usr/sbin/nologin cnctole
systemctl enable --now mariadb
EXISTS=$(mariadb -Nse "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='cnctolequotation'")
[[ $EXISTS == 0 ]] || { echo 'Base existante : import refusé pour conserver les données.' >&2; exit 1; }
install -d -m 0755 "$INSTALL_DIR"
rsync -a --exclude='.git' --exclude='venv' --exclude='.venv' --exclude='api/config.php' --exclude='data/uploads/*' --exclude='data/models/*' --exclude='data/history/*' --exclude='tmp/*' --exclude='logs/*' "$SCRIPT_DIR/" "$INSTALL_DIR/"
install -d -m 2770 -o cnctole -g cnctole "$INSTALL_DIR/data" "$INSTALL_DIR/data/uploads" "$INSTALL_DIR/data/models" "$INSTALL_DIR/data/history" "$INSTALL_DIR/logs" "$INSTALL_DIR/tmp"
python3 -m venv "$INSTALL_DIR/venv"
install -d -m 0700 /var/tmp/cnctolequotation-install
TMPDIR=/var/tmp/cnctolequotation-install "$INSTALL_DIR/venv/bin/pip" install numpy pandas scikit-learn lightgbm joblib scipy
DB_PASSWORD=$(openssl rand -hex 32)
mariadb <<SQL
CREATE DATABASE cnctolequotation CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'cnctole'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER 'cnctole'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL ON cnctolequotation.* TO 'cnctole'@'localhost';
SQL
# Initial schema contains a demo token: import it disabled, never usable.
sed "s/SHA2('demo-token-change-me', 256), 1/SHA2('demo-token-change-me', 256), 0/" "$INSTALL_DIR/sql/schema.sql" | mariadb
cat > "$INSTALL_DIR/api/config.php" <<PHP
<?php
return [
 'db'=>['host'=>'localhost','port'=>3306,'name'=>'cnctolequotation','user'=>'cnctole','password'=>'$DB_PASSWORD','charset'=>'utf8mb4'],
 'paths'=>['root'=>'$INSTALL_DIR','uploads'=>'$INSTALL_DIR/data/uploads','models'=>'$INSTALL_DIR/data/models','logs'=>'$INSTALL_DIR/logs','tmp'=>'$INSTALL_DIR/tmp','geometry_python'=>'$INSTALL_DIR/venv/bin/python','python'=>'$INSTALL_DIR/venv/bin/python','geometry'=>'$INSTALL_DIR/core/geometry/analyze.py','predict'=>'$INSTALL_DIR/core/ml/predict.py'],
 'security'=>['max_upload_mb'=>50,'allowed_ext'=>['step','stp','iges','igs']]
];
PHP
unset DB_PASSWORD
chown -R root:cnctole "$INSTALL_DIR"
chmod -R g+rX,o-rwx "$INSTALL_DIR"
chmod 0755 "$INSTALL_DIR"
chown -R cnctole:cnctole "$INSTALL_DIR/data" "$INSTALL_DIR/logs" "$INSTALL_DIR/tmp"
find "$INSTALL_DIR/data" "$INSTALL_DIR/logs" "$INSTALL_DIR/tmp" -type d -exec chmod 2770 {} +
find "$INSTALL_DIR/data" "$INSTALL_DIR/logs" "$INSTALL_DIR/tmp" -type f -exec chmod 0660 {} +
chmod 0640 "$INSTALL_DIR/api/config.php"
usermod -aG cnctole www-data
install -d -m 0750 -o root -g www-data /etc/cnctolequotation
printf '%s\n' "$ADMIN_PASSWORD" | htpasswd -iBc /etc/cnctolequotation/admin.htpasswd admin
unset ADMIN_PASSWORD
chown root:www-data /etc/cnctolequotation/admin.htpasswd
chmod 0640 /etc/cnctolequotation/admin.htpasswd
runuser -u cnctole -- env CNCTOLE_MODELS_DIR="$INSTALL_DIR/data/models" "$INSTALL_DIR/venv/bin/python" "$INSTALL_DIR/core/ml/create_initial_model.py"
printf 'v0.1.0\n' > "$INSTALL_DIR/data/models/active_model.txt"
chown cnctole:cnctole "$INSTALL_DIR/data/models/active_model.txt"
chmod 0660 "$INSTALL_DIR/data/models/active_model.txt"
cat > /etc/apache2/sites-available/cnctolequotation.conf <<'APACHE'
<VirtualHost *:80>
    ServerName cnctolequotation
    DocumentRoot /opt/cnctolequotation/web
    SetEnv CNCTOLE_ALLOW_FALLBACK 0
    SetEnv CNCTOLE_MODELS_DIR /opt/cnctolequotation/data/models
    <Directory /opt/cnctolequotation/web>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        DirectoryIndex index.php
        AuthType Basic
        AuthName "CNCToleQuotation administration"
        AuthUserFile /etc/cnctolequotation/admin.htpasswd
        Require valid-user
    </Directory>
    Alias /api /opt/cnctolequotation/api
    <Directory /opt/cnctolequotation/api>
        Options -Indexes
        AllowOverride None
        Require all granted
        CGIPassAuth On
        SetEnvIf Authorization "(.*)" HTTP_AUTHORIZATION=$1
        RewriteEngine On
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^v1/quote$ v1/quote.php [L,QSA]
        <Files "config.php">
            Require all denied
        </Files>
    </Directory>
    <DirectoryMatch "^/opt/cnctolequotation/(core|data|sql|scripts|cli|logs|tmp|venv|tests|docs|packaging)">
        Require all denied
    </DirectoryMatch>
    <IfModule mod_php.c>
        php_value upload_max_filesize 55M
        php_value post_max_size 60M
        php_value max_execution_time 300
        php_value memory_limit 512M
    </IfModule>
    ErrorLog ${APACHE_LOG_DIR}/cnctole_error.log
    CustomLog ${APACHE_LOG_DIR}/cnctole_access.log combined
</VirtualHost>
APACHE
a2enmod rewrite headers env auth_basic authn_file
# Dedicated fresh server: disable only the stock default site.
a2dissite 000-default.conf >/dev/null 2>&1 || true
a2ensite cnctolequotation.conf
apache2ctl configtest
systemctl enable apache2
systemctl restart apache2
CODE=$(curl --silent --show-error --max-time 10 --output /dev/null --write-out '%{http_code}' http://127.0.0.1/)
[[ $CODE == 401 ]] || { echo "Contrôle admin attendu 401, reçu $CODE" >&2; exit 1; }
echo 'Socle installé. Administration : http://IP_LAN/ ; identifiant admin.'
echo 'Installer OpenCascade avec scripts/install-occ.sh avant toute cotation réelle.'
echo 'Le modèle ML initial est un modèle de démonstration à calibrer ; aucun token API actif par défaut.'
echo 'Configurer HTTPS ou un tunnel avant un accès depuis un réseau non fiable.'
