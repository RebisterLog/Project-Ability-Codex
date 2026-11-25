const ReplicatedStorage = game:GetService("ReplicatedStorage")
const TweenService = game:GetService("TweenService")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const OnEvent = require(ReplicatedStorage.shared.packages.Fusion.Instances.OnEvent)
const peek = require(ReplicatedStorage.shared.packages.Fusion.State.peek)

const Children = Fusion.Children
const peek = Fusion.peek
const OnEvent = Fusion.OnEvent
const OnChange = Fusion.OnChange
type UsedAs<T> = Fusion.UsedAs<T>

const Sample = function(
	scope: Fusion.Scope,
	props: {
		IsShown: UsedAs<boolean>,
	}
)
end

return Sample
