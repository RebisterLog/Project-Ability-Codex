--!strict

--[[
	Crane Bridge — a Studio-only control surface for tooling and agents.

	Each side of the game owns one Crane service that publishes a pair of
	BindableEvents, a Request and a Response, under a container its own agents can
	address directly:

		Server  ->  ServerScriptService.Bridge
		Client  ->  ReplicatedStorage.Bridge

	An agent fires a request and waits for the matching response. Fire never
	yields, so the wait always has to be explicit.

	SECURITY

	Nothing here exists in a published game. Both services check
	RunService:IsStudio() before they create a single instance, and Ops.Run
	re-checks it on every call, so a direct Fire on the event does nothing either.

	The server container lives in ServerScriptService rather than
	ReplicatedStorage on purpose. ServerScriptService never replicates, so a
	remote client has no address to aim at and cannot subscribe to responses. The
	server additionally never connects to the client pair, so a replicated client
	container is inert from the server side.

	BindableEvent drops metatables, so nothing live ever crosses. Codec converts
	every value into tagged plain data on the way out and back on the way in. A
	table that had a metatable comes back flagged with __hasMetatable, which is the
	honest signal that an agent is holding a snapshot rather than an object.
]]

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Codec = require(script.Codec)
local Ops = require(script.Ops)

local Bridge = {
	Codec = Codec,
	Ops = Ops,
}

export type Request = {
	Id: string?,
	Op: string?,
	Args: { [string]: any }?,
}

export type Response = {
	Id: string,
	Ok: boolean,
	Value: any?,
	Error: string?,
	Ms: number?,
}

export type Container = {
	Folder: Folder,
	Request: BindableEvent,
	Response: BindableEvent,
}

--- Creates the Request/Response pair, reusing an existing container when one is
--- already present so a second pass never orphans a live pair.
function Bridge.CreateContainer(parent: Instance, name: string): Container
	local existing = parent:FindFirstChild(name)

	if existing and existing:IsA("Folder") then
		local request = existing:FindFirstChild("Request")
		local response = existing:FindFirstChild("Response")

		if
			request
			and response
			and request:IsA("BindableEvent")
			and response:IsA("BindableEvent")
		then
			return {
				Folder = existing,
				Request = request,
				Response = response,
			}
		end

		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent

	local request = Instance.new("BindableEvent")
	request.Name = "Request"
	request.Parent = folder

	local response = Instance.new("BindableEvent")
	response.Name = "Response"
	response.Parent = folder

	return { Folder = folder, Request = request, Response = response }
end

--- Handles one request and answers it. Never raises: every failure comes back
--- as an error envelope so the waiting agent always gets something to read.
function Bridge.Dispatch(payload: any, response: BindableEvent)
	if not RunService:IsStudio() then return end

	local started = os.clock()

	local id = if typeof(payload) == "table" then payload.Id else nil
	if type(id) ~= "string" or #id == 0 then id = HttpService:GenerateGUID(false) end

	local op = if typeof(payload) == "table" then payload.Op else nil
	local args = Codec.DecodeArgs(if typeof(payload) == "table" then payload.Args else nil)

	local value: any, err: string?
	if type(op) ~= "string" or #op == 0 then
		err = 'Request is missing a non-empty "Op"'
	else
		value, err = Ops.Run(op, args)
	end

	local envelope: Response = {
		Id = id,
		Ok = err == nil,
		Ms = math.floor((os.clock() - started) * 1000 + 0.5),
	}

	if err == nil then
		envelope.Value = value
	else
		envelope.Error = err
	end

	Ops.Record({
		Id = id,
		Op = if type(op) == "string" then op else "?",
		Ok = envelope.Ok,
		Ms = envelope.Ms,
	})

	response:Fire(envelope)
end

return Bridge
