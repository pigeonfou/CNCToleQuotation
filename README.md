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

## Déployer seul sur un serveur dédié

Ubuntu 24.04 ou 26.04 x86_64, accès sudo, installation native Apache/PHP/MariaDB. Lire [le guide autonome](docs/INSTALL_UBUNTU.md). Le script refuse de réimporter une installation existante, demande un mot de passe admin, génère le secret DB et laisse le token de démonstration désactivé.

```bash
git clone --branch main https://github.com/pigeonfou/CNCToleQuotation.git
cd CNCToleQuotation
sudo bash scripts/install.sh
sudo bash scripts/install-occ.sh
```

Pour un dépôt privé, configurer l’accès Git avant de cloner. L’administration demande le compte `admin`. Les cotations nécessitent un token API distinct, créé dans l’administration. Sans OpenCascade, le serveur refuse une cotation plutôt que de générer une géométrie fictive. Le modèle ML initial est une démonstration à calibrer.

## Installer via OneForAll

Voir [docs/ONEFORALL.md](docs/ONEFORALL.md). Les chemins, services, mots de passe et procédures de mise à jour diffèrent du mode autonome. Ne pas lancer les scripts autonomes sur une instance OneForAll.

## OpenCascade

Le script autonome configure un Python Conda distinct, y compris `geometry_python`. Pour OneForAll, fournir l’exécutable OpenCascade avec le choix 16 du gestionnaire. Voir [INSTALL-OCC.md](docs/INSTALL-OCC.md).

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
