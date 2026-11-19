#!/usr/bin/env bash
# Compiles the library ash_threat_shield as a dependency of the app and fails on every
# warning except the known ones.
#
# The library is compiled before the app, so Ecto and the domain verifier of Ash warn
# that the owner resource ThreatShield.Accounts.Organisation does not exist yet (see
# "Library ash_threat_shield" in AGENTS.md). `mix compile --warnings-as-errors` in the
# app ignores warnings of dependencies, and the standalone build of the library checks
# it against its test host only. This script covers the gap: any other warning of the
# library in the app fails it.
set -euo pipefail

cd "$(dirname "$0")/.."

output=$(mix deps.compile ash_threat_shield --force 2>&1)
printf '%s\n' "$output"

unexpected=$(printf '%s\n' "$output" | awk '
  /^[[:space:]]*warning: / {
    if ($0 ~ /^warning: invalid association `organisation` in schema AshThreatShield\.ThreatManagement\.(Asset|System|Threat): associated schema ThreatShield\.Accounts\.Organisation does not exist$/) next
    if ($0 ~ /^warning: Exception while verifying `AshThreatShield\.ThreatManagement:`$/) { pending = $0; next }
    print
    next
  }
  pending != "" {
    if ($0 !~ /^\*\* \(RuntimeError\) Relationship AshThreatShield\.ThreatManagement\.(Asset|System|Threat)\.organisation has an invalid destination: ThreatShield\.Accounts\.Organisation\.$/) print pending
    pending = ""
  }
')

if [ -n "$unexpected" ]; then
  echo
  echo "Unexpected warnings of ash_threat_shield compiled in the app:"
  printf '%s\n' "$unexpected"
  exit 1
fi

echo "ash_threat_shield: only the known warnings about the owner resource."
