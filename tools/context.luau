--!strict
--- CLI for a compact pre-session context snapshot.
---
---   lune run tools/context.luau
---   lune run tools/context.luau --json

local Toolchain = require("./Toolchain")
local fs = require("@lune/fs")
local process = require("@lune/process")

local function hasBin(root: string, name: string): boolean
	return Toolchain.find(root, name) ~= nil
end

local args = process.args
local wantsJson = false
for _, a in args do
	if a == "--json" then wantsJson = true end
end

local root = Toolchain.findRoot()

local function runGit(sub: { string }): string
	local ok, res = pcall(process.exec, "git", sub, { cwd = root })
	if ok and res.ok then return res.stdout end
	return ""
end

local branch = (runGit({ "rev-parse", "--abbrev-ref", "HEAD" }):gsub("%s+$", ""))
local head = (runGit({ "rev-parse", "--short", "HEAD" }):gsub("%s+$", ""))
local statusOut = runGit({ "status", "--porcelain" })
local modified: { string } = {}
for line in statusOut:gmatch("[^\r\n]+") do
	if line ~= "" then table.insert(modified, line) end
end

local function countLuau(dir: string): number
	local c = 0
	local function walk(p: string)
		if not fs.isDir(p) then return end
		for _, e in fs.readDir(p) do
			local path = `{p}/{e}`
			if fs.isDir(path) then
				walk(path)
			elseif e:sub(-5) == ".luau" then
				c += 1
			end
		end
	end
	walk(dir)
	return c
end

local srcCount = countLuau(`{root}/src`)
local toolsCount = countLuau(`{root}/tools`)
local testsCount = countLuau(`{root}/tests`)

local function countLuauFiles(dir: string): number
	return countLuau(dir)
end
local skillCount = countLuauFiles(`{root}/src/server/skills`)
local specCount = countLuauFiles(`{root}/src/server/specs`)

if wantsJson then
	print("{")
	print(`  "root": "{root}",`)
	print(`  "branch": "{branch}",`)
	print(`  "head": "{head}",`)
	print(`  "modifiedCount": {#modified},`)
	print(`  "srcLuau": {srcCount},`)
	print(`  "toolsLuau": {toolsCount},`)
	print(`  "testsLuau": {testsCount},`)
	print(`  "skills": {skillCount},`)
	print(`  "specs": {specCount}`)
	print("}")
else
	print("PAC context")
	print(`  root:    {root}`)
	print(`  git:     {branch} @ {head}`)
	print(`  modified files: {#modified}`)
	for _, m in modified do
		print(`    {m}`)
	end
	print(`  sources: src={srcCount} luau, tools={toolsCount}, tests={testsCount}`)
	print(`  content: skills={skillCount}, specs={specCount}`)
	print("  tools:")
	for _, name in { "lune", "stylua", "luau-compile", "luau-lsp", "rojo" } do
		local status = if hasBin(root, name) then "ok" else "MISSING"
		print(`    {name}: {status}`)
	end
	print(
		"  note: run 'lune run tools/check.luau' for gates; 'lune run tools/run-tests.luau' for tests"
	)
end

process.exit(0)
