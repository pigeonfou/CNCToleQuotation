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

- C / Python 3 (analyse géométrique + ML)
- PHP 8.x (API + Admin)
- JavaScript vanilla + CSS
- MariaDB / MySQL
- Apache 2.4
- Shell bash

## Installation rapide

```bash
sudo ./scripts/install.sh
```

Voir `docs/INSTALL.md` pour les détails.

## Structure

Voir `docs/ARCHITECTURE.md`.

## Licence

Propriétaire – pigeonfou
