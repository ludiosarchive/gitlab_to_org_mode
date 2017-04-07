defmodule GitlabToOrgMode.Converter do
	alias GitlabToOrgMode.Repo
	import Ecto.Query

	def main(_args) do
		for issue <- issues() do
			IO.inspect(issue)
		end
	end

	def issues() do
		notes_aggregate =
			from("notes")
			|> select([n], %{
					noteable_id: n.noteable_id,
					notes:       fragment("array_agg(json_build_object('note', ?::varchar, 'system', ?))", n.note, n.system)
				})
			|> group_by([n], n.noteable_id)

		from("issues")
		|> join(:left, [i], p in "projects", i.project_id == p.id)
		|> join(:left, [i], n in subquery(notes_aggregate), i.id == n.noteable_id)
		|> select([i, p, n], %{issue_id: i.id, project_name: p.name, created_at: i.created_at, title: i.title, description: i.description, notes: n.notes})
		|> Repo.all
		|> Enum.map(&fix_row/1)
	end

	defp fix_row(row) do
		row = %{row | created_at: row.created_at |> erlang_date_to_datetime}
		row
	end

	defp fix_windows_newlines(text) do
		text
		|> String.replace("\r\n", "\n")
	end

	# https://github.com/elixir-ecto/ecto/issues/1920
	def erlang_date_to_datetime({{year, month, day}, {hour, min, sec, usec}}) do
		%DateTime{
			year: year, month: month, day: day, hour: hour, minute: min,
			second: sec, microsecond: {usec, 6}, zone_abbr: "UTC", time_zone: "Etc/UTC",
			utc_offset: 0, std_offset: 0
		}
	end
end


# - State "TODO"       from "TODO"       [2017-04-07 Fri 10:16]
# - State "TODO"       from              [2017-04-07 Fri 10:17]
