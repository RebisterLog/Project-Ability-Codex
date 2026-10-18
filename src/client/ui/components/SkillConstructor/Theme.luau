--- `GothamSSm` из §10 недостижим: это семейство ассетов, а не элемент `Enum.Font`,
--- а объект `Font.new` Fusion 0.3 отклоняет проверкой типов (`expected a 'EnumItem'
--- type, but got a 'Font' type`). Поэтому берётся ближайший элемент перечисления:
--- Gotham — тот же шрифт в Regular-начертании. Расхождение зафиксировано в §10.
const FONT_FAMILY = Enum.Font.Gotham

--- Отступы кратны 4px, вложенность — 16px на уровень (§10).
const SPACING = {
	Tiny = 4,
	Small = 8,
	Medium = 16,
	Large = 24,
}

--- Геометрия плашек и дорожки.
---
--- Раньше блок занимал ровно один кадр: при зуме 4 это 4px, и подпись в нём
--- не помещалась. Теперь у плашки есть минимальная ширина — она держит
--- читаемую подпись, а кадровая шкала влияет на блоки с диапазоном (`Repeat`)
--- и на расстояние между плашками.
const METRICS = {
	RowHeight = 34,
	SlotHeight = 16,
	HandleWidth = 10,
	TimelinePadding = 8,
	RulerHeight = 18,
	ChipMinWidth = 110,
	ChipHeight = 34,
}

--- 6px блокам, 4px кнопкам (§10).
const RADIUS = {
	Block = 6,
	Button = 4,
}

--- 0.15s, `Enum.EasingStyle.Quad` (§10).
const TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--- Зоны клика не меньше 28px (§10, доступность).
const MIN_CLICK = 28

const COLORS = {
	Background = Color3.fromRGB(18, 18, 20),
	Surface = Color3.fromRGB(28, 28, 32),
	SurfaceAlt = Color3.fromRGB(36, 36, 42),
	Outline = Color3.fromRGB(56, 56, 64),
	Text = Color3.fromRGB(236, 236, 240),
	TextMuted = Color3.fromRGB(138, 138, 150),
	Accent = Color3.fromRGB(79, 195, 247),
	AccentSoft = Color3.fromRGB(38, 62, 82),
	Error = Color3.fromRGB(239, 83, 80),
	Warning = Color3.fromRGB(255, 167, 38),
	Success = Color3.fromRGB(38, 166, 154),
	WarningBorder = Color3.fromRGB(255, 202, 40),
}

--- `#RRGGBB` → `Color3`.
---
--- Реестр хранит цвета категорий строками (§3, §10), потому что сам остаётся
--- независимым от Roblox-типов; в UI они уже настоящие цвета. Разбор ручной, без
--- `Color3.fromHex`, чтобы не зависеть от версии Roblox-движка.
const hexToColor3 = function(hex: string): Color3
	const cleaned = string.gsub(hex, "^#", "")
	const r = tonumber(string.sub(cleaned, 1, 2), 16) or 255
	const g = tonumber(string.sub(cleaned, 3, 4), 16) or 255
	const b = tonumber(string.sub(cleaned, 5, 6), 16) or 255
	return Color3.fromRGB(r, g, b)
end

return {
	Font = FONT_FAMILY,
	Spacing = SPACING,
	Radius = RADIUS,
	Metrics = METRICS,
	Tween = TWEEN,
	MinClick = MIN_CLICK,
	Colors = COLORS,
	hexToColor3 = hexToColor3,
}
