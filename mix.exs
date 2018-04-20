defmodule TusClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :tus_client,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 1.1"},
      # development stuff,
      # {:stream_data, "~> 0.4", only: :test},
      {:bypass, "~> 0.8", only: :test},
      {:excoveralls, "~> 0.8", only: :test, runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false}
    ]
  end
end
