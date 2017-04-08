defmodule GitlabToOrgMode.Mixfile do
	use Mix.Project

	def project do
		[
			app:             :gitlab_to_org_mode,
			version:         "0.1.0",
			elixir:          ">= 1.4.0",
			build_embedded:  Mix.env == :prod,
			start_permanent: Mix.env == :prod,
			escript:         [main_module: GitlabToOrgMode.Converter],
			deps:            deps()
		]
	end

	def application do
		[
			extra_applications: [:logger],
			mod: {GitlabToOrgMode.Application, []}
		]
	end

	defp deps do
		[
			{:ecto,     ">= 2.1"},
			{:postgrex, ">= 0.13.0"},
			{:poison,   ">= 3.1.0"},
		]
	end
end
