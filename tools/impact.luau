--!strict
--- CLI to estimate blast radius for a file/path/module.
---
---   lune run tools/impact.luau src/shared/packages/Proxy.luau
---   lune run tools/impact.luau Proxy
---
--- Scans src/, tools/, tests/ (minus vendored) for references to the given
--- path/identifier and lists dependent files with hit counts.

local fs = require("@lune/fs")
local process = require("@lune/process")
local Toolchain = require("./Toolchain")

local function norm(p: string): string
	return (p:gsub("\\", "/"))
end

local root = Toolchain.findRoot()
local args = process.args
if #args == 0 then
	print("usage: lune run tools/impact.luau <path-or-identifier> [--json]")
	process.exit(2)
end

local target = norm(args[1]):gsub("/+$", "")
local wantJson = false
for _, a in args do if a == "--json" then wantJson = true end end
local base = target:match("([^/]+)$") or target
local baseNoExt = base:gsub("%.luau$", "")
-- possible require-ish variants
local variants = { target, base, baseNoExt }
-- dedupe
local uniq: { [string]: boolean } = {}
local vList: { string } = {}
for _, v in variants do
	if not uniq[v] and v ~= "" then uniq[v] = true; table.insert(vList, v) end
end

local vendored = Toolchain.vendoredSet(root)
local files = Toolchain.sources(root) -- includes src/tools/tests minus vendored

local results: { { file: string, hits: number } } = {}
for _, f in files do
	local rel = Toolchain.relative(root, f)
	if rel == target then continue end -- skip self
	local ok, text = pcall(fs.readFile, f)
	if not ok or not text then continue end
	local hits = 0
	for _, v in vList do
		-- count occurrences (plain)
		local s = 1
		while true do
			local i = text:find(v, s, true)
			if not i then break end
			hits += 1
			s = i + #v
		end
	end
	if hits > 0 then table.insert(results, { file = rel, hits = hits }) end
end

-- sort by hits desc
table.sort(results, function(a, b) return a.hits > b.hits end)

if wantJson then
	print("[")
	for i, r in results do
		local comma = if i < #results then "," else ""
		print('  {"file":"' .. r.file .. '","hits":' .. tostring(r.hits) .. "}" .. comma)
	end
	print("]")
else
	print(`Impact for: {target}`)
	print(`  scanned: {#files} files, matches: {#results}`)
	for _, r in results do
		print(`  {r.hits}  {r.file}`)
	end
	if #results == 0 then print("  (no references found)") end
end

process.exit(0)