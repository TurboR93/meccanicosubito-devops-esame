# MeccanicoSubito — Ciclo DevOps completo

> Progetto d'esame: analisi e ricostruzione del ciclo DevOps **realmente in uso** su
> [meccanicosubito.it](https://meccanicosubito.it), dall'ambiente locale al deploy pubblico,
> con pipeline CI/CD, sicurezza e monitoraggio.
>
> Revisione del **23/09/2026**: la consegna presenta la **pipeline CI/CD storica**,
> lo **staging logico prima del deploy** e il monitoraggio della webapp attuale.
> Le prove, con le rispettive date, sono in [`evidenze/`](./evidenze),
> i workflow recuperati dalla history in [`workflows-storici/`](./workflows-storici).
> La pipeline storica non viene presentata come automazione ancora attiva.
> Stato della consegna e verifiche residue: §9.

> **Audit sulla traccia completa, 24/09/2026: conformità parziale.**
> La documentazione storica non dimostra tutti i requisiti operativi richiesti.
> Vedi [verifica punto per punto](VERIFICA-CONFORMITA.md) e §9.

| | |
|---|---|
| **URL pubblico** | https://meccanicosubito.it — health: https://meccanicosubito.it/api/health |
| **Repository pubblica dell’esame** | https://github.com/TurboR93/meccanicosubito-devops-esame |
| **Repository originale della webapp** | https://github.com/TurboR93/meccanicosubito (privato; origine delle run storiche) |
| **CI verde storica (ultima)** | https://github.com/TurboR93/meccanicosubito/actions/runs/26833635111 — 02/06/2026, riverificata il 23/09 |
| **CD verde (ultima via Actions)** | https://github.com/TurboR93/meccanicosubito/actions/runs/26680816310 |
| **Codice analizzato** | repository originale al commit `6b577b7` del 22/09/2026, consultata per l’analisi; sorgenti e migration non sono inclusi in questa consegna pubblica |
| **Versione pubblicata verificata** | `756d161`, build 22/09/2026, `/api/health` HTTP 200 il 23/09. I commit successivi nello snapshot aggiornano la documentazione |

---

## 1. Esplorazione — cosa stiamo deployando

### 1.1 L'app in breve

MeccanicoSubito è una webapp italiana che mette in contatto chi ha bisogno di un meccanico
(auto, moto, furgoni, camion, mezzi agricoli, bici) con l'officina giusta vicina.

- **Cliente**: cerca un'officina sulla mappa, descrive il problema con foto e prenota uno slot;
  paga caparra e saldo online.
- **Officina**: riceve richieste qualificate, gestisce calendario, listino, preventivi, chat e incassi.
- **Admin**: approva officine, gestisce utenti e prenotazioni cross-tenant.

### 1.2 Architettura (vista da DevOps)

```
 Browser ──HTTPS──► Cloudflare DNS ──► VPS Hostinger (Ubuntu)
                                        ├─ Nginx  (TLS Let's Encrypt, header sicurezza, rate-limit, manutenzione)
                                        └─ Docker: container "web" Next.js standalone su 127.0.0.1:3000
                                                     │
              ┌──────────────────────────────────────┼───────────────────────────────┐
              ▼                                      ▼                               ▼
     Supabase Cloud (managed)               Stripe (Connect)                Resend / GA4-GTM
     Postgres + RLS, Auth (Google/email),   pagamenti + webhook              email transazionali, analytics
     Storage foto, Edge Functions email
```

| Livello | Tecnologia |
|---|---|
| Front end + BFF | **Next.js 15** (App Router, RSC, route handler `/api/*`), TypeScript strict, Tailwind |
| Back end | **Supabase**: Postgres con RLS su tutte le tabelle, Auth, Storage, Edge Functions; schema versionato in **134 migration** (`supabase/migrations/0000→0133`) |
| Pagamenti | Stripe Connect (webhook firmati) |
| Runtime prod | Docker (immagine multi-stage) dietro Nginx su VPS |

**Punto chiave per il DevOps:** il data layer è astratto (`src/lib/data/`) e si sceglie con
`NEXT_PUBLIC_DATA_SOURCE=mock|supabase`. In `mock` l'app gira **senza alcun back end**
(localStorage + seed): utile per sviluppo UI veloce. In produzione è sempre `supabase`, e c'è
uno script che lo fa rispettare (`predeploy-check.sh`).

**Cosa rende il deploy delicato:**
1. Le `NEXT_PUBLIC_*` vengono **scritte dentro il bundle al momento della build**, quindi vanno passate come build-arg. Se sono sbagliate, il sito è rotto anche con la pipeline verde.
2. Codice e **schema DB** devono arrivare in ordine: prima le migration, poi il nuovo container.
3. L'app gestisce **pagamenti reali**: serve rollback immediato e una modalità manutenzione.

---

## 2. I tre ambienti

| | **Development** | **Staging** (pre-produzione) | **Production** |
|---|---|---|---|
| Dove | Mac dello sviluppatore | Mac: verifica logica prima della pubblicazione | VPS Hostinger + Supabase Cloud |
| Avvio | `npm run dev` | `npm run deploy:dry`, prove con Supabase locale e immagine Docker `linux/amd64` | `npm run deploy` |
| Dati | `mock` (localStorage) **oppure** Supabase **locale** in Docker (`supabase start`) + `seed.sql` | copia **read-only** dei dati prod ripristinata in locale (`npm run db:pull-prod`) | Supabase Cloud |
| Env file | `.env.local` | `.env.local` + `.env.backup`; il dump impone una sessione read-only | `.env.production` **solo sul VPS** |
| Auth | email/password su utenti seed; `/dev/login` autologin (404 fuori da development) | come dev | Google OAuth + email/password |
| Gate qualità | pre-commit Husky: `typecheck` + `lint` | preflight, `predeploy-check.sh`, `check:migrations` | smoke test + rollback automatico |
| URL | http://localhost:3000 | locale; nessun dominio di staging dedicato | https://meccanicosubito.it |

**Staging logico: scelta del progetto.** La validazione prima della pubblicazione è una fase
del processo sul Mac, senza un server di staging dedicato. Si basa su:
- **Parità dati**: `db:pull-prod` fa un dump di produzione in sola lettura (DSN con
  `default_transaction_read_only=on`) e lo ripristina sul Supabase locale.
- **Parità runtime**: la stessa immagine Docker di produzione, costruita per `linux/amd64`, si può avviare in locale.
- **Dry run**: `npm run deploy:dry` esegue preflight e `supabase db push --dry-run` senza deployare.
- **Prove funzionali locali**: UI, validazione, ruoli e query vengono provati con Supabase locale;
  i test autenticati non usano il database cloud di produzione.

**Dopo la pubblicazione**, smoke test e rollback verificano la release sul VPS. Se la manutenzione
è attiva, il cookie di bypass consente di controllarla dietro la pagina di cortesia: è una verifica
di produzione, distinta dallo staging logico locale.

**Limiti dichiarati:** il dry run controlla preflight e migration ma si ferma prima della build;
la build e le prove funzionali sono passaggi separati. La copia dei dati è read-only nella lettura
dalla produzione, mentre il ripristino sostituisce il DB locale. OAuth Google e consegna email
reale richiedono verifiche nell'ambiente pubblico. Un ambiente remoto isolato resta un'eventuale
evoluzione, non un passaggio necessario alla configurazione presentata in questa consegna.

---

## 3. Scelta degli strumenti: GitHub Actions

**Scelto: GitHub Actions** (non GitLab CI). Motivi:
1. Il codice **vive già su GitHub**: niente mirror, i trigger `push`/`pull_request` sono nativi.
2. **GitHub Secrets e Variables** integrati, con mascheramento automatico nei log (verificato, §4.4).
3. **GHCR** (GitHub Container Registry) come registry Docker, autenticato con il `GITHUB_TOKEN` effimero.
4. **Integrazione Supabase↔GitHub**: le migration vengono applicate al push su `main`.
5. Marketplace di action (buildx, cache GHA, SSH) e minuti gratuiti sufficienti per un progetto in fase iniziale.

### 3.1 Come si è evoluto il DevOps (storia reale, dati da `gh run list`)

| Fase | Periodo | Deploy | Esiti pipeline |
|---|---|---|---|
| **1. GitHub Pages** | 30/04 → 08/05/2026 | export statico, workflow [`deploy-pages.yml`](./workflows-storici/deploy-pages.yml) | 20 ✅ / 1 ❌ |
| **2. VPS + CI/CD Actions** | 09/05 → 02/06/2026 | [`ci.yml`](./workflows-storici/ci.yml) + [`deploy.yml`](./workflows-storici/deploy.yml): build su runner → GHCR → SSH → smoke → rollback | CI 101 ✅ / 5 ❌ — Deploy 47 ✅ / 56 ❌ / 6 skip |
| **3. Deploy locale scriptato** | 02/06/2026 → oggi | `npm run deploy` → `deploy/deploy-local.sh` (stessi step, lanciati dal Mac) | — |

**Perché la fase 1 è stata abbandonata:** GitHub Pages serve solo file statici. Con Supabase Auth
(callback OAuth), route API, webhook Stripe e middleware serviva un runtime Node.

**Perché la fase 3 (decisione del 02/06/2026, commit `70eaf24`):** il job *Deploy to VPS* era il
punto fragile. I fallimenti si concentrano nella messa a punto (09–13/05) e compaiono tutti nello step SSH.
L'ultimo log disponibile riporta `dial tcp ***:22: i/o timeout`: il runner GitHub non riusciva a raggiungere
la porta SSH del VPS, protetta da firewall `ufw` e `fail2ban`. Inoltre l'audit di sicurezza del 02/06
(voce I4) segnalava il rischio di supply chain nel dare la **chiave SSH privata del VPS** a un'action
di terze parti (`appleboy/ssh-action`, non pinnata a SHA).
Il deploy locale mantiene **identici** swap, smoke test e rollback; cambia solo come arriva l'immagine
(`docker save | ssh docker load` invece di un pull da GHCR). I secrets runtime restano sul VPS.

> **Perimetro dell'esame:** documento la pipeline Actions (fase 2) come implementazione storica
> di CI/CD, con run reali e link, e la fase 3 come scelta operativa successiva.
> Oggi il comando di rilascio è manuale; build, trasferimento, swap e controlli sono scriptati.
> Lo staging logico locale precede la pubblicazione. Non è prevista la riattivazione di Actions
> per preparare questa consegna.

---

## 4. Containerizzazione

### 4.1 Dockerfile (front end Next.js) — [esempio Dockerfile](./esempi/Dockerfile)

Build **multi-stage** su `node:20-alpine`:

| Stage | Cosa fa | Perché |
|---|---|---|
| `deps` | `npm ci` da `package-lock.json` | layer cache: si ricostruisce solo se cambiano le dipendenze |
| `builder` | riceve le `NEXT_PUBLIC_*` come `ARG`, lancia `npm run build` con `BUILD_TARGET=docker` → `output: "standalone"` | le variabili pubbliche finiscono nel bundle al build |
| `runner` | copia solo `.next/standalone`, `.next/static`, `public`; utente **non-root** `nextjs` (uid 1001); `CMD node server.js` | runtime ridotto e minore superficie d'attacco |

`.dockerignore` esclude `.env`, `.env.*` (tranne `*.example`), `.git`, `node_modules`, `.next`
e la documentazione interna. Il `COPY . .` dello stage builder quindi **non può** includere secrets nei layer.

### 4.2 docker-compose.yml — [esempio docker-compose.yml](./esempi/docker-compose.yml)

```yaml
services:
  web:
    image: ghcr.io/turbor93/meccanicosubito:latest
    build: { context: ., args: { NEXT_PUBLIC_*: ${...} } }
    env_file: [.env.production]          # secrets runtime, mai nell'immagine
    ports: ["127.0.0.1:3000:3000"]       # solo loopback: si passa da Nginx
    restart: unless-stopped
    healthcheck: wget /api/health ogni 30s
    logging: json-file, 10m × 3 file     # log rotation
```

**Il back end nel locale.** Il back end è Supabase, e in locale non sta nel compose dell'app:
lo avvia la **Supabase CLI** (`npm run db:start`) come stack Docker di container
(Postgres, GoTrue/Auth, PostgREST, Storage, Studio, Kong, Edge Runtime), gestito da OrbStack.
È una scelta voluta: la CLI garantisce **parità di versione con il cloud**
e applica automaticamente le 134 migration e il seed (`db:reset`). In produzione il back end è managed (Supabase Cloud),
quindi il compose di produzione contiene solo `web`.

### 4.3 Comandi usati

Questi comandi descrivono il lavoro nella repository originale. La consegna pubblica
contiene solo documentazione ed esempi: non include il codice necessario ad avviare l’app.

```bash
# --- Development (modalità veloce, nessun back end) ---
npm install
cp .env.local.example .env.local        # NEXT_PUBLIC_DATA_SOURCE=mock
npm run dev                             # http://localhost:3000

# --- Development con back end reale in Docker ---
npm run db:start                        # stack Supabase locale
npm run db:reset                        # migration + seed
npm run db:status                       # URL + anon key da copiare in .env.local
npm run dev

# --- Container di produzione in locale ---
set -a && source .env.production && set +a
docker compose up -d --build
docker compose ps                       # STATUS: healthy
curl -s http://127.0.0.1:3000/api/health
docker compose logs -f web --tail 100
docker compose down

# --- Build immagine per il VPS (x86_64) dal Mac arm64 ---
docker buildx build --platform linux/amd64 -t ghcr.io/turbor93/meccanicosubito:$(git rev-parse --short HEAD) --load .
```

---

## 5. Sicurezza e gestione dei secrets

### 5.1 `.env` fuori dal repository

| File | Dove vive | Contiene |
|---|---|---|
| `.env.local` | Mac, gitignored | config dev (mock o Supabase locale) |
| `.env.production` | **solo VPS**, gitignored | service_role Supabase, Stripe secret + webhook secret, chiavi OAuth Fatture in Cloud |
| `.env.backup` | Mac, gitignored, `chmod 400` | credenziali DB; il dump impone read-only alla sessione, password restic, token manutenzione |
| `.env.sentry-build-plugin` | Mac, gitignored | token di upload source map passato a Docker come **build secret**, mai come `ARG`/`ENV` persistente |
| `*.example` | **committati** | solo nomi delle variabili e placeholder |

### 5.2 Verifica che la separazione sia reale — [`evidenze/01-env-history.txt`](./evidenze/01-env-history.txt)

```bash
$ git log --all --diff-filter=A --name-only -- .env .env.local .env.production .env.backup '*.env'
# (nessun output nei percorsi e nei ref disponibili controllati)
$ git ls-files | grep -i env
.env.backup.example  .env.local.example  .env.production.example
$ git check-ignore -v .env.local .env.production .env.backup
.gitignore:7:.env*.local   .gitignore:9:.env.production   .gitignore:10:.env.backup
```

### 5.3 GitHub Secrets e Variables storici — [`evidenze/02-github-secrets.txt`](./evidenze/02-github-secrets.txt)

| Secrets (cifrati, non rileggibili) | Variables (non sensibili) |
|---|---|
| `VPS_HOST`, `VPS_USER`, `VPS_SSH_PRIVATE_KEY`, `GHCR_PULL_TOKEN`, `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` | `PROD_DEPLOY_ENABLED` (gate del deploy), `NEXT_PUBLIC_SITE_URL`, `NEXT_PUBLIC_GTM_ID`, `NEXT_PUBLIC_DEPOSIT_ENABLED` |

Scelte:
- Anche le chiavi *publishable* stanno nei Secrets, per tenerle fuori dai log.
- I secrets **runtime** (service_role, Stripe secret) **non sono mai stati su GitHub**: vivono solo nel `.env.production` del VPS.
- Il push su GHCR usa il `GITHUB_TOKEN` effimero, non un token personale.

### 5.4 Nessun secret nei log della pipeline — [`evidenze/04-log-masking.txt`](./evidenze/04-log-masking.txt)

Analisi del log completo della run CD `26680816310`:
**1.742 righe, 31 valori mascherati `***`, 0 occorrenze** di pattern di chiavi in chiaro
(`sb_publishable_…`, `pk_live/test_…`, `BEGIN OPENSSH`, IP del VPS). Anche nel log d'errore
della run `26833635113` l'host appare come `dial tcp ***:22`.

> **Lezione trovata nei log:** `VPS_USER` vale `deploy`, una parola comune. GitHub quindi maschera
> *ogni* occorrenza di "deploy" (`./***/pre***-check.sh`). Non è una fuga di dati, ma rende i log
> meno leggibili: meglio usare come secret solo valori ad alta entropia e mettere lo username
> non sensibile in una Variable.

### 5.5 Trappola documentata

`gh secret set NOME --body -` **non** legge da stdin: salva letteralmente `-`. La pipeline resta
verde, ma il bundle contiene una chiave non valida e ogni chiamata a Supabase risponde 401.
Soluzione: omettere `--body` e passare il valore via pipe.

### 5.6 Hardening dell'infrastruttura (oltre la consegna)

- **VPS**: login root disabilitato, solo chiavi SSH, `ufw`, `fail2ban`, utente `deploy` non-root.
- **Nginx**: HSTS, `X-Frame-Options`, `nosniff`, `Referrer-Policy`, `Permissions-Policy`, CSP (in *Report-Only*), rate-limit su lead form e `/api/stripe/*` (webhook escluso).
- **App/DB**: RLS su tutte le tabelle, audit di sicurezza del 02/06 e del 17/07/2026. Esempio: la migration `0128` revoca l'EXECUTE ad `anon` e chiude un open email relay.

---

## 6. Pipeline CI storica — [`workflows-storici/ci.yml`](./workflows-storici/ci.yml)

```yaml
on:  { push: { branches: [main] }, pull_request: }
concurrency: { group: ci-${{ github.ref }}, cancel-in-progress: true }
jobs:
  validate:   # "Typecheck + Lint + Build"
    steps: checkout → setup-node 20 (cache npm) → npm ci
           → npm run typecheck     (tsc --noEmit)
           → npm run lint          (next lint: next/core-web-vitals + next/typescript)
           → npm run build:docker  (Next.js standalone; non costruisce l'immagine Docker)
```

- **Trigger** a ogni push su `main` e su ogni PR; `concurrency` cancella le run superate.
- **Fallimento visibile**: ogni step che esce ≠ 0 rende il job rosso ❌ e la run appare fallita
  su Actions, sul commit e sulla PR. Esempi reali:
  - [`25784837319`](https://github.com/TurboR93/meccanicosubito/actions/runs/25784837319): step **Typecheck** fallito (13/05).
  - [`25610054412`](https://github.com/TurboR93/meccanicosubito/actions/runs/25610054412): step **Build** fallito, pagina non prerenderizzabile senza `Suspense` (09/05).
- **Secondo livello, prima della CI**: il pre-commit Husky esegue `typecheck && lint`, quindi
  il codice con errori di lint in genere non arriva nemmeno al commit.
- **Ultima CI verde storica**: [`26833635111`](https://github.com/TurboR93/meccanicosubito/actions/runs/26833635111), commit `bca78e1`, 02/06/2026. Job da 16:31:24 a 16:33:53 UTC: 2 min 29 s. Typecheck, lint e build tutti riusciti; esiti riverificati via GitHub il 23/09 in [`08-ci-storica-verificata.json`](./evidenze/08-ci-storica-verificata.json).
- **Statistiche**: 101 run verdi, 5 fallite, 1 cancellata.

> **Nota sulla build Docker:** `next.config.ts` imposta `eslint.ignoreDuringBuilds` quando
> `BUILD_TARGET=docker`. Per questo il lint è uno **step separato ed esplicito** della CI.
> Lo script esegue `BUILD_TARGET=docker next build`: la build dell'immagine avveniva
> nel workflow CD separato. Non è dimostrato il requisito «lint + build container»
> come sequenza che blocchi il deploy se il lint fallisce.

---

## 7. Pipeline CD storica e deploy pubblico — [`workflows-storici/deploy.yml`](./workflows-storici/deploy.yml)

```
push main ─► build-and-push ─► wait-for-schema ─► deploy (SSH) ─► smoke-test ──ok──► ✅ live
             buildx + GHCR      poll migration     predeploy-check           │
             :sha e :latest     su Supabase        tag :previous             └─fail─► rollback a :previous
             cache GHA          (max 120 s)        pull + compose up -d
```

| Job | Dettagli |
|---|---|
| **Gate** | `if: vars.PROD_DEPLOY_ENABLED == 'true'`: la pipeline è stata mergiata *prima* di configurare i secrets senza rompere nulla (6 run "skipped" il 09/05) |
| **build-and-push** | build sul runner (toglie 2–4 GB di picco RAM dal VPS), push `ghcr.io/turbor93/meccanicosubito:<sha>` e `:latest`, cache layer GHA (build successive 2–3 min) |
| **wait-for-schema** | evita la race *codice nuovo / schema vecchio*: `psql` aspetta che l'ultima migration del repo compaia in `schema_migrations` sul cloud |
| **deploy** | `git reset --hard origin/main` sul VPS, `predeploy-check.sh` (blocca se `DATA_SOURCE≠supabase` o chiavi malformate), tag `:previous`, `docker compose up -d --no-build` |
| **smoke-test** | `deploy/smoke-test.sh`: 9 path a 200, `/api/health` con `status:ok`, bundle con il Supabase ref corretto, REST anon che vede ≥1 officina, redirect 308 UUID→slug, webhook Stripe che rifiuta firme false, sitemap senza UUID. **Se fallisce → rollback automatico** |

- **Piattaforma**: VPS Hostinger con Docker + Nginx, **non** Vercel/Netlify/Pages. Motivi: runtime Node
  completo (middleware, route API, webhook Stripe senza limiti di durata), controllo su Nginx
  (header, rate-limit, manutenzione), costo fisso, nessun vendor lock-in e dati in UE.
  GitHub Pages è stato provato nella fase 1 e superato.
- **URL pubblico**: https://meccanicosubito.it (HTTP 200, TLS Let's Encrypt), verificato il 14/09/2026 in [`evidenze/05-produzione-health.txt`](./evidenze/05-produzione-health.txt).
- **Run CD verde**: [`26680816310`](https://github.com/TurboR93/meccanicosubito/actions/runs/26680816310), 30/05/2026, `e3b58b1`, 3 min 11 s.

> **Difetto trovato analizzando la run verde:** nella `26680816310` il job *Smoke test* risulta
> **skipped**. La causa è che `wait-for-schema` era saltato (variabile `SUPABASE_DB_PASSWORD_SET` non impostata),
> e su GitHub Actions lo stato "skipped" si propaga ai job a valle, a meno di un `if:` esplicito.
> Il job `deploy` lo aveva (`always() && …`), `smoke-test` no. Risultato: con quella configurazione
> smoke test e rollback non partivano mai. Correzione:
> ```yaml
> smoke-test:
>   needs: [build-and-push, deploy]
>   if: ${{ always() && needs.deploy.result == 'success' }}
> ```
> Un problema distinto: CI e deploy erano due workflow **paralleli** e il deploy non aspettava
> la CI. Andrebbero legati con `needs:` in un unico workflow, oppure con `on: workflow_run`.

### 7.1 Deploy attuale (fase 3) — `npm run deploy`

1. **Preflight**: working tree pulito, `HEAD == origin/main`, SSH ok.
2. `supabase db push` (migration **prima** dello swap, idempotente).
3. Lettura delle `NEXT_PUBLIC_*` dal `.env.production` **del VPS** via SSH: un'unica fonte di verità.
4. Build `linux/amd64` sul Mac (buildx).
5. `docker save | gzip | ssh docker load`.
6. Tag `:previous` → `compose up`.
7. Smoke test → rollback automatico.

Lo script è *maintenance-aware*: se il sipario è alzato, lo smoke test usa il cookie di bypass.
Il 15/09/2026 `/api/health` mostrava `3001617`, il deploy che ha introdotto Sentry.

**Aggiornamento 23/09:** `/api/health` ora espone `756d161ce5c190df470e9196639d82ffe4178e9f`,
build `2026-09-22T14:11:26Z`, HTTP 200 e `Cache-Control: no-store, max-age=0`.
Il test Sentry del 15/09 resta associato alla sua release `3001617`.
Prova attuale: [`10-produzione-health-attuale.json`](./evidenze/10-produzione-health-attuale.json).

---

## 8. Monitoraggio

### 8.1 Cosa esiste oggi

| Strumento | Cosa rileva |
|---|---|
| **`/api/health`** | `{"status":"ok","commit":"<sha>","builtAt":"<iso>"}` con `Cache-Control: no-store`: dice *se* il sito risponde e *quale* versione gira |
| **Docker healthcheck** | ogni 30 s; `docker compose ps` mostra `healthy/unhealthy` |
| **Smoke test post-deploy** | regressioni funzionali al momento del rilascio, con rollback |
| **Log rotation + `docker compose logs`** | errori server consultabili, disco protetto (max 30 MB) |
| **Modalità manutenzione** | `npm run maintenance on/off`: toggle istantaneo via flag file letto da Nginx |
| **Backup restic** | snapshot incrementali cifrati di DB e Storage (nati dall'incident del 17/06/2026) |
| **GA4 / Stripe Dashboard** | traffico, pagamenti, consegna dei webhook |

### 8.2 Uptime monitor — UptimeRobot *(già attivo)*

- **Comportamento documentato il 22/09**: richieste `HEAD /api/health` dall'esterno ogni circa
  5 minuti; 218 richieste con user-agent UptimeRobot, tutte HTTP 200, nei log Nginx esaminati.
- **Fonte**: documento operativo `docs/sentry-observability.md §6`, commit `6b577b7`,
  consultato nella repository privata. [Riscontro riportato nella consegna](./evidenze/11-uptimerobot-stato.md).
  È una verifica operativa precedente, non una lettura della dashboard svolta il 23/09.
- **Copertura**: raggiungibilità HTTP dell'app. L'endpoint non interroga Supabase o Stripe:
  uno stato `ok` non certifica il funzionamento dei pagamenti o del database.
- **Da verificare nella dashboard**: destinatario degli avvisi, ritardo e regola di alert;
  salvare la schermata del monitor. Le richieste HEAD non dimostrano un controllo della keyword
  nel corpo della risposta: la precedente configurazione proposta non va presentata come attiva.

### 8.3 Error tracker — Sentry *(attivo in produzione dal 15/09/2026)*

- `@sentry/nextjs` con `withSentryConfig`, inizializzazione server, edge e browser e tunnel
  `/monitoring`. La configurazione effettiva usa `NEXT_PUBLIC_SENTRY_DSN`, letta dal VPS al build.
- `SENTRY_AUTH_TOKEN` resta in `.env.sentry-build-plugin` sul Mac: Docker lo riceve tramite
  `--secret` e `RUN --mount=type=secret`, **non** come build-arg. Le source map pubbliche vengono
  cancellate dopo l’upload. L’implementazione è nella repository privata; gli screenshot
  del test e l’esempio Dockerfile documentano il comportamento nella consegna.
- **Test eseguito il 15/09/2026**: la route `/api/debug-sentry` risponde 404 senza token o con token errato e 500 con il token giusto. L'errore compare in *Issues* come `MECCANICOSUBITO-2`, con environment `production`, release `300161757fb7` e stack trace risolto dalle source map (`src/app/api/debug-sentry/route.ts:31`). Il token nella query string arriva a Sentry come `[Filtered]`. Prove in [`evidenze/06-sentry-verifica.txt`](./evidenze/06-sentry-verifica.txt) e `screenshot/sentry-*.png`.
- **Perché Sentry**: supporto nativo a Next.js (client, server ed edge), stack trace leggibili grazie alle source map, release legate al commit SHA che è già esposto da `/api/health`.
- **Limite attuale**: gli errori intercettati e scritti solo con `console.error` non vengono
  inviati automaticamente. L'evento ricevuto prova l'error tracking, non la consegna degli alert
  email: regola e destinatario vanno verificati separatamente.

### 8.4 Come interpretare gli alert

| Alert | Significato | Primi passi |
|---|---|---|
| UptimeRobot **DOWN**, timeout | VPS o Nginx non raggiungibili | `ssh` al VPS; se non risponde → pannello Hostinger/console; controllare Cloudflare DNS |
| **DOWN**, HTTP 502 | Nginx attivo ma container fermo | `docker compose ps` → `logs web`; `docker compose up -d`; se il deploy è recente → rollback a `:previous` |
| **DOWN**, HTTP 503 | modalità manutenzione accesa (voluta?) | `npm run maintenance status` → `off` se dimenticata |
| **DOWN**, keyword mancante | risponde qualcosa che non è l'app | verificare la config Nginx e il certificato (`certbot renew --dry-run`) |
| **UP** dopo DOWN | ripristinato | annotare durata e causa; se ricorrente → aprire un task |
| Sentry **nuovo issue** subito dopo un deploy | regressione introdotta dal rilascio | confrontare `release` con il commit in `/api/health`; se blocca i flussi (login, prenotazione, pagamento) → rollback |
| Sentry **picco** di un issue noto | problema esterno (Supabase, Stripe) o traffico anomalo | status page dei provider; log Nginx per rate-limit/429 |
| Sentry issue **isolato** | edge case di un singolo utente | triage in backlog, `Resolve in next release` |

**Regola generale:** prima si mitiga (rollback o manutenzione), poi si indaga.

---

## 9. Stato della consegna rispetto alla traccia completa

**Esito del 24/09: conformità parziale.** La matrice completa e le prove consultate
sono in [VERIFICA-CONFORMITA.md](VERIFICA-CONFORMITA.md).

| Area | Stato rispetto alla richiesta |
|---|---|
| Analisi, scelta strumenti e comandi | Documentati; pianificazione iniziale non dimostrata dal primo README. |
| Tre ambienti | Staging come fase locale documentato; separazione da development e prove da precisare. Non è richiesto necessariamente un server remoto. |
| Containerizzazione | Dockerfile presente; Compose solo front end, Supabase avviato a parte. Prova dell'avvio locale non allegata. |
| Sicurezza | Verifiche e inventari disponibili, con i limiti dei percorsi e dei log esaminati. |
| CI | Lint e build Next.js storici verificati; build immagine nel workflow CD separato. CI applicativa non attiva oggi. |
| CD | Deploy storico riuscito, ma indipendente dall'esito CI. Oggi avvio manuale dal Mac; VPS diverso dai provider richiesti. |
| Prove delle run | JSON pubblici disponibili, link originali privati: screenshot o accesso al docente necessari per la consultazione delle run richieste. |
| Monitoraggio | Uptime documentato; evento Sentry e screenshot presenti, guida agli alert presente. Destinatari e ricezione degli avvisi non dimostrati. |
| URL pubblico | Home e health nuovamente HTTP 200 il 24/09 alle 08:45 UTC; release `756d161`. |

**Per l'esposizione:** le run storiche provano ciò che hanno eseguito, non un deploy
bloccato dalla CI né l'automazione attuale. La scelta di raccontare la storia del progetto
resta valida come perimetro narrativo; per soddisfare la traccia occorrono correzioni
dimostrate o l'accettazione delle differenze da parte del docente. Non basta aggiornare
la documentazione. Smoke test e rollback saltati restano limiti storici, pur non essendo
requisiti espliciti della traccia. PDF e Canva precedono questo audit e vanno letti
insieme al rapporto di conformità.

**Condivisione:** questa repository dell’esame è pubblica e separata dalla repository
privata della webapp. Relazione, PDF, prove esportate e configurazioni illustrative
sono consultabili senza accesso alla produzione. Il codice dell’app e le migration restano
privati. Solo i link alle run Actions originali
richiedono accesso alla repository privata; i relativi esiti sono inclusi nelle evidenze.
