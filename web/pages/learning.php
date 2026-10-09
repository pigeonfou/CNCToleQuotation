<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Module Learning – CNCToleQuotation</title>
    <link rel="stylesheet" href="../assets/css/admin.css">
</head>
<body>
    <header>
        <h1>CNCToleQuotation</h1>
        <p class="subtitle">Module Learning – Réentraînement du modèle</p>
    </header>

    <nav>
        <a href="../index.php">Tableau de bord</a>
        <a href="quotes.php">Historique cotations</a>
        <a href="learning.php" class="active">Module Learning</a>
        <a href="config.php">Configuration</a>
        <a href="tokens.php">Tokens API</a>
    </nav>

    <main>
        <section class="card">
            <h2>Modèles ML disponibles</h2>
            <?php
            $modelsDir = (getenv('CNCTOLE_MODELS_DIR') ?: '/opt/cnctolequotation/data/models');
            $activeFile = $modelsDir . '/active_model.txt';

            if (!is_dir($modelsDir) || !is_readable($modelsDir)) {
                echo '<p class="error">Le répertoire des modèles n’est pas accessible par Apache (www-data).</p>';
                echo '<p class="muted">Corrigez avec :<br>
                <code>sudo usermod -aG cnctole www-data && sudo chmod -R 750 /opt/cnctolequotation/data/models && sudo systemctl restart apache2</code></p>';
            } else {
            $active = (file_exists($activeFile) && is_readable($activeFile))
                ? trim(file_get_contents($activeFile))
                : '(aucun)';

            echo '<p>Modèle <strong>actif</strong> : <code>' . htmlspecialchars($active) . '</code></p>';

            $files = glob($modelsDir . '/model_*.json') ?: [];
            if (empty($files)) {
                echo '<p class="muted">Aucun modèle trouvé. Lancez d’abord create_initial_model.py.</p>';
            } else {
                echo '<table class="data-table"><thead><tr>
                    <th>Version</th><th>Échantillons</th><th>MAE temps</th><th>R² temps</th><th>MAE prix</th><th>R² prix</th>
                </tr></thead><tbody>';
                foreach ($files as $f) {
                    $meta = json_decode(file_get_contents($f), true);
                    if (!$meta) continue;
                    $m = $meta['metrics'] ?? [];
                    echo '<tr>';
                    echo '<td><code>' . htmlspecialchars($meta['version'] ?? basename($f)) . '</code></td>';
                    echo '<td>' . ($meta['train_samples'] ?? $m['train_samples'] ?? '-') . '</td>';
                    echo '<td>' . (isset($m['mae_time']) ? number_format($m['mae_time'], 2) : '-') . '</td>';
                    echo '<td>' . (isset($m['r2_time']) ? number_format($m['r2_time'], 3) : '-') . '</td>';
                    echo '<td>' . (isset($m['mae_price']) ? number_format($m['mae_price'], 2) : '-') . '</td>';
                    echo '<td>' . (isset($m['r2_price']) ? number_format($m['r2_price'], 3) : '-') . '</td>';
                    echo '</tr>';
                }
                echo '</tbody></table>';
            }
            } // fin is_readable
            ?>
        </section>

        <section class="card">
            <h2>Réentraîner le modèle</h2>
            <p>Pour réentraîner à partir de votre historique de commandes validées :</p>
            <ol style="margin: 1rem 0 1rem 1.5rem; color: var(--muted);">
                <li>Exportez les données validées (voir README)</li>
                <li>Placez le CSV dans <code>data/history/export.csv</code></li>
                <li>Exécutez la commande ci-dessous en SSH</li>
            </ol>
            <pre class="result-box">cd /opt/cnctolequotation
sudo -u cnctole bash -c 'source venv/bin/activate && python3 core/learning/train.py --csv data/history/export.csv --version v1.0.0'</pre>
            <p class="muted">Le nouveau modèle devient automatiquement actif après l’entraînement.</p>
        </section>

        <section class="card">
            <h2>Historique d’apprentissage (BDD)</h2>
            <?php
            $configFile = (getenv('CNCTOLE_CONFIG') ?: dirname(__DIR__, 2) . '/api/config.php');
            if (file_exists($configFile)) {
                $config = require $configFile;
                try {
                    $pdo = new PDO(
                        sprintf('mysql:host=%s;port=%d;dbname=%s;charset=%s',
                            $config['db']['host'], $config['db']['port'],
                            $config['db']['name'], $config['db']['charset']
                        ),
                        $config['db']['user'], $config['db']['password'],
                        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
                    );
                    $count = $pdo->query('SELECT COUNT(*) FROM learning_history WHERE is_validated = 1')->fetchColumn();
                    $total = $pdo->query('SELECT COUNT(*) FROM learning_history')->fetchColumn();
                    echo '<p>Échantillons validés : <strong>' . (int)$count . '</strong> / ' . (int)$total . '</p>';
                    if ($count < 20) {
                        echo '<p class="muted">Minimum recommandé : 20–30 pièces validées avant un réentraînement sérieux.</p>';
                    }
                } catch (Exception $e) {
                    echo '<p class="error">' . htmlspecialchars($e->getMessage()) . '</p>';
                }
            }
            ?>
        </section>
    </main>

    <footer>
        <p>CNCToleQuotation – 100 % offline</p>
    </footer>
</body>
</html>

