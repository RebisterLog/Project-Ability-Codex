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

			StartSkill = ByteNet.definePacket({
				value = ByteNet.struct({
					Id = ByteNet.string,
					AimPoint = ByteNet.optional(ByteNet.vec3),
				}),
			}),

			StopSkill = ByteNet.definePacket({
				value = ByteNet.string,
			}),

			-- Client -> server pose sample for melee lag compensation. Position
			-- and Time always travel; Velocity/LookYaw are diffed on the client
			-- to stay inside ByteNet's shared 512 B/s budget. Append only:
			-- packet and struct IDs are declaration order and must not shift.
			ClientState = ByteNet.definePacket({
				reliabilityType = "unreliable",
				value = ByteNet.struct({
					-- GetServerTimeNow() is epoch-scale here; float32 would
					-- quantise it to ~128 s and break latency maths.
					Time = ByteNet.float64,
					Position = ByteNet.vec3,
					Velocity = ByteNet.optional(ByteNet.vec3),
					LookYaw = ByteNet.optional(ByteNet.float32),
					IsGrounded = ByteNet.bool,
				}),
			}),
		},

		queries = {},
	}
end)
