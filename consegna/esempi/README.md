# Configurazioni illustrative della containerizzazione

Questi tre file sono estratti dalla configurazione di MeccanicoSubito e accompagnano
la sezione 4 della relazione:

- [Dockerfile](Dockerfile): build multi-stage, utente non-root e secret di build Sentry.
- [docker-compose.yml](docker-compose.yml): porta loopback, variabili runtime,
  healthcheck e rotazione dei log.
- [.dockerignore](.dockerignore): esclusione di configurazioni locali e secrets dall’immagine.

Sono esempi da consultare, non un’applicazione da avviare: i sorgenti, le dipendenze
applicative e le migration del database restano nella repository privata della webapp.
I file non contengono valori di credenziali. I workflow storici sono documentati
separatamente in [workflows-storici](../workflows-storici/).
