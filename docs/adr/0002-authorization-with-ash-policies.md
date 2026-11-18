# 0002 Authorization with Ash policies derived from role rights

**Status:** Proposed (2026-11-18)

## Context

The domain layer moved from Ecto contexts to Ash resources. During the move, the
contexts called every action with `authorize?: false` and checked access in a helper
module (`ThreatShield.Access`) with `:for_user` read actions. Several policies were
wrong (any user could update or delete any organisation; anyone could read invites and
create memberships). The Ash actions will be offered to chat agents as MCP tools
(ash_ai) that act as the signed-in user, so the actions themselves must be safe to call.

## Decision

- **The actions are the public API.** The domains `ThreatShield.Accounts` and
  `ThreatShield.ThreatManagement` define code interfaces; callers pass the user as
  `actor:`, and the Ash policies decide. There are no context modules in between.
- **One map of rights.** `ThreatShield.Accounts.Rights` maps each right to the roles
  that have it. The policies use it through two checks:
  `ThreatShield.Checks.OrganisationRole` (a filter check: reads return only the
  records of the actor's organisations; updates and deletes of other records fail) and
  `ThreatShield.Checks.OrganisationRoleForCreate` (resolves the organisation of a new
  record from its `organisation_id` or its parent). Templates call `may?/2` on the
  membership with the same map, so buttons and policies agree.
- **Joining needs an invite.** Memberships are created by the owner bootstrap of a new
  organisation and by the actions `:accept_invite` and `:join_with_token`. No policy
  allows creating a membership directly.
- **`authorize?: false` only for system operations**, each with a comment: the owner
  membership of a new organisation, consuming an accepted invite, deleting expired
  invites, quota bookkeeping, and lookups inside the checks themselves.

## Consequences

- Every new action needs a policy; without one, it is forbidden.
- Records of other organisations are "not found" (404), not "forbidden".
- Risks and mitigations reach their organisation through `threat` and `risk`; their
  policies use these paths. Switching to attribute multitenancy later needs an
  `organisation_id` column on both tables.

## Rejected alternatives

- **Access checks in context modules (`ThreatShield.Access`).** Works for the web
  layer, but every other caller of the actions (MCP tools, scripts) bypasses it.
- **An `Ash.can?` helper in templates instead of `may?/2`.** Asks the policies
  directly, but costs a query per button. Since the policies derive from the same map
  as `may?/2`, both give the same answer.
- **Ash attribute multitenancy now.** Cleaner scoping, but needs schema changes for
  risks and mitigations and changes every call; deferred.
