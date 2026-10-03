<?php
/**
 * Fichier de configuration exemple
 * Copié en config.php par le script d'installation
 *
 * Après install-occ.sh :
 *   geometry_python et python pointent vers le Python conda (OCC + ML)
 * Avant (venv seul) :
 *   les deux pointent vers /opt/cnctolequotation/venv/bin/python3
 */
return [
    'db' => [
        'host'     => 'localhost',
        'port'     => 3306,
        'name'     => 'cnctolequotation',
        'user'     => 'cnctole',
        'password' => 'CHANGE_ME',
        'charset'  => 'utf8mb4',
    ],
    'paths' => [
        'root'             => '/opt/cnctolequotation',
        'uploads'          => '/opt/cnctolequotation/data/uploads',
        'models'           => '/opt/cnctolequotation/data/models',
        'logs'             => '/opt/cnctolequotation/logs',
        'tmp'              => '/opt/cnctolequotation/tmp',
        // Python pour l'analyse géométrique (OpenCascade si install-occ.sh a été lancé)
        'geometry_python'  => '/opt/cnctolequotation/venv/bin/python3',
        // Python pour la prédiction ML
        'python'           => '/opt/cnctolequotation/venv/bin/python3',
        'geometry'         => '/opt/cnctolequotation/core/geometry/analyze.py',
        'predict'          => '/opt/cnctolequotation/core/ml/predict.py',
    ],
    'security' => [
        'max_upload_mb' => 50,
        'allowed_ext'   => ['step', 'stp', 'iges', 'igs'],
    ],
];
