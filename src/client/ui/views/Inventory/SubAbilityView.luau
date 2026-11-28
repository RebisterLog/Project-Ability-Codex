const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const TabView = require(script.Parent.TabView)

type UsedAs<T> = Fusion.UsedAs<T>

const SubAbilityView = function(
	scope: Fusion.Scope,
	props: {
		Cards: UsedAs<{ [string]: TabView.Card }>,
		SelectedKey: UsedAs<string>,
		OnSelect: (key: string) -> (),
		OnEquip: (key: string) -> (),
		OnUnequip: (key: string) -> (),
		OnDelete: (key: string) -> (),
	}
)
	return TabView(scope, {
		Cards = props.Cards,
		SelectedKey = props.SelectedKey,
		EquipLabel = "Equip",
		ShowUnequip = true,
		OnSelect = props.OnSelect,
		OnEquip = props.OnEquip,
		OnUnequip = props.OnUnequip,
		OnDelete = props.OnDelete,
	})
end

return SubAbilityView
