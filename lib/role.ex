defmodule RoleWebTesting do
	def role(_tags \\ []) do
		%{
			desired_packages: [
				"google-chrome-stable",
				"google-chrome-beta",
				"google-chrome-unstable",
				"firefox",
			],
			implied_roles:    [RoleGoogleChromeRepo],
		}
	end
end
