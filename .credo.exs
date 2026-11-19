# Credo for the app. Run it with `mix credo --strict` after `mix compile`: some
# AshCredo checks read the compiled resources. See "Checks" in AGENTS.md.
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/", "config/", "priv/repo/seeds.exs", "mix.exs", "credo_checks/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      plugins: [{AshCredo, []}],
      # the checks of this repository's own rules, shared with the library
      requires: ["credo_checks/support/*.ex", "credo_checks/*.ex"],
      strict: true,
      checks: %{
        extra: [
          # --- Rules of AGENTS.md, see credo_checks/ ---
          # Tests and their fixtures set up data without authorization, as AshCredo
          # assumes for its checks.
          {CredoChecks.AuthorizeFalseNeedsReason, files: %{excluded: ["test/"]}},
          {CredoChecks.RequireAtomicFalseNeedsReason, []},
          {
            CredoChecks.ActorInWebCalls,
            # actions for visitors who are not signed in: they find the user by email
            # address or token, and their policies allow them without an actor
            files: %{included: ["lib/threat_shield_web/"]},
            domains: [
              ThreatShield.Accounts,
              AshThreatShield.ThreatManagement,
              ThreatShield.Quotas
            ],
            public: [
              {ThreatShield.Accounts, :sign_in_user},
              {ThreatShield.Accounts, :get_user_by_reset_token},
              {ThreatShield.Accounts, :confirm_user},
              {ThreatShield.Accounts, :request_confirmation},
              {ThreatShield.Accounts, :request_password_reset},
              {ThreatShield.Accounts, :get_invite_by_token}
            ]
          },
          {CredoChecks.NoRepoInWeb, files: %{included: ["lib/threat_shield_web/"]}},

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
          {
            AshCredo.Check.Refactor.RaisingCall,
            # A LiveView or controller reads with the bang functions: a record that
            # does not exist or belongs to another organisation raises NotFound, which
            # Phoenix renders as 404 (AGENTS.md, "Do not swallow errors"). Writes
            # return {:error, error} and show it.
            excluded_functions: [
              {ThreatShield.Accounts, :get_organisation!},
              {ThreatShield.Accounts, :list_organisations!},
              {ThreatShield.Accounts, :list_received_invites!},
              {ThreatShield.Accounts, :get_invite_by_token!},
              {ThreatShield.Accounts, :list_api_keys!},
              {AshThreatShield.ThreatManagement, :get_system!},
              {AshThreatShield.ThreatManagement, :get_asset!},
              {AshThreatShield.ThreatManagement, :get_threat!},
              {AshThreatShield.ThreatManagement, :get_risk!},
              {AshThreatShield.ThreatManagement, :get_mitigation!},
              {AshThreatShield.ThreatManagement, :list_systems!},
              {AshThreatShield.ThreatManagement, :list_assets!},
              {AshThreatShield.ThreatManagement, :list_assets_of_system!},
              {AshThreatShield.ThreatManagement, :list_threats!},
              {AshThreatShield.ThreatManagement, :list_threats_of_system!},
              {AshThreatShield.ThreatManagement, :list_risks!},
              {AshThreatShield.ThreatManagement, :list_mitigations!},
              {AshThreatShield.ThreatManagement, :risk_summary!}
            ]
          },
          # Changes and actions of a domain may call the actions of their own
          # domain directly; callers outside a domain use its code interfaces.
          {AshCredo.Check.Refactor.UseCodeInterface, [enforce_code_interface_in_domain: false]},
          {
            AshCredo.Check.Design.MissingCodeInterface,
            # Actions that are called only by AshAuthentication, by the actions and
            # changes of their own resource, or by system operations. Callers outside
            # the domain need a code interface (see UseCodeInterface).
            excluded_actions: [
              "ThreatShield.Accounts.Token.read",
              "ThreatShield.Accounts.Token.destroy",
              "ThreatShield.Accounts.Token.get_token",
              "ThreatShield.Accounts.Token.store_token",
              "ThreatShield.Accounts.Token.store_confirmation_changes",
              "ThreatShield.Accounts.Token.get_confirmation_changes",
              "ThreatShield.Accounts.Token.revoked?",
              "ThreatShield.Accounts.Token.revoke_all_stored_for_subject",
              "ThreatShield.Accounts.Token.revoke_jti",
              "ThreatShield.Accounts.Token.revoke_token",
              "ThreatShield.Accounts.Token.read_expired",
              "ThreatShield.Accounts.Token.expunge_expired",
              "ThreatShield.Accounts.User.log_out_everywhere",
              "ThreatShield.Accounts.User.confirm",
              "ThreatShield.Accounts.User.get_by_subject",
              # forbidden by its policies; AddOwnerMembership and AcceptInvite create
              # memberships
              "ThreatShield.Accounts.Membership.create",
              "ThreatShield.Accounts.Invite.read",
              "ThreatShield.Accounts.Invite.expired",
              "ThreatShield.Accounts.ApiKey.expired",
              "ThreatShield.Quotas.QuotaUsage.read"
            ]
          },
          {AshCredo.Check.Design.MissingIdentity, []},
          {AshCredo.Check.Design.MissingPrimaryAction, []},
          {AshCredo.Check.Design.MissingTimestamps, []},
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
