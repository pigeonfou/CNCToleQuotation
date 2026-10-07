#!/usr/bin/env python3
"""
CNCToleQuotation - Analyse géométrique d'un fichier STEP/IGES
Utilise OpenCascade (pythonocc-core) si disponible, sinon mode dégradé.

Usage:
    python3 analyze.py <fichier.step> [--json]

Sortie JSON sur stdout.
"""

import sys
import os
import json
import hashlib
import math
from pathlib import Path

# Tentative d'import OpenCascade
HAS_OCC = False
try:
    from OCC.Core.STEPControl import STEPControl_Reader
    from OCC.Core.IGESControl import IGESControl_Reader
    from OCC.Core.IFSelect import IFSelect_RetDone
    from OCC.Core.BRepGProp import brepgprop
    from OCC.Core.GProp import GProp_GProps
    from OCC.Core.Bnd import Bnd_Box
    from OCC.Core.BRepBndLib import brepbndlib
    from OCC.Core.TopExp import TopExp_Explorer
    from OCC.Core.TopAbs import TopAbs_FACE, TopAbs_EDGE, TopAbs_SOLID
    from OCC.Core.BRep import BRep_Tool
    from OCC.Core.TopoDS import topods
    from OCC.Core.BRepAdaptor import BRepAdaptor_Surface, BRepAdaptor_Curve
    from OCC.Core.GeomAbs import GeomAbs_Cylinder, GeomAbs_Plane
    HAS_OCC = True
except ImportError:
    HAS_OCC = False


def file_hash(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def analyze_with_occ(filepath: str) -> dict:
    """Analyse complète avec OpenCascade."""
    ext = Path(filepath).suffix.lower()

    if ext in (".step", ".stp"):
        reader = STEPControl_Reader()
        status = reader.ReadFile(filepath)
    elif ext in (".iges", ".igs"):
        reader = IGESControl_Reader()
        status = reader.ReadFile(filepath)
    else:
        raise ValueError(f"Extension non supportée: {ext}")

    if status != IFSelect_RetDone:
        raise RuntimeError("Impossible de lire le fichier CAD")

    reader.TransferRoots()
    shape = reader.OneShape()

    # Volume + surface
    props = GProp_GProps()
    brepgprop.VolumeProperties(shape, props)
    volume_mm3 = abs(props.Mass())  # OCC retourne mm³ si le modèle est en mm

    props_surf = GProp_GProps()
    brepgprop.SurfaceProperties(shape, props_surf)
    surface_mm2 = abs(props_surf.Mass())

    # Bounding box
    bbox = Bnd_Box()
    brepbndlib.Add(shape, bbox)
    xmin, ymin, zmin, xmax, ymax, zmax = bbox.Get()
    bbox_x = abs(xmax - xmin)
    bbox_y = abs(ymax - ymin)
    bbox_z = abs(zmax - zmin)

    # Volume du brut approximatif (bounding box)
    stock_volume = bbox_x * bbox_y * bbox_z
    removed_volume = max(0.0, stock_volume - volume_mm3)

    # Comptage des faces
    face_count = 0
    explorer = TopExp_Explorer(shape, TopAbs_FACE)
    while explorer.More():
        face_count += 1
        explorer.Next()

    # Détection approximative des trous (cylindres)
    hole_count = 0
    min_radius = 9999.0
    max_depth = 0.0

    explorer = TopExp_Explorer(shape, TopAbs_FACE)
    while explorer.More():
        face = topods.Face(explorer.Current())
        surf = BRepAdaptor_Surface(face)
        if surf.GetType() == GeomAbs_Cylinder:
            hole_count += 1
            radius = surf.Cylinder().Radius()
            if radius < min_radius:
                min_radius = radius
        explorer.Next()

    if min_radius > 9000:
        min_radius = 1.0  # valeur par défaut si aucun rayon détecté

    # Estimation basique du nombre de setups (très simplifiée)
    # Si une dimension est nettement plus petite → probablement 3 axes
    dims = sorted([bbox_x, bbox_y, bbox_z])
    if dims[0] < dims[2] * 0.15:
        estimated_setups = 2
    else:
        estimated_setups = 3

    return {
        "success": True,
        "engine": "opencascade",
        "volume_mm3": round(volume_mm3, 3),
        "surface_mm2": round(surface_mm2, 3),
        "bbox_x_mm": round(bbox_x, 3),
        "bbox_y_mm": round(bbox_y, 3),
        "bbox_z_mm": round(bbox_z, 3),
        "removed_volume_mm3": round(removed_volume, 3),
        "min_internal_radius_mm": round(min_radius, 4),
        "max_pocket_depth_mm": round(max(bbox_x, bbox_y, bbox_z) * 0.3, 3),  # approximation
        "face_count": face_count,
        "hole_count": hole_count,
        "estimated_setups": estimated_setups,
        "dfm_alerts": []
    }


def analyze_fallback(filepath: str) -> dict:
    """
    Mode dégradé sans OpenCascade.
    Ne peut pas vraiment analyser la géométrie → valeurs par défaut + warning.
    """
    size = os.path.getsize(filepath)
    # Heuristique très grossière basée sur la taille du fichier
    approx_volume = max(1000.0, size / 50.0)

    return {
        "success": True,
        "engine": "fallback",
        "volume_mm3": round(approx_volume, 3),
        "surface_mm2": round(approx_volume ** (2/3) * 6, 3),
        "bbox_x_mm": 50.0,
        "bbox_y_mm": 50.0,
        "bbox_z_mm": 20.0,
        "removed_volume_mm3": round(approx_volume * 1.5, 3),
        "min_internal_radius_mm": 1.0,
        "max_pocket_depth_mm": 15.0,
        "face_count": 10,
        "hole_count": 2,
        "estimated_setups": 2,
        "dfm_alerts": [
            {
                "code": "NO_OCC",
                "severity": "warning",
                "message": "OpenCascade non disponible – analyse géométrique dégradée (valeurs approximatives)"
            }
        ]
    }


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"success": False, "error": "Usage: analyze.py <fichier> [--json]"}))
        sys.exit(1)

    filepath = sys.argv[1]
    if not os.path.isfile(filepath):
        print(json.dumps({"success": False, "error": f"Fichier introuvable: {filepath}"}))
        sys.exit(1)

    try:
        if HAS_OCC:
            result = analyze_with_occ(filepath)
        else:
            if os.environ.get('CNCTOLE_ALLOW_FALLBACK', '1') != '1':
                raise RuntimeError('OpenCascade requis : configurez le moteur géométrique avant une cotation réelle.')
            result = analyze_fallback(filepath)

        result["file_hash"] = file_hash(filepath)
        result["file_size"] = os.path.getsize(filepath)

        print(json.dumps(result, ensure_ascii=False, indent=None))
        sys.exit(0)

    except Exception as e:
        print(json.dumps({
            "success": False,
            "error": str(e),
            "engine": "opencascade" if HAS_OCC else "fallback"
        }))
        sys.exit(1)


if __name__ == "__main__":
    main()
