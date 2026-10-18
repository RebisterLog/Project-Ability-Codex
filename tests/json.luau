--!strict
--- Tests for the `tools/json.luau` codec.
---
---   lune run tests/json.luau
---
--- What is covered is what the app emits and the CLI reads: array versus object,
--- key sorting, integers with no fractional part, the `decode(encode(x))` round
--- trip, and a refusal to encode a cyclic table.

local json = require("../tools/json")

local passed = 0
local failures: { string } = {}

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		return
	end

	table.insert(failures, if detail ~= nil then `{name}: {detail}` else name)
end

local function equal(name: string, actual: any, expected: any)
	check(name, actual == expected, `expected {tostring(expected)}, got {tostring(actual)}`)
end

-- DECODE --------------------------------------------------------------------

do
	local value = json.decode('{"a":1,"b":[true,null,2.5],"c":{"d":"e"}}')
	equal("decode: number", value.a, 1)
	equal("decode: nested bool", value.b[1], true)
	equal("decode: array keeps null position", tostring(value.b[2]), "null")
	equal("decode: fractional", value.b[3], 2.5)
	equal("decode: nested object", value.c.d, "e")
end

do
	local value = json.decode('{"a":null,"b":1}')
	check("decode: null key is dropped, not nil-valued", value.a == nil and value.b == 1)
end

do
	local value = json.decode("[1,2,3]")
	check("decode: top-level array", #value == 3 and value[1] == 1 and value[3] == 3)
end

do
	local value = json.decode('"a\\nb\\u0041"')
	equal("decode: escapes", value, "a\nbA")
end

do
	local value = json.decode("[-1.5e2,0,12345678901234]")
	equal("decode: exponent", value[1], -150)
	equal("decode: zero", value[2], 0)
	equal("decode: long integer", value[3], 12345678901234)
end

do
	local ok = pcall(json.decode, "{} trailing")
	check("decode: rejects trailing content", not ok)
end

do
	local ok = pcall(json.decode, "{bad}")
	check("decode: rejects unquoted key", not ok)
end

-- ENCODE --------------------------------------------------------------------

equal("encode: nil", json.encode(nil), "null")
equal("encode: true", json.encode(true), "true")
equal("encode: false", json.encode(false), "false")
equal("encode: string", json.encode("hi"), '"hi"')
equal("encode: quote escape", json.encode('a"b'), '"a\\"b"')
equal("encode: backslash escape", json.encode("a\\b"), '"a\\\\b"')
equal("encode: newline escape", json.encode("a\nb"), '"a\\nb"')
equal("encode: tab escape", json.encode("a\tb"), '"a\\tb"')
equal("encode: control escape", json.encode("\1"), '"\\u0001"')
equal("encode: utf8 kept raw", json.encode("Привет"), '"Привет"')

do
	equal("encode: integer stays integral", json.encode(15), "15")
	equal("encode: negative integer", json.encode(-3), "-3")
	equal("encode: zero", json.encode(0), "0")
	equal("encode: fraction", json.encode(0.5), "0.5")
	equal("encode: inf", json.encode(math.huge), "null")
	equal("encode: nan", json.encode(0 / 0), "null")
end

do
	equal("encode: array", json.encode({ 1, 2, 3 }), "[1,2,3]")
	equal("encode: empty array", json.encode({}), "[]")
	equal("encode: object", json.encode({ b = 1, a = 2 }), '{"a":2,"b":1}')
	equal("encode: empty object stays object", json.encode({ n = 1 }), '{"n":1}')
	equal("encode: nested", json.encode({ a = { b = { 1, 2 } } }), '{"a":{"b":[1,2]}}')
end

--- An empty array and an empty object are indistinguishable in Luau, so context
--- decides: `Children` and `Properties` are read as tables, where an empty object
--- is correct, but `{}` cannot be told apart from `[]`. Check that the choice
--- falls to the array.
equal("encode: empty table becomes array", json.encode({}), "[]")

do
	local sparse = { [1] = "a", [3] = "c" }
	local text = json.encode(sparse)
	check("encode: sparse table becomes object", string.find(text, '"3"') ~= nil, text)
end

do
	-- The table type is declared explicitly: without it the array infers as
	-- `{number}`, and the `NULL` sentinel does not fit inside it.
	local nulled: { any } = { 1, json.NULL, 3 }
	equal("encode: NULL sentinel", json.encode(nulled), "[1,null,3]")
end

do
	local shared = { x = 1 }
	local value = { a = shared, b = shared }
	local ok, text = pcall(json.encode, value)
	check("encode: shared table is not a cycle", ok, tostring(text))
end

do
	local cyclic: { [any]: any } = {}
	cyclic.self = cyclic
	local ok = pcall(json.encode, cyclic)
	check("encode: rejects cycle", not ok)
end

do
	local deep: { [string]: any } = {}
	local cursor = deep
	for _ = 1, 300 do
		local node: { [string]: any } = {}
		cursor.next = node
		cursor = node
	end
	local ok = pcall(json.encode, deep)
	check("encode: rejects excessive nesting", not ok)
end

-- JSON ROUNDTRIP ------------------------------------------------------------

do
	local original = {
		Id = "FirePunch",
		Cooldown = 3,
		Active = true,
		AnimationSlots = { { Id = "a1", Name = "Punch", Speed = 1 } },
		Blocks = {
			{
				Id = "blk_01",
				Type = "Hitbox",
				StartFrame = 0,
				Properties = {
					Size = { ["$"] = "V3", x = 7, y = 7, z = 7 },
					Origin = { ["$"] = "CF", px = 0, py = 0, pz = -3, rx = 0, ry = 0, rz = 0 },
				},
			},
		},
	}

	local text = json.encode(original, { pretty = true })
	local back = json.decode(text)

	equal("roundtrip: Id", back.Id, "FirePunch")
	equal("roundtrip: integer cooldown", back.Cooldown, 3)
	equal("roundtrip: boolean", back.Active, true)
	equal("roundtrip: nested array length", #back.AnimationSlots, 1)
	equal("roundtrip: Vector3 x", back.Blocks[1].Properties.Size.x, 7)
	equal("roundtrip: CFrame pz", back.Blocks[1].Properties.Origin.pz, -3)
	--- `EndFrame` is absent on purpose: a `null` inside an object does not
	--- survive decoding — the very contract by which `codec.encode` drops
	--- `nil` fields. An unfilled field and a missing value are indistinguishable
	--- deliberately, otherwise `null` properties would leak into emitted code.
	check("roundtrip: absent optional field stays absent", back.Blocks[1].EndFrame == nil)

	local again = json.encode(back, { pretty = true })
	equal("roundtrip: encode is idempotent", again, text)

	check(
		"encode: pretty output is indented",
		string.find(text, "\n  ") ~= nil,
		"expected a two-space indent"
	)
end

print(`[tests.json] passed: {passed}, failed: {#failures}`)

if #failures > 0 then error(table.concat(failures, "\n"), 0) end

return { passed = passed, failed = #failures }
