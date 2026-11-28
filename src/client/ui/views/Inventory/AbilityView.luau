const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const TabView = require(script.Parent.TabView)

type UsedAs<T> = Fusion.UsedAs<T>

const AbilityView = function(
	scope: Fusion.Scope,
	props: {
		Cards: UsedAs<{ [string]: TabView.Card }>,
		SelectedKey: UsedAs<string>,
		OnSelect: (key: string) -> (),
		OnEquip: (key: string) -> (),
		OnDelete: (key: string) -> (),
	}
)
	return TabView(scope, {
		Cards = props.Cards,
		SelectedKey = props.SelectedKey,
		EquipLabel = "Equip",
		ShowUnequip = false,
		OnSelect = props.OnSelect,
		OnEquip = props.OnEquip,
		OnUnequip = function() end,
		OnDelete = props.OnDelete,
	})
end

return AbilityView
