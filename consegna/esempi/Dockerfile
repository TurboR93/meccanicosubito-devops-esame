# syntax=docker/dockerfile:1.10
# (1.10+: serve per `RUN --mount=type=secret,...,env=` usato dall'upload source maps Sentry)
# Multi-stage build per Next.js 15 con output: "standalone".
# Image finale ~150 MB (vs ~1+ GB con node_modules completi).

# ----- Stage 1: dipendenze --------------------------------------------------
FROM node:20-alpine AS deps
WORKDIR /app

# libc6-compat: alcuni nativi (sharp era dev-only, ma altri pacchetti...) ne hanno bisogno
RUN apk add --no-cache libc6-compat

COPY package.json package-lock.json ./
RUN npm ci --legacy-peer-deps


# ----- Stage 2: build --------------------------------------------------------
FROM node:20-alpine AS builder
WORKDIR /app

# Le NEXT_PUBLIC_* sono bake-ate al build (Next le inietta nel bundle JS).
# Le passiamo come build args, dichiarate da docker-compose / build script.
ARG NEXT_PUBLIC_DATA_SOURCE=supabase
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
ARG NEXT_PUBLIC_COMMIT_SHA=
ARG NEXT_PUBLIC_BUILD_TIME=
ARG NEXT_PUBLIC_SITE_URL=https://meccanicosubito.it
ARG NEXT_PUBLIC_GTM_ID=
ARG NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=
ARG NEXT_PUBLIC_STRIPE_BNPL_MIN_AMOUNT_CENTS=15000
ARG NEXT_PUBLIC_DEPOSIT_ENABLED=false

ENV NEXT_PUBLIC_DATA_SOURCE=$NEXT_PUBLIC_DATA_SOURCE
ENV NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL
ENV NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=$NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
ENV NEXT_PUBLIC_COMMIT_SHA=$NEXT_PUBLIC_COMMIT_SHA
ENV NEXT_PUBLIC_BUILD_TIME=$NEXT_PUBLIC_BUILD_TIME
ENV NEXT_PUBLIC_SITE_URL=$NEXT_PUBLIC_SITE_URL
ENV NEXT_PUBLIC_GTM_ID=$NEXT_PUBLIC_GTM_ID
ENV NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=$NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY
ENV NEXT_PUBLIC_STRIPE_BNPL_MIN_AMOUNT_CENTS=$NEXT_PUBLIC_STRIPE_BNPL_MIN_AMOUNT_CENTS
ENV NEXT_PUBLIC_DEPOSIT_ENABLED=$NEXT_PUBLIC_DEPOSIT_ENABLED
ENV BUILD_TARGET=docker
ENV NEXT_TELEMETRY_DISABLED=1

# Sentry: DSN pubblica (finisce nel bundle browser, vuota = Sentry spento).
ARG NEXT_PUBLIC_SENTRY_DSN=
ARG NEXT_PUBLIC_SENTRY_ENVIRONMENT=
ENV NEXT_PUBLIC_SENTRY_DSN=$NEXT_PUBLIC_SENTRY_DSN
ENV NEXT_PUBLIC_SENTRY_ENVIRONMENT=$NEXT_PUBLIC_SENTRY_ENVIRONMENT
# Org/project NON sono segreti: servono solo all'upload source maps. Restano
# nello stage builder (non copiati nel runner).
ARG SENTRY_ORG=
ARG SENTRY_PROJECT=
ENV SENTRY_ORG=$SENTRY_ORG
ENV SENTRY_PROJECT=$SENTRY_PROJECT

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# SENTRY_AUTH_TOKEN arriva come BUILD SECRET buildx (mai ARG/ENV → mai nei layer
# né in `docker history`): esiste solo durante questo RUN.
#   docker buildx build --secret id=sentry_auth_token,env=SENTRY_AUTH_TOKEN ...
# Secret assente (required=false) → upload source maps saltato, build normale.
RUN --mount=type=secret,id=sentry_auth_token,env=SENTRY_AUTH_TOKEN,required=false \
    npm run build


# ----- Stage 3: runner -------------------------------------------------------
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

# Utente non-root.
RUN addgroup --system --gid 1001 nodejs \
 && adduser  --system --uid 1001 nextjs

# Copia output standalone (server.js + node_modules ridotto), static e public.
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]
