const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const Rarity = require(ReplicatedStorage.shared.configs.Rarity)

const Button = require(script.Parent.Parent.utils.Button)
const Content = require(script.Parent.Parent.views.Inventory.Content)
const AbilityView = require(script.Parent.Parent.views.Inventory.AbilityView)
const SubAbilityView = require(script.Parent.Parent.views.Inventory.SubAbilityView)
const SkinsView = require(script.Parent.Parent.views.Inventory.SkinsView)

const controls = {
	ActiveTab = "Ability",
}

const story = {
	fusion = Fusion,
	controls = controls,

	story = function(props)
		const target = props.target

		const scope = Fusion.scoped(Fusion, {
			Button = Button,
		})
		table.insert(props.scope, function()
			Fusion.doCleanup(scope)
		end)

		const activeTab = props.controls.ActiveTab :: Fusion.Value<string>
		const selected = scope:Value("")

		const abilityCards = scope:Value({
			["standless"] = {
				Name = "Standless",
				SpecName = "Standless",
				Icon = "",
				Description = "<b>Standless</b>\nNo stand, no powers — just your own two hands.",
				RarityColor = Rarity.Common.Color,
				Equipped = true,
			},
			["star-platinum"] = {
				Name = "Star Platinum",
				SpecName = "StarPlatinum",
				Icon = "",
				Description = '<b>Star Platinum</b>\n<font color="rgb(199,154,75)">Legendary</font> stand with incredible precision.',
				RarityColor = Rarity.Legendary.Color,
				Equipped = false,
			},
			["the-world"] = {
				Name = "The World",
				SpecName = "TheWorld",
				Icon = "",
				Description = "<b>The World</b>\nStops time for everyone but its user.",
				RarityColor = Rarity.Mythic.Color,
				Equipped = false,
			},
		})

		const subAbilityCards = scope:Value({
			["jonathan-hamon"] = {
				Name = "Jonathan Hamon",
				SpecName = "JonathanHamon",
				Icon = "",
				Description = "<b>Jonathan Hamon</b>\nA secondary fighting style built on breath and speed.",
				RarityColor = Rarity.Rare.Color,
				Equipped = false,
			},
		})

		const skinCards = scope:Value({
			["pac-hamon"] = {
				Name = "PAC Hamon",
				SpecName = "JonathanHamon",
				Icon = "",
				Description = "<b>PAC Hamon</b>\nGolden aura for the Hamon user.",
				RarityColor = Rarity.Legendary.Color,
				Equipped = false,
			},
		})

		const function onSelect(key: string)
			selected:set(key)
		end

		const pages = {
			Ability = AbilityView(scope, {
				Cards = abilityCards,
				SelectedKey = selected,
				OnSelect = onSelect,
				OnEquip = function() end,
				OnDelete = function() end,
			}),
			SubAbility = SubAbilityView(scope, {
				Cards = subAbilityCards,
				SelectedKey = selected,
				OnSelect = onSelect,
				OnEquip = function() end,
				OnUnequip = function() end,
				OnDelete = function() end,
			}),
			Skins = SkinsView(scope, {
				Cards = skinCards,
				SelectedKey = selected,
				OnSelect = onSelect,
				OnEquip = function() end,
				OnUnequip = function() end,
				OnDelete = function() end,
			}),
		}

		const root = scope:New("Frame")({
			Name = "InventoryStory",
			BackgroundColor3 = Color3.fromRGB(32, 32, 32),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = target,

			[Fusion.Children] = {
				Content(scope, {
					ActiveTab = activeTab,
					Tabs = {
						Ability = { Label = "Ability", Order = 1 },
						SubAbility = { Label = "Sub-Ability", Order = 2 },
						Skins = { Label = "Skins", Order = 3 },
					},
					Pages = pages,
					OnTabClick = function(id: string)
						activeTab:set(id)
						selected:set("")
					end,
				}),
			},
		})

		return root
	end,
}

return story
