--!strict
--- Запуск всех наборов проверок ядра SkillConstructor и инструментов.
---
---   lune run tools/run-tests.luau
---
--- Каждый набор — отдельный процесс: его код возврата доезжает до вызывающего без
--- обёрток, а падение в одном наборе не мешает увидеть результаты остальных.
--- Код возврата ненулевой, если хотя бы один набор упал.

local process = require("@lune/process")

local SUITES = {
	{ name = "structural", path = "src/shared/packages/SkillConstructor/tests/structural.luau" },
	{ name = "codec", path = "src/shared/packages/SkillConstructor/tests/codec.luau" },
	{ name = "emitter", path = "src/shared/packages/SkillConstructor/tests/emitter.luau" },
	{
		name = "against-spec",
		path = "src/shared/packages/SkillConstructor/tests/against-spec.luau",
	},
	{ name = "json", path = "tools/tests/json.luau" },
}

local failed: { string } = {}

for _, suite in SUITES do
	local started, result = pcall(
		process.exec,
		"lune",
		{ "run", suite.path },
		{ cwd = process.cwd }
	)

	if not started then
		print(`FAIL {suite.name}: could not be started ({result})`)
		table.insert(failed, suite.name)
		continue
	end

	local outcome: { code: number, ok: boolean, stdout: string, stderr: string } = result

	-- Вывод набора печатается здесь, а не наследуется: `exec` перехватывает потоки.
	-- Хвостовой перевод строки убирается, иначе `print` добавит второй.
	print((outcome.stdout:gsub("\n$", "")))
	print((outcome.stderr:gsub("\n$", "")))

	if not outcome.ok then
		print(`FAIL {suite.name}: exit code {outcome.code}`)
		table.insert(failed, suite.name)
	else
		print(`ok {suite.name}`)
	end
end

print("")

if #failed > 0 then
	print(`FAILED: {table.concat(failed, ", ")}`)
	process.exit(1)
end

print(`OK: {#SUITES} suites passed`)

return 0
