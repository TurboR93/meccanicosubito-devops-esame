#!/usr/bin/env bash
# Rigenera il PDF canonico. Le prove CI/UptimeRobot sono riportate come testo
# con fonte e data; gli screenshot Sentry e della home sono in ./screenshot/.
# Uso: bash consegna/rigenera-pdf.sh
set -euo pipefail
cd "$(dirname "$0")"
export PDF_CHROME="${PDF_CHROME:-}"
python3 - <<'PY'
from pathlib import Path
from tempfile import TemporaryDirectory
from html.parser import HTMLParser
import os
import subprocess

source = Path('presentazione.html').resolve()
target = source.with_name('presentazione-meccanicosubito-devops.pdf')
# Preferisce il motore dedicato ai documenti, se già installato. Nessun download.
engines = list((Path.home() / 'Library/Caches/ms-playwright').glob(
    'chromium_headless_shell-*/chrome-headless-shell-mac-*/chrome-headless-shell'
))
chrome = os.environ['PDF_CHROME'] or (
    str(max(engines, key=lambda p: p.stat().st_mtime)) if engines
    else '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
)

class Images(HTMLParser):
    def handle_starttag(self, tag, attrs):
        if tag != 'img':
            return
        src = dict(attrs).get('src', '')
        if src and not src.startswith(('https://', 'http://', 'data:')):
            if not (source.parent / src).is_file():
                raise SystemExit(f'Immagine mancante: {src}')

Images().feed(source.read_text())
with TemporaryDirectory(prefix='mms-pdf-') as work:
    draft = Path(work) / 'presentazione.pdf'
    try:
        result = subprocess.run([
            chrome, '--headless=new', '--disable-gpu',
            '--no-first-run', f'--user-data-dir={work}/profile', '--timeout=15000',
            '--no-pdf-header-footer', f'--print-to-pdf={draft}', source.as_uri(),
        ], capture_output=True, text=True, timeout=50)
    except subprocess.TimeoutExpired:
        raise SystemExit('Esportazione scaduta dopo 50 secondi; PDF precedente conservato.')
    if result.returncode or not draft.is_file():
        raise SystemExit(f'Esportazione PDF fallita.\n{result.stderr[-2000:]}')
    content = draft.read_bytes()
    if not content.startswith(b'%PDF-'):
        raise SystemExit('Il file generato non è un PDF valido.')
    target.write_bytes(content)
print(f'PDF rigenerato: {target} ({target.stat().st_size} byte)')
PY
