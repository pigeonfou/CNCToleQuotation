/**
 * CNCToleQuotation – Admin JavaScript (vanilla)
 */

document.addEventListener('DOMContentLoaded', () => {
    const form = document.getElementById('test-form');
    const resultBox = document.getElementById('result');
    const statusBox = document.getElementById('status');

    // Statut simple
    if (statusBox) {
        statusBox.innerHTML = `
            <p><strong>API</strong> : prête</p>
            <p><strong>Mode</strong> : offline / air-gapped</p>
            <p><strong>Modèle ML</strong> : voir data/models/active_model.txt</p>
        `;
    }

    if (!form) return;

    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        resultBox.textContent = 'Analyse en cours…';
        const btn = form.querySelector('button');
        btn.disabled = true;

        const fd = new FormData(form);
        const token = fd.get('token');
        fd.delete('token');

        try {
            const resp = await fetch('/api/v1/quote', {
                method: 'POST',
                headers: {
                    'Authorization': 'Bearer ' + token
                },
                body: fd
            });

            const data = await resp.json();
            resultBox.textContent = JSON.stringify(data, null, 2);

            if (data.success) {
                resultBox.style.color = '#22c55e';
            } else {
                resultBox.style.color = '#ef4444';
            }
        } catch (err) {
            resultBox.textContent = 'Erreur réseau ou serveur : ' + err.message;
            resultBox.style.color = '#ef4444';
        } finally {
            btn.disabled = false;
        }
    });
});
