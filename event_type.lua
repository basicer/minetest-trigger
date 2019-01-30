local trigger = require('trigger')

event_type = {
	setup = function(self) print("default setup of " .. self.name) end,
	on_watch = function(self, handle, params)

	end,
	on_unwatch = function(self, handle)

	end,
	emit = function(self, handle, env)
		trigger.emit({
			type = self,
			trigger = trigger.from_handle(handle),
			env = env or {}
		})
	end,
	emitAll = function(self, env)
		for k,v in pairs(self.instances) do self:emit(k, env) end
	end,
	teardown = function(self) end
}