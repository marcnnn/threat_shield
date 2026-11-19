defmodule ThreatShield.MixProject do
  use Mix.Project

  def project do
    [
      app: :threat_shield,
      version: "0.1.0",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      hex: [ignore_advisories: ignored_advisories()],
      dialyzer: [
        plt_local_path: Path.expand("priv/plts", __DIR__),
        plt_core_path: Path.expand("priv/plts", __DIR__),
        plt_add_apps: [:mix, :ex_unit],
        ignore_warnings: ".dialyzer_ignore.exs",
        list_unused_filters: true
      ]
    ]
  end

  # Advisories of `mix hex.audit` that do not affect the app and cannot be fixed by an
  # update yet. Remove an entry as soon as the update is possible.
  defp ignored_advisories do
    [
      # assent 0.2.13, Sign in with Apple (fixed in 0.3.2): the app signs in only with
      # a password or an API key and has no OAuth strategy, so assent's Apple code
      # never runs. ash_authentication 4.15 (the latest) requires assent < 0.3.
      "EEF-CVE-2026-117656",
      # phoenix_live_view 0.20.17, open redirect with tab/LF/CR in redirect/2 (fixed in
      # 1.0.19): the app redirects only to paths it builds itself (verified routes
      # and ids), never to a URL from a request. The fix needs LiveView 1.x.
      "EEF-CVE-2026-64941"
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {ThreatShield.Application, []},
      extra_applications: [:dotenv, :logger, :runtime_tools, :os_mon, :bcrypt_elixir, :ex_rated]
    ]
  end

  # Specifies which paths to compile per environment.
  # The fixtures of the threat model are shared with the tests of the library.
  defp elixirc_paths(:test),
    do: ["lib", "test/support", "packages/ash_threat_shield/test/support/fixtures"]

  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:ash_threat_shield, path: "packages/ash_threat_shield"},
      {:ash, "~> 3.37"},
      {:ash_postgres, "~> 2.16"},
      {:ash_authentication, "~> 4.0"},
      {:ash_phoenix, "~> 2.0"},
      {:ash_ai, "~> 1.5"},
      {:picosat_elixir, "~> 0.2"},
      {:bcrypt_elixir, "~> 3.1"},
      {:phoenix, "~> 1.7.11"},
      {:phoenix_ecto, "~> 4.5"},
      {:dotenv, "~> 3.1.0"},
      {:ecto_sql, "~> 3.14"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.12"},
      {:floki, ">= 0.36.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:finch, "~> 0.19"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:openai, "~> 0.5.2"},
      # openai needs httpoison ~> 2.0, which is held at hackney 1.x with open advisories.
      # Its calls work unchanged with httpoison 3 and hackney 4.
      {:httpoison, "~> 3.0", override: true},
      {:ecto_psql_extras, "~> 0.8"},
      {:ex_rated, "~> 2.1"},
      {:timex, "~> 3.7.11"},
      {:elixlsx, "~> 0.5.1"},
      {:logger_json, "~> 5.1"},
      # static analysis, see "Checks" in AGENTS.md
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ash_credo, "~> 0.19.2", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.19", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.17", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
