defmodule Decorum.MixProject do
  use Mix.Project

  @version "0.1.2"
  @repo_url "https://github.com/CoderDennis/decorum"

  def project do
    [
      app: :decorum,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description: "Property-based testing for Elixir with shrinking that just works",
      package: [
        licenses: ["MIT"],
        links: %{"GitHub" => @repo_url}
      ],
      docs: [
        extras: ["README.md", "NOTES.md"],
        main: "readme"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false}
    ]
  end
end
