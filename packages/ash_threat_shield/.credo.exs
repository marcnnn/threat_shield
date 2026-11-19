# Credo for the library. Run it with `mix credo --strict` after `mix compile`: some
# AshCredo checks read the compiled resources. The custom checks live in the
# repository root (credo_checks/), see "Checks" in AGENTS.md of ThreatShield.
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/", "config/", "mix.exs"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      plugins: [{AshCredo, []}],
      requires: ["../../credo_checks/support/*.ex", "../../credo_checks/*.ex"],
      strict: true,
      checks: %{
        extra: [
          # --- Rules of AGENTS.md, see credo_checks/ ---
          # Tests and their fixtures set up data without authorization, as AshCredo
          # assumes for its checks.
          {CredoChecks.AuthorizeFalseNeedsReason, files: %{excluded: ["test/"]}},
          {CredoChecks.RequireAtomicFalseNeedsReason, []},
          # The library does not know its host.
          {CredoChecks.NoHostReferences,
           namespaces: [ThreatShield, ThreatShieldWeb], apps: [:threat_shield]},

          # --- Opt-in checks of Credo ---
          {Credo.Check.Warning.UnsafeToAtom, []},
          {Credo.Check.Warning.MixEnv, []},
          {Credo.Check.Warning.LeakyEnvironment, []},

          # --- AshCredo: all checks, except the ones below ---
          {AshCredo.Check.Warning.ActorOnCallOptions, []},
          {AshCredo.Check.Warning.AuthorizerWithoutPolicies, []},
          {AshCredo.Check.Warning.EmptyDomain, []},
          {AshCredo.Check.Warning.MissingDomain, []},
          {AshCredo.Check.Warning.OverlyPermissivePolicy, []},
          {AshCredo.Check.Warning.RedundantValidation, []},
          {AshCredo.Check.Warning.RepoCallInResource, []},
          {AshCredo.Check.Warning.SensitiveAttributeExposed, []},
          {AshCredo.Check.Warning.SensitiveFieldInAccept, []},
          {AshCredo.Check.Warning.UnknownAction, []},
          {AshCredo.Check.Warning.WildcardAcceptOnAction, []},
          {AshCredo.Check.Refactor.AnonymousFunctionInDsl, []},
          {AshCredo.Check.Refactor.DirectiveInFunctionBody, []},
          {AshCredo.Check.Refactor.LargeResource, []},
          {AshCredo.Check.Refactor.RaisingCall, []},
          # Changes and actions of a domain may call the actions of their own
          # domain directly; callers outside a domain use its code interfaces.
          {AshCredo.Check.Refactor.UseCodeInterface, [enforce_code_interface_in_domain: false]},
          # The test host in test/support/host is a minimal stand-in for the
          # accounts of a host app: no timestamps, no identities, only the code
          # interfaces that the tests use.
          {AshCredo.Check.Design.MissingCodeInterface,
           files: %{excluded: ["test/support/host/"]}},
          {AshCredo.Check.Design.MissingIdentity, files: %{excluded: ["test/support/host/"]}},
          {AshCredo.Check.Design.MissingPrimaryAction, []},
          {AshCredo.Check.Design.MissingTimestamps, files: %{excluded: ["test/support/host/"]}},
          {AshCredo.Check.Readability.ActionMissingDescription, []},
          {AshCredo.Check.Readability.BelongsToMissingAllowNil, []},
          {AshCredo.Check.Readability.CalculationMissingAllowNil, []}
        ],
        disabled: [
          # Replaced by CredoChecks.AuthorizeFalseNeedsReason: AGENTS.md allows
          # authorize?: false for system operations without a user, with a comment
          # that says why. This check flags every use.
          {AshCredo.Check.Warning.AuthorizeFalse, []}
        ]
      }
    }
  ]
}
