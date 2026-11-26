ARG REGISTRY=docker.io/library
ARG APP_VERSION=0.0.0-dev
ARG NPM_REGISTRY=https://registry.npmjs.org

FROM ${REGISTRY}/node:20-slim AS builder
ARG NPM_REGISTRY
WORKDIR /app
COPY package*.json ./
RUN npm config set registry "${NPM_REGISTRY}" \
 && npm config set fetch-retries 2 \
 && npm config set fetch-timeout 60000 \
 && npm ci --ignore-scripts --no-audit --no-fund
COPY . .
RUN npm run build

FROM ${REGISTRY}/node:20-slim
ARG APP_VERSION
ARG NPM_REGISTRY
WORKDIR /app
COPY package*.json ./
RUN npm config set registry "${NPM_REGISTRY}" \
 && npm config set fetch-retries 2 \
 && npm config set fetch-timeout 60000 \
 && npm ci --omit=dev --ignore-scripts --no-audit --no-fund
COPY server ./server
COPY --from=builder /app/dist ./dist
ENV APP_VERSION=${APP_VERSION}
LABEL org.opencontainers.image.title="tybooks" \
      org.opencontainers.image.version="${APP_VERSION}"
EXPOSE 8080
CMD ["node", "server/index.js"]
