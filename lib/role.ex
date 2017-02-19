defmodule RoleXfs do
	def role(_tags \\ []) do
		%{
			desired_packages: ["xfsprogs", "xfsdump"]
		}
	end
end
