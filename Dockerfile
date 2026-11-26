ARG REGISTRY=docker.io/library
ARG APP_VERSION=0.0.0-dev

FROM ${REGISTRY}/node:20-slim AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM ${REGISTRY}/node:20-slim
ARG APP_VERSION
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY server ./server
COPY --from=builder /app/dist ./dist
ENV APP_VERSION=${APP_VERSION}
LABEL org.opencontainers.image.title="tybooks" \
      org.opencontainers.image.version="${APP_VERSION}"
EXPOSE 8080
CMD ["node", "server/index.js"]
