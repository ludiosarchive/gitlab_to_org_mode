defmodule GitlabToOrgMode.Application do
	@moduledoc false

	use Application

	def start(_type, _args) do
		import Supervisor.Spec, warn: false

		children = [
			supervisor(GitlabToOrgMode.Repo, []),
		]
		opts = [strategy: :one_for_one, name: GitlabToOrgMode.Supervisor]
		Supervisor.start_link(children, opts)
	end
end
