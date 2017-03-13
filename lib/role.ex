defmodule RoleGrabSite do
	def role(_tags \\ []) do
		%{
			desired_packages: [
				"git",
				"build-essential",
				"python3.4",
				"python3.4-dev",
				"python3.4-venv",
			],
			implied_roles: [RoleCustomPackages],
		}
	end
end
