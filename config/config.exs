use Mix.Config

config :gitlab_to_org_mode, GitlabToOrgMode.Repo,
	adapter: Ecto.Adapters.Postgres,
	database: "gitlabhq_production",
	username: "gitlab",
	password: "",
	hostname: "localhost",
	port: 5433,
	pool_size: 3

config :gitlab_to_org_mode, ecto_repos: [GitlabToOrgMode.Repo]

config :logger,
	level: :warn,
	truncate: 4096
