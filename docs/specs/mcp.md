# MCP server for chat agents

A chat agent (for example Claude Code or Claude Desktop) works with the threat models
of a user through the Model Context Protocol (MCP). The agent does the reasoning and
calls ThreatShield actions as tools. It acts as the user: it sees and changes exactly
what the user may see and change in the web application.

Decision: [ADR 0003](../adr/0003-mcp-with-personal-api-keys.md).

## Endpoint

- URL: `https://<host>/mcp` (locally `http://localhost:4000/mcp`). The settings page
  shows the URL of the running instance.
- Transport: streamable HTTP, served by `AshAi.Mcp.Router` (ash_ai 1.0.2). It supports
  the protocol versions `2025-03-26` and `2025-06-18` (with `initialize`) and
  `2026-07-28`.
- Server name `ThreatShield`. The `initialize` answer carries instructions for the
  agent: start with `list_organisations`, read `threat_model_context` before creating
  entities, ask the user before writing.
- Route: `scope "/mcp"` in `lib/threat_shield_web/router.ex`, pipeline `:mcp`.

## Authentication

- Every request needs a personal API key in the header
  `Authorization: Bearer <key>`. `AshAuthentication.Strategy.ApiKey.Plug` signs the
  user in with `User.sign_in_with_api_key` and sets the user as the Ash actor.
- A request without a key, with an unknown, expired or revoked key, or with another
  authorization scheme gets `401`.
- A key is valid until `expires_at`. Only a SHA-256 hash is stored
  (`ThreatShield.Accounts.ApiKey`). The key starts with `threatshield_`.
- A key cannot create further keys (`ApiKey` policy `UsingApiKey`).

### Creating and revoking a key

On **Account Settings** (`/users/settings`), section **API keys**:

- choose the validity (30, 90 or 365 days) and click **Create API key**. The key is
  shown once; copy it then.
- the table lists the keys of the user with creation and expiry dates; **Revoke**
  deletes a key, and requests with it get `401` from then on.
- changing or resetting the password deletes all keys of the user.
- expired keys are deleted by `ThreatShield.Periodically`.

Domain functions: `Accounts.create_api_key/2`, `Accounts.list_api_keys/1`,
`Accounts.revoke_api_key/2` (by id), each with `actor:`.

## Tools

The tools are defined in the `tools` blocks of the domains
(`lib/threat_shield/accounts.ex`, `lib/threat_shield/threat_management.ex`). The router
serves all tools of the domains of `:threat_shield`. A tool takes its description from
the tool or the action, and the descriptions of its inputs from the action arguments
and the accepted attributes.

| Tool | Resource and action | Purpose |
|------|---------------------|---------|
| `list_organisations` | `Organisation.read` | Organisations of the user with threat, risk and mitigation counts |
| `threat_model_context` | `ThreatModel.context` | Text description of the threat model, optionally focused on a system, asset, threat or risk |
| `risk_summary` | `ThreatModel.risk_summary` | Figures of the risk board |
| `list_systems`, `list_assets`, `list_threats`, `list_risks`, `list_mitigations` | `:for_organisation` reads | Records of one organisation; ash_ai adds `filter`, `sort`, `limit`, `offset` |
| `create_system`, `create_asset`, `create_threat`, `create_risk`, `create_mitigation` | `:create` | New records; the parent id is part of the input |
| `update_system`, `update_asset`, `update_threat`, `update_risk`, `update_mitigation` | `:update` | Change a record by `id` |

There are no tools to delete records or to manage organisations, members, invites or
API keys. Those stay in the web application.

### Threat model context

`ThreatShield.ThreatManagement.ThreatModel` is a resource without data. Its generic
actions read the records with the actor:

- `:context` (`organisation_id`, optional `system_id`, `asset_id`, `threat_id`,
  `risk_id`) returns the text of
  `ThreatShield.ThreatManagement.Description.threat_model/1`: the organisation with
  its properties and systems (the same text the built-in AI assistant puts into its
  system prompt), the records in focus, and the known entities of the most specific
  one with their ids. A record of another organisation is an invalid argument.
- `:risk_summary` (`organisation_id`) returns a map with the counts, the estimated
  risk costs (total, mitigated, unmitigated), the risks and mitigations per status, and
  the ten risks with the highest severity and cost.

Code interfaces: `ThreatManagement.threat_model_context/3`,
`ThreatManagement.risk_summary/2`.

## Authorization

- The tools run with the user of the key as the actor and with authorization; the
  resource policies apply as in the web application (see ADR 0002). A viewer can read
  but not write; records of other organisations are not found; a create in an
  organisation where the user lacks the right is forbidden.
- ash_ai lists and resolves a tool only if `Ash.can?` allows its action for the actor,
  with an empty input. `Checks.OrganisationRoleForCreate` cannot know the organisation
  then and allows this pre-check (private context `ash_ai_pre_check?`, which a client
  cannot set). The call itself is authorized with its input.

## Client setup

Create a key on the settings page first. Replace `<host>` and `<key>`.

Claude Code:

```bash
claude mcp add --transport http threatshield https://<host>/mcp \
  --header "Authorization: Bearer <key>"
```

Claude Desktop (`claude_desktop_config.json`), through the `mcp-remote` bridge, which
needs Node.js:

```json
{
  "mcpServers": {
    "threatshield": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "https://<host>/mcp",
        "--header",
        "Authorization:${THREATSHIELD_AUTH}"
      ],
      "env": {
        "THREATSHIELD_AUTH": "Bearer <key>"
      }
    }
  }
}
```

The header value goes through an environment variable because some clients split
arguments at spaces.

Remote connectors that are added in the web interface of Claude (claude.ai) need OAuth
and do not work with an API key; see ADR 0003.

## Tests

`test/threat_shield_web/mcp_test.exs` (tool list, reads of the own organisations,
forbidden writes in another organisation, viewer, 401 cases) and the section "API keys"
of `test/threat_shield_web/live/user_settings_live_test.exs`.
