--!strict
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")
local Toolchain = require("./Toolchain")

local root = Toolchain.findRoot()
local refRoot = `{root}/docs/ref`

local clean = false
for _, a in process.args do if a == "--clean" then clean = true end end

if clean and fs.isDir(refRoot) then
	for _, entry in fs.readDir(refRoot) do
		local path = `{refRoot}/{entry}`
		if fs.isDir(path) then
			pcall(process.exec, "powershell", { "-Command", `Remove-Item -Recurse -Force '{path}'` })
		else
			pcall(fs.removeFile, path)
		end
	end
end

local INCLUDE_EXT = { md = true, mdx = true, yaml = true, yml = true, txt = true }
local function shouldInclude(name: string): boolean
	local ext = name:match("%.([^.]+)$")
	if not ext then return false end
	return INCLUDE_EXT[string.lower(ext)] == true
end

local function ensureDir(path: string)
	if fs.isDir(path) then return end
	local parts = Toolchain.split(path)
	local acc = ""
	for _, p in parts do
		acc = acc .. p .. "/"
		local trimmed = acc:gsub("/+$", "")
		if not fs.isDir(trimmed) then pcall(fs.writeDir, trimmed) end
	end
end

local function rawUrl(source: any, path: string): string
	return `https://raw.githubusercontent.com/{source.owner}/{source.repo}/{source.branch}/{path}`
end

local function apiList(source: any, path: string): { any }?
	local res = net.request({
		url = `https://api.github.com/repos/{source.owner}/{source.repo}/contents/{path}`,
		headers = { ["User-Agent"] = "lune-sync-docs", ["Accept"] = "application/vnd.github+json" },
	})
	if res.statusCode ~= 200 then return nil end
	local ok, data = pcall(function() return serde.decode("json", res.body) end)
	if not ok or type(data) ~= "table" then return nil end
	return data
end

local sources = {
	{ owner = "luau-lang", repo = "site", branch = "master", remoteRoot = "src/content/docs", localBase = "luau" },
	{ owner = "Roblox", repo = "creator-docs", branch = "master", remoteRoot = "content/en-us/luau", localBase = "roblox/luau" },
	{ owner = "Roblox", repo = "creator-docs", branch = "master", remoteRoot = "content/en-us/scripting", localBase = "roblox/scripting" },
	{ owner = "Roblox", repo = "creator-docs", branch = "master", remoteRoot = "content/en-us/reference/engine/classes", localBase = "roblox/api-classes" },
	{ owner = "Roblox", repo = "creator-docs", branch = "master", remoteRoot = "content/en-us/reference/engine/datatypes", localBase = "roblox/api-datatypes" },
	{ owner = "Roblox", repo = "creator-docs", branch = "master", remoteRoot = "content/en-us/reference/engine/globals", localBase = "roblox/api-globals" },
}

type Job = { source: any, remote: string, localPath: string }
local jobs: { Job } = {}

local function collect(source: any, remotePath: string, localPath: string)
	local entries = apiList(source, remotePath)
	if not entries then print(`WARN list {source.repo}/{remotePath}`); return end
	for _, entry in entries do
		local name = tostring(entry.name)
		if entry.type == "dir" then
			collect(source, `{remotePath}/{name}`, `{localPath}/{name}`)
		elseif entry.type == "file" and shouldInclude(name) then
			table.insert(jobs, { source = source, remote = tostring(entry.path), localPath = `{localPath}/{name}` })
		end
	end
end

for _, src in sources do
	print(`listing {src.owner}/{src.repo}: {src.remoteRoot}`)
	collect(src, src.remoteRoot, `{refRoot}/{src.localBase}`)
end

print(`jobs: {#jobs}`)

local CONCURRENCY = 12
local errors = 0
local files = 0
local i = 1
while i <= #jobs do
	local remaining = #jobs - i + 1
	local batch = math.min(CONCURRENCY, remaining)
	local done = 0
	for k = 1, batch do
		local job = jobs[i + k - 1]
		task.spawn(function()
			ensureDir(job.localPath:match("^(.*)/[^/]+$") :: string)
			local ok, r = pcall(function() return net.request(rawUrl(job.source, job.remote)) end)
			if not ok or r == nil then
				print(`WARN net {job.remote}: {tostring(r)}`)
				errors += 1
			elseif (r :: any).statusCode == 200 then
				fs.writeFile(job.localPath, (r :: any).body)
				files += 1
			else
				print(`WARN download {job.remote}: {(r :: any).statusCode}`)
				errors += 1
			end
			done += 1
		end)
	end
	while done < batch do task.wait() end
	i += batch
	if i % 100 == 1 then print(`progress {i-1}/{#jobs}`) end
end

print(`sync-docs done: files={files} errors={errors}`)
process.exit(0)