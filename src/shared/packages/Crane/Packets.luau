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

local ByteNet = require(script.Parent.packages.ByteNet)

return ByteNet.defineNamespace("CranePackets", function()
	return {
		packets = {
			RequestProxy = ByteNet.definePacket({
				value = ByteNet.optional(ByteNet.array(ByteNet.unknown)),
			}),
			
			Patch = ByteNet.definePacket({
				value = ByteNet.array(
					ByteNet.array(
						ByteNet.struct({
							Name = ByteNet.string,
							Path = ByteNet.array(ByteNet.string),
							Args = ByteNet.array(ByteNet.unknown)
						})
					)
				)
			}),

			StartVFX = ByteNet.definePacket({
				value = ByteNet.struct({
					name = ByteNet.string,
					args = ByteNet.array(ByteNet.unknown)
				})
			}),

			StopVFX = ByteNet.definePacket({
				value = ByteNet.struct({
					name = ByteNet.string,
					args = ByteNet.array(ByteNet.unknown)
				})
			}),
			
			StartSkill = ByteNet.definePacket({
				value = ByteNet.string,
			}),
			
			StopSkill = ByteNet.definePacket({
				value = ByteNet.string,	
			}),
		},
		
		queries = {

		}
	}
end)

