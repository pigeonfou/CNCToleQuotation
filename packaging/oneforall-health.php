<?php
// CLI-only readiness check: contains no paths, credentials or exception details.
declare(strict_types=1);
if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
$result = ['database' => false, 'models' => false, 'geometry' => false, 'ready' => false];
try {
    $path = getenv('CNCTOLE_CONFIG');
    if (!$path || !is_file($path)) {
        throw new RuntimeException('Unconfigured');
    }
    $config = require $path;
    $db = $config['db'];
    $pdo = new PDO(sprintf('mysql:host=%s;port=%d;dbname=%s;charset=%s', $db['host'], $db['port'], $db['name'], $db['charset']), $db['user'], $db['password'], [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    $pdo->query('SELECT COUNT(*) FROM config')->fetchColumn();
    $result['database'] = true;
    $models = $config['paths']['models'];
    $active = is_readable($models . '/active_model.txt') ? trim(file_get_contents($models . '/active_model.txt')) : '';
    $result['models'] = preg_match('/^[a-zA-Z0-9._-]+$/', $active) === 1 && is_readable($models . '/model_' . $active . '.joblib');
    $python = $config['paths']['geometry_python'];
    $command = escapeshellarg($python) . ' -c ' . escapeshellarg('from OCC.Core.STEPControl import STEPControl_Reader; print("ready")') . ' 2>/dev/null';
    $result['geometry'] = trim((string)shell_exec($command)) === 'ready';
    $result['ready'] = $result['database'] && $result['models'] && $result['geometry'];
} catch (Throwable $e) {
    // Report failed state without disclosing database details.
}
echo json_encode($result, JSON_UNESCAPED_SLASHES) . PHP_EOL;
