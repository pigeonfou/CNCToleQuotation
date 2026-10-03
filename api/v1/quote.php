<?php
/**
 * CNCToleQuotation - Endpoint principal de cotation
 * POST /api/v1/quote
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');

// --------------------------------------------------
// Bootstrap
// --------------------------------------------------
$config = require __DIR__ . '/../config.php';

function json_response(array $data, int $code = 200): void
{
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function log_msg(string $msg): void
{
    global $config;
    $line = date('Y-m-d H:i:s') . ' ' . $msg . PHP_EOL;
    @file_put_contents($config['paths']['logs'] . '/api.log', $line, FILE_APPEND);
}

// --------------------------------------------------
// Méthode
// --------------------------------------------------
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['success' => false, 'error' => 'Method Not Allowed'], 405);
}

// --------------------------------------------------
// Authentification Bearer
// --------------------------------------------------
// Apache ne transmet pas toujours Authorization → plusieurs fallbacks
$authHeader = $_SERVER['HTTP_AUTHORIZATION']
    ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
    ?? '';

if ($authHeader === '' && function_exists('apache_request_headers')) {
    $headers = apache_request_headers();
    foreach ($headers as $key => $value) {
        if (strtolower($key) === 'authorization') {
            $authHeader = $value;
            break;
        }
    }
}

if (!preg_match('/Bearer\s+(\S+)/i', $authHeader, $m)) {
    json_response(['success' => false, 'error' => 'Missing or invalid Authorization header'], 401);
}
$token = $m[1];
$tokenHash = hash('sha256', $token);

try {
    $pdo = new PDO(
        sprintf('mysql:host=%s;port=%d;dbname=%s;charset=%s',
            $config['db']['host'],
            $config['db']['port'],
            $config['db']['name'],
            $config['db']['charset']
        ),
        $config['db']['user'],
        $config['db']['password'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
} catch (PDOException $e) {
    log_msg('DB connection failed: ' . $e->getMessage());
    json_response(['success' => false, 'error' => 'Database unavailable'], 503);
}

$stmt = $pdo->prepare('SELECT id, name, rate_limit FROM api_tokens WHERE token_hash = ? AND is_active = 1');
$stmt->execute([$tokenHash]);
$tokenRow = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$tokenRow) {
    json_response(['success' => false, 'error' => 'Invalid API token'], 401);
}

// Mise à jour last_used
$pdo->prepare('UPDATE api_tokens SET last_used_at = NOW() WHERE id = ?')->execute([$tokenRow['id']]);

// --------------------------------------------------
// Validation du fichier
// --------------------------------------------------
if (empty($_FILES['file']) || $_FILES['file']['error'] !== UPLOAD_ERR_OK) {
    json_response(['success' => false, 'error' => 'No file uploaded or upload error'], 400);
}

$file = $_FILES['file'];
$maxBytes = (int)$config['security']['max_upload_mb'] * 1024 * 1024;
if ($file['size'] > $maxBytes) {
    json_response(['success' => false, 'error' => 'File too large'], 413);
}

$ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
if (!in_array($ext, $config['security']['allowed_ext'], true)) {
    json_response(['success' => false, 'error' => 'File type not allowed. Accepted: step, stp, iges, igs'], 415);
}

// --------------------------------------------------
// Paramètres optionnels
// --------------------------------------------------
$materialCode = strtoupper(trim($_POST['material'] ?? 'AL6061'));
$quantity     = max(1, (int)($_POST['quantity'] ?? 1));
$technology   = $_POST['technology'] ?? 'cnc_milling';
$finish       = trim($_POST['finish'] ?? 'as_machined');

$allowedTech = ['cnc_milling', 'cnc_turning', 'sheet_metal'];
if (!in_array($technology, $allowedTech, true)) {
    $technology = 'cnc_milling';
}

// --------------------------------------------------
// Sauvegarde temporaire
// --------------------------------------------------
$uuid = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
    mt_rand(0, 0xffff), mt_rand(0, 0xffff),
    mt_rand(0, 0xffff),
    mt_rand(0, 0x0fff) | 0x4000,
    mt_rand(0, 0x3fff) | 0x8000,
    mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
);

$uploadDir = $config['paths']['uploads'];
if (!is_dir($uploadDir)) {
    mkdir($uploadDir, 0770, true);
}
$tmpPath = $uploadDir . '/' . $uuid . '.' . $ext;
if (!move_uploaded_file($file['tmp_name'], $tmpPath)) {
    json_response(['success' => false, 'error' => 'Failed to store uploaded file'], 500);
}

// --------------------------------------------------
// Analyse géométrique
// --------------------------------------------------
$python = $config['paths']['python'];
$analyzeScript = $config['paths']['geometry'];

$cmd = escapeshellcmd($python) . ' ' . escapeshellarg($analyzeScript) . ' ' . escapeshellarg($tmpPath) . ' 2>&1';
$geoOutput = shell_exec($cmd);
$geo = json_decode($geoOutput ?? '', true);

if (!$geo || empty($geo['success'])) {
    @unlink($tmpPath);
    log_msg("Geometry analysis failed for $uuid : " . ($geoOutput ?? 'null'));
    json_response([
        'success' => false,
        'error' => 'Geometry analysis failed',
        'detail' => $geo['error'] ?? 'Unknown error'
    ], 422);
}

// --------------------------------------------------
// Prédiction ML
// --------------------------------------------------
$features = [
    'volume_mm3'             => $geo['volume_mm3'],
    'surface_mm2'            => $geo['surface_mm2'],
    'bbox_x_mm'              => $geo['bbox_x_mm'],
    'bbox_y_mm'              => $geo['bbox_y_mm'],
    'bbox_z_mm'              => $geo['bbox_z_mm'],
    'removed_volume_mm3'     => $geo['removed_volume_mm3'],
    'min_internal_radius_mm' => $geo['min_internal_radius_mm'],
    'max_pocket_depth_mm'    => $geo['max_pocket_depth_mm'],
    'face_count'             => $geo['face_count'],
    'hole_count'             => $geo['hole_count'],
    'estimated_setups'       => $geo['estimated_setups'],
    'quantity'               => $quantity,
    'material_code'          => $materialCode,
];

$featureFile = $config['paths']['tmp'] . '/' . $uuid . '_features.json';
file_put_contents($featureFile, json_encode($features));

$predictScript = $config['paths']['predict'];
$cmdPred = escapeshellcmd($python) . ' ' . escapeshellarg($predictScript) . ' ' . escapeshellarg($featureFile) . ' 2>&1';
$predOutput = shell_exec($cmdPred);
$pred = json_decode($predOutput ?? '', true);
@unlink($featureFile);

if (!$pred || empty($pred['success'])) {
    @unlink($tmpPath);
    log_msg("ML prediction failed for $uuid : " . ($predOutput ?? 'null'));
    json_response([
        'success' => false,
        'error' => 'ML prediction failed',
        'detail' => $pred['error'] ?? 'Unknown error'
    ], 422);
}

// --------------------------------------------------
// Calcul final du prix (formule configurable)
// --------------------------------------------------
// Récupération des paramètres
$configRows = $pdo->query("SELECT `key`, `value` FROM config")->fetchAll(PDO::FETCH_KEY_PAIR);
$hourlyRate = (float)($configRows['hourly_rate_3axis'] ?? 45.0);
$setupCost  = (float)($configRows['setup_cost_per_setup'] ?? 25.0);
$marginPct  = (float)($configRows['default_margin_pct'] ?? 25.0);

// Coût matière
$stmtMat = $pdo->prepare('SELECT density_kg_m3, price_per_kg FROM materials WHERE code = ? AND is_active = 1');
$stmtMat->execute([$materialCode]);
$mat = $stmtMat->fetch(PDO::FETCH_ASSOC);
if (!$mat) {
    $mat = ['density_kg_m3' => 2700, 'price_per_kg' => 4.50]; // fallback aluminium
}

$volume_m3 = $geo['volume_mm3'] / 1e9;
$materialCost = $volume_m3 * (float)$mat['density_kg_m3'] * (float)$mat['price_per_kg'];

$timeMin = (float)$pred['estimated_time_min'];
$machiningCost = ($timeMin / 60.0) * $hourlyRate;
$setupsCost = (int)$geo['estimated_setups'] * $setupCost;
$finishCost = 0.0; // à étendre plus tard

$baseCost = $materialCost + $machiningCost + $setupsCost + $finishCost;
$unitPrice = $baseCost * (1 + $marginPct / 100) / max(1, pow($quantity, 0.25)); // dégressivité légère
$totalPrice = $unitPrice * $quantity;

// --------------------------------------------------
// Enregistrement en base
// --------------------------------------------------
$stmtIns = $pdo->prepare("
    INSERT INTO quotes (
        uuid, api_token_id, original_filename, file_hash, technology, material_id, quantity,
        volume_mm3, surface_mm2, bbox_x_mm, bbox_y_mm, bbox_z_mm, removed_volume_mm3,
        min_internal_radius_mm, max_pocket_depth_mm, face_count, hole_count, estimated_setups,
        estimated_time_min, material_cost, machining_cost, setup_cost, finish_cost,
        unit_price, total_price, confidence_score, dfm_alerts, model_version, status
    ) VALUES (
        ?, ?, ?, ?, ?, (SELECT id FROM materials WHERE code = ? LIMIT 1), ?,
        ?, ?, ?, ?, ?, ?,
        ?, ?, ?, ?, ?,
        ?, ?, ?, ?, ?,
        ?, ?, ?, ?, ?, 'success'
    )
");

$dfmJson = json_encode($geo['dfm_alerts'] ?? []);

$stmtIns->execute([
    $uuid,
    $tokenRow['id'],
    $file['name'],
    $geo['file_hash'] ?? hash_file('sha256', $tmpPath),
    $technology,
    $materialCode,
    $quantity,
    $geo['volume_mm3'],
    $geo['surface_mm2'],
    $geo['bbox_x_mm'],
    $geo['bbox_y_mm'],
    $geo['bbox_z_mm'],
    $geo['removed_volume_mm3'],
    $geo['min_internal_radius_mm'],
    $geo['max_pocket_depth_mm'],
    $geo['face_count'],
    $geo['hole_count'],
    $geo['estimated_setups'],
    $timeMin,
    round($materialCost, 4),
    round($machiningCost, 4),
    round($setupsCost, 4),
    round($finishCost, 4),
    round($unitPrice, 4),
    round($totalPrice, 4),
    $pred['confidence_score'],
    $dfmJson,
    $pred['model_version']
]);

// Nettoyage du fichier temporaire
@unlink($tmpPath);

// --------------------------------------------------
// Réponse
// --------------------------------------------------
json_response([
    'success' => true,
    'quote_id' => $uuid,
    'technology' => $technology,
    'material' => $materialCode,
    'quantity' => $quantity,
    'geometry' => [
        'volume_mm3' => $geo['volume_mm3'],
        'surface_mm2' => $geo['surface_mm2'],
        'bbox_mm' => [
            'x' => $geo['bbox_x_mm'],
            'y' => $geo['bbox_y_mm'],
            'z' => $geo['bbox_z_mm']
        ],
        'removed_volume_mm3' => $geo['removed_volume_mm3'],
        'min_internal_radius_mm' => $geo['min_internal_radius_mm'],
        'face_count' => $geo['face_count'],
        'hole_count' => $geo['hole_count'],
        'estimated_setups' => $geo['estimated_setups'],
        'engine' => $geo['engine']
    ],
    'pricing' => [
        'material_cost' => round($materialCost, 2),
        'machining_cost' => round($machiningCost, 2),
        'setup_cost' => round($setupsCost, 2),
        'finish_cost' => round($finishCost, 2),
        'unit_price' => round($unitPrice, 2),
        'total_price' => round($totalPrice, 2),
        'currency' => 'EUR'
    ],
    'estimation' => [
        'time_min' => $timeMin,
        'confidence_score' => $pred['confidence_score'],
        'model_version' => $pred['model_version']
    ],
    'dfm_alerts' => $geo['dfm_alerts'] ?? []
]);
