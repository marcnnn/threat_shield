# AGENTS.md

Guidance for working in this repository.

## What this is

ThreatShield is an **AI-powered threat-analysis and threat-modeling web app**, built with
**Elixir / Phoenix (LiveView)** and **PostgreSQL**. Users organize security work under an
**organisation**, then describe their **systems** and **assets**, identify **threats**,
assess **risks**, and plan **mitigations**. An OpenAI-backed assistant suggests entities
(threats, assets, risks, etc.) at each step. Chat agents such as Claude work on the same
data through an MCP server, authenticated with a personal API key.

## Tech stack

- **Elixir** 1.20.4 / **OTP** 29.1.1 (see `.tool-versions`; CI and the `Dockerfile` pin the
  same versions). `mix.exs` requires Elixir `~> 1.20`.
- **Phoenix** `~> 1.7` with **LiveView** `~> 0.20` — the UI is almost entirely LiveView.
- **Ash 3** for the domain layer: **AshPostgres** over **PostgreSQL**, **AshPhoenix**
  (forms), **AshAuthentication** (users and tokens). Ecto is still there underneath
  (repo, migrations, test sandbox).
- **OpenAI** via the `openai` hex package (`gpt-3.5-turbo`), behind the behaviour
  `ThreatShield.AI.Provider` (see "AI integration").
- **ash_ai** (held at 1.0.2, later versions need ash 3.33) serves the domain actions as
  MCP tools at `/mcp` (see "MCP server").
- Assets: **esbuild** + **tailwind**, run through Mix. JS dependencies (`chart.js`,
  `@popperjs/core`) come from `assets/package.json` and need `npm install` in `assets/`
  (Node.js 20, see `.tool-versions`). `choices.js` is listed there but not used.
- Other: `bcrypt_elixir` (passwords), `ex_rated` (rate limiting), `gettext` (i18n),
  `elixlsx` (Excel export), `swoosh`/`finch` (mail), `timex`, `logger_json`.

## Common commands

```bash
npm install --prefix assets   # JS dependencies (not part of mix setup)
mix setup                # deps.get + ecto.setup + assets.setup + assets.build
mix phx.server           # run the app at http://localhost:4000
iex -S mix phx.server    # run with an interactive shell

mix test                 # creates+migrates the test DB, then runs tests
mix test path/to/test.exs:NN   # single test

mix ecto.setup           # ecto.create + ecto.migrate + seeds
mix ecto.reset           # ecto.drop + ecto.setup
mix format               # format (see .formatter.exs)

mix ash.codegen --check  # must report no changes: resources match the snapshots
mix ash.codegen add_x    # after a resource change: generates a migration + snapshots
```

Docker Compose is also supported (`docker compose up --build`); see `README.md`.
The app reads config from a `.env` file at the project root (DB creds, OpenAI key, etc.).
DB defaults: user/db `threat_shield`, password `secret`, host `localhost`.

`mix` only starts when exactly the Elixir and Erlang versions of `.tool-versions` are
installed (`asdf install`). Run `mix deps.get` when `mix.lock` has changed.

## Architecture

### Domain model (the core hierarchy)

```
Organisation ──< System ──< Asset
      │            │           │
      └──< Threat <┘<──────────┘     (a Threat may belong to a System and/or an Asset)
              └──< Risk ──< Mitigation
```

### Ash domains and resources

- **Domains** are the public API: `ThreatShield.Accounts` (`lib/threat_shield/accounts.ex`:
  users, tokens, organisations, memberships, invites, API keys),
  `ThreatShield.ThreatManagement` (`threat_management.ex`: systems, assets, threats,
  risks, mitigations, and `ThreatModel`, a resource without data whose generic actions
  `:context` and `:risk_summary` describe a threat model and `:suggest_assets`,
  `:suggest_threats`, `:suggest_risks`, `:suggest_mitigations` ask the AI assistant) and `ThreatShield.Quotas`. Each domain defines **code interfaces** (`define ...`) such as
  `ThreatManagement.get_threat!(id, actor: user, load: [...])`,
  `list_threats!(org_id, actor: user)`, `create_risk(attrs, actor: user)`,
  `update_asset(asset, attrs, actor: user)`, `destroy_system(id, actor: user)`.
  LiveViews, controllers and tests call these functions directly; there are no context
  modules.
- **Resources** live under `lib/threat_shield/<domain>/<resource>.ex`. Actions, their
  arguments and the accepted attributes have a `description`: ash_ai sends them to chat
  agents as the descriptions of the MCP tools. A foreign key that a create accepts is
  declared as an attribute with a description (`define_attribute? false` on the
  `belongs_to`).
- Logic goes into the resource, not into callers: module **changes**
  (`threat_management/changes/`, `accounts/changes/`), **validations**
  (`validations/`, `accounts/validations/`), **calculations** (e.g.
  `Risk.estimated_risk_cost`, `Threat.system_name`), **aggregates** (e.g.
  `Organisation.threat_count`), and read actions with arguments for filters
  (`:for_organisation`, `:for_system`, `:for_asset`). Filter in the database, not in
  Elixir. Give a change an `atomic/3` callback where possible, so that updates can
  run atomically; use `require_atomic? false` only with a comment why.
- Multi-step writes run in one action: `after_action` hooks in changes (e.g. the owner
  membership of a new organisation, the accepted invite), not hand-written
  transactions.
- **Enums** are `Ash.Type.Enum` modules stored as strings: `Accounts.Role`,
  `ThreatManagement.RiskStatus`, `ThreatManagement.MitigationStatus`. Derive lists of
  states from `values/0`.
- Expression calculations (`expr(organisation.name)`) do not apply the read policies of
  the related resource. They are used where a user may see a field of a record they may
  not read (the organisation name of an invite). Users read themselves and the members
  of their organisations, so memberships load `:user`.

### Scope

`ThreatShield.Scope` (`lib/threat_shield/scope.ex`) is a struct carrying the current
`user`, `organisation`, `membership`, and the relevant `system` / `asset` / `threat`.
The LiveViews build it per page and pass it to the list components and the AI module.
It is a view helper, not an access check: the policies check access.

### Authorization

See `docs/adr/0002-authorization-with-ash-policies.md`.

- **`ThreatShield.Accounts.Rights`** maps each right (`:create_threat`,
  `:delete_member`, ...) to the roles (`:owner` / `:editor` / `:viewer`) that have it.
  It is the single source of truth for both layers:
  - the **policies** of the resources authorize with
    `{ThreatShield.Checks.OrganisationRole, right: ...}` (reads, updates, destroys; a
    filter check with a `path:` to the organisation, e.g. `[:threat, :organisation]`
    for risks) and `{ThreatShield.Checks.OrganisationRoleForCreate, right: ...}`
    (creates; resolves the organisation from `organisation_id` or from the parent,
    e.g. `parent: {:threat_id, Threat}`);
  - **templates** use `may?(@scope, :create_threat)` (imported everywhere; takes a scope
    or a membership) to show only allowed buttons.
- Platform roles (`global_roles` on the user, e.g. `platform_admin`) are separate from
  organisation rights.
- MCP tool calls run with the user of the API key as the actor, so the same policies
  apply. A user signed in with an API key cannot create further keys.

### Access rules (apply to every change)

- **Every call on a user path passes the user as `actor:`.** Never call an action with
  `authorize?: false` for a user request. It is allowed only for system operations
  without a user (cleanup of expired invites, quota bookkeeping, the bootstrap of the
  first owner, consuming an accepted invite, the lookups inside policy checks), each
  with a comment why.
- **Every action needs a policy.** An action without a matching policy is forbidden;
  that is the intended default for internal actions (e.g. `Membership.create`).
- **Hidden buttons are not protection.** A client can send any LiveView event with any
  id. Each `handle_event` must end in a domain function called with the actor.
- **Foreign keys are accepted attributes**, guarded by the create policy, which checks
  the actor's role in the organisation of the parent. Forms set the parent id with
  `transform_params`, so a client cannot move a new record elsewhere. Update actions do
  not accept parent ids (a mitigation stays with its risk).
- **Check references against the organisation.** When an entity points to another one
  (a threat to a system or an asset), the validation
  `ThreatManagement.Validations.SameOrganisation` checks that both belong to the same
  organisation.
- **Invites are matched by email address.** They are listed and accepted only by users
  with a confirmed address (`Checks.InviteAddressee`). The token of an invite link is a
  secret: whoever has it may read the invite and join.
- **Do not swallow errors.** A record that does not exist or belongs to another
  organisation raises `NotFound` from `get_*!`, which ash_phoenix turns into a 404. A
  failed write returns `{:error, error}`; show it in the form or as a flash.

### Database and migrations

- The migrations up to `20261118100200` were written by hand (most for Ecto);
  `priv/resource_snapshots` holds the matching Ash snapshots, and the resources describe
  the existing columns (`migration_types`, `migration_defaults`, `index?: true` on
  references, `custom_indexes`). Generate new migrations with `mix ash.codegen <name>`
  and review them.
- Columns that are nullable in the database but required by the application keep
  `allow_nil? true` and get a `present` validation, so that the snapshots match the
  schema.
- To check a resource change against the schema, generate migrations for all resources
  into an empty snapshot and migration path
  (`mix ash_postgres.generate_migrations --snapshot-path ... --migration-path ...`),
  run them on a scratch database and compare its columns, indexes and constraints with
  a database built from `priv/repo/migrations`.

### Web layer

- `lib/threat_shield_web/live/<entity>_live/` — LiveViews, one folder per entity
  (`threat_live`, `risk_live`, `asset_live`, `system_live`, `organisation_live`,
  `members_live`, `mitigation_live`, `admin_live`). `*_details.ex` modules are the main
  show/edit screens, `*_list.ex` and `*_form.ex` are LiveComponents used by them.
  `risk_live/risk_board.ex` is the risk board.
- `lib/threat_shield_web/components/` — shared function components: `core_components.ex`,
  `ts_components.ex`, `breadcrumbs.ex`, `labels.ex`, `icons.ex`, `info_vis.ex`,
  `spinner.ex`.
- Shared building blocks — use them, do not copy the pattern again:
  - `ThreatShieldWeb.FormHelpers`: `assign_form/2`, `validate_form/2` and
    `submit_form/5` for form components built with `AshPhoenix.Form`
    (`for_create`/`for_update` with `actor:` and `as:`). A form gets its return path in
    the assign `:patch`. `ThreatShieldWeb.AshErrors.normalize/2` gives Ash messages the
    Ecto wording of `priv/gettext/errors.pot`; `translate_error/1` applies it.
  - `ThreatShieldWeb.AiSuggestions` — the AI suggestion flow of the list components
    (`request/3`, `handle_result/2`, `selected/2`).
  - `delete_menu_item/1` and `edit_menu_item/1` in `ts_components.ex` — the entries of the
    context menu on detail pages.
- `lib/threat_shield_web/router.ex` — routes are deeply nested by the domain hierarchy
  (`/organisations/:org_id/systems/:sys_id/threats/:threat_id/risks/:risk_id/...`).
  Auth via `live_session` blocks: `redirect_if_user_is_authenticated`,
  `require_authenticated_user`, `platform_admin`, `current_user`.
- `lib/threat_shield_web/user_auth.ex` — session auth + LiveView `on_mount` hooks.
- The `:mcp` pipeline of the router authenticates with an API key
  (`Authorization: Bearer`) and forwards `/mcp` to `AshAi.Mcp.Router`.

### AI integration

A suggestion has three parts; only the second needs a language model:

1. `ThreatShield.AI.Prompts` builds the prompt (pure functions). Its context is the
   text of `ThreatShield.ThreatManagement.Description`, which also answers the MCP tool
   `threat_model_context`.
2. The configured `ThreatShield.AI.Provider` answers it (`chat/2`, returns the text of
   the answer). The provider is read from `config :threat_shield, :ai_provider`; the
   default is `ThreatShield.AI.Providers.OpenAI`.
3. `ThreatShield.AI` turns the JSON answer into unsaved records. The user selects some,
   and the list components store them with the normal create actions (`actor:`).

A suggestion on a user path is a generic action of `ThreatModel`
(`ThreatManagement.suggest_threats(org_id, %{system_id: ...}, actor: user)` etc.). Its
policy requires the right to create what is suggested, then it reads the records in
focus with the actor and uses one AI request of the organisation's **quota**
(`Quotas.QuotaManager.consume/5`: check and record in one transaction with a lock on
the organisation, `ai_requests_per_month`) before it calls `ThreatShield.AI`. The
functions of `ThreatShield.AI` check neither rights nor quota. The call blocks, so run
it in a separate process: the list components use `ThreatShieldWeb.AiSuggestions`,
which starts it with `start_async` under `ThreatShield.TaskSupervisor`. When adding AI
features, add an action that consumes the quota the same way. Call a language model
only through a provider, so that tests can replace it.

### MCP server

`/mcp` serves the `tools` of the domains (`accounts.ex`, `threat_management.ex`) to chat
agents; the spec is `docs/specs/mcp.md`, the decision ADR 0003. Rules:

- A tool is an existing action; put logic and checks into the action, not into the tool.
- Expose reads, creates and updates of the threat model. Deletes and the management of
  members, invites and API keys stay in the web application.
- A new tool needs a description (on the tool or the action) and descriptions of all
  inputs, and a case in `test/threat_shield_web/mcp_test.exs`.
- ash_ai lists a tool only if `Ash.can?` allows its action with an empty input. A
  create check that needs the input must allow that pre-check (see
  `Checks.OrganisationRoleForCreate`).

### Extraction

The ThreatManagement core is meant to become a reusable Ash library later. It is not
extracted yet, but kept ready:

- Nothing under `lib/threat_shield/` references `ThreatShieldWeb`, except
  `application.ex`, which starts the endpoint. Links and other web details are passed
  in by the web layer (`Accounts.Senders.Urls`, the invite link in
  `UserNotifier.deliver_invite/2`).
- The ThreatManagement resources read their repo from
  `config :threat_shield, :threat_management_repo` (default `ThreatShield.Repo`, read at
  compile time).
- The language model is a behaviour (`ThreatShield.AI.Provider`).

What still couples ThreatManagement to the rest of the app, and what an extraction
needs:

- **Organisation** (`Accounts.Organisation`) owns systems, assets and threats
  (`belongs_to :organisation`), and has `has_many` and count aggregates back to them.
  `Description` uses `Organisation.attributes_config/0`, and `ThreatModel` reads the
  organisation through `Accounts.get_organisation`. An extraction needs a configurable
  owner resource (or a behaviour for "the organisation") and moves the reverse
  relationships and aggregates into the host app.
- **Rights and membership.** The policies use `Checks.OrganisationRole` and
  `Checks.OrganisationRoleForCreate`, which read `Accounts.Membership` and
  `Accounts.Rights`. A library would take the checks (or a "role of the actor in the
  owner" function) from the host app.
- **User** is only the actor; nothing in ThreatManagement reads it directly.
- **AI and quotas.** The suggestion actions of `ThreatModel` use
  `Quotas.QuotaManager` and the `Scope` struct. Prompts and `Description` need no
  quota; a library would ship them and leave quota handling to the host.
- **Static configuration.** `otp_app: :threat_shield` in the domain and resources, the
  table names, and the migrations and snapshots in `priv/`. A library needs its own
  migrations (or an installer) and an `otp_app` option.

### Other notable modules

- `lib/threat_shield/dynamic_attribute.ex` — organisations/systems carry flexible,
  AI-suggestable attributes stored as a JSON `:map` field.
- `lib/threat_shield/exporters/excel_exporter.ex` — Excel export (`/exports/excel`).
- `lib/threat_shield/analytics/risk_analytics.ex` — risk analytics for the risk board.
- `lib/threat_shield/quotas/` — quota tracking and enforcement.
- `lib/threat_shield/const/` — static reference data (retention times). The country list
  for the location field is `ThreatShieldWeb.Locations`.

## Conventions

- Module namespaces: `ThreatShield.*` for domain, `ThreatShieldWeb.*` for web.
- Keep business logic in the resources; keep LiveViews thin (mount → load via a domain
  function with `actor:` and `load:` → assign → render). See
  `live/threat_live/threat_details.ex` as the reference pattern.
- User-facing strings go through `gettext`.
- Run `mix format` before committing; `.formatter.exs` governs style.
- Compile after each change and add no new compiler warnings. Elixir 1.20 infers types
  and reports contradictions as warnings, for example a clause that never matches or a
  comparison that is always false. Treat a new warning as a defect in the change.

## Documentation

Plans, specs, and architecture decision records live in `docs/`. The folder structure and
the rules are defined in `docs/README.md` — read it before adding or changing a document.

- **Plan to spec:** when a step of a plan is built, remove it from the plan and describe
  the result in the spec.
- **Decisions:** a decision with a serious rejected alternative gets an ADR in `docs/adr/`.
- Working rules stay in this file; specs do not repeat them.
- `docs/audit/` is local only and ignored by git. Never commit audit reports; the
  repository is public.

## Testing

- `mix test` auto-creates and migrates the test DB.
- Tests live under `test/threat_shield/` (domains) and `test/threat_shield_web/`
  (LiveViews/controllers). Support in `test/support/` — `ConnCase`, `DataCase`, and
  fixtures under `test/support/fixtures/`. The SQL sandbox rolls back DB changes per test.
- Add a regression test with every fix. For a new read or write path, add a test with a
  second organisation and with a `:viewer` (`MembersFixtures.membership_fixture/3`,
  `AccountsFixtures.confirmed_user_fixture/1`). `test/threat_shield/authorization_test.exs`
  covers every ThreatManagement resource; extend it for a new resource.
- Tests never call a language model: `config/test.exs` sets `ThreatShield.AI.StubProvider`
  (`test/support/ai_stub_provider.ex`) as the AI provider.
- `AccountsFixtures.api_key_fixture/2` creates an API key and returns the key itself.
- Examples to copy from: `test/threat_shield/authorization_test.exs` and
  `test/threat_shield/members_test.exs` (policies), and in `test/threat_shield_web/live/`:
  `entity_form_live_test.exs` (forms), `entity_menu_live_test.exs` (rights in the UI,
  events, 404 for other organisations), `ai_suggestions_live_test.exs` (async flow with
  `render_async`).

## CI/CD

- `.github/workflows/test.yml` — runs `mix test` against a Postgres 18 service on every push.
- `.github/workflows/build.yml`, `deploy_gcp.yml` — build and deploy to GCP. Deployment
  manifests are in `deployment/` and `rel/`.
- **Do not use `/` in branch names.** `test.yml` triggers on `branches: "*"`, which does
  not match such names, so no tests run for them (see `docs/plans/backlog.md`).
- **A push to `main` deploys to production** (Cloud Run) when the tests pass.
- CI runs only the tests. Format and compiler warnings are not checked there; check them
  locally.
