# Release of the Ash translation

**Status:** open. The branch `ash-translation` is not merged yet. Delete this file after
the first production deployment of the branch.

The branch moves the domain layer to Ash and the sign in to AshAuthentication
(ADR 0002, ADR 0003). A merge to `main` deploys to production (see `AGENTS.md`,
"CI/CD"). These steps keep that deployment from failing and tell the users what changes.

## Before the merge

1. Create the secret `token-signing-secret` in the Secret Manager of the production
   project and reference it on the Cloud Run service as `TOKEN_SIGNING_SECRET`
   (commands in `deployment/gcp/GCP_Setup.md`, "Secret Manager").
   `config/runtime.exs` raises without it, so the new revision would not start. The
   deploy workflow only replaces the image and does not add the secret.
2. Tell the users that they will be signed out once (see below).

## What the deployment does

- `rel/overlays/bin/start` runs the migrations before the server starts:
  - `20261118095900_create_user_tokens` creates `user_tokens`, the tokens of
    AshAuthentication.
  - `20261118100200_drop_users_tokens` drops `users_tokens`, the sessions of
    phx.gen.auth. **Every user is signed out once**, including "remember me" cookies,
    and signs in again with the same email address and password.
  - `20261118100000` and `20261118100100` add the email change confirmation and the
    API keys; `20261118120000` installs the SQL functions of AshPostgres, and
    `20261119163119` updates them to the version of ash_postgres 2.16.
- Links in confirmation and password reset emails that were sent before the
  deployment no longer work; users request new ones.

## After the deployment

- Look at a few pages (sign in, an organisation, a threat with its risks, the risk
  board): the branch moves the styles to Tailwind CSS 4, which needs Safari 16.4,
  Chrome 111 or Firefox 128 or newer.
- Check in Cloud Logging that the logs still arrive as JSON with a severity: the
  production logger is now the formatter `LoggerJSON.Formatters.GoogleCloud` of
  logger_json 7.
- Sign in, request a password reset and accept an invite once, to check the links of
  the emails (`ThreatShieldWeb.AccountUrls`, host from `PHX_HOST`).
- Create an API key on the settings page and call `/mcp` with it
  (`docs/specs/mcp.md`, "Client setup").

## Local databases

The migration of `user_tokens` was renamed from `20260316120000` to `20261118095900`
before the merge. A local database that ran it under the old version would run it
again and fail; fix it once with

```sql
UPDATE schema_migrations SET version = 20261118095900 WHERE version = 20260316120000;
```

or recreate the database (`mix ecto.reset`).
