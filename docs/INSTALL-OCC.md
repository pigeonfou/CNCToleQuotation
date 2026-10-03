# Installation OpenCascade (Option A – conda)

`pythonocc-core` n’est **pas** disponible sur PyPI.  
Utilisez le script fourni :

```bash
cd /tmp
git clone https://github.com/pigeonfou/CNCToleQuotation.git
cd CNCToleQuotation
sudo chmod +x scripts/install-occ.sh
sudo ./scripts/install-occ.sh
```

## Ce que fait le script

1. Installe Miniconda dans `/opt/miniconda3` (si absent)
2. Crée l’environnement `pyocc` (Python 3.12)
3. Installe `pythonocc-core` depuis conda-forge
4. Installe lightgbm / sklearn / joblib / pandas dans le même env
5. Met à jour `/opt/cnctolequotation/api/config.php` pour utiliser ce Python

## Vérification

```bash
/opt/miniconda3/envs/pyocc/bin/python -c "from OCC.Core.STEPControl import STEPControl_Reader; print('OCC OK')"
```

Puis lancez une cotation : `geometry.engine` doit valoir `"opencascade"` (plus `"fallback"`).

## Désinstallation

```bash
sudo rm -rf /opt/miniconda3
# Remettre le Python venv dans config.php si besoin
```
