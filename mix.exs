defmodule Tela.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/idabmat/tela"

  def project do
    [
      app: :tela,
      version: @version,
      elixir: "~> 1.19",
      deps: deps(),
      description: "A zero-dependency Elixir library for building terminal UIs using the Elm Architecture.",
      package: package(),
      docs: docs(),
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false},
      {:stream_data, "~> 1.2", only: [:dev, :test]},
      {:styler, "~> 1.11", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*)
    ]
  end

  defp docs do
    [
      main: "Tela",
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end
end
