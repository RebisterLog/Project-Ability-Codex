--!strict
--- Generate a compact code map for key areas (not every file).
---   lune run tools/gen-code-map.luau
--- writes docs/CODE_MAP.md

local fs = require("@lune/fs")
local process = require("@lune/process")
local Toolchain = require("./Toolchain")

local root = Toolchain.findRoot()

local function listLuau(dir: string): { string }
	local out: { string } = {}
	if not fs.isDir(dir) then return out end
	for _, e in fs.readDir(dir) do
		if e:sub(-5) == ".luau" then table.insert(out, e) end
	end
	table.sort(out)
	return out
end

local function section(title: string, dir: string): { string }
	local out: { string } = { `## {title}` }
	local files = listLuau(dir)
	if #files == 0 then
		table.insert(out, "(none)")
		table.insert(out, "")
		return out
	end
	for _, f in files do table.insert(out, `- {f}`) end
	table.insert(out, "")
	return out
end

local lines: { string } = {
	"# PAC Code Map (generated)",
	"",
	"Regenerate: `lune run tools/gen-code-map.luau`. Scope: key entry surfaces only.",
	"",
}

local function addDir(title: string, rel: string)
	for _, l in section(title, `{root}/{rel}`) do table.insert(lines, l) end
end

addDir("Server services", "src/server/services")
addDir("Server specs", "src/server/specs")
addDir("Server combat-classes", "src/server/combat-classes")
addDir("Server skills (root)", "src/server/skills")
addDir("Shared schemas", "src/shared/schemas")
addDir("Client services", "src/client/services")
addDir("Client components", "src/client/components")
table.insert(lines, "## Shared packages (names)")
for _, e in fs.readDir(`{root}/src/shared/packages`) do
	table.insert(lines, `- {e}`)
end

fs.writeFile(`{root}/docs/CODE_MAP.md`, table.concat(lines, "\n"))
print("wrote docs/CODE_MAP.md")
process.exit(0)