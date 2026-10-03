<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tokens API – CNCToleQuotation</title>
    <link rel="stylesheet" href="../assets/css/admin.css">
</head>
<body>
    <header>
        <h1>CNCToleQuotation</h1>
        <p class="subtitle">Gestion des tokens API</p>
    </header>

    <nav>
        <a href="../index.php">Tableau de bord</a>
        <a href="quotes.php">Historique cotations</a>
        <a href="learning.php">Module Learning</a>
        <a href="config.php">Configuration</a>
        <a href="tokens.php" class="active">Tokens API</a>
    </nav>

    <main>
        <section class="card">
            <h2>Tokens existants</h2>
            <?php
            $configFile = '/opt/cnctolequotation/api/config.php';
            $message = '';

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

                    // Traitement des actions
                    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
                        $action = $_POST['action'] ?? '';

                        if ($action === 'create' && !empty($_POST['name']) && !empty($_POST['token'])) {
                            $name = trim($_POST['name']);
                            $token = trim($_POST['token']);
                            $hash = hash('sha256', $token);
                            $stmt = $pdo->prepare('INSERT INTO api_tokens (name, token_hash, is_active) VALUES (?, ?, 1)');
                            $stmt->execute([$name, $hash]);
                            $message = '<p class="ok">Token « ' . htmlspecialchars($name) . ' » créé. Conservez la valeur en clair : <code>' . htmlspecialchars($token) . '</code></p>';
                        }

                        if ($action === 'toggle' && !empty($_POST['id'])) {
                            $id = (int)$_POST['id'];
                            $pdo->prepare('UPDATE api_tokens SET is_active = 1 - is_active WHERE id = ?')->execute([$id]);
                            $message = '<p class="ok">État du token mis à jour.</p>';
                        }

                        if ($action === 'delete' && !empty($_POST['id'])) {
                            $id = (int)$_POST['id'];
                            $pdo->prepare('DELETE FROM api_tokens WHERE id = ?')->execute([$id]);
                            $message = '<p class="ok">Token supprimé.</p>';
                        }
                    }

                    echo $message;

                    $rows = $pdo->query('SELECT id, name, is_active, rate_limit, created_at, last_used_at FROM api_tokens ORDER BY id')->fetchAll(PDO::FETCH_ASSOC);

                    if (empty($rows)) {
                        echo '<p class="muted">Aucun token.</p>';
                    } else {
                        echo '<table class="data-table"><thead><tr>
                            <th>ID</th><th>Nom</th><th>Actif</th><th>Rate limit</th><th>Créé</th><th>Dernière util.</th><th>Actions</th>
                        </tr></thead><tbody>';
                        foreach ($rows as $r) {
                            echo '<tr>';
                            echo '<td>' . (int)$r['id'] . '</td>';
                            echo '<td>' . htmlspecialchars($r['name']) . '</td>';
                            echo '<td class="' . ($r['is_active'] ? 'ok' : 'err') . '">' . ($r['is_active'] ? 'Oui' : 'Non') . '</td>';
                            echo '<td>' . (int)$r['rate_limit'] . '/min</td>';
                            echo '<td>' . htmlspecialchars($r['created_at']) . '</td>';
                            echo '<td>' . htmlspecialchars($r['last_used_at'] ?? '-') . '</td>';
                            echo '<td class="actions">';
                            echo '<form method="post" style="display:inline">
                                <input type="hidden" name="action" value="toggle">
                                <input type="hidden" name="id" value="' . (int)$r['id'] . '">
                                <button type="submit" class="btn-small">' . ($r['is_active'] ? 'Désactiver' : 'Activer') . '</button>
                            </form> ';
                            echo '<form method="post" style="display:inline" onsubmit="return confirm(\'Supprimer ce token ?\')">
                                <input type="hidden" name="action" value="delete">
                                <input type="hidden" name="id" value="' . (int)$r['id'] . '">
                                <button type="submit" class="btn-small btn-danger">Supprimer</button>
                            </form>';
                            echo '</td></tr>';
                        }
                        echo '</tbody></table>';
                    }
                } catch (Exception $e) {
                    echo '<p class="error">Erreur : ' . htmlspecialchars($e->getMessage()) . '</p>';
                }
            }
            ?>
        </section>

        <section class="card">
            <h2>Créer un nouveau token</h2>
            <form method="post">
                <input type="hidden" name="action" value="create">
                <div class="form-row">
                    <label>Nom du token</label>
                    <input type="text" name="name" required placeholder="Ex: Production, Site web, ...">
                </div>
                <div class="form-row">
                    <label>Valeur du token (en clair – elle sera hashée)</label>
                    <input type="text" name="token" required placeholder="Chaîne longue et aléatoire">
                </div>
                <button type="submit">Créer le token</button>
            </form>
            <p class="muted" style="margin-top:1rem">
                Le token en clair n’est affiché qu’une seule fois à la création. Notez-le précieusement.
            </p>
        </section>
    </main>

    <footer>
        <p>CNCToleQuotation – 100 % offline</p>
    </footer>
</body>
</html>
