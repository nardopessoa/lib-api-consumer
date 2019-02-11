defmodule ApiConsumer.MixProject do
  use Mix.Project

  def project do
    [
      app: :api_consumer,
      version: "0.1.0",
      build_path: "_build",
      config_path: "config/config.exs",
      deps_path: "deps",
      lockfile: "mix.lock",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [
        :logger,
        :httpoison,
        :timex,
        :logger_file_backend,
        :meeseeks
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 1.1"},
      {:poison, "~> 3.1"},
      {:timex, "~> 3.2"},
      {:logger_file_backend, "~> 0.0"},
      {:meeseeks, "~> 0.7.7"}
    ]
  end
end
