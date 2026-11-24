# AshThreatShield

Threat modeling with [Ash](https://ash-hq.org): the systems, assets, threats, risks
and mitigations of an organisation, the policies that guard them, a plain text
description and a risk summary of a threat model, suggestions of an AI assistant, and
MCP tools for chat agents (via [ash_ai](https://hexdocs.pm/ash_ai)).

The library holds the threat model. The host application provides what it does not
own: the repo, the organisations, the rights of users in them, the language model
and, optionally, a hook before each AI request (e.g. a quota). It was extracted from
[ThreatShield](../../README.md), which uses it as a path dependency.

The library is backend only: it ships no LiveViews, components or styles. A host
builds its own screens on the code interfaces (e.g. with `AshPhoenix.Form`), or lets
chat agents work through the MCP tools.

## Contents

- `AshThreatShield.ThreatManagement`: the domain with code interfaces
  (`list_threats/2`, `create_risk/2`, `suggest_threats/3`, ...) and the MCP tools.
- Resources `System`, `Asset`, `Threat`, `Risk`, `Mitigation` (AshPostgres, tables
  `systems`, `assets`, `threats`, `risks`, `mitigations`), the enums `RiskStatus` and
  `MitigationStatus`, and `ThreatModel`, a resource without data with the generic
  actions `:context`, `:risk_summary` and `:suggest_assets`, `:suggest_threats`,
  `:suggest_risks`, `:suggest_mitigations`.
- `AshThreatShield.Checks.OrganisationRole` and `OrganisationRoleForCreate`: policy
  checks that ask the configured authorization. A host can use them for its own
  resources too.
- `AshThreatShield.AI` with `Prompts`, `Provider` (OpenAI provider and a stub for
  tests) and `Hook`; `AshThreatShield.ThreatManagement.Description`.
- `AshThreatShield.DynamicAttribute`: properties of organisations and systems, stored
  in a map `attributes`, with AI suggestions of typical values.

## Installation

```elixir
def deps do
  [
    {:ash_threat_shield, path: "packages/ash_threat_shield"},
    # the default AI provider; optional
    {:openai, "~> 0.6.2"},
    # openai asks for httpoison ~> 2.0, which is held at hackney 1.x with open
    # security advisories; openai works with httpoison 3
    {:httpoison, "~> 3.0", override: true}
  ]
end
```

The library needs ash 3.37 or later, with `config :ash, default_string_length_count:
:codepoints` (or `:mixed`), and ash_ai 1.5 or later.

Add `AshThreatShield.ThreatManagement` to the `:ash_domains` of your application, so
that `mix ash.codegen` and the ash_ai router find it.

## Configuration

All options are set under `config :ash_threat_shield`:

```elixir
config :my_app, ash_domains: [MyApp.Accounts, AshThreatShield.ThreatManagement]

config :ash_threat_shield,
  repo: MyApp.Repo,
  owner_resource: MyApp.Accounts.Organisation,
  authorization: MyApp.ThreatModelAuthorization,
  ai_provider: AshThreatShield.AI.Providers.OpenAI,
  ai_hook: MyApp.AiQuota
```

| Option | Required | When read | Meaning |
|--------|----------|-----------|---------|
| `:repo` | yes | compile time | The `AshPostgres.Repo` of the library resources. |
| `:owner_resource` | yes | compile time | The Ash resource of the organisations, see below. |
| `:authorization` | yes | runtime | A module that implements `AshThreatShield.Authorization`. |
| `:ai_provider` | no | runtime | A module that implements `AshThreatShield.AI.Provider`. Default `AshThreatShield.AI.Providers.OpenAI` (needs the dependency `openai` and its API key configuration). |
| `:ai_hook` | no | runtime | A module that implements `AshThreatShield.AI.Hook`. Without it every AI request is allowed. |

`config :ash_threat_shield, AshThreatShield.AI.Providers.OpenAI, model: "..."` sets the
model of the OpenAI provider (default `gpt-3.5-turbo`).

Changing a compile time option recompiles the library.

### The owner resource

The library resources `belongs_to :organisation` of the owner resource, with the
column `organisation_id`. The owner resource needs

- an integer primary key `id`,
- a `name` and optionally a map `attributes` (property names to texts), which describe
  the organisation to the AI assistant,
- read policies: the library reads the organisation with the actor, and an
  organisation that the actor may not read is not found.

It may implement `AshThreatShield.Owner` to describe its `attributes`
(`attributes_config/0`, a list of `AshThreatShield.DynamicAttribute`). Relationships
back to the library resources (`has_many :threats, AshThreatShield.ThreatManagement.Threat`)
and aggregates such as a threat count are optional and belong to the host.

### Authorization

The policies of the library resources ask the configured implementation of
`AshThreatShield.Authorization` for the rights `:view_organisation` and
`:create_*`, `:edit_*`, `:delete_*` of `system`, `asset`, `threat`, `risk` and
`mitigation` (`AshThreatShield.Authorization.rights/0`):

```elixir
defmodule MyApp.ThreatModelAuthorization do
  @behaviour AshThreatShield.Authorization

  import Ash.Expr
  require Ash.Query

  # an expression on the owner resource, used as a filter by reads, updates, destroys
  @impl true
  def filter(_actor, right) do
    roles = MyApp.Rights.roles(right)
    expr(exists(memberships, user_id == ^actor(:id) and role in ^roles))
  end

  # creates and AI suggestions; the check is the authorization, so read without it
  @impl true
  def authorized?(actor, organisation_id, right) do
    roles = MyApp.Rights.roles(right)

    MyApp.Accounts.Membership
    |> Ash.Query.filter(user_id == ^actor.id and organisation_id == ^organisation_id and role in ^roles)
    |> Ash.exists?(authorize?: false)
  end

  # ash_ai lists a create tool only for an actor with the right in some organisation
  @impl true
  def authorized_somewhere?(actor, right) do
    roles = MyApp.Rights.roles(right)

    MyApp.Accounts.Membership
    |> Ash.Query.filter(user_id == ^actor.id and role in ^roles)
    |> Ash.exists?(authorize?: false)
  end
end
```

### AI provider and hook

A provider implements `chat(messages, opts)` and returns `{:ok, text}`. The library
asks for JSON and parses the answer itself. Tests use
`AshThreatShield.AI.Providers.Stub`, which answers in the requested format and can
report requests to a test process (see its docs).

The suggestion actions check the right to create what is suggested, read the records
in focus with the actor, then call `before_ai_request(organisation, actor, kind)` of
the hook. `:ok` lets the request go to the provider; `{:error, error}` stops it and is
returned by the action. Use it for quotas or auditing.

## Migrations

The host owns the migrations and resource snapshots. After adding the library (or
upgrading it), generate them in the host:

```bash
mix ash.codegen add_threat_model
```

Review them: the library tables reference the table of the owner resource.

## MCP tools

The domain declares ash_ai tools for reads, creates and updates of the threat model
(`list_threats`, `create_risk`, `threat_model_context`, `risk_summary`, ...); there are
no delete tools. ash_ai runs a tool with the domain of its resource, so the tools stay
on the library domain. A host serves them with `AshAi.Mcp.Router` and its `otp_app`
when the domain is in its `:ash_domains`, and chooses or excludes tools with the
router options `tools` and `exclude_actions`. The tools run with the actor of the MCP
request, so the policies apply.

## Compile warnings in a host

The library is compiled before the host, so Ecto and the domain verifier of Ash warn
that the owner resource does not exist yet, e.g.

```
warning: invalid association `organisation` in schema AshThreatShield.ThreatManagement.System:
associated schema MyApp.Accounts.Organisation does not exist
```

The warnings are expected and harmless: the module exists at runtime. The standalone
build of the library verifies the relationships with its test host.

## Development

The library has its own test suite with a minimal test host in `test/support/host`
(users, organisations, memberships, an authorization, an AI hook and a repo). Its
migrations in `priv/test_repo/migrations` are generated with
`MIX_ENV=test mix ash.codegen <name>`. The tests need PostgreSQL (user and password
from `POSTGRES_USER`/`POSTGRES_PASSWORD`, default `threat_shield`/`secret`, host
`POSTGRES_HOST`) and use the database `ash_threat_shield_test`.

```bash
mix test
mix format --check-formatted
mix compile --warnings-as-errors
```

In this repository the library shares `deps/` and `mix.lock` with ThreatShield
(`deps_path` and `lockfile` in `mix.exs`); run `mix deps.get` at the root.

## Future work

- An Igniter installer that adds the configuration and generates the migrations.
- Owner resources with other primary key types.

## License

MIT, see [LICENSE.txt](LICENSE.txt).
