alias Converge.Util

defmodule RoleXfs do
	require Util
	Util.declare_external_resources("files")

	def role(_tags \\ []) do
		%{
			desired_packages: ["xfsprogs", "xfsdump"]
		}
	end
end
