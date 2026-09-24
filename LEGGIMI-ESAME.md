# MeccanicoSubito — consegna DevOps

Aggiornamento materiali: **23 settembre 2026**. Repository pubblica: **24 settembre 2026**.

Repository della consegna: https://github.com/TurboR93/meccanicosubito-devops-esame.
È separata dalla repository privata della webapp e contiene esclusivamente i materiali
dell’esame, con storia Git autonoma. Il codice dell’applicazione non viene pubblicato.

La presentazione riguarda la **pipeline CI/CD storica**, lo **staging logico
locale prima del deploy** e il monitoraggio oggi implementato sulla webapp.
Il perimetro è stato confermato da Riccardo: non occorre riattivare Actions
né creare un server di staging per questa consegna.

## Materiali da usare

- [Presentazione PDF](consegna/presentazione-meccanicosubito-devops.pdf).
- [Presentazione modificabile HTML](consegna/presentazione.html).
- [Relazione tecnica](consegna/README-DEVOPS.md).
- [Prove datate](consegna/evidenze/) e [workflow storici](consegna/workflows-storici/).

Le versioni precedenti sono conservate solo localmente e sono escluse dalla
repository pubblica. Per la consegna fanno fede il PDF e la relazione indicati sopra.

## Cosa è stato chiuso

- Analisi del progetto originale al commit `6b577b7`: integrazione Sentry verificata
  e documentazione allineata. Sorgenti e migration restano privati.
- CI storica riverificata su GitHub: run `26833635111`, 2 giugno, typecheck/lint/build riusciti.
- CD storico riverificato: run `26680816310`, 30 maggio, build e deploy riusciti;
  attesa schema e smoke test saltati, limite esplicitato nella relazione.
- Health pubblico verificato il 23 settembre: HTTP 200, release `756d161`, build del 22 settembre.
- Sentry: conservati evento e screenshot del test del 15 settembre; configurazione
  corretta nella relazione (token source map via build secret, non build-arg).
- UptimeRobot riconosciuto come già attivo, sulla base della verifica operativa
  nei log del 22 settembre. Rimossa la vecchia indicazione “da attivare”.

## Ultimo controllo operativo

- [ ] UptimeRobot: verificare destinatario, intervallo e ritardo degli alert nella dashboard;
      salvare una schermata del monitor e una prova dell'avviso.
- [ ] Sentry: verificare la regola di alert e una notifica ricevuta. Un evento in Issues
      da solo non dimostra che sia arrivata un'email.
- [x] Consegna: accesso senza autenticazione verificato il 24 settembre per README,
      PDF e prova CI esportata (HTTP 200 e contenuti identici ai file locali).
      Verificati tutti i 32 file pubblicati; la repository originale resta privata.
      Solo le run Actions originali richiedono accesso alla repository privata.

Non serve provocare un'interruzione del sito per completare le prove degli avvisi.
La repository pubblica è documentale: non esegue la build o il deploy dell’app.
