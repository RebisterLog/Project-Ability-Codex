--[[
██████╗██████╗  █████╗ ███╗   ██╗███████╗
██╔════╝██╔══██╗██╔══██╗████╗  ██║██╔════╝
██║     ██████╔╝███████║██╔██╗ ██║█████╗
██║     ██╔══██╗██╔══██║██║╚██╗██║██╔══╝
╚██████╗██║  ██║██║  ██║██║ ╚████║███████╗
╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝

███████╗██████╗  █████╗ ███╗   ███╗███████╗██╗    ██╗ ██████╗ ██████╗ ██╗  ██╗
██╔════╝██╔══██╗██╔══██╗████╗ ████║██╔════╝██║    ██║██╔═══██╗██╔══██╗██║ ██╔╝
█████╗  ██████╔╝███████║██╔████╔██║█████╗  ██║ █╗ ██║██║   ██║██████╔╝█████╔╝
██╔══╝  ██╔══██╗██╔══██║██║╚██╔╝██║██╔══╝  ██║███╗██║██║   ██║██╔══██╗██╔═██╗
██║     ██║  ██║██║  ██║██║ ╚═╝ ██║███████╗╚███╔███╔╝╚██████╔╝██║  ██║██║  ██╗
╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝ ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
by RebisterLog
]]

--!native
--!optimize 2

--[[
	This module contains the packets used by the Crane Framework.
	You can use any network library you want, such as ByteNet for example.
	Just return the packets table, and use it in your middleware or services!
]]

const ByteNet = require(script.Parent.packages.ByteNet)

return ByteNet.defineNamespace("CranePackets", function()
	return {
		packets = {
			RequestProxy = ByteNet.definePacket({
				value = ByteNet.optional(ByteNet.array(ByteNet.unknown)),
			}),

			Patch = ByteNet.definePacket({
				value = ByteNet.array(ByteNet.array(ByteNet.struct({
					Name = ByteNet.string,
					Path = ByteNet.array(ByteNet.string),
					Args = ByteNet.array(ByteNet.unknown),
				}))),
			}),

			StartVFX = ByteNet.definePacket({
				value = ByteNet.struct({
					name = ByteNet.string,
					args = ByteNet.array(ByteNet.unknown),
				}),
			}),

			StopVFX = ByteNet.definePacket({
				value = ByteNet.struct({
					name = ByteNet.string,
					args = ByteNet.array(ByteNet.unknown),
				}),
			}),

			-- Carries the client's Chrono render timestamps so the server can
			-- rewind hitboxes to exactly what the attacker saw. float64 keeps
			-- sub-millisecond precision on `os.clock()`-scale timestamps.
			StartSkill = ByteNet.definePacket({
				value = ByteNet.struct({
					Id = ByteNet.string,
					AimNormal = ByteNet.float64,
					AimHalf = ByteNet.float64,
				}),
			}),

			StopSkill = ByteNet.definePacket({
				value = ByteNet.string,
			}),
		},

		queries = {},
	}
end)
