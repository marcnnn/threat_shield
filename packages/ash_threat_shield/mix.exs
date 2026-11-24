defmodule AshThreatShield.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ash_threat_shield,
      version: @version,
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      # In this repository the library shares the dependencies and the lock file of
      # the application at the root of the repository, so both use the same versions.
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      aliases: aliases(),
      deps: deps(),
      # With the deps and the lock file of ThreatShield, dialyxir treats the library like
      # an umbrella child and does not build a PLT; it uses the PLTs of ThreatShield,
      # which cover the same dependencies (build them with `mix dialyzer --plt` there).
      dialyzer: [
        plt_local_path: Path.expand("../../priv/plts", __DIR__),
        plt_core_path: Path.expand("../../priv/plts", __DIR__),
        plt_add_apps: [:mix, :ex_unit],
        ignore_warnings: ".dialyzer_ignore.exs",
        list_unused_filters: true
      ],
      description: "Threat modeling with Ash: systems, assets, threats, risks and mitigations.",
      package: package()
    ]
  end

  def application do
    [
      mod: {AshThreatShield.Application, []},
      extra_applications: [:logger]
    ]
  end

  # The test host (owner, users, authorization, repo) is compiled in dev too, so
  # that `mix compile` in this directory has a configuration to compile against.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      {:ash, "~> 3.37"},
      {:ash_postgres, "~> 2.16"},
      {:ash_ai, "~> 1.5"},
      {:picosat_elixir, "~> 0.2"},
      {:jason, "~> 1.2"},
      # the default AI provider; a host with another provider can leave it out
      {:openai, "~> 0.6.2", optional: true},
      # openai 0.6 (the latest) still needs httpoison ~> 2.0, which is held at hackney 1.x
      # with open advisories. Its calls work unchanged with httpoison 3 and hackney 4.
      # The override applies only to the builds of this project; a host sets its own.
      {:httpoison, "~> 3.0", override: true, optional: true},
      # static analysis, see "Checks" in AGENTS.md of ThreatShield
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ash_credo, "~> 0.19.2", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE.txt)
    ]
  end
end
