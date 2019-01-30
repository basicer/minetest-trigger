local run = false
if not trigger then
	run = true
	require = dofile('init.lua')
end

local event_types = require('registry').event_types
local action_types = require('registry').action_types

local function t(sep, what)
	if not what then return "" end
	return sep .. what
end

local o = print
function make_docs( )

	o("# Events")
	for k,v in pairs(event_types) do
		o("## " .. v.name)
		o(v.description)
		o("### Properties")
		for pk,pv in pairs(v.properties or {}) do
			o("* " .. pk .. t(" - ",pv.description))
		end
		o()
	end

	o("# Actions")
	for k,v in pairs(action_types) do
		o("## " .. v.name)
		o(v.description)
		o("### Properties")
		for pk,pv in pairs(v.properties or {}) do
			o("* " .. pk .. t(" - ",pv.description))
		end

		o()
	end
end

if run then make_docs() end