--!strict
--- Generate compact type reference from src/server/types.luau and shared schemas.
---
---   lune run tools/gen-types-doc.luau
--- writes docs/API_TYPES.md

local fs = require("@lune/fs")
local process = require("@lune/process")
local Toolchain = require("./Toolchain")

local root = Toolchain.findRoot()

local function exportsFromFile(path: string): { string }
	local ok, text = pcall(fs.readFile, path)
	if not ok or not text then return {} end
	local out: { string } = {}
	for line in (text:gsub("\r\n", "\n")):gmatch("[^\n]+") do
		local trimmed = line:match("^%s*(.+)%s*$")
		if trimmed and trimmed:sub(1, 11) == "export type" then
			table.insert(out, trimmed)
		end
	end
	return out
end

local lines: { string } = {}
table.insert(lines, "# PAC API Types (generated)")
table.insert(lines, "")
table.insert(lines, "Source: `src/server/types.luau`, `src/shared/schemas/*.luau`. Regenerate: `lune run tools/gen-types-doc.luau`.")
table.insert(lines, "")
table.insert(lines, "## src/server/types.luau")
for _, e in exportsFromFile(`{root}/src/server/types.luau`) do
	table.insert(lines, "- " .. e)
end

table.insert(lines, "")
table.insert(lines, "## shared/schemas")
local schemaDir = `{root}/src/shared/schemas`
if fs.isDir(schemaDir) then
	for _, entry in fs.readDir(schemaDir) do
		if entry:sub(-5) == ".luau" then
			local path = `{schemaDir}/{entry}`
			local exps = exportsFromFile(path)
			if #exps > 0 then
				table.insert(lines, `### {entry}`)
				for _, e in exps do table.insert(lines, "- " .. e) end
				table.insert(lines, "")
			end
		end
	end
end

fs.writeFile(`{root}/docs/API_TYPES.md`, table.concat(lines, "\n"))
print("wrote docs/API_TYPES.md")
process.exit(0)