---
name: create-ui-element
description: Use when the user asks to create or add a new UI element/widget to the Sky Race Roblox project from raw Fusion UI code. Trigger words: "уи элемент", "новый UI", "UI элемент", "добавить элемент интерфейса", "Fusion компонент", "Component/View", "вьюшка", "story", "UI Labs". Splits raw Fusion code into a Component (logic: proxy subscriptions, packets, Router) and a View (pure Fusion markup), registers the widget in src/client/ui/main.luau, and optionally generates a UI Labs .story test file for visual layout testing. Use ONLY for this project's UI layer (src/client/ui); do not use for gameplay logic, services, server code, or plugins.
---

# Creating a UI Element (Sky Race standard)

The Sky Race UI is built on **Fusion 0.3** (reactive UI) inside the **Crane** framework. Every UI element is split into two modules:

- **Component** (`src/client/ui/components/<Name>Component.luau`) — logic: reads `playerProxy` / `gameProxy` via Proxy subscriptions, sends Crane packets, observes `currentPage`, and passes reactive `props` down to a View.
- **View** (`src/client/ui/view/<Name>View.luau`) — pure visual markup in Fusion: takes `(scope, props)`, returns instance(s), animates via `scope:Tween/Spring`, `scope:Observer`, and shared utils (`Button`, `Shadow`, `MixedText`).

## 0. Input contract and mandatory clarification

Input is the raw Fusion UI code the user pastes (a function returning instances, or a fragment). It may also include: animations, which page/widget the element belongs to, which proxy fields it reacts to, and whether it is a full page or a persistent widget.

**If the user did NOT specify animations, ask first** using the `question` tool (never silently pick). Offer at least these dimensions:

- появление (appearance / open)
- закрытие (closing)
- активация (activation / click)
- наведение (hover)
- потеря фокуса (focus loss)
- no animations

Present the catalog from §5 as concrete options. Ask once, then proceed. Also ask (if unknown) whether the element is a **page** (Router) or a **persistent widget** (always mounted in `main.luau`), since this changes the wiring.

## 1. Project layout (exact paths)

```
src/client/ui/
├── main.luau              <- THE render tree. Add new widgets here (NOT newMain.luau).
├── newMain.luau           <- Router-based alternative. DO NOT TOUCH.
├── components/            <- <Name>Component.luau — logic layer.
├── view/                  <- <Name>View.luau — visual layer (pure Fusion).
│   ├── Storage/           <- sub-views for the Storage pages (group by folder).
│   └── StorageControlsView/ ...
├── utils/                 <- Button, Shadow, MixedText, LoadingFrame, Router/.
└── stories/               <- UI Labs *.story.luau test files (currently empty).
```

Require paths used across the project:

- `ReplicatedStorage.shared.packages.Fusion`
- `ReplicatedStorage.shared.packages.Proxy`
- `ReplicatedStorage.shared.schemas.PlayerData` / `GameData` (and `PlayerSaveData` / `PlayerDynamicData`)
- `ReplicatedStorage.shared.packages.Crane`
- Views from components: `StarterPlayer.StarterPlayerScripts.client.ui.view.<Name>` (VotingComponent style) or relative `script.Parent.Parent.view.<Name>` (StorageComponent style). Prefer relative paths (`script.Parent.Parent.view.<Name>`) since both files live under `src/client/ui/`.
- Utils from components/views: `script.Parent.Parent.utils.Button` etc.

## 2. Canonical reference files

Before writing code, read these files in the repo — they are the source of truth for conventions:

| File | What it demonstrates |
|---|---|
| `src/client/ui/main.luau` | Render tree, `scoped(Fusion, {Button, Shadow, MixedText, LoadingFrame})`, component call order, `currentPage` wiring |
| `src/client/ui/components/VotingComponent.luau` | Full loop: proxy subscribe → `Value` state → view props → packet send |
| `src/client/ui/view/VotingView.luau` | Full view: `Shadow`, `Button`, `MixedText`, `Spring`, `ForPairs`, `Observer:onBind`, `TweenInfo` constants |
| `src/client/ui/components/StorageComponent.luau` | Router sub-pages integration (`ProvidePages`/`Render`/`SwitchPage`), `innerScope`, `currentPage` toggle |
| `src/client/ui/components/StatsHudComponent.luau` | Proxy subscriptions + `Computed` formatting |
| `src/client/ui/components/Sample.luau` / `view/Sample.luau` | Official skeletons (see §9) |

### Standard import idiom (copy verbatim, matches every file)

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")   -- only if tweening

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local peek = require(ReplicatedStorage.shared.packages.Fusion.State.peek)  -- optional; usually shadowed below

local Children = Fusion.Children
local peek = Fusion.peek
local OnEvent = Fusion.OnEvent
local OnChange = Fusion.OnChange
type UsedAs<T> = Fusion.UsedAs<T>
```

Note: existing files redundantly require `OnEvent`/`peek` from sub-modules AND re-export from `Fusion`. Keep this idiom as-is when editing existing files; for new files the compact idiom above is sufficient. Use `--!strict` only if the file you are editing already has it (most views/components do not — match the neighbor files, no pragmas by default).

## 3. Proxy cheatsheet

Source of truth: `src/shared/packages/Proxy.luau`. Proxies are created in `src/client/services/PlayerService.luau` and passed to `main.luau` as `(playerProxy, gameProxy)`.

### API

- `Proxy(t)` → `proxy` (deep-copies `t`; calling `proxy()` returns the live source table).
- `proxy:Subscribe(instruction, path, callback) -> CleanupFunction` — path is `{string}`.
- `proxy:Patch(instructions)` — batch of `{ Name = ..., Path = {string}, Args = {...} }` (client normally only listens; patches arrive via the `Patch` packet in `PlayerService`).
- `proxy:OnPatch(callback)` — global post-patch hook.

### Patch instruction names

| Instruction | Effect | Callback args |
|---|---|---|
| `ChangeValue` | set primitive at path | `newValue, oldValue` |
| `InsertArray` | insert into array at path | `value, index` |
| `RemoveArray` | remove by index | `index, oldValue` |
| `SetDictionary` | set dict key | `key, newValue, oldValue` |
| `RemoveDictionary` | remove dict key | `key, oldValue` |
| `Clear` | clear table / reset primitive | `oldValue` |
| `AnyChange` | fires for the exact key or any nested key under it | same as underlying instruction |

### Subscription pattern (from real code)

```lua
local money = scope:Value(playerProxy().Money)

table.insert(scope, playerProxy:Subscribe("ChangeValue", {"Money"}, function(newValue)
	money:set(newValue)
end))
```

Use `"AnyChange"` for list/dict fields where the exact nested instruction is unknown:

```lua
table.insert(scope, playerProxy:Subscribe("AnyChange", {"Accessories"}, function()
	list:set(playerProxy().Accessories)
end))
```

### Proxy path table (PlayerData = PlayerDynamicData + PlayerSaveData; GameData)

| Path (array) | Type | Schema |
|---|---|---|
| `{"Checkpoint"}` | number | PlayerDynamicData |
| `{"InRace"}` | boolean | PlayerDynamicData |
| `{"WinStreak"}` | number | PlayerDynamicData |
| `{"LastPlaceOnRace"}` | number | PlayerDynamicData |
| `{"AFK"}` | boolean | PlayerSaveData |
| `{"Money"}`, `{"Robux"}`, `{"Wins"}`, `{"PlayTime"}`, `{"Level"}`, `{"LevelExp"}` | number | PlayerSaveData |
| `{"EquippedStarter"}`, `{"EquippedFinisher"}`, `{"EquippedTitle"}`, `{"EquippedPackName"}` | string | PlayerSaveData |
| `{"EquippedPacks", "<Element>"}` | string (PackName) | PlayerSaveData |
| `{"LootPacks", "<PackName>"}` | number (count) | PlayerSaveData |
| `{"Packs"}`, `{"Accessories"}`, `{"EquippedAccessories"}`, `{"Trails"}`, `{"EquippedTrails"}`, `{"Auras"}`, `{"EquippedAuras"}`, `{"Titles"}`, `{"Finishers"}`, `{"Startes"}` | `{string}` | PlayerSaveData |
| `{"Emotes"}`, `{"EquippedEmotes"}` | `{{string}}` (nested!) | PlayerSaveData |
| `{"Settings","HideOtherPlayers"}`, `{"Settings","HideOtherPlayersEmotes"}`, `{"Settings","HideOtherPlayersPacks"}`, `{"Settings","Effects"}`, `{"Settings","HideUI"}` | boolean | PlayerSaveData |
| `{"Settings","Time"}`, `{"Settings","Weather"}` | string | PlayerSaveData |
| `{"ClaimedLevelRewards", <number>}` | boolean | PlayerSaveData |
| `{"DailyTasks","LastResetDate"}` | string | PlayerSaveData |
| `{"DailyTasks","Tasks"}` | `{{TrueName, progress, completed}}` | PlayerSaveData |
| `{"Voting","Votes"}`, `{"Voting","Votes",<i>,"Name"}`, `{"Voting","Votes",<i>,"Votes"}` | `{VoitingMap}` / string / number | GameData |
| `{"Voting","EndTime"}` | number? (`os.time()`) | GameData |
| `{"CurrentMap"}`, `{"ServerRegion"}` | string | GameData |
| `{"InRacePlayers"}`, `{"FinishedPlayers"}`, `{"FinishedPlayersStreaks"}` | `{number}` | GameData |
| `{"RaceStartTime"}`, `{"GlobalTimer"}` | number | GameData |

Rules of thumb:

- Arrays (`Packs`, `Emotes`, `InRacePlayers`, ...) are mutated with `InsertArray`/`RemoveArray` — subscribe with `"AnyChange"` (or `"ChangeValue"` if you must know the exact index).
- Dictionaries (`EquippedPacks`, `LootPacks`, `Settings`, `ClaimedLevelRewards`) are mutated with `SetDictionary`/`RemoveDictionary`; a `"ChangeValue"` on `{"LootPacks","Gold"}` is a valid keyed path too.
- Numeric indices in paths are literal numbers in the array: `{"Voting","Votes",1,"Votes"}`.
- The schema contains the typo `Startes` — use it exactly as written.
- Never guess a path: read `src/shared/schemas/PlayerSaveData.luau`, `PlayerDynamicData.luau`, `GameData.luau` before wiring subscriptions.

## 4. Router cheatsheet

Source of truth: `src/client/ui/utils/Router/init.luau` and `SwitchStyles.luau`. Used for **page/sub-page systems** (see `StorageComponent`), NOT for persistent widgets.

### API

- `Router.new(scope)` → `router` (internally `scope:innerScope()`).
- `router:ProvidePage(props: PageProps)` — `PageProps = { Name: string, Page: Instance | {Instance} | (self: Page) -> UIFragment, OnEnter?, OnLeave? }`.
- `router:ProvidePages({ PageProps })` — register several at once.
- `router:Render(startPageName?)` → `{[string]: Instance}` — call ONCE, parent the returned map into your tree.
- `router:SwitchPage(name?, enterData?, style?)` — `name = nil` leaves the current page.
- Style: `{ style = SwitchStyles.SwitchStyle.X, duration, easingStyle, easingDirection, delayBetween, delay }`.

`SwitchStyle` enum: `Visibility` (instant), `Transparency` (fade), `CardsUp` / `CardsDown` (vertical slide), `Gallery` (horizontal slide).

### Canonical wiring (StorageComponent pattern)

```lua
local router = Router.new(storScope)
router:ProvidePages({
	{
		Name = "Accessories",
		Page = AccessoriesView(storScope, { IsShown = Items.Accessories.IsShown, ... }),
		OnEnter = function()
			Items.Accessories.IsShown:set(true)
			storagePage:set("Accessories")
		end,
		OnLeave = function()
			Items.Accessories.IsShown:set(false)
		end,
	},
})
local pages = router:Render()
```

Then `router:SwitchPage(name, nil, TAB_SWITCH_STYLE)` to navigate.

### `currentPage` pattern (for persistent widgets in main.luau)

- `main.luau` owns `local currentPage = scope:Value("None")` and passes it to widgets.
- Toggle: `if peek(currentPage) == name then currentPage:set("None") else currentPage:set(name) end`.
- Widgets watch it: `scope:Observer(currentPage):onChange(function() ... end)` and derive `IsShown`.

## 5. Animation catalog (standard)

- **Open/close of a big widget**: `scope:Shadow(props.IsShown, frame)` — cinematic shadow + content reveal (VotingView, StorageControlsView). Use `TweenService` under the hood; it handles shadow gradients and list-item scaling.
- **Buttons (hover + click + sound)**: `scope:Button(guiButton)` — scale-up on hover, icon rotation, `UI_Button` sounds from `SoundService`. Apply to every `ImageButton`/`TextButton`.
- **Text reveal**: `scope:MixedText(isActive, textLabel)` — random-character "mixing" reveal.
- **Property motion**: `scope:Tween(stateObject, TweenInfo)` or `scope:Spring(target, speed, damping)` for reactive values.
- **Side effects on visibility**: `scope:Observer(isShown):onBind(function() ... end)` — play tweens imperatively when shown/hidden.
- **Constants**: define named `TweenInfo` at the top of the file (`local SHOW_STYLE = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)`).

Defaults used by the project: buttons via `Button` util; modal-like widgets via `Shadow`; text headers via `MixedText`; quick fades via `Tween` on `Transparency`/`Position`. If the user gives no specifics, ask per §0; if they say "standard", apply the catalog defaults above.

## 6. Crane integration

Source of truth: `src/shared/packages/Crane/init.luau` (full `--[=[ ]=]` docs embedded), `Packets.luau`, and services in `src/client/services/`.

- `Crane:CreateService({ Name, LoadOrder? })` with `onInit`/`onStart`; `Crane:GetService("Name")`.
- Packets: `Crane:GetPacket("Name").send(data)` / `.listen(callback)`. Available packets (from `Packets.luau`): `RequestProxy`, `Patch`, `StartVFX`, `StopVFX`, `RequestParkourVFX`, `Vote`, `AFK`, `ObstacleHit`, `ChangeCharacter`, `SpectatePlayer`, `InventoryItem`, `PackResult`, `ClaimLevelReward`, `ChangeVisualSetting`, `PlayEmote`, `StopEmote`. Queries: `Crane:GetQuery("Name")`.
- Configs: `Crane:GetService("ConfigService"):Get("Maps")` (see `VotingComponent`). Config modules live in `src/shared/configs/`.
- The proxies come from `PlayerService` (`PlayerService.Proxy`, `PlayerService.GameProxy`); `UIService` requires the `UIStartPoint` module (→ `main.luau`) with those two proxies. Components must never re-create proxies.

## 7. Registering in main.luau

Edit `src/client/ui/main.luau` ONLY (never `newMain.luau`):

1. Add the require alongside the other components:
   `local NameComponent = require(script.Parent.components.NameComponent)`
2. Add the call inside the ScreenGui `[Children]` list:
   `NameComponent(scope, playerProxy, gameProxy, currentPage),`
3. Keep the argument order `(scope, playerProxy, gameProxy, currentPage?)`. Pass `currentPage` only if the widget uses the page-toggle pattern; some widgets (e.g. `CountdownComponent`, `RaceFinishComponent`) don't take it.
4. Match the placement of the widget in the `[Children]` order by visual stacking need.

## 8. UI Labs story (optional test file)

Docs: https://ui-labs.luau.page/docs/stories/advanced/fusion (Fusion 0.3: `props.scope` is auto-cleaned, `props.controls` are `Fusion.Value`s, returning the root instance is optional).

Rules:

- File goes to `src/client/ui/stories/<Name>.story.luau`. In Rojo the ModuleScript name ends with `.story`, so UI Labs auto-discovers it. Never `require` story files from game code.
- Story table: `{ fusion = Fusion, controls = {...}, story = function(props) ... end }`.
- If the View uses custom scope constructors (`Button`, `Shadow`, `MixedText`), add `scoped = { Button = require(script.Parent.Parent.utils.Button), Shadow = ..., MixedText = ... }` to the story table so `props.scope` gains them (UI Labs calls `Fusion.scoped(Fusion, ...scoped)`).
- Mocks instead of proxies: plain tables wrapped in `scope:Value(...)` / `scope:Computed(...)`; callbacks are stubs.
- Parent everything under `props.target`.

### Filled template

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)

local Button = require(script.Parent.Parent.utils.Button)
local Shadow = require(script.Parent.Parent.utils.Shadow)
local MixedText = require(script.Parent.Parent.utils.MixedText)

local NameView = require(script.Parent.Parent.view.NameView)

local controls = {
	IsShown = true,
}

local story = {
	fusion = Fusion,
	scoped = {
		Button = Button,
		Shadow = Shadow,
		MixedText = MixedText,
	},
	controls = controls,

	story = function(props)
		local scope = props.scope
		local target = props.target

		local isShown = props.controls.IsShown :: Fusion.Value<boolean>

		local mockList = scope:Value({ "Item1", "Item2", "Item3" })

		local view = NameView(scope, {
			IsShown = isShown,
			List = mockList,
			-- Static props pass through directly, reactive props use
			-- scope:Value()/scope:Computed(), proxy data becomes mock tables.
			OnClose = function()
				isShown:set(false)
			end,
		})

		local root = scope:New "Frame" {
			Name = "NameStory",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = target,

			[Fusion.Children] = { view },
		}

		return root
	end,
}

return story
```

## 9. Skeletons (start from these)

### Component — `src/client/ui/components/<Name>Component.luau`

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)
local PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
local GameData = require(ReplicatedStorage.shared.schemas.GameData)

local Children = Fusion.Children
local peek = Fusion.peek
type UsedAs<T> = Fusion.UsedAs<T>

local NameView = require(script.Parent.Parent.view.NameView)

local function NameComponent(
	scope: Fusion.Scope,
	playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	gameProxy: Proxy.ProxyTab<GameData.GameData>,
	currentPage: UsedAs<string>?
)
	local nameScope = scope:innerScope()

	local isShown = nameScope:Value(false)
	local list = nameScope:Value(playerProxy().Accessories)

	table.insert(nameScope, playerProxy:Subscribe("AnyChange", {"Accessories"}, function()
		list:set(playerProxy().Accessories)
	end))

	if currentPage then
		nameScope:Observer(currentPage):onChange(function()
			isShown:set(peek(currentPage) == "Name")
		end)
	end

	return NameView(nameScope, {
		IsShown = isShown,
		List = list,
		OnClose = function()
			if currentPage then currentPage:set("None") end
		end,
	})
end

return NameComponent
```

### View — `src/client/ui/view/<Name>View.luau`

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)

local Children = Fusion.Children
local peek = Fusion.peek
local OnEvent = Fusion.OnEvent
type UsedAs<T> = Fusion.UsedAs<T>

local SHOW_STYLE = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local function NameView(
	scope: Fusion.Scope,
	props: {
		IsShown: UsedAs<boolean>,
		List: UsedAs<{string}>,
		OnClose: () -> (),
	}
)
	return scope:Shadow(props.IsShown, scope:New "Frame" {
		Name = "Name",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),

		[Children] = {
			-- visual markup; every GuiButton goes through scope:Button(...)
			-- dynamic text/images go through scope:Computed(...)
		}
	})
end

return NameView
```

## 10. Verification checklist

- Requires are valid and relative paths resolve; `default.project.json` needs no changes (Rojo maps whole folders).
- Signature order everywhere: Component `(scope, playerProxy, gameProxy, currentPage?)`, View `(scope, props)`.
- Every `proxy:Subscribe` cleanup / `task.delay` is inserted into a scope (`table.insert(scope, ...)`) so it is cleaned with `innerScope()`.
- Views contain zero references to `Proxy`, `Crane`, schemas, or Components; Components contain no heavy visual markup.
- All instances in the UI tree are created with `scope:New` (never bare `Fusion.New`/`Instance.new`); nothing sets `Parent = PlayerGui` inside views (only `LoadingFrame` util wraps a `ScreenGui`).
- Buttons are wrapped in `scope:Button(...)`; big show/hide flows use `scope:Shadow(...)` unless otherwise specified.
- `TweenInfo` values are named constants at the top of the file.
- `currentPage` toggles to `"None"`; `"None"` is the default page in `main.luau`.
- If a story was generated: file ends in `.story.luau`, lives in `stories/`, mocks all proxy-backed props, and the story table includes `scoped` when the View uses custom constructors.
- Syntax check: `rojo build -o "Sky Race.rbxlx"` (optional; builds the place and catches Luau syntax errors).

## 11. Documentation (read for accuracy)

Local (authoritative for this repo):

- `src/client/ui/main.luau`, `src/client/ui/components/Sample.luau`, `src/client/ui/view/Sample.luau`
- `src/client/ui/components/VotingComponent.luau`, `src/client/ui/view/VotingView.luau`
- `src/client/ui/components/StorageComponent.luau`, `src/client/ui/view/StorageControlsView/init.luau`
- `src/client/ui/utils/Router/init.luau`, `src/client/ui/utils/Router/SwitchStyles.luau`, `Button.luau`, `Shadow.luau`, `MixedText.luau`, `LoadingFrame.luau`
- `src/shared/packages/Proxy.luau`
- `src/shared/packages/Crane/init.luau`, `Component.luau`, `Service.luau`, `Packets.luau`
- `src/shared/packages/Fusion/init.luau` (exported API list, version 0.3.0)
- `src/shared/schemas/PlayerSaveData.luau`, `PlayerDynamicData.luau`, `GameData.luau`
- `src/client/services/PlayerService.luau` (proxy origin), `src/client/services/UIService.luau` (UI entry)

External:

- Fusion 0.3 documentation: https://elttob.uk/Fusion/0.3/
- UI Labs Fusion stories: https://ui-labs.luau.page/docs/stories/advanced/fusion
- UI Labs story basics: https://ui-labs.luau.page/docs/stories/create
- UI Labs storybooks: https://ui-labs.luau.page/docs/storybooks

## 12. Negative rules (style constraints)

- Never edit `src/client/ui/newMain.luau`, `src/client/Main/*`, or `Configuration/UIStartPoint`.
- Do not add the widget to anything other than `main.luau`'s ScreenGui `[Children]` (unless the user explicitly asks for a Router page — then it belongs inside a component like `StorageComponent`).
- Views must not require `Proxy`, `Crane`, schemas, components, or other views that aren't sub-views of the same element.
- Do not create duplicate/parallel systems: reuse `Button`, `Shadow`, `MixedText`, `Router`, `LoadingFrame` instead of inventing new utils, unless the user asks.
- Do not hardcode asset ids / strings / colors that were not given in the input; if the raw code contains them, preserve them exactly.
- No code comments in generated Luau files (matches repo style).
- Keep the generated code minimal and consistent with the canonical files; do not "improve" the project's existing architecture.
