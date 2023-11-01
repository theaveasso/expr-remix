FROM node:18-bullseye-slim AS base

# install openssl and sqlite3 for prisma
RUN apt-get update && apt-get install -y openssl sqlite3

# Dev deps stage
FROM base AS deps
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

## Prod deps stage
FROM deps AS prod-deps
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY package.json package-lock.json ./

RUN npm prune --omit=dev

## Builder stage
FROM deps AS builder
WORKDIR /app

COPY prisma ./prisma
RUN npx prisma generate

COPY . .
COPY --from=deps /app/node_modules ./node_modules

RUN npm run build

## Runner stage
FROM base AS runner
WORKDIR /app

ENV NODE_ENV="production"
ENV DATABASE_URL="file:/app/data/sqlite.db"
ENV PORT="3000"

COPY --from=prod-deps /app/package.json ./
COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=builder /app/build ./build
COPY --from=builder /app/public ./public

ENTRYPOINT ["node", "node_modules/.bin/remix-serve", "build/index.js"]



