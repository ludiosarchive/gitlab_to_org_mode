alias Converge.Util

defmodule RoleNetworkManager do
	require Util
	Util.declare_external_resources("files")

	def role(_tags \\ []) do
		%{
			desired_packages: [
				"network-manager",
				"network-manager-gnome",
				"network-manager-openvpn",
				"network-manager-openvpn-gnome",
			],
		}
	end
end
