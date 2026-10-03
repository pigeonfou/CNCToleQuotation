# CNCToleQuotation

Moteur de cotation automatique **100 % offline** pour pièces CNC (fraisage / tournage) et tôlerie.

## Caractéristiques

- Analyse géométrique déterministe (OpenCascade)
- Estimation hybride + Machine Learning (LightGBM)
- Module Learning pour réentraînement sur historique réel
- API REST pure PHP (Apache + mod_php)
- Interface d’administration PHP + JavaScript vanilla
- Fonctionne sur Ubuntu Server 24.04 LTS x64 sans interface graphique
- Aucun appel réseau pendant la cotation (air-gapped)

## Stack

| Composant              | Technologie                          |
|------------------------|--------------------------------------|
| Analyse géométrique    | Python 3 + OpenCascade (pythonocc)  |
| Machine Learning       | LightGBM + scikit-learn + joblib     |
| API REST               | PHP 8 + Apache 2.4                   |
| Base de données        | MariaDB 10.11+                       |
| Interface admin        | PHP + JavaScript vanilla + CSS       |
| Scripts                | Bash                                 |

---

## Déploiement complet (Ubuntu Server 24.04 frais)

Cette procédure part d’un **Ubuntu Server 24.04 LTS x64** fraîchement installé (sans interface graphique).

### 1. Prérequis système

Connectez-vous en root ou avec un compte sudo :

```bash
sudo -i
```

Mettez à jour le système :

```bash
apt update && apt upgrade -y
```

Installez les outils de base :

```bash
apt install -y git curl wget unzip ca-certificates
```

### 2. Récupération du projet

```bash
cd /opt
git clone https://github.com/pigeonfou/CNCToleQuotation.git
cd CNCToleQuotation
```

### 3. Lancement de l’installation automatique

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

Le script effectue automatiquement :

1. Création de l’utilisateur système `cnctole`
2. Installation de tous les paquets (Apache, PHP, MariaDB, Python, OpenCascade, etc.)
3. Création de l’environnement virtuel Python et installation des packages ML
4. Création de la base de données + import du schéma
5. Configuration d’Apache (VirtualHost)
6. Génération d’un modèle ML initial de démonstration
7. Mise en place des permissions

**Durée estimée** : 5 à 15 minutes selon la connexion internet (les paquets sont téléchargés uniquement pendant l’installation).

### 4. Vérifications post-installation

```bash
# Apache tourne ?
systemctl status apache2

# MariaDB tourne ?
systemctl status mariadb

# Test de l’API (depuis le serveur)
curl -X POST http://localhost/api/v1/quote \
  -H "Authorization: Bearer demo-token-change-me" \
  -F "file=@/chemin/vers/une/piece.step" \
  -F "material=AL6061" \
  -F "quantity=1"
```

### 5. Accès à l’interface d’administration

Depuis un navigateur :

```
http://<IP-du-serveur>/
```

Exemple : `http://192.168.1.50/`

### 6. Sécurisation obligatoire (à faire immédiatement)

#### 6.1 Changer le mot de passe MariaDB

```bash
mysql -u root
```

```sql
ALTER USER 'cnctole'@'localhost' IDENTIFIED BY 'VOTRE_NOUVEAU_MOT_DE_PASSE_FORT';
FLUSH PRIVILEGES;
EXIT;
```

Puis éditez le fichier de configuration :

```bash
nano /opt/cnctolequotation/api/config.php
```

Modifiez la ligne `'password' => '...'`.

#### 6.2 Révoquer le token de démonstration

Connectez-vous à la base :

```bash
mysql -u cnctole -p cnctolequotation
```

```sql
UPDATE api_tokens SET is_active = 0 WHERE name = 'Demo Token';
-- Créez un nouveau token (remplacez 'mon-super-token' par une valeur aléatoire longue)
INSERT INTO api_tokens (name, token_hash, is_active)
VALUES ('Production', SHA2('mon-super-token', 256), 1);
EXIT;
```

#### 6.3 (Recommandé) Firewall

```bash
ufw allow OpenSSH
ufw allow 80/tcp
ufw enable
```

### 7. Utilisation de l’API

```bash
curl -X POST http://<IP>/api/v1/quote \
  -H "Authorization: Bearer mon-super-token" \
  -F "file=@piece.step" \
  -F "material=AL6061" \
  -F "quantity=5" \
  -F "technology=cnc_milling"
```

### 8. Module Learning (réentraînement)

1. Exportez les données validées :

```bash
/opt/cnctolequotation/cli/export_history.sh > /opt/cnctolequotation/data/history/export.csv
```

2. Réentraînez le modèle :

```bash
cd /opt/cnctolequotation
source venv/bin/activate
python3 core/learning/train.py --csv data/history/export.csv --version v1.0.0
deactivate
```

Le nouveau modèle devient automatiquement actif.

---

## Structure du projet

```
CNCToleQuotation/
├── api/                    # API REST PHP
├── core/
│   ├── geometry/           # Analyse OpenCascade
│   ├── ml/                 # LightGBM train & predict
│   └── learning/           # Réentraînement
├── web/                    # Interface d’administration
├── cli/                    # Outils en ligne de commande
├── data/
│   ├── models/             # Modèles ML (.joblib)
│   ├── history/            # Historique d’entraînement
│   └── uploads/            # Fichiers temporaires
├── sql/schema.sql
├── scripts/install.sh
└── docs/
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [API Reference](docs/API.md)
- [Module Learning](docs/LEARNING.md)

## Licence

Propriétaire – pigeonfou
