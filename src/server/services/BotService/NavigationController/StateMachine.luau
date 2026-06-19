--!native
--!optimize 2

local RunService = game:GetService("RunService")

type Cleanup = () -> ()

export type State = {
	Enter: (self: State, replacing: string?) -> ()?,
	Exit: (self: State, replacedBy: string?) -> ()?,
	Update: ((self: State, dt: number) -> ())?,
}

export type StateMachine<T = {[string]: State}> = {
	States: T,
	CurrentState: string?,
	Listeners: {(new: string?, old: string?) -> ()},

	UpdateConnection: RBXScriptConnection?,
	
	ChangeState: (self: StateMachine<T>, stateName: string?) -> (),
	GetCurrent: (self: StateMachine<T>) -> string?,
	AddState: (self: StateMachine<T>, name: string, state: State) -> (),
	RemoveState: (self: StateMachine<T>, name: string, state: State) -> (),
	OnStateChanged: (self: StateMachine<T>, callback: (new: string?, old: string?) -> ()) -> Cleanup,
	Destroy: (self: StateMachine<T>) -> (),
}

export type StateMachineConfig = {
	Initial: string?,
	CreateNoneState: boolean?,
	States: {[string]: State}?,
}

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.ChangeState<T>(self: StateMachine<T>, new: keyof<T>)
	local old = self.CurrentState
	
	if old then
		self.CurrentState = nil
		if self.States[old]["Exit"] then self.States[old]:Exit(new) end
	end
	
	if new then
		if self.States[new]["Enter"] then self.States[new]:Enter(old) end
		self.CurrentState = new
	end
	
	for _, listener in self.Listeners do
		listener(new, old)
	end
end

function StateMachine.GetCurrent<T>(self: StateMachine<T>): string?
	return self.CurrentState
end

function StateMachine.AddState<T>(self: StateMachine<T>, name: string, state: State)
	self.States[name] = state
end

function StateMachine.RemoveState<T>(self: StateMachine<T>, name: string, state: State)
	if self.CurrentState == state then
		self:ChangeState(nil)
	end
	
	self.States[name] = nil
end

function StateMachine.OnStateChanged<T>(self: StateMachine<T>, callback: (stateName: string?) -> ()): Cleanup
	table.insert(self.Listeners, callback)
	
	return function()
		local index = table.find(self.Listeners, callback)
		if index then
			table.remove(self.Listeners, index)
		end
	end
end

function StateMachine.Destroy<T>(self: StateMachine<T>)
	if self.CurrentState then
		self:ChangeState(nil)
	end
	
	if self.UpdateConnection then
		self.UpdateConnection:Disconnect()
	end
end

return {
	new = function<T>(config: StateMachineConfig?): StateMachine<T>
		config = config or {}
		
		if config.CreateNoneState then
			if not config.States["None"] then
				config.States["None"] = {
					Enter = function() end,
					Exit = function() end,
				}
			end
		end
		
		local machine = setmetatable({
			States = config.States or {},
			Listeners = {},
			CurrentState = nil,
		}, StateMachine)
		
		machine.UpdateConnection = RunService.Heartbeat:Connect(function(dt)
			if machine.CurrentState and machine.States[machine.CurrentState] and machine.States[machine.CurrentState].Update then
				machine.States[machine.CurrentState]:Update(dt)
			end
		end)
		
		if config.Initial then
			machine:ChangeState(config.Initial or "None")
		end
		
		return machine
	end,
}