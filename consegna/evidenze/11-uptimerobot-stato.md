# UptimeRobot: provenienza della verifica

Consolidamento per la consegna del 23/09/2026.

Il documento operativo `docs/sentry-observability.md` §6, commit
`6b577b75791623bacd88b5ff69d2313d2200a24d` del 22/09/2026, riporta una verifica
nei log Nginx: **218 richieste HEAD /api/health** con user-agent UptimeRobot,
tutte **HTTP 200**, intervallo circa cinque minuti.

La consegna usa questa evidenza documentale. Non include il log grezzo né una
nuova lettura della dashboard. Il tentativo del 23/09 di leggere il log con
l'utente deploy non aveva i permessi necessari; non sono stati modificati.

Questa prova sostiene che il monitor era attivo al momento della verifica.
Non prova il destinatario, la soglia o la consegna degli alert. Le chiamate HEAD
non attestano il controllo di una keyword nel corpo JSON.

Da completare dalla dashboard: schermata del monitor attivo e impostazioni
avvisi; verificare una notifica di test al destinatario previsto senza fermare
il sito. Non attivare un secondo monitor per duplicare quello esistente.
