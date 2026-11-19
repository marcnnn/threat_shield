# 0004 Threat model library with a configurable owner instead of multitenancy

**Status:** Accepted (2026-11-19)

## Context

The threat model (systems, assets, threats, risks, mitigations, the AI assistant and
the MCP tools) should be reusable by other Ash applications. It was coupled to the app
through the organisation, the memberships and rights, the quota of the AI requests and
the `Scope` struct of the web layer. ThreatShield itself must keep working unchanged,
with the same database schema, and must not hold a second copy of the code.

## Decision

- **One repository, two Mix projects.** The app stays at the root (CI, Dockerfiles and
  deployment change little). The library lives in `packages/ash_threat_shield`
  (otp_app `:ash_threat_shield`, namespace `AshThreatShield`) with its own tests and a
  test host. The app uses it as a path dependency; both share `deps/` and `mix.lock`.
- **A configurable owner resource, no multitenancy.** The library resources
  `belongs_to :organisation` of the resource in `config :ash_threat_shield,
  :owner_resource`, with the existing column `organisation_id`. The reverse
  relationships and counts stay in the host's resource.
- **Authorization through a behaviour.** The checks `OrganisationRole` and
  `OrganisationRoleForCreate` ask `AshThreatShield.Authorization` (a filter for reads,
  a boolean for creates, and "the right in any organisation" for the ash_ai tool
  listing). ThreatShield implements it with `Membership` and `Rights`.
- **AI hook.** The suggestion actions call `AshThreatShield.AI.Hook` before the
  language model; ThreatShield counts its quota there. The AI functions take a plain
  focus map instead of `Scope`.
- **The host owns migrations.** It generates them with `mix ash.codegen`; the library
  ships no migrations for hosts.
- **MCP tools stay on the library domain.** ash_ai runs a tool with the domain of its
  resource, so a host domain cannot declare them. Hosts choose tools at the router.

## Consequences

- The schema and the snapshots of ThreatShield do not change.
- The library is compiled before the host, so Ecto and the domain verifier of Ash warn
  there that the owner resource does not exist yet. The standalone build of the
  library verifies the relationships with its test host.
- The owner needs an integer `id`, a `name`, optionally `attributes`, and read
  policies. Other id types would need another option.

## Rejected alternatives

- **Ash multitenancy with the organisation as tenant.** Every read and tool call would
  need a tenant. Reads across organisations, such as the MCP tool
  `list_organisations` with its counts, the "right in any organisation" pre-check of
  ash_ai, or a user's view of all their organisations, do not fit one tenant per call,
  and the existing policies already isolate the organisations.
- **Resources defined in the host from library extensions or fragments.** Avoids the
  compile order problem, but the resources would no longer be library modules, and
  the host would repeat the resource definitions.
- **A separate repository for the library.** Needs releases and version bumps for
  every change of the threat model while ThreatShield is its only host.
