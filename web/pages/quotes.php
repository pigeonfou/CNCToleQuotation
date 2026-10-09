<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Historique des cotations – CNCToleQuotation</title>
    <link rel="stylesheet" href="../assets/css/admin.css">
</head>
<body>
    <header>
        <h1>CNCToleQuotation</h1>
        <p class="subtitle">Historique des cotations</p>
    </header>

    <nav>
        <a href="../index.php">Tableau de bord</a>
        <a href="quotes.php" class="active">Historique cotations</a>
        <a href="learning.php">Module Learning</a>
        <a href="config.php">Configuration</a>
        <a href="tokens.php">Tokens API</a>
    </nav>

    <main>
        <section class="card">
            <h2>Dernières cotations</h2>
            <div class="table-wrapper">
                <?php
                $configFile = (getenv('CNCTOLE_CONFIG') ?: dirname(__DIR__, 2) . '/api/config.php');
                if (!file_exists($configFile)) {
                    echo '<p class="error">Fichier de configuration introuvable.</p>';
                } else {
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

                        $stmt = $pdo->query("
                            SELECT uuid, original_filename, technology, quantity,
                                   unit_price, total_price, estimated_time_min,
                                   confidence_score, status, created_at, model_version
                            FROM quotes
                            ORDER BY created_at DESC
                            LIMIT 50
                        ");
                        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

                        if (empty($rows)) {
                            echo '<p class="muted">Aucune cotation pour le moment.</p>';
                        } else {
                            echo '<table class="data-table">';
                            echo '<thead><tr>
                                <th>Date</th>
                                <th>Fichier</th>
                                <th>Techno</th>
                                <th>Qté</th>
                                <th>Temps (min)</th>
                                <th>Prix unit.</th>
                                <th>Total</th>
                                <th>Confiance</th>
                                <th>Modèle</th>
                                <th>Statut</th>
                            </tr></thead><tbody>';

                            foreach ($rows as $r) {
                                $statusClass = $r['status'] === 'success' ? 'ok' : 'err';
                                echo '<tr>';
                                echo '<td>' . htmlspecialchars($r['created_at']) . '</td>';
                                echo '<td title="' . htmlspecialchars($r['uuid']) . '">' . htmlspecialchars(mb_strimwidth($r['original_filename'], 0, 30, '…')) . '</td>';
                                echo '<td>' . htmlspecialchars($r['technology']) . '</td>';
                                echo '<td>' . (int)$r['quantity'] . '</td>';
                                echo '<td>' . number_format((float)$r['estimated_time_min'], 1) . '</td>';
                                echo '<td>' . number_format((float)$r['unit_price'], 2) . ' €</td>';
                                echo '<td>' . number_format((float)$r['total_price'], 2) . ' €</td>';
                                echo '<td>' . number_format((float)$r['confidence_score'] * 100, 0) . ' %</td>';
                                echo '<td>' . htmlspecialchars($r['model_version'] ?? '-') . '</td>';
                                echo '<td class="' . $statusClass . '">' . htmlspecialchars($r['status']) . '</td>';
                                echo '</tr>';
                            }
                            echo '</tbody></table>';
                        }
                    } catch (Exception $e) {
                        echo '<p class="error">Erreur base de données : ' . htmlspecialchars($e->getMessage()) . '</p>';
                    }
                }
                ?>
            </div>
        </section>
    </main>

    <footer>
        <p>CNCToleQuotation – 100 % offline</p>
    </footer>
</body>
</html>

