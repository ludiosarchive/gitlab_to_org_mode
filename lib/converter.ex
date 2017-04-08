defmodule GitlabToOrgMode.Reader do
	alias GitlabToOrgMode.Repo
	import Ecto.Query

	def issues() do
		notes_aggregate =
			from("notes")
			|> select([n], %{
					noteable_id: n.noteable_id,
					notes:       fragment("array_agg(json_build_object('note', ?, 'created_at', ?, 'system', ?))", n.note, n.created_at, n.system)
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
				updated_at:   i.updated_at,
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
		row = %{row | updated_at:  row.updated_at  |> erlang_date_to_datetime}
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
		%{
			note:       note["note"] |> fix_windows_newlines,
			system:     note["system"],
			created_at: note["created_at"],
		}
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
		split_notes =
			row.notes
			|> Enum.filter(&include_note?/1)
			|> Enum.map(&split_note/1)
		[
			"* ", keyword, " ", row.title, "\n",
			if row.state == "closed" do
				# Assume that the updated_at time for a closed issue is when the
				# issue was closed.  Not always true, but good enough.
				[~s(- State "DONE"       from "TODO"       [), datetime_to_org_date(row.updated_at), "]", "\n"]
			else
				""
			end,
			~s(- State "TODO"       from              [), datetime_to_org_date(row.created_at), "]", "\n",
			(if description != "", do: [description, "\n"], else: ""),
			for %{headline: headline, body: body} <- split_notes do
				[
					"** ", headline, "\n",
					(if body, do: [body |> String.trim, "\n"], else: "")
				]
			end
		]
	end

	defp include_note?(note) do
		not note.system
	end

	defp split_note(%{note: text, system: system, created_at: created_at}) do
		{headline, body} = case text |> String.split("\n", parts: 2) do
			[headline, body] -> {headline, body}
			[headline]       -> {headline, nil}
		end
		%{headline: headline, body: body, system: system, created_at: created_at}
	end

	defp datetime_to_org_date(datetime) do
		:io_lib.format(
			"~4..0B-~2..0B-~2..0B ~s ~2..0B:~2..0B",
			[
				datetime.year, datetime.month, datetime.day, get_weekday(datetime),
				datetime.hour, datetime.minute
			]
		)
	end

	defp get_weekday(datetime) do
		date = datetime |> DateTime.to_date
		case date |> Date.day_of_week do
			1 -> "Mon"
			2 -> "Tue"
			3 -> "Wed"
			4 -> "Thu"
			5 -> "Fri"
			6 -> "Sat"
			7 -> "Sun"
		end
	end
end


defmodule GitlabToOrgMode.FileHandler do
	defstruct pid: nil

	def new() do
		{:ok, pid} = Agent.start_link(fn -> %{} end)
		%GitlabToOrgMode.FileHandler{pid: pid}
	end

	def handle(fh, filename) do
		Agent.get_and_update(fh.pid, fn(handles) ->
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
	alias GitlabToOrgMode.{Reader, Writer, FileHandler}

	def main(_args) do
		fh = FileHandler.new()
		for row <- Reader.issues() do
			dest = Writer.dest_filename(row)
			IO.puts("#{dest} <- #{row.title}; labeled #{inspect row.labels}; #{row.notes |> length} notes")
			#IO.puts("#{inspect row}")

			handle = FileHandler.handle(fh, dest)
			:ok = IO.binwrite(handle, Writer.org_item(row))
		end
	end
end
