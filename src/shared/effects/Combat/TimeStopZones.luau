--[=[ Time Stop freeze zones: client side.

   The whole world pauses for everyone, so a client-side simulation that
   replicates server state (projectile flight, particle trails) needs to know
   when and where Time Stop is active. The Time Stop effect registers the zone
   on Release and the zones expire on their own after the freeze ends.

   A zone carries the blast radius from the cast so simulations outside the
   sphere are left alone, mirroring the server's projectile freeze.
]=]

const TimeStopZones = {
	Zones = {} :: { { Center: Vector3, Radius: number, Expiry: number } },
}

function TimeStopZones.Register(center: Vector3, radius: number, duration: number)
	table.insert(TimeStopZones.Zones, {
		Center = center,
		Radius = radius,
		Expiry = os.clock() + duration,
	})
end

function TimeStopZones.IsFrozen(position: Vector3): boolean
	const now = os.clock()
	local inside = false
	const kept: { { Center: Vector3, Radius: number, Expiry: number } } = {}

	for _, zone in TimeStopZones.Zones do
		if zone.Expiry > now then
			table.insert(kept, zone)
			if (position - zone.Center).Magnitude <= zone.Radius then inside = true end
		end
	end

	TimeStopZones.Zones = kept
	return inside
end

return TimeStopZones
