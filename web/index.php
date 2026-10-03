<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CNCToleQuotation – Administration</title>
    <link rel="stylesheet" href="assets/css/admin.css">
</head>
<body>
    <header>
        <h1>CNCToleQuotation</h1>
        <p class="subtitle">Moteur de cotation CNC & Tôlerie – Mode offline</p>
    </header>

    <nav>
        <a href="index.php" class="active">Tableau de bord</a>
        <a href="pages/quotes.php">Historique cotations</a>
        <a href="pages/learning.php">Module Learning</a>
        <a href="pages/config.php">Configuration</a>
        <a href="pages/tokens.php">Tokens API</a>
    </nav>

    <main>
        <section class="card">
            <h2>État du système</h2>
            <div id="status">
                <p>Chargement…</p>
            </div>
        </section>

        <section class="card">
            <h2>Test rapide de cotation</h2>
            <form id="test-form" enctype="multipart/form-data">
                <div class="form-row">
                    <label>Fichier 3D (STEP/IGES)</label>
                    <input type="file" name="file" accept=".step,.stp,.iges,.igs" required>
                </div>
                <div class="form-row">
                    <label>Matériau</label>
                    <select name="material">
                        <option value="AL6061">Aluminium 6061</option>
                        <option value="AL7075">Aluminium 7075</option>
                        <option value="S235">Acier S235</option>
                        <option value="SS304">Inox 304</option>
                        <option value="SS316">Inox 316L</option>
                        <option value="TI6AL4V">Titane Ti-6Al-4V</option>
                        <option value="POM">POM / Delrin</option>
                        <option value="PA6">Nylon PA6</option>
                        <option value="PEEK">PEEK</option>
                    </select>
                </div>
                <div class="form-row">
                    <label>Quantité</label>
                    <input type="number" name="quantity" value="1" min="1" max="10000">
                </div>
                <div class="form-row">
                    <label>Token API</label>
                    <input type="text" name="token" value="demo-token-change-me" required>
                </div>
                <button type="submit">Lancer la cotation</button>
            </form>
            <pre id="result" class="result-box"></pre>
        </section>
    </main>

    <footer>
        <p>CNCToleQuotation – 100 % offline – Ubuntu Server 24.04</p>
    </footer>

    <script src="assets/js/admin.js"></script>
</body>
</html>
