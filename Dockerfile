# Stage 1: Build vault-sync from source
FROM golang:1.25-bookworm AS builder

# renovate: datasource=github-tags depName=alexjbarnes/vault-sync
ARG VAULT_SYNC_VERSION=v1.1.0

RUN git clone --depth 1 --branch "${VAULT_SYNC_VERSION}" \
        https://github.com/alexjbarnes/vault-sync.git /src

WORKDIR /src

RUN CGO_ENABLED=0 go build \
        -ldflags "-s -w -X main.Version=${VAULT_SYNC_VERSION}" \
        -o /vault-sync ./cmd/vault-sync

# Stage 2: Runtime
FROM node:24-bookworm-slim

# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        ripgrep \
        build-essential \
        python3 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/obsidian-headless
COPY package.json package-lock.json ./
RUN npm ci \
 && apt-get purge -y build-essential python3 \
 && apt-get autoremove -y \
 && rm -rf /root/.npm
ENV PATH="/opt/obsidian-headless/node_modules/.bin:$PATH"

# Install vault-sync binary
COPY --from=builder /vault-sync /usr/local/bin/vault-sync

# Install entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

EXPOSE 8090

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
