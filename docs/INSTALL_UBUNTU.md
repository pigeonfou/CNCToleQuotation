# CNCToleQuotation autonome — Ubuntu 24.04 / 26.04

Cible : serveur dédié x86_64, accès sudo, Apache/PHP et MariaDB. Cette procédure est distincte de [OneForAll](ONEFORALL.md). Les dépendances ML sont résolues lors de l’installation ; un environnement OpenCascade séparé est nécessaire pour les fichiers STEP/IGES. La validation complète doit être effectuée sur le serveur cible.

## Installation initiale

```bash
sudo apt-get update
sudo apt-get install -y git ca-certificates
git clone --branch main https://github.com/pigeonfou/CNCToleQuotation.git
cd CNCToleQuotation
sudo bash scripts/install.sh
```

Pour un dépôt privé, autoriser d’abord la lecture Git (clé de déploiement ou accès GitHub existant). Le script demande puis confirme le mot de passe `admin` (12 caractères minimum), crée un secret MariaDB aléatoire et protège l’administration par HTTP Basic Auth. La base est importée une seule fois ; le token de démonstration reste désactivé. Aucun secret n’est affiché.

L’administration écoute sur `http://IP_LAN/`. Sur le serveur, `curl -i http://127.0.0.1/` doit retourner 401 sans identifiants. Configurer HTTPS avec votre PKI LAN ou un tunnel avant l’utilisation sur un réseau non fiable. Le script retire seulement le site Apache de démonstration, et suppose un serveur dédié ; ne pas l’appliquer à un hôte Apache partagé sans adaptation.

Configuration : `/opt/cnctolequotation/api/config.php` ; données : `/opt/cnctolequotation/data` ; mots de passe admin hashés : `/etc/cnctolequotation/admin.htpasswd`. Le code et la configuration sont root, lisibles par le groupe `cnctole` auquel appartient Apache. Les répertoires de données sont inscriptibles par l’application.

## OpenCascade et premier test

```bash
sudo bash scripts/install-occ.sh
/opt/miniconda3/envs/pyocc/bin/python -c 'from OCC.Core.STEPControl import STEPControl_Reader; print("OpenCascade OK")'
```

Le script configure `python` et `geometry_python`. Voir [INSTALL-OCC.md](INSTALL-OCC.md). Les bibliothèques OCCT C++ seules ne suffisent pas : le binding Python doit être importable par le Python configuré. Sans ce binding, une cotation est refusée. Le modèle initial ML est une démonstration à calibrer sur des données métier.

Se connecter comme admin, créer un token API aléatoire distinct dans **Tokens API**, puis utiliser la requête décrite dans [API.md](API.md) avec ce token. Le endpoint `/api/v1/quote` utilise Bearer, indépendamment du compte Basic Auth de l’administration. Ne pas utiliser `demo-token-change-me`.

Tester un fichier STEP connu, vérifier `geometry.engine=opencascade`, les matériaux, quantités, résultats et l’historique. Contrôler aussi les refus sans token et sans OCC. Redémarrer Apache/MariaDB et vérifier la persistance.

## Sauvegarde et mise à jour autonome

Ne pas relancer `install.sh` sur une installation existante : il refuse une base ou configuration existante. Avant une mise à jour, sauvegarder le répertoire applicatif, le fichier de compte admin et la base MariaDB dans un répertoire root privé :

```bash
sudo install -d -m 0700 /var/backups/cnctolequotation/avant-mise-a-jour
sudo tar -C / -czf /var/backups/cnctolequotation/avant-mise-a-jour/files.tar.gz opt/cnctolequotation etc/cnctolequotation
sudo sh -c 'umask 077; mariadb-dump --single-transaction --databases cnctolequotation > /var/backups/cnctolequotation/avant-mise-a-jour/database.sql'
```

Choisir un nouveau dossier de sauvegarde pour chaque mise à jour. Vérifier et tester la nouvelle source avant le déploiement ; arrêter Apache pendant le remplacement du code. Conserver `api/config.php`, `data/`, `logs/`, `tmp/` et `venv/`. Mettre à jour les dépendances dans le venv si nécessaire, relire les migrations SQL avant exécution, tester `apache2ctl configtest`, puis redémarrer et refaire la recette. Une sauvegarde du seul code ne permet pas de revenir sur une migration de base.

Pour restaurer, arrêter Apache, extraire l’archive dans `/`, restaurer la base avec `sudo mariadb < database.sql` depuis un shell root ou une redirection via sudo, contrôler les permissions et la configuration puis redémarrer. Cette restauration remplace les données actives : la tester sur un serveur de validation et sauvegarder l’état courant avant de l’utiliser.
