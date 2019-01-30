print('So actually uh, minetest isnt here right now, but well stub it.');
local json = require('test/json')

function minetest.register_chatcommand() end

function minetest.get_worldpath()
	return './data'
end

function minetest.after(time, fn) fn() end

function minetest.parse_json(str) return json.decode(str) end

function minetest.register_globalstep() end

function minetest.register_entity() end

function minetest.register_on_punchnode() end

function minetest.register_on_player_receive_fields() end

function minetest.register_on_joinplayer() end
function minetest.register_on_placenode() end
function minetest.register_on_respawnplayer() end
function minetest.register_on_newplayer() end

function minetest.get_dir_list() return {} end

minetest.registered_nodes = {}

--module.exports = function() print('hai') end