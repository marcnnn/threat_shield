# 0003 MCP tools with ash_ai, authenticated with personal API keys

**Status:** Proposed (2026-11-18)

## Context

Users want to work on their threat models from a chat agent such as Claude, not only
through the built-in assistant, which needs an OpenAI key on the server. The agent
reasons itself and needs tools to read and change the model as the user. The domain
actions already carry descriptions and policies (ADR 0002).

## Decision

- **ash_ai serves the actions as MCP tools** at `/mcp`. The tools are declared in the
  `tools` blocks of the domains; a tool is an existing action, so the policies and
  validations of the web application apply unchanged.
- **Authentication with personal API keys.** The user creates a key on the settings
  page and puts it into the client configuration (`Authorization: Bearer`). The key
  signs in the user with the AshAuthentication `api_key` strategy; the user is the
  actor of every tool call.
- **Reads, creates and updates only.** No deletes, no member, invite or key
  management over MCP.
- **ash_ai 1.0.2.** Later versions need ash 3.33, and the app is held at ash 3.27.7.

## Consequences

- A leaked key gives the rights of its user until it expires or is revoked. Keys
  expire after at most 365 days, and only a hash is stored.
- Clients with a static header (Claude Code, Claude Desktop with `mcp-remote`) work.
  Remote connectors that require OAuth (claude.ai web) do not.
- `Checks.OrganisationRoleForCreate` allows the ash_ai pre-check with an empty input,
  so that create tools are listed.

## Rejected alternatives

- **OAuth 2.1 with dynamic client registration** (recommended by ash_ai for remote
  clients). Works with claude.ai connectors and needs no copied secret, but needs an
  authorization server, consent screens and token storage. Can be added later beside
  the keys.
- **A hand-written MCP server or REST API.** Duplicates the action descriptions and
  input schemas that ash_ai derives from the resources.
- **Only the built-in OpenAI integration.** Keeps the reasoning on the server and
  costs the quota; users cannot bring their own agent.
