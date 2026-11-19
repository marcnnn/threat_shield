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
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"},
      # 1.0.3 and later need ash 3.33, which needs ecto 3.14
      {:ash_ai, "~> 1.0.2"},
      {:picosat_elixir, "~> 0.2"},
      {:jason, "~> 1.2"},
      # the default AI provider; a host with another provider can leave it out
      {:openai, "~> 0.5.2", optional: true}
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
