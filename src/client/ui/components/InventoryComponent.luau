const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const UserInputService = game:GetService("UserInputService")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const GameData = require(ReplicatedStorage.shared.schemas.GameData)
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Specs = require(ReplicatedStorage.shared.configs.Specs)
const Rarity = require(ReplicatedStorage.shared.configs.Rarity)

const Router = require(script.Parent.Parent.utils.Router)
const Content = require(script.Parent.Parent.views.Inventory.Content)
const AbilityView = require(script.Parent.Parent.views.Inventory.AbilityView)
const SubAbilityView = require(script.Parent.Parent.views.Inventory.SubAbilityView)
const SkinsView = require(script.Parent.Parent.views.Inventory.SkinsView)

const peek = Fusion.peek

type DefaultProps = {
	PlayerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	GameProxy: Proxy.ProxyTab<GameData.GameData>,
}

const function rarityColor(code: string): Color3
	const info = Rarity[code]
	return if info then info.Color else Color3.fromRGB(232, 232, 232)
end

return function(scope: Fusion.Scope, props: DefaultProps, router: Router.Router)
	const invScope = scope:innerScope()
	const playerProxy = props.PlayerProxy

	const activeTab = invScope:Value("Ability")
	const selected = invScope:Value("")

	const ownedSpecs = invScope:Value(table.clone(playerProxy().Specs))
	const ownedSkins = invScope:Value(table.clone(playerProxy().Skins))
	const equippedSkins = invScope:Value(table.clone(playerProxy().EquippedSkins))
	const equippedSpec = invScope:Value(playerProxy().Spec)
	const equippedSubSpec = invScope:Value(playerProxy().SubSpec)

	table.insert(
		invScope,
		playerProxy:Subscribe("AnyChange", { "Specs" }, function()
			ownedSpecs:set(table.clone(playerProxy().Specs))
		end)
	)
	table.insert(
		invScope,
		playerProxy:Subscribe("AnyChange", { "Skins" }, function()
			ownedSkins:set(table.clone(playerProxy().Skins))
		end)
	)
	table.insert(
		invScope,
		playerProxy:Subscribe("AnyChange", { "EquippedSkins" }, function()
			equippedSkins:set(table.clone(playerProxy().EquippedSkins))
		end)
	)
	table.insert(
		invScope,
		playerProxy:Subscribe("AnyChange", { "Spec" }, function()
			equippedSpec:set(playerProxy().Spec)
		end)
	)
	table.insert(
		invScope,
		playerProxy:Subscribe("AnyChange", { "SubSpec" }, function()
			equippedSubSpec:set(playerProxy().SubSpec)
		end)
	)

	const abilityCards = invScope:Computed(function(use)
		const cards = {}
		const worn = use(equippedSpec)
		for id, owned in use(ownedSpecs) do
			const info = Specs[owned.Name]
			if not info or info.Type == "SubSpec" then continue end

			cards[id] = {
				Name = info.DisplayName or owned.Name,
				SpecName = owned.Name,
				Icon = info.InventoryIcon or "",
				Description = info.Description or "",
				RarityColor = rarityColor(info.Rarity),
				Equipped = id == worn,
			}
		end
		return cards
	end)

	const subAbilityCards = invScope:Computed(function(use)
		const cards = {}
		const worn = use(equippedSubSpec)
		for id, owned in use(ownedSpecs) do
			const info = Specs[owned.Name]
			if not info or info.Type ~= "SubSpec" then continue end

			cards[id] = {
				Name = info.DisplayName or owned.Name,
				SpecName = owned.Name,
				Icon = info.InventoryIcon or "",
				Description = info.Description or "",
				RarityColor = rarityColor(info.Rarity),
				Equipped = id == worn,
			}
		end
		return cards
	end)

	const skinCards = invScope:Computed(function(use)
		const cards = {}
		const owned = use(ownedSpecs)
		const equipped = use(equippedSkins)
		for id, skin in use(ownedSkins) do
			const info = Specs[skin.Spec]
			if not info then continue end

			local specId
			for ownedId, ownedSpec in owned do
				if ownedSpec.Name == skin.Spec then
					specId = ownedId
					break
				end
			end

			cards[id] = {
				Name = skin.Id,
				SpecName = skin.Spec,
				Icon = info.InventoryIcon or "",
				Description = info.Description or "",
				RarityColor = rarityColor(info.Rarity),
				Equipped = specId ~= nil and equipped[specId] == skin.Id,
			}
		end
		return cards
	end)

	const function select(key: string)
		selected:set(key)
	end

	const function equipAbility(key: string)
		const card = peek(abilityCards)[key]
		if card then
			Crane:GetPacket("SetSpecSlot").send({ Slot = "Spec", SpecName = card.SpecName })
		end
	end

	const function equipSubAbility(key: string)
		const card = peek(subAbilityCards)[key]
		if card then
			Crane:GetPacket("SetSpecSlot").send({ Slot = "SubSpec", SpecName = card.SpecName })
		end
	end

	const function unequipSubAbility()
		Crane:GetPacket("SetSpecSlot").send({ Slot = "SubSpec", SpecName = nil })
	end

	const function equipSkin(key: string)
		const card = peek(skinCards)[key]
		if card then
			Crane:GetPacket("SetSkin").send({ SpecName = card.SpecName, SkinName = card.Name })
		end
	end

	const function unequipSkin(key: string)
		const card = peek(skinCards)[key]
		if card then
			Crane:GetPacket("SetSkin").send({ SpecName = card.SpecName, SkinName = nil })
		end
	end

	const function deleteSpec(key: string)
		Crane:GetPacket("DeleteItem").send({ Kind = "Spec", Id = key })
	end

	const function deleteSkin(key: string)
		Crane:GetPacket("DeleteItem").send({ Kind = "Skin", Id = key })
	end

	table.insert(
		invScope,
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed or input.KeyCode ~= Enum.KeyCode.M then return end

			const current = router.CurrentPage
			if current and current.Props.Name == "Inventory" then
				router:SwitchPage("PlayerHUD", nil)
			else
				router:SwitchPage("Inventory", nil)
			end
		end)
	)

	const pages = {
		Ability = AbilityView(invScope, {
			Cards = abilityCards,
			SelectedKey = selected,
			OnSelect = select,
			OnEquip = equipAbility,
			OnDelete = deleteSpec,
		}),
		SubAbility = SubAbilityView(invScope, {
			Cards = subAbilityCards,
			SelectedKey = selected,
			OnSelect = select,
			OnEquip = equipSubAbility,
			OnUnequip = unequipSubAbility,
			OnDelete = deleteSpec,
		}),
		Skins = SkinsView(invScope, {
			Cards = skinCards,
			SelectedKey = selected,
			OnSelect = select,
			OnEquip = equipSkin,
			OnUnequip = unequipSkin,
			OnDelete = deleteSkin,
		}),
	}

	return Content(invScope, {
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
	})
end
