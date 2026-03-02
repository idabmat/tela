defmodule Grocery.MixProject do
  use Mix.Project

  def project do
    [
      app: :grocery,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      releases: releases(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Grocery.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tela, "~> 0.1"},
      {:burrito, "~> 1.5"}
    ]
  end

  defp releases() do
    [
      grocery: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            linux: [
              os: :linux,
              cpu: :x86_64,
              # Set this to point to a custom ERTS with support for TERMCAP as the one provided
              # by burrito out-of-the-box does not.
              custom_erts: System.fetch_env!("LINUX_ERTS_PATH")
            ]
          ]
        ]
      ]
    ]
  end
end
