--[[

	Minecart
	========

	Copyright (C) 2019-2020 Joachim Stolberg

	MIT
	See license.txt for more information
	
]]--

minecart = {}

-- Version for compatibility checks, see readme.md/history
minecart.version = 1.05

minecart.hopper_enabled = minetest.settings:get_bool("minecart_hopper_enabled") ~= false

print("minecart_hopper_enabled", dump(minetest.settings:get_bool("minecart_hopper_enabled")))

minecart.S = minetest.get_translator("minecart")
local MP = minetest.get_modpath("minecart")
dofile(MP.."/storage.lua")
dofile(MP.."/lib.lua")
dofile(MP.."/routes.lua")
dofile(MP.."/cart_entity.lua")
dofile(MP.."/buffer.lua")
dofile(MP.."/protection.lua")
dofile(MP.."/cart_api.lua")

if minecart.hopper_enabled then
	dofile(MP.."/hopper.lua")
end
dofile(MP.."/doc.lua")
minetest.log("info", "[MOD] Minecart loaded")