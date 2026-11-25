const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Crane = require(ReplicatedStorage.shared.packages.Crane)

const View = require(script.View)
type ViewHandle = View.Handle

type HeadInfoData = {
	View: ViewHandle?,
}

const HeadInfo = Crane:CreateComponent({
	Name = "HeadInfo",
	Tag = "HeadInfo",
} :: Crane.Component<HeadInfoData>)

function HeadInfo.onStart(self: typeof(HeadInfo))
	if not self.instance:IsDescendantOf(workspace) then return end

	self.View = View(self.instance)
end

function HeadInfo:SetStunned(state: boolean)
	if not self.View then return end

	self.View.Stunned:set(state)
end

function HeadInfo:Destroy()
	if not self.View then return end

	self.View.Destroy()
	self.View = nil
end

return HeadInfo
