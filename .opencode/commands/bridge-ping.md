---
name: bridge-ping
description: Remind how to ping Crane Bridge in Studio
---
See docs/BRIDGE.md. In a playtest, fire `{ Id, Op="bridge.ping", Args={} }` over Request; read matching response. Operations catalog via `bridge.help`. Requires `RunService:IsStudio()`.