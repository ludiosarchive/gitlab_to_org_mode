defmodule GitlabToOrgMode.Reader do
	alias GitlabToOrgMode.Repo
	import Ecto.Query

	def issues() do
		notes_aggregate =
			from("notes")
			|> select([n], %{
					noteable_id: n.noteable_id,
					notes:       fragment("array_agg(json_build_object('note', ?::varchar, 'system', ?))", n.note, n.system)
				})
			|> group_by([n], n.noteable_id)

		labels_aggregate =
			from("label_links")
			|> join(:left, [ll], l in "labels", ll.label_id == l.id)
			|> select([ll, l], %{
					target_id: ll.target_id,
					labels:    fragment("array_agg(?)", l.title)
				})
			|> group_by([ll], ll.target_id)

		from("issues")
		|> join(:left, [i], p in "projects", i.project_id == p.id)
		|> join(:left, [i], n in subquery(notes_aggregate),  i.id == n.noteable_id)
		|> join(:left, [i], l in subquery(labels_aggregate), i.id == l.target_id)
		|> select([i, p, n, l], %{
				issue_id:     i.id,
				created_at:   i.created_at,
				title:        i.title,
				description:  i.description,
				state:        i.state,
				project_id:   i.project_id,
				project_name: p.name,
				notes:        n.notes,
				labels:       l.labels,
			})
		|> Repo.all
		|> Enum.map(&fix_row/1)
	end

	defp fix_row(row) do
		row = %{row | created_at:  row.created_at  |> erlang_date_to_datetime}
		row = %{row | description: row.description |> fix_windows_newlines}
		row = %{row | notes:       (if row.notes,  do: row.notes |> fix_notes, else: [])}
		row = %{row | labels:      (if row.labels, do: row.labels,             else: [])}
		row
	end

	defp fix_notes(notes) do
		notes
		|> Enum.map(&fix_note/1)
	end

	defp fix_note(note) do
		%{note: note["note"] |> fix_windows_newlines, system: note["system"]}
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


defmodule GitlabToOrgMode.Writer do
	def dest_filename(row) do
		basename = case row.project_name do
			# Modify this to map your GitLab projects to org files:
			# GitLab project -> org file
			"sysadmin-tasks" -> "tasks"
			"life-tasks"     -> "tasks"
			"japanese-tasks" -> "japanese"
			"media-tasks"    -> cond do
				"film"  in row.labels -> "movies"
				"game"  in row.labels -> "games"
				"text"  in row.labels -> "reading"
				"audio" in row.labels -> "reading"
				true                  -> "media"
			end
			# GitLab is great, it keeps issues around for deleted projects
			nil              -> "orphaned_#{row.project_id}"
			other            -> other
		end
		case row.state do
			"opened"   -> basename <> ".org"
			"reopened" -> basename <> ".org"
			"closed"   -> basename <> ".org_archive"
			other      -> raise "Unexpected state for issue: #{inspect other}"
		end
	end

	def org_item(row) do
		keyword = case row.state do
			"closed" -> "DONE"
			_        -> "TODO"
		end
		description = row.description |> String.trim
		split_notes = row.notes |> Enum.map(&split_note/1)
		EEx.eval_string(
		"""
		* <%= keyword %> <%= row.title %><%= if description != "" do %>
		<%= description %><% end %><%= for %{headline: headline, body: body} <- split_notes do %>
		** <%= headline %><%= if body do %>
		<%= body |> String.trim %><% end %><% end %>
		""", [keyword: keyword, row: row, description: description, split_notes: split_notes])
		# - State "TODO"       from "TODO"       [2017-04-07 Fri 10:16]
		# - State "TODO"       from              [2017-04-07 Fri 10:17]
	end

	defp split_note(%{note: text, system: system}) do
		{headline, body} = case text |> String.split("\n", parts: 2) do
			[headline, body] -> {headline, body}
			[headline]       -> {headline, nil}
		end
		%{headline: headline, body: body, system: system}
	end
end


defmodule GitlabToOrgMode.MultiFileWriter do
	defstruct pid: nil

	def new() do
		{:ok, pid} = Agent.start_link(fn -> %{} end)
		%GitlabToOrgMode.MultiFileWriter{pid: pid}
	end

	def handle(mfw, filename) do
		Agent.get_and_update(mfw.pid, fn(handles) ->
			case handles[filename] do
				nil ->
					handle = File.open!(filename, [:write])
					{handle, handles |> Map.put(filename, handle)}
				handle ->
					{handle, handles}
			end
		end)
	end
end


defmodule GitlabToOrgMode.Converter do
	alias GitlabToOrgMode.{Reader, Writer, MultiFileWriter}

	def main(_args) do
		mfw = MultiFileWriter.new()
		for row <- Reader.issues() do
			dest = Writer.dest_filename(row)
			#IO.puts("#{dest} <- #{row.title}; labeled #{inspect row.labels}; #{row.notes |> length} notes")
			IO.puts("#{inspect row}")

			handle = MultiFileWriter.handle(mfw, dest)
			:ok = IO.binwrite(handle, Writer.org_item(row))
		end
	end
end
