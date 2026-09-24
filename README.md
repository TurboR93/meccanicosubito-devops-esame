# MeccanicoSubito — progetto d’esame DevOps

**Riccardo Brunello · settembre 2026**

Questa repository pubblica raccoglie **solo i materiali dell’esame**: presentazione,
relazione tecnica, prove, workflow storici e configurazioni illustrative Docker.
Il codice dell’applicazione MeccanicoSubito resta nella sua repository privata.

**Verifica della traccia completa (24/09): conformità parziale.** Restano scostamenti
su CI/CD, Compose locale e destinazione del deploy, oltre ad alcune prove mancanti.
La [verifica punto per punto](consegna/VERIFICA-CONFORMITA.md) distingue implementazioni
storiche, stato attuale e requisiti non ancora dimostrati.

Il progetto racconta la **pipeline CI/CD storica su GitHub Actions**, lo
**staging logico locale prima del deploy** e il monitoraggio della webapp con
Sentry e UptimeRobot. App pubblica: [meccanicosubito.it](https://meccanicosubito.it).

## Materiali della consegna

1. **[Presentazione PDF — 9 slide](consegna/presentazione-meccanicosubito-devops.pdf)**.
2. **[Relazione tecnica completa](consegna/README-DEVOPS.md)**.
3. **[Prove datate](consegna/evidenze/)** e **[screenshot selezionati](consegna/screenshot/)**.
4. **[Workflow CI/CD storici](consegna/workflows-storici/)**, conservati come documentazione.
5. **[Esempi Docker](consegna/esempi/)**: Dockerfile, Compose e regole di esclusione dei secrets.

Le prove esportate sono consultabili senza accedere alla repository originale.
I link alle run GitHub Actions originali richiedono invece accesso alla repository
privata: i relativi esiti sono già inclusi nei file della consegna.

## Perimetro

La repository ha una storia Git autonoma ed è confinata alla cartella `devOps`.
Non include sorgenti della webapp, database, migration, dati clienti, credenziali,
script operativi di produzione o la storia Git della repository privata.
I workflow si trovano in `consegna/workflows-storici`, quindi non si eseguono come Actions.

Gli esempi Docker documentano la struttura originale: non sono eseguibili senza
il codice dell’applicazione. I comandi descritti nella relazione si riferiscono
all’ambiente originale e non richiedono di avviare nulla per leggere questa consegna.

## Presentazione modificabile

La sorgente è [consegna/presentazione.html](consegna/presentazione.html).
Su macOS il PDF si rigenera con `bash consegna/rigenera-pdf.sh` usando Chromium/Chrome
già installato; `PDF_CHROME` consente di indicare un eseguibile diverso.

Stato delle prove e ultimi controlli: [LEGGIMI-ESAME.md](LEGGIMI-ESAME.md).
