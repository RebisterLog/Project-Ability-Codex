--!strict
--- Loading the real skill modules into a Roblox-free environment.
---
--- A skill cannot simply be `require`d: inside it calls `game:GetService` and
--- `require(ReplicatedStorage.shared.packages.Crane)`, and Lune knows neither,
--- while globals cannot be handed to a foreign module either — every chunk has
--- its own environment. So the source is read as text, a prelude holding the
--- stand-ins is glued onto it, and the result is compiled through `loadstring`.
---
--- Nothing is copied or rewritten: only the prefix is altered. The test works
--- with the very same code that will ship to the game.
---
--- This is the subtlety the whole approach rests on: `require` inside a chunk
--- from `loadstring` is unsupported, but a local `require` at the top of the
--- chunk shadows the global one. Values are exchanged through `_G`: it is
--- shared by every chunk in the process, bare globals are not.

local fs = require("@lune/fs")

local Loader = {}

--- Names the prelude declares as locals. The order matches the order of the
--- arguments the compiled chunk is called with.
const INJECTED = {
	"game",
	"workspace",
	"script",
	"Instance",
	"Vector3",
	"Vector2",
	"CFrame",
	"Color3",
	"BrickColor",
	"Enum",
	"UDim2",
	"UDim",
	"NumberSequence",
	"NumberRange",
	"ColorSequence",
	"Region3",
	"Ray",
	"Rect",
	"Axes",
	"Faces",
	"PhysicalProperties",
	"TweenInfo",
	"task",
	"os",
	"tick",
	"require",
}

--- One-line prelude with no trailing newline.
---
--- That keeps the line numbers in the trace aligned with the source: separate
--- lines would shift every error by however many there are and point it at the
--- wrong line of the skill. The first line of the source simply gets longer.
local function prelude(): string
	return `local __PAC, {table.concat(INJECTED, ", ")} = ...`
end

--- Arguments for the chunk: the same names in the same order, plus the
--- environment the skill digs out through `__PAC`.
---
--- The array is preallocated and filled by index. `table.insert` is not usable
--- here: inserting `nil` does not extend the array, so a single missing name
--- shifts everything after it and the last name (`require`) arrives as `nil`.
--- For the same reason the length is explicit — `#` on a table with holes
--- guesses wrong.
local function arguments(env: { [string]: any }): { any }
	const args: { any } = table.create(#INJECTED + 1, false)

	args[1] = env

	for index, name in INJECTED do
		args[index + 1] = env[name]
	end

	return args
end

--- Module path from whatever was handed to `require`: a string, or an instance
--- tree node whose path lives in `__path`.
function Loader.path(target: any): string?
	if type(target) == "string" then return target end

	if type(target) == "table" then
		local path = rawget(target, "__path")

		if type(path) == "string" then return path end
	end

	return nil
end

--- `require` for the stand-ins: looks the path up in the registry and hands
--- anything unknown to the fallback. Failing on an unknown path is not an
--- option — a skill may require things the test never exercises.
function Loader.shim(registry: { [string]: any }, fallback: (path: string) -> any): any
	return function(target: any)
		local path = Loader.path(target)

		if path == nil then return fallback("?") end

		local module = registry[path]

		if module ~= nil then return module end

		return fallback(path)
	end
end

--- Compiles and runs the source inside the faked environment.
function Loader.compile(env: { [string]: any }, source: string, chunkName: string): any
	local chunk = loadstring(prelude() .. source, `={chunkName}`)

	if not chunk then error(`failed to compile {chunkName}`, 2) end

	local ok, result = pcall(chunk, table.unpack(arguments(env), 1, #INJECTED + 1))

	if not ok then error(`{chunkName}: {result}`, 0) end

	return result
end

--- Same, but for a file in the project.
function Loader.file(env: { [string]: any }, path: string): any
	if not fs.isFile(path) then error(`harness: no such module {path}`, 2) end

	return Loader.compile(env, fs.readFile(path), path)
end

--- Compiles with no faking: that is how modules needing nothing from Roblox
--- get loaded — `server/Enums`, for instance.
function Loader.plain(path: string): any
	local chunk = loadstring(fs.readFile(path), `={path}`)

	if not chunk then error(`failed to compile {path}`, 2) end

	local ok, result = pcall(chunk)

	if not ok then error(`{path}: {result}`, 0) end

	return result
end

return Loader
