# Obsidian MCP on Fly.io

Run an [MCP server][vault-sync] for your Obsidian vault on Fly.io.
AI assistants (Claude.ai, etc.) can read, write, and search your
vault over HTTPS with OAuth 2.1 authentication.

[vault-sync]: https://github.com/alexjbarnes/vault-sync

## Architecture

Single container with two processes managed by a shell entrypoint:

- **ob sync** — [obsidian-headless][ob] keeps a local copy of your
  vault in sync with Obsidian's servers
- **vault-sync** — Serves the local vault files over MCP
  with OAuth 2.1 auth

[ob]: https://www.npmjs.com/package/obsidian-headless

Both share a persistent volume at `/data`.

```text
┌──────────────────────────────────────────┐
│  Container (node:24-bookworm-slim)       │
│  entrypoint.sh                           │
│                                          │
│  ┌─────────────┐  ┌──────────────┐       │
│  │ ob sync     │  │ vault-sync   │       │
│  │ Node.js CLI │  │ Go binary    │       │
│  └──────┬──────┘  └──────┬───────┘       │
│         └────────┬───────┘               │
│                  │                       │
│  ┌───────────────┴───────────────┐       │
│  │  Fly.io Persistent Volume     │       │
│  │  /data/vault     (vault files)│       │
│  │  /data/.vault-sync (state db) │       │
│  └───────────────────────────────┘       │
│                                          │
│  Exposed: :8090 (MCP only)               │
└──────────────────────────────────────────┘
```

## Prerequisites

- [Fly.io CLI](https://fly.io/docs/flyctl/install/) (`flyctl`)
- [Docker](https://docs.docker.com/get-docker/) (for local testing)
- [Node.js](https://nodejs.org/) 22+ (for initial auth token)
- An [Obsidian Sync](https://obsidian.md/sync) subscription

## First-Time Auth Setup

Obsidian requires an interactive login to obtain an auth token. Do this once locally:

```bash
npm install -g obsidian-headless
ob login
```

Or with [Nix](https://nixos.org/):

```bash
nix develop
ob login
```

After logging in, extract your token:

```bash
cat ~/.obsidian-headless/auth_token
```

Save this value — you'll set it as `OBSIDIAN_AUTH_TOKEN` on Fly.io.

## Deploy to Fly.io

### 1. Create the app and configure fly.toml

```bash
fly apps create
cp fly.toml.example fly.toml
```

Edit `fly.toml` and set `app` to your app name and `primary_region` to your
nearest [Fly.io region](https://fly.io/docs/reference/regions/).

### 2. Create a volume

```bash
# single volume is fine for personal use — answer "y" to the HA warning
# region MUST match primary_region in fly.toml (machines can only mount local volumes)
fly volumes create obsidian_data --region <same-as-primary_region> --size 1
```

### 3. Set secrets

```bash
fly secrets set OBSIDIAN_AUTH_TOKEN="your-auth-token"
fly secrets set OBSIDIAN_VAULT_NAME="Your Vault Name"
fly secrets set MCP_SERVER_URL="https://<your-app-name>.fly.dev"
fly secrets set MCP_AUTH_USERS="user:password"
fly secrets set OBSIDIAN_VAULT_PASSWORD="your-e2ee-password"  # optional, only if E2E encrypted
```

### 4. Deploy

```bash
fly deploy
```

### 5. Verify

```bash
curl "https://<your-app-name>.fly.dev/.well-known/oauth-protected-resource"
```

## Connect Claude.ai

Add `https://<your-app>.fly.dev/mcp` as a remote MCP server in
Claude.ai settings. You'll be prompted to authenticate via OAuth
using the credentials set in `MCP_AUTH_USERS`.

## Local Testing

```bash
cp .env.example .env
# Edit .env with your credentials

docker build -t obsidian-mcp .
docker run --env-file .env -p 8090:8090 -v obsidian_data:/data obsidian-mcp
```

## Environment Variables

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `OBSIDIAN_AUTH_TOKEN` | Yes | — | Auth token (from `ob login`) |
| `OBSIDIAN_VAULT_NAME` | Yes | — | Name of the vault to sync |
| `OBSIDIAN_VAULT_PASSWORD` | If E2EE | — | E2E encryption password |
| `ENABLE_SYNC` | No | `false` | vault-sync built-in sync |
| `ENABLE_MCP` | No | `true` | Enable the MCP server |
| `OBSIDIAN_SYNC_DIR` | No | `/data/vault` | Path to vault files |
| `MCP_SERVER_URL` | Yes | — | Public base URL |
| `MCP_AUTH_USERS` | Yes | — | `user:pass` pairs for OAuth |
| `MCP_CLIENT_CREDENTIALS` | No | — | `id:secret` for headless OAuth |
| `MCP_API_KEYS` | No | — | `user:key` for API key auth |
| `MCP_LOG_LEVEL` | No | `info` | `debug`/`info`/`warn`/`error` |
| `ENVIRONMENT` | No | `production` | `production` or `development` |
