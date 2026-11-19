# `mix check` (ex_check) runs all checks of the app and of the library
# ash_threat_shield; see "Checks" in AGENTS.md. The compiler runs first, the other
# tools in parallel. CI runs the same commands in .github/workflows/.
lib = "packages/ash_threat_shield"

[
  tools: [
    # --- app ---
    {:compiler, "mix compile --warnings-as-errors --force"},
    {:credo, "mix credo --strict"},
    {:ash_codegen, "mix ash.codegen --check"},
    {:dialyzer, "mix dialyzer"},
    # deps.compile --force rebuilds the library in _build/test, so it waits for the tests
    {:library_warnings, "scripts/check_library_warnings_in_app.sh",
     env: %{"MIX_ENV" => "test"}, deps: [:ex_unit]},
    {:npm_audit, "npm audit --omit=dev", cd: "assets"},
    # the catalogs in priv/gettext are not kept up to date (English only, the msgids
    # are the texts); see docs/plans/backlog.md
    {:gettext, false},
    # assets/package.json has no tests
    {:npm_test, false},

    # --- library; it shares deps/ and mix.lock with the app, so the audits and the
    # check for unused dependencies of the app cover it ---
    {:lib_compiler, "mix compile --warnings-as-errors --force", cd: lib},
    {:lib_formatter, "mix format --check-formatted", cd: lib},
    {:lib_credo, "mix credo --strict", cd: lib, deps: [:lib_compiler]},
    {:lib_ash_codegen, "mix ash.codegen --check", cd: lib, env: %{"MIX_ENV" => "test"}},
    {:lib_dialyzer, "mix dialyzer", cd: lib, deps: [:lib_compiler]},
    {:lib_ex_unit, "mix test", cd: lib, deps: [:lib_ash_codegen]}
  ]
]
