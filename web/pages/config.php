<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Configuration – CNCToleQuotation</title>
    <link rel="stylesheet" href="../assets/css/admin.css">
</head>
<body>
    <header>
        <h1>CNCToleQuotation</h1>
        <p class="subtitle">Paramètres de cotation</p>
    </header>

    <nav>
        <a href="../index.php">Tableau de bord</a>
        <a href="quotes.php">Historique cotations</a>
        <a href="learning.php">Module Learning</a>
        <a href="config.php" class="active">Configuration</a>
        <a href="tokens.php">Tokens API</a>
    </nav>

    <main>
        <?php
        $configFile = (getenv('CNCTOLE_CONFIG') ?: dirname(__DIR__, 2) . '/api/config.php');
        $message = '';

        if (!file_exists($configFile)) {
            echo '<section class="card"><p class="error">Fichier de configuration introuvable.</p></section>';
        } else {
            $appConfig = require $configFile;
            try {
                $pdo = new PDO(
                    sprintf('mysql:host=%s;port=%d;dbname=%s;charset=%s',
                        $appConfig['db']['host'], $appConfig['db']['port'],
                        $appConfig['db']['name'], $appConfig['db']['charset']
                    ),
                    $appConfig['db']['user'], $appConfig['db']['password'],
                    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
                );

                if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['config'])) {
                    $stmt = $pdo->prepare('UPDATE config SET `value` = ? WHERE `key` = ?');
                    foreach ($_POST['config'] as $key => $value) {
                        $stmt->execute([trim($value), $key]);
                    }
                    $message = '<p class="ok">Configuration enregistrée.</p>';
                }

                $rows = $pdo->query('SELECT `key`, `value`, description FROM config ORDER BY `key`')->fetchAll(PDO::FETCH_ASSOC);
                $materials = $pdo->query('SELECT code, name, density_kg_m3, price_per_kg, machinability, is_active FROM materials ORDER BY code')->fetchAll(PDO::FETCH_ASSOC);
        ?>

        <section class="card">
            <h2>Paramètres globaux</h2>
            <?= $message ?>
            <form method="post">
                <?php foreach ($rows as $r): ?>
                <div class="form-row">
                    <label>
                        <?= htmlspecialchars($r['key']) ?>
                        <?php if ($r['description']): ?>
                            <span class="muted"> – <?= htmlspecialchars($r['description']) ?></span>
                        <?php endif; ?>
                    </label>
                    <input type="text" name="config[<?= htmlspecialchars($r['key']) ?>]"
                           value="<?= htmlspecialchars($r['value']) ?>">
                </div>
                <?php endforeach; ?>
                <button type="submit">Enregistrer</button>
            </form>
        </section>

        <section class="card">
            <h2>Matériaux</h2>
            <table class="data-table">
                <thead>
                    <tr>
                        <th>Code</th>
                        <th>Nom</th>
                        <th>Densité (kg/m³)</th>
                        <th>Prix (€/kg)</th>
                        <th>Usinabilité</th>
                        <th>Actif</th>
                    </tr>
                </thead>
                <tbody>
                <?php foreach ($materials as $m): ?>
                    <tr>
                        <td><code><?= htmlspecialchars($m['code']) ?></code></td>
                        <td><?= htmlspecialchars($m['name']) ?></td>
                        <td><?= number_format((float)$m['density_kg_m3'], 0) ?></td>
                        <td><?= number_format((float)$m['price_per_kg'], 2) ?></td>
                        <td><?= number_format((float)$m['machinability'], 2) ?></td>
                        <td class="<?= $m['is_active'] ? 'ok' : 'err' ?>"><?= $m['is_active'] ? 'Oui' : 'Non' ?></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
            <p class="muted" style="margin-top:1rem">
                Pour modifier les matériaux, utilisez la base de données (table <code>materials</code>).
            </p>
        </section>

        <?php
            } catch (Exception $e) {
                echo '<section class="card"><p class="error">Erreur : ' . htmlspecialchars($e->getMessage()) . '</p></section>';
            }
        }
        ?>
    </main>

    <footer>
        <p>CNCToleQuotation – 100 % offline</p>
    </footer>
</body>
</html>

