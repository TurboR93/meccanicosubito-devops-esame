# Verifica di conformità alla traccia del Master

Verifica del **24 settembre 2026**, sulla traccia integrale fornita da Riccardo.

**Esito: conformità parziale.** La consegna documenta un'app reale, containerizzazione,
sicurezza, pipeline storiche e monitoraggio. Non dimostra però un ciclo attuale
`push main → lint → build immagine → deploy automatico solo dopo CI verde`.
La scelta di presentare la storia del progetto non costituisce, da sola, una deroga
ai requisiti della traccia. L'accettazione delle alternative compete al docente.

Questa verifica integra la presentazione PDF e la copia Canva del 24 settembre:
non sono state modificate durante questo controllo. Per il giudizio di conformità
fa fede la matrice qui sotto, non la precedente indicazione che mancassero solo gli alert.

## Perimetro e riscontri

- Esaminati [relazione](README-DEVOPS.md), [workflow storici](workflows-storici/),
  [configurazioni Docker](esempi/) e [prove esportate](evidenze/).
- Consultata in sola lettura la repository privata originale, HEAD `9429941`.
  Nessun workflow applicativo è presente sotto `.github` a quel commit.
  `build:docker` esegue `BUILD_TARGET=docker next build`; `deploy` avvia lo script locale.
- GitHub elenca ancora il workflow dinamico `pages-build-deployment` come active:
  le tre run più recenti restituite risalgono al 30 aprile. Questo non dimostra
  una CI/CD applicativa attuale su ogni push.
- Il 24/09 alle **08:45 UTC**, sia la home sia `/api/health` rispondono **HTTP 200**.
  Health: `status=ok`, commit `756d161ce5c190df470e9196639d82ffe4178e9f`,
  build `2026-09-22T14:11:26Z`. Il check HTTP non verifica database o pagamenti.
- Repository dell'esame PUBLIC; originale PRIVATE. Nessun codice applicativo viene pubblicato.
- Non sono stati eseguiti nuovi deploy, test di errore in produzione o avvii del database locale.

Legenda: **coperto** = prova presente; **parziale** = requisito soddisfatto solo in parte
o con una soluzione differente; **non conforme** = scostamento verificato;
**non dimostrato** = prove insufficienti, non necessariamente lavoro mai eseguito.

## 1. Esplorazione

| Requisito | Esito | Riscontro / limite |
|---|---|---|
| Descrivere l'app | Coperto | Relazione §1: utenti, prenotazioni, architettura e dipendenze. |
| Definire development, staging e production | Parziale | Relazione §2: development e produzione definiti; staging descritto come fase locale sullo stesso Mac. Non è dimostrato un ambiente di staging separato da development. La traccia non impone un server remoto; vanno provati configurazione, isolamento e verifiche pre-deploy. Il dry run non esegue la build. |
| Scegliere Actions/GitLab e motivare | Coperto | Relazione §3: GitHub Actions, trigger, registry e gestione secrets. |
| README iniziale con pianificazione | Non dimostrato | Il primo README, commit `797bff3` del 30/04, contiene descrizione e quick start e rimanda alla roadmap in CLAUDE.md; non contiene un piano DevOps esplicito. La relazione attuale è retrospettiva. Un piano scritto oggi non dimostra la pianificazione iniziale. |

## 2. Containerizzazione

| Requisito | Esito | Riscontro / limite |
|---|---|---|
| Dockerfile front end | Coperto | [Dockerfile](esempi/Dockerfile) multi-stage Next.js. La run CD storica prova la build dell'immagine. |
| Compose locale front end + back end | Non conforme al formato richiesto | [Compose](esempi/docker-compose.yml) contiene solo `web`; Supabase locale è avviato separatamente con la CLI. È una soluzione operativa diversa dal Compose con entrambi richiesto dalla traccia. |
| Test dell'avvio locale | Non dimostrato nella consegna | Comandi presenti, ma nessun output datato allegato che mostri front end e back end locali avviati e comunicanti. Una build sul runner o l'health di produzione non provano l'avvio locale. |
| Comandi nel README | Coperto | Relazione §4.3. Sono comandi della repository privata; gli esempi pubblici non sono autonomamente eseguibili. |

## 3. Sicurezza e secrets

| Requisito | Esito | Riscontro / limite |
|---|---|---|
| Variabili tramite file env non committati | Coperto per le configurazioni esaminate | Relazione §5, file example e riferimenti `env_file`; nessun valore segreto viene aggiunto alla consegna. |
| Esclusione `.env` e verifica history | Coperto nel perimetro controllato | `.gitignore` originale esclude `.env`, `.env*.local`, `.env.production`, `.env.backup` e `.env.sentry-build-plugin`. Riverificati il 24/09 tutti i ref locali disponibili: nessun percorso non-example nei match `.env`, `.env.*`, `*.env`. Non è una certificazione di assenza di ogni possibile segreto in qualunque file o ref non disponibile. |
| Secrets del repository | Coperto da prova storica | [Inventario dei nomi](evidenze/02-github-secrets.txt), 14/09, e riferimenti nei workflow originali. La repo pubblica documentale non necessita di credenziali di produzione. |
| Verifica log pipeline | Coperto nel campione esaminato | [Controllo del log CD](evidenze/04-log-masking.txt): 1.742 righe, 31 mascheramenti, zero corrispondenze ai pattern cercati. Non equivale a una scansione esaustiva di tutte le run e di tutti i formati di secret. |

## 4. Pipeline CI

| Requisito | Esito | Riscontro / limite |
|---|---|---|
| Avvio automatico su ogni push a main | Storico; non conforme come stato attuale | [ci.yml](workflows-storici/ci.yml) aveva il trigger. Il workflow applicativo è stato rimosso il 02/06. |
| Lint + build del container | Parziale | CI: lint + `next build` standalone. La vera immagine Docker veniva costruita nel workflow CD separato, non nello stesso percorso vincolato al lint. Il nome `build:docker` non significa `docker build`. |
| Fallimento visibile se lint fallisce | Coperto dalla configurazione storica | Step lint separato, senza `continue-on-error`. Non è allegata una run specificamente fallita per lint; gli esempi disponibili riguardano typecheck e build. La traccia richiede il comportamento, non una distinta schermata di fallimento lint. |
| Screenshot o link alla pipeline verde | Parziale per il docente senza accesso | [Esiti esportati](evidenze/08-ci-storica-verificata.json) e link alla run `26833635111` presenti. Il link originale è privato; il JSON pubblico è utile, ma non è uno screenshot della run. Allegare uno screenshot leggibile della run verde oppure consentire al docente l'accesso. |

## 5. CD e deploy pubblico

| Requisito | Esito | Riscontro / limite |
|---|---|---|
| Deploy automatico dopo CI verde | Non conforme | CI e CD storiche erano indipendenti: il deploy non aspettava l'esito del lint. La run verde di CD non dimostra questo vincolo. Oggi il comando di rilascio parte manualmente dal Mac. |
| Front end su Pages, Vercel o Netlify | Non conforme alla destinazione indicata | Il sito attuale gira su VPS Hostinger. Pages esiste nella storia, ma non è il deploy attuale dell'app con runtime Node. La motivazione tecnica del VPS va distinta dall'accettazione della deroga. |
| URL pubblico funzionante | Coperto | Home e health HTTP 200 il 24/09, come riportato sopra. |
| Deploy automatico a ogni push a main | Storico; non conforme come stato attuale | Trigger storico presente, con gate `PROD_DEPLOY_ENABLED`; oggi rilascio avviato manualmente. |
| Consegna URL + run | Parziale | URL pubblico disponibile; [run CD esportata](evidenze/09-cd-storica-verificata.json) del 30/05, link originale privato. Non documenta il rilascio della versione attualmente online. |

Difetto storico aggiuntivo: nella run CD `26680816310`, attesa schema e smoke test
risultano skipped. Smoke test/rollback non sono richiesti esplicitamente dalla traccia,
ma non vanno presentati come eseguiti in quella run. La causa e una correzione proposta
sono descritte nella relazione §7; la correzione non è una nuova prova di esecuzione.

## 6. Monitoraggio

| Requisito | Esito | Riscontro / limite |
|---|---|---|
| Uptime monitor sull'URL pubblico | Coperto da riscontro documentale, non riverificato in dashboard | [UptimeRobot](evidenze/11-uptimerobot-stato.md): verifica operativa del 22/09, 218 richieste HEAD, tutte 200. Mancano dashboard e impostazioni di notifica nella consegna. |
| Error tracker integrato | Coperto | Sentry documentato nella relazione §8.3 e nelle prove. |
| Errore simulato e tracciato | Coperto | [Test del 15/09](evidenze/06-sentry-verifica.txt), issue `MECCANICOSUBITO-2`, release e stack trace. Non è stato ripetuto durante questo audit. |
| Interpretazione degli alert nel README | Coperto come guida; ricezione non dimostrata | Relazione §8.4. La guida spiega la diagnosi, ma non prova destinatari e consegna delle notifiche. |
| Screenshot dashboard con evento | Coperto | [Issues in produzione](screenshot/sentry-01-issues-production.png) e [dettaglio evento](screenshot/sentry-02-evento-production.png). La traccia non richiede espressamente uno screenshot di un'email: non va aggiunto come requisito formale autonomo. |

## Priorità per chiudere gli scostamenti

1. Dimostrare un flusso applicativo in cui il lint blocchi build immagine e deploy,
   automatico su push, con run verificabile dal docente. Le prove storiche non dimostrano questo vincolo.
2. Soddisfare il Compose front end + back end e documentare un avvio locale riuscito,
   oppure ottenere l'accettazione dell'architettura Supabase CLI separata.
3. Concordare l'accettazione del VPS e della pipeline storica, oppure adeguare il
   progetto ai provider e al funzionamento automatico richiesti. Non basta una modifica al README.
4. Precisare e dimostrare lo staging locale, recuperare eventuali prove della pianificazione
   iniziale e rendere consultabili le run verdi. Completare la verifica operativa degli avvisi.

L'audit non cambia la precedente decisione di mantenere privata l'app né autorizza da solo
una riattivazione del deploy di produzione. Pubblicare tutta la webapp non è un requisito
della traccia; rendere verificabili le prove lo è. Una pipeline che pubblichi soltanto
questi documenti non colmerebbe i requisiti relativi alla build e al deploy dell'app.
