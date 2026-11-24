# Backlog

**Status:** open list. Last updated 2026-11-19.

Short entries for open work without a plan of its own. When work on an entry starts and
needs steps, it gets its own file in this folder and is removed from here.

## Upgrade Phoenix LiveView to 1.0

The app runs on LiveView 0.20 (`mix.exs`: `~> 0.20.12`). The upgrade to 1.0 changes
`mix.exs`, `mix.lock`, `assets/package.json`, and parts of
`lib/threat_shield_web/components/core_components.ex`. It fixes the advisory
EEF-CVE-2026-64941 (fixed in 1.0.19), which `mix.exs` ignores until then.

## Run tests on all branches

`.github/workflows/test.yml` and `security.yml` trigger on `branches: "*"`. This pattern
does not match branch names that contain a `/`, such as `chore/upgrade-elixir-postgres`.
Pushes to these branches start no test run. Use `"**"` or remove the branch filter.

## Build only after the tests

`.github/workflows/build.yml` starts on a push to `main`, on a pull request, and after the
"Run Tests" workflow. Only the last trigger checks the test result.

- A push to `main` builds the image twice: once directly, once after the tests.
- The direct build and the pull-request build do not wait for the tests.
- Every build pushes the `latest` image tag, including builds of pull requests that are
  not merged.

## Login with OpenID Connect (Microsoft 365 / Entra ID)

Users log in with email and password only (AshAuthentication password strategy on
`ThreatShield.Accounts.User`, sessions in `ThreatShieldWeb.UserAuth`). Add login through
an OpenID Connect provider. The first provider to support is Microsoft Entra ID, so that
users can log in with their Microsoft 365 account.

Open points: how an external identity maps to an existing user and to an organisation
membership, and whether an organisation can require this login for its members.

## REST API

The app has no API. The router defines an `:api` pipeline, but no route uses it. Add a
REST API for the domain objects (organisations, systems, assets, threats, risks,
mitigations).

Chat agents already reach the domain actions through the MCP server at `/mcp`
(`specs/mcp.md`). A REST API could use the same authentication: the `:mcp` pipeline
signs the user in with a personal API key (`Authorization: Bearer`) and sets the actor,
so the policies apply.

Open point: whether a REST API is still needed beside MCP.

## Component hierarchy for systems

A system is a flat entry below an organisation. Allow a hierarchy, for example a system
that consists of sub-systems, which contain services.

Open points: the number of levels and their names, and how assets and threats relate to
a component and to its parent system.

## Upgrade PostgreSQL in production

Production runs PostgreSQL 15.18 (Cloud SQL instance `threatshield-db`, checked on
2026-10-07). The repository uses 18 everywhere: CI, Docker Compose, the Kubernetes files,
and `deployment/gcp/create_database.py`. So the tests run against a newer major version
than production.

Upgrade the instance to 18 with an in-place major version upgrade of Cloud SQL. Take a
backup first and check that automated backups are enabled. Until then, consider running
the tests against 15 as well.

## Update assent

ash_authentication 4.15 requires assent `< 0.3`, so the lock holds assent 0.2.13 with the
advisory EEF-CVE-2026-117656 (Sign in with Apple, fixed in 0.3.2). The app uses no OAuth
strategy, so `mix.exs` ignores the advisory. When ash_authentication allows assent 0.3,
update it and remove the entry from `ignored_advisories/0`.

## Replace the package openai

The provider `AshThreatShield.AI.Providers.OpenAI` uses the package `openai` 0.6, the
latest version, which asks for httpoison 2 and so for hackney 1 with open advisories. Both `mix.exs` override
httpoison to 3 (hackney 4); a host of the library has to do the same. A provider that
calls the API with Finch or Req would drop the package and the override.

## Timestamps of memberships

`memberships` has no `inserted_at`/`updated_at`, so nobody can see when a member joined
or got a role (AshCredo `MissingTimestamps`, disabled in
`lib/threat_shield/accounts/membership.ex`). Adding them needs a migration and a default
for the existing rows.

## Translations

The catalogs in `priv/gettext` are not up to date: newer texts are missing, and the
msgids are the English texts. `mix gettext.extract --check-up-to-date` would fail, so
`.check.exs` disables the gettext check of ex_check. Extract the catalogs and enable the
check when the app gets a second language.
