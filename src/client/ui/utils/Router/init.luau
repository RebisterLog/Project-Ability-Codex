local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Buttler = require(script.Buttler)

local SwitchStyles = require(script.SwitchStyles)
local SwitchStyle = SwitchStyles.SwitchStyle

-- Fusion imports

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local Children = Fusion.Children

-- Types
export type SwitchStyle = SwitchStyles.SwitchStyle

export type UIFragment = Instance | { Instance } | () -> Instance | () -> { Instance }

export type PageProps<T = UIFragment, I = any> = {
	Name: string,
	Page: T,
	OnEnter: ((scope: Fusion.Scope, element: T, ...I) -> ())?,
	OnLeave: ((scope: Fusion.Scope, element: T) -> ())?,
}

type Page = {
	Props: PageProps,
	Scope: Fusion.Scope,
	Fragment: UIFragment,
	Cleaner: typeof(Buttler.new()),

	Enter: (self: Page, style: SwitchStyleProps, ...any) -> (),
	Leave: (self: Page, style: SwitchStyleProps) -> (),
}

type SwitchStyleProps = {
	style: SwitchStyle,
	duration: number,
	easingStyle: Enum.EasingStyle,
	easingDirection: Enum.EasingDirection,
	delayBetween: number,
}

export type Router = {
	RootScope: Fusion.Scope,

	CurrentPage: Page?,

	Pages: { [string]: Page },

	new: (scope: Fusion.Scope) -> Router,
	Render: (self: Router, startPage: string) -> { [string]: Instance },
	ProvidePage: (self: Router, props: PageProps) -> (),
	SwitchPage: <T>(self: Router, name: string, enterData: T, style: SwitchStyleProps?) -> (),
	ProvidePages: (self: Router, pages: { PageProps }) -> (),
}

-- Utils

local DefaultSwitchStyle: SwitchStyleProps = {
	style = SwitchStyle.Visibility,
	duration = 0,
	easingStyle = Enum.EasingStyle.Linear,
	easingDirection = Enum.EasingDirection.Out,
	delayBetween = 0,
}

-- Page class

local Page = {}
Page.__index = Page

function Page.new(pageScope: Fusion.Scope, props: PageProps)
	--- Fusion 0.3 принимает в `[Children]` только словарь: числовые ключи в таблице
	--- свойств он трактует как опечатку (`unrecognisedPropertyKey`). Страница может
	--- вернуть как одиночный инстанс, так и список, поэтому список приводится к
	--- словарю с именами-индексами, а одиночка заворачивается в `Fragment`.
	local fragment = if typeof(props.Page) == "function" then props.Page(pageScope) else props.Page
	local children: { [string]: any } = {}

	if fragment == nil then
		-- Пустая страница: `Children` без детей допустим.
	elseif fragment:IsA("Instance") then
		children.Fragment = fragment
	else
		for index, child in fragment do
			children[tostring(index)] = child
		end
	end

	local self = {
		Props = props,
		Scope = pageScope,

		Fragment = pageScope:New("CanvasGroup")({
			Name = props.Name,
			Size = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,

			[Children] = children,
		}),

		Cleaner = Buttler.new(),
	}

	setmetatable(self, Page)

	return self
end

function Page.Enter<T>(self: Page, style: SwitchStyleProps, data: T?)
	self.Cleaner:Clean()

	if self.Props.OnEnter then self.Props.OnEnter(self.Scope, self.Fragment, data) end

	local toClean = SwitchStyles.Animations[style.style].Enter(self.Fragment, style)

	if toClean then self.Cleaner:Add(toClean) end
end

function Page.Leave(self: Page, style: SwitchStyleProps)
	self.Cleaner:Clean()

	if self.Props.OnLeave then self.Props.OnLeave(self.Scope, self.Fragment) end

	local toClean = SwitchStyles.Animations[style.style].Leave(self.Fragment, style)

	if toClean then self.Cleaner:Add(toClean) end
end

function Page.Destroy(self: Page)
	self.Scope:doCleanup()
	self.Cleaner:Destroy()
end

-- Router class

local Router = {}
Router.__index = Router

function Router.SwitchPage<T>(self: Router, name: string?, enterData: T?, style: SwitchStyleProps?)
	if self.Pages[name] == self.CurrentPage then return end

	if name and not self.Pages[name] then error("Page with name " .. name .. " does not exist") end

	if self.CurrentPage then self.CurrentPage:Leave(style or DefaultSwitchStyle) end

	self.CurrentPage = nil

	if name then
		local page = self.Pages[name]
		page:Enter(style or DefaultSwitchStyle, enterData)
		self.CurrentPage = page
	end
end

function Router.ProvidePage(self: Router, props: PageProps)
	if self.Pages[props.Name] then
		error("Page with name " .. props.Name .. " already exists in this router")
	end

	local pageScope = self.RootScope:innerScope()

	self.Pages[props.Name] = Page.new(pageScope, props)
end

function Router.ProvidePages(self: Router, pages: { PageProps })
	for i, props in pages do
		self:ProvidePage(props)
	end
end

function Router.Render<T>(self: Router, startPage: string?, startPageData: T?)
	const pages = {}

	for name, page in self.Pages do
		pages[name] = page.Fragment

		if startPage and name == startPage then
			page:Enter(DefaultSwitchStyle, startPageData)
			self.CurrentPage = page
		else
			page:Leave(DefaultSwitchStyle)
		end
	end

	return pages
end

function Router.new(scope: Fusion.Scope, name: string?)
	local self = {
		RootScope = scope:innerScope(),
		Pages = {},
	}

	setmetatable(self, Router)

	return self
end

function Router.Destroy(self: Router)
	self.RootScope:doCleanup()
end

return Router :: Router
