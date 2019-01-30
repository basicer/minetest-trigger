local minetest = require('minetest')
local io = require('io')

-- type_resolver is an interesting file
-- A TriggerSpec is a way to search for triggers
local type_resolver = require('type_resolver')
local EventType = require('event_type')
local TriggerType = require('trigger_type')
local registry = require('registry')
local util = require('util')
local normalize = util.normalize

trigger.util = util


local ActionType = {
	perform = function(self, ...)
		error("Action " .. self.name .. " has no perform function.")
	end,
	perform_async = function(self, props, done)
		self:perform(props)
		done()
	end
}

local event_types = registry.event_types
local action_types = registry.action_types
local condition_types = registry.condition_types

local triggers_by_id = registry.triggers_by_id
local triggers_by_name = registry.triggers_by_name
local triggers_by_uuid = registry.triggers_by_uuid
local step_events = {}

trigger.tbm = triggers_by_name

local variables_proxy = {}
local variables_cache = {}
setmetatable(variables_proxy, {
	__index = function(self, key, value)
		if variables_cache[key] == nil then
			local str = require('storage'):get_string('var:' .. key)
			if str and #str > 0 then
				variables_cache[key] = minetest.parse_json(str)
			end
		end
		return variables_cache[key]
	end,
	__newindex = function(self, key, value)
		if value == variables_cache[key] then return end
		variables_cache[key] = value
		require('storage'):set_string('var:' .. key, minetest.write_json(value))
	end
})
registry.variables = variables_proxy

local paused = false

local function assign(from, to)
	for k,v in pairs(from) do to[k] = v end
end

function trigger.register_event(spec)
	setmetatable(spec, {__index = EventType})
	spec.instances = {}
	spec.data = {}
	event_types[normalize(spec.name)] = spec
	if spec.step then table.insert(step_events, spec) end
end

function trigger.register_condition(spec)
	setmetatable(spec, {__index = ConditionType})
	condition_types[normalize(spec.name)] = spec
end

function trigger.register_action(spec)
	if spec.preform then
		spec.perform = spec.preform
		spec.preform = nil
	end
	if spec.preform_async then
		spec.perform_async = spec.preform_async
		spec.preform_async = nil
	end
	setmetatable(spec, {__index = ActionType})
	action_types[normalize(spec.name)] = spec
end



function trigger.emit(spec)
	local env = {} -- Trigger env
	if not spec.trigger.state.active then return end
	if paused then return end
	spec.trigger:write_env(env)
	assign(spec.env, env) -- Clobber with event env.
	if spec.trigger:check_conditions(env) then
		local analytics = require('mod/analytics')
		if analytics and analytics.trigger then analytics.trigger(spec.trigger) end
		spec.trigger:run(env)
	end
end



function trigger.add(spec)
	local event = event_types[normalize(spec.event.type)]
	if event then
		spec.event.type = event.name -- Fix bad casing or whatever
	else
		event = event_types["never"]
		print("UNKNOWN EVENT TYPE: " .. spec.event.type)
	end

	local trigger = TriggerType.new(spec)
	local nn = normalize(spec.name)
	if spec.name then triggers_by_name[nn] = trigger end

	triggers_by_uuid[spec.uuid] = trigger

	local props = trigger:write_props_for_event(event)
	event.instances[trigger.id] = props
	if event.on_watch then event:on_watch(trigger.id, props) end
	return trigger
end

require('builtin/events')
require('builtin/conditions')
require('builtin/actions')
require('builtin/actions_static')
require('builtin/values')

function trigger.from_handle(id)
	return triggers_by_id[id]
end

function trigger.reload()
	--TODO: Release existing triggers
	for k,v in pairs(triggers_by_id) do
		local event = event_types[normalize(v.spec.event.type)]
		if event.on_unwatch then event:on_unwatch(v.id, v.spec.event) end
	end

	for k,v in pairs(triggers_by_id) do triggers_by_id[k]=nil end
	for k,v in pairs(triggers_by_name) do triggers_by_name[k]=nil end

	for k,v in pairs(event_types) do
		v.instances = {}
	end
	trigger.load()
end

function trigger.load()
	local list = {}
	local function load(fn)
		print("LOAD", fn)
		local file = io.open(minetest.get_worldpath() .. "/" .. fn, "r")
		if not file then return end
		local data = minetest.parse_json(file:read("*all"))
		if data then
			for k,v in ipairs(data) do
				local t = trigger.add(v)
				if fn ~= "triggers.json" then
					t.file = fn:sub(10,-6)
				end
			end
		end
		file:close()
	end

	load("triggers.json")
	for k,v in ipairs(minetest.get_dir_list(minetest.get_worldpath(), false)) do
		if v:match("^triggers_.-%.json$") then
			load(v)
		end
	end
end

function trigger.flush()
	local files = {}
	for k,v in ipairs(triggers_by_id) do
		local file = 'triggers.json'
		if v.file then file = 'triggers_' .. v.file .. '.json' end
		if not files[file] then files[file] = {} end
		if ( v ) then table.insert(files[file],v.spec) end
	end
	for k,v in pairs(files) do
		local file = io.open(minetest.get_worldpath() .. "/" .. k, "w+")
		file:write(minetest.write_json(v, true))
		file:close()
	end
end

function trigger.pause()
	paused = true
end

function trigger.unpause()
	paused = false
end

function trigger.is_paused()
	return paused
end

require('commands')
require('markers')
require('ui')

minetest.after(0, function()
	for k,v in pairs(event_types) do v:setup() end
	trigger.load()
	minetest.register_globalstep(function(dt)
		for k,v in ipairs(step_events) do v:step(dt) end
	end)
end)

