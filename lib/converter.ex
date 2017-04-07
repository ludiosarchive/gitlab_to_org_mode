defmodule GitlabToOrgMode.Converter do
	alias GitlabToOrgMode.Repo
	import Ecto.Query

	def issues() do
		from("issues")
		|> join(:left, [i], p in "projects", i.project_id == p.id)
		|> select([i, p], %{issue_id: i.id, project_name: p.name, created_at: i.created_at, title: i.title, description: i.description})
		|> Repo.all
	end

	# - State "TODO"       from "TODO"       [2017-04-07 Fri 10:16]
	# - State "TODO"       from              [2017-04-07 Fri 10:17]

	def main(_args) do
		for issue <- issues() do
			IO.inspect(issue)
		end
	end
end
