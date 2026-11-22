const Assets = game:GetService("ReplicatedStorage").assets
const Models = Assets.JonathanHamon["PAC Hamon"].Models

-- Everything not declared here (animations, sounds, VFX, stats) is inherited
-- from JonathanHamon/None by the Skins loader.
return {
	Models = {
		Sword = Models.Sword,
		SendoHamon = Models.SendoHamon,
		YellowOverdrive = Models.YellowOverdrive,
	},
}
