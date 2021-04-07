--[[

	TechAge
	=======

	Copyright (C) 2019 Joachim Stolberg

	AGPL v3
	See LICENSE.txt for more information

	TA2/TA3/TA4 Distributor
	
]]--

-- for lazy programmers
local M = minetest.get_meta
local N = minetest.get_node
-- Consumer Related Data
local CRD = function(pos) return (minetest.registered_nodes[techage.get_node_lvm(pos).name] or {}).consumer end
local Tube = techage.Tube

local S = techage.S

local SRC_INV_SIZE = 8

local STANDBY_TICKS = 3
local COUNTDOWN_TICKS = 4
local CYCLE_TIME = 4

local INFO = [[Turn port on/off or read its state: command = 'port', payload = red/green/blue/yellow{=on/off}]]


--local Side2Color = {B="red", L="green", F="blue", R="yellow"}
local SlotColors = {"red", "green", "blue", "yellow"}
local Num2Ascii = {"B", "L", "F", "R"} 
local FilterCache = {} -- local cache for filter settings

-- Permutation table to improve distribution between ports (number of ports: 1-4)
-- Usage: permIdx[num_ports][math.random(1, #permIdx[num_ports])][idx]
local permIdx = {
	{ { 1 } },
	{ { 1, 2 }, { 2, 1 } },
	{ { 1, 2, 3 }, { 1, 3, 2 }, { 2, 1, 3 }, { 2, 3, 1 }, { 3, 1, 2 }, { 3, 2, 1 } },
	{ { 1, 2, 3, 4 }, { 1, 2, 4, 3 }, { 1, 3, 2, 4 }, { 1, 3, 4, 2 }, { 1, 4, 2, 3 },
	  { 1, 4, 3, 2 }, { 2, 1, 3, 4 }, { 2, 1, 4, 3 }, { 2, 3, 1, 4 }, { 2, 3, 4, 1 },
	  { 2, 4, 1, 3 }, { 2, 4, 3, 1 }, { 3, 1, 2, 4 }, { 3, 1, 4, 2 }, { 3, 2, 1, 4 },
	  { 3, 2, 4, 1 }, { 3, 4, 1, 2 }, { 3, 4, 2, 1 }, { 4, 1, 2, 3 }, { 4, 1, 3, 2 },
	  { 4, 2, 1, 3 }, { 4, 2, 3, 1 }, { 4, 3, 1, 2 }, { 4, 3, 2, 1 }, }
}

local function filter_settings(pos)
	local meta = M(pos)
	local param2 = techage.get_node_lvm(pos).param2
	local inv = meta:get_inventory()
	local filter = minetest.deserialize(meta:get_string("filter")) or {false,false,false,false}
	local ItemFilter = {}  -- {<item:name> = {dir,...}]
	local OpenPorts = {}  -- {dir, ...}
	-- collect all filter settings
	for idx,slot in ipairs(SlotColors) do
		if filter[idx] == true then
			local side = Num2Ascii[idx]
			local out_dir = techage.side_to_outdir(side, param2)
			if inv:is_empty(slot) then
				table.insert(OpenPorts, out_dir)
			else
				for idx2,stack in ipairs(inv:get_list(slot)) do
					local name = stack:get_name()
					if name ~= "" then
						if not ItemFilter[name] then
							ItemFilter[name] = {}
						end
						table.insert(ItemFilter[name], out_dir)
					end
				end
			end
		end
	end
	
	FilterCache[minetest.hash_node_position(pos)] = {
		ItemFilter = ItemFilter, 
		OpenPorts = OpenPorts,
	}
end

-- Return filter table and list of open ports.
-- (see test data)
local function get_filter_settings(pos)
--	local ItemFilter = {
--		["default:dirt"] = {1,2},
--		["default:cobble"] = {4},
--	}
--	local OpenPorts = {3}
--	return ItemFilter, OpenPorts
	
	local hash = minetest.hash_node_position(pos)
	if FilterCache[hash] == nil then
		filter_settings(pos)
	end
	return FilterCache[hash].ItemFilter, FilterCache[hash].OpenPorts
end

local function blocking_checkbox(pos, filter, is_hp)
	local cnt = 0
	local _, open_ports = get_filter_settings(pos)
	local fs_pos = is_hp and "0.25,5" or "3,3.9"
	for _,val in ipairs(filter) do
		if val then cnt = cnt + 1 end
	end
	if cnt > 1 and #open_ports > 0 then
		local blocking = M(pos):get_int("blocking") == 1 and "true" or "false"
		return "checkbox["..fs_pos..";blocking;"..S("blocking mode")..";"..blocking.."]"..
			"tooltip["..fs_pos..";1,1;"..S("Block configured items for open ports")..";#0C3D32;#FFFFFF]"
	else
		M(pos):set_int("blocking", 0) -- disable blocking
	end
	return ""
end		
		
local function formspec(self, pos, nvm)
	local filter = minetest.deserialize(M(pos):get_string("filter")) or {false,false,false,false}
	local is_hp = nvm.high_performance == true
	local blocking = blocking_checkbox(pos, filter, is_hp)

	if is_hp then
		return "size[10.5,9.5]"..
		"box[0.25,-0.1;9.6,1.1;#005500]"..
		"label[0.6,0.2;"..S("Input").."]"..
		"list[context;src;1.75,0;8,1;]"..
		blocking..
		"image_button[0.25,5.8;1,1;"..self:get_state_button_image(nvm)..";state_button;]"..
		"tooltip[0.25,5.8;1,1;"..self:get_state_tooltip(nvm).."]"..
		"checkbox[0.25,1.2;filter1;On;"..dump(filter[1]).."]"..
		"checkbox[0.25,2.2;filter2;On;"..dump(filter[2]).."]"..
		"checkbox[0.25,3.2;filter3;On;"..dump(filter[3]).."]"..
		"checkbox[0.25,4.2;filter4;On;"..dump(filter[4]).."]"..
		"image[1.25,1.2;0.3,1;techage_inv_red.png]"..
		"image[1.25,2.2;0.3,1;techage_inv_green.png]"..
		"image[1.25,3.2;0.3,1;techage_inv_blue.png]"..
		"image[1.25,4.2;0.3,1;techage_inv_yellow.png]"..
		"list[context;red;1.75,1.2;8,1;]"..
		"list[context;green;1.75,2.2;8,1;]"..
		"list[context;blue;1.75,3.2;8,1;]"..
		"list[context;yellow;1.75,4.2;8,1;]"..
		"list[current_player;main;1.75,5.8;8,4;]"..
		"listring[context;src]"..
		"listring[current_player;main]"..
		default.get_hotbar_bg(1.75,5.8)
	else
		return "size[10.5,8.5]"..
		"list[context;src;0,0;2,4;]"..
		blocking..
		"image[2,1.5;1,1;techage_form_arrow.png]"..
		"image_button[0,4.8;1,1;"..self:get_state_button_image(nvm)..";state_button;]"..
		"tooltip[0,4.8;1,1;"..self:get_state_tooltip(nvm).."]"..
		"checkbox[3,0;filter1;On;"..dump(filter[1]).."]"..
		"checkbox[3,1;filter2;On;"..dump(filter[2]).."]"..
		"checkbox[3,2;filter3;On;"..dump(filter[3]).."]"..
		"checkbox[3,3;filter4;On;"..dump(filter[4]).."]"..
		"image[4,0;0.3,1;techage_inv_red.png]"..
		"image[4,1;0.3,1;techage_inv_green.png]"..
		"image[4,2;0.3,1;techage_inv_blue.png]"..
		"image[4,3;0.3,1;techage_inv_yellow.png]"..
		"list[context;red;4.5,0;6,1;]"..
		"list[context;green;4.5,1;6,1;]"..
		"list[context;blue;4.5,2;6,1;]"..
		"list[context;yellow;4.5,3;6,1;]"..
		"list[current_player;main;1.25,4.8;8,4;]"..
		"listring[context;src]"..
		"listring[current_player;main]"..
		default.get_hotbar_bg(1.25,4.8)
	end
end

local function allow_metadata_inventory_put(pos, listname, index, stack, player)
	local inv = M(pos):get_inventory()
	local list = inv:get_list(listname)
	
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	if listname == "src" then
		CRD(pos).State:start_if_standby(pos)
		return stack:get_count()
	elseif list[index]:get_count() == 0 then
		stack:set_count(1)
		inv:set_stack(listname, index, stack)
		return 0
	end
	return 0
end

local function allow_metadata_inventory_take(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	if listname == "src" then
		return stack:get_count()
	else
		local inv = M(pos):get_inventory()
		inv:set_stack(listname, index, nil)
		return 0
	end
end

local function allow_metadata_inventory_move(pos, from_list, from_index, to_list, to_index, count, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	local inv = minetest.get_meta(pos):get_inventory()
	local stack = inv:get_stack(from_list, from_index)

	if from_list == "src" and to_list ~= "src" and not inv:contains_item(to_list, {name = stack:get_name()}) then
		stack:set_count(1)
		inv:set_stack(to_list, to_index, stack)
		return 0
	elseif from_list ~= "src" and to_list == "src" then
		inv:set_stack(from_list, from_index, nil)
		return 0
	elseif not inv:contains_item(to_list, {name = stack:get_name()}) then
		return 1
	else
		return 0
	end
end

local function tubelib2_on_update2(pos, outdir, tlib2, node)
	local is_ta4_tube = true
	for dir = 1,4 do
		for i, pos, node in Tube:get_tube_line(pos, dir) do
			is_ta4_tube = is_ta4_tube and techage.TA4tubes[node.name]
		end
	end
	
	local nvm = techage.get_nvm(pos)
	local crd = CRD(pos)
	if CRD(pos).stage == 4 and not is_ta4_tube then
		nvm.num_items = crd.num_items / 2
	else
		nvm.num_items = crd.num_items
	end
end

local function push_item(pos, filter, itemstack, num_items, nvm)
	local idx = 1
	local num_pushed = 0
	local num_ports = #filter
	num_ports = techage.in_range(num_ports, 1, 4)
	local randidx = permIdx[num_ports][math.random(1, #permIdx[num_ports])]
	local amount = math.floor(math.max((num_items + 1) / num_ports, 1))
	local num_of_trials = 0
	while num_pushed < num_items and num_of_trials <= 8 do
		num_of_trials = num_of_trials + 1
		local push_dir = filter[randidx[idx]]
		local num_to_push = math.min(amount, num_items - num_pushed)
		if techage.push_items(pos, push_dir, itemstack:peek_item(num_to_push)) then
			num_pushed = num_pushed + num_to_push
			nvm.port_counter[push_dir] = (nvm.port_counter[push_dir] or 0) + num_to_push
		end
		-- filter start offset
		idx = idx + 1
		if idx > num_ports then
			idx = 1
		end
	end
	return num_pushed
end

-- move items to output slots
local function distributing(pos, inv, crd, nvm)
	local item_filter, open_ports = get_filter_settings(pos)
	local sum_num_pushed = 0
	local num_pushed = 0
	local blocking_mode = M(pos):get_int("blocking") == 1
	
	-- start searching after last position
	local offs = nvm.last_index or 1
	
	for i = 1, SRC_INV_SIZE do
		local idx = ((i + offs - 1) % 8) + 1
		local stack = inv:get_stack("src", idx)
		local item_name = stack:get_name()
		local num_items = stack:get_count()
		local num_to_push = math.min((nvm.num_items or crd.num_items) - sum_num_pushed, num_items)
		local stack_to_push = stack:peek_item(num_to_push)
		num_pushed = 0
		
		if item_filter[item_name] then
			-- Push items based on filter
			num_pushed = push_item(pos, item_filter[item_name], stack_to_push, num_to_push, nvm)
		elseif blocking_mode and #open_ports > 0 then
			-- Push items based on open ports
			num_pushed = push_item(pos, open_ports, stack_to_push, num_to_push, nvm)
		end
		if not blocking_mode and num_pushed == 0 and #open_ports > 0 then
			-- Push items based on open ports
			num_pushed = push_item(pos, open_ports, stack_to_push, num_to_push, nvm)
		end
			
		sum_num_pushed = sum_num_pushed + num_pushed
		stack:take_item(num_pushed)
		inv:set_stack("src", idx, stack)
		if sum_num_pushed >= (nvm.num_items or crd.num_items) then 
			nvm.last_index = idx
			break 
		end
	end
	
	if sum_num_pushed == 0 then
		crd.State:blocked(pos, nvm)
	else
		crd.State:keep_running(pos, nvm, COUNTDOWN_TICKS)
	end
end

-- move items to the output slots
local function keep_running(pos, elapsed)
	local nvm = techage.get_nvm(pos)
	nvm.port_counter = nvm.port_counter or {}
	local crd = CRD(pos)
	local inv = M(pos):get_inventory()
	if not inv:is_empty("src") then
		distributing(pos, inv, crd, nvm)
	else
		crd.State:idle(pos, nvm)
	end
	return crd.State:is_active(nvm)
end

local function on_receive_fields(pos, formname, fields, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return
	end
	local meta = M(pos)
	local crd = CRD(pos)
	local filter = minetest.deserialize(meta:get_string("filter"))
	if fields.filter1 ~= nil then
		filter[1] = fields.filter1 == "true"
	elseif fields.filter2 ~= nil then
		filter[2] = fields.filter2 == "true"
	elseif fields.filter3 ~= nil then
		filter[3] = fields.filter3 == "true"
	elseif fields.filter4 ~= nil then
		filter[4] = fields.filter4 == "true"
	elseif fields.blocking ~= nil then
		meta:set_int("blocking", fields.blocking == "true" and 1 or 0)
	end
	meta:set_string("filter", minetest.serialize(filter))
	
	filter_settings(pos)
	
	local nvm = techage.get_nvm(pos)
	if fields.state_button ~= nil then
		crd.State:state_button_event(pos, nvm, fields)
	else
		meta:set_string("formspec", formspec(crd.State, pos, nvm))
	end
end

-- techage command to turn on/off filter channels
local function change_filter_settings(pos, slot, val)
	local slots = {["red"] = 1, ["green"] = 2, ["blue"] = 3, ["yellow"] = 4}
	local meta = M(pos)
	local filter = minetest.deserialize(meta:get_string("filter"))
	local num = slots[slot] or 1
	if num >= 1 and num <= 4 then
		filter[num] = val == "on"
	end
	meta:set_string("filter", minetest.serialize(filter))
	
	filter_settings(pos)
	
	local nvm = techage.get_nvm(pos)
	meta:set_string("formspec", formspec(CRD(pos).State, pos, nvm))
	return true
end

-- techage command to read filter channel status (on/off)
local function read_filter_settings(pos, slot)
	local slots = {["red"] = 1, ["green"] = 2, ["blue"] = 3, ["yellow"] = 4}
	local filter = minetest.deserialize(M(pos):get_string("filter"))
	return filter[slots[slot]] and "on" or "off"
end

local function can_dig(pos, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return false
	end
	local inv = M(pos):get_inventory()
	return inv:is_empty("src")
end

local get_tiles = function(is_hp)
	local variant = is_hp and "_hp" or ""
	local tiles = {}
	-- '#' will be replaced by the stage number
	-- '{power}' will be replaced by the power PNG
	tiles.pas = {
		-- up, down, right, left, back, front
		"techage_filling_ta#.png^techage_appl_distri.png^techage_frame_ta#_top"..variant..".png^techage_appl_color_top.png",
		"techage_filling_ta#.png^techage_frame_ta#_top"..variant..".png^(techage_appl_color_top.png^[transformFY)",
		"techage_filling_ta#.png^techage_frame_ta#"..variant..".png^techage_appl_distri_yellow.png",
		"techage_filling_ta#.png^techage_frame_ta#"..variant..".png^techage_appl_distri_green.png",
		"techage_filling_ta#.png^techage_frame_ta#"..variant..".png^techage_appl_distri_red.png",
		"techage_filling_ta#.png^techage_frame_ta#"..variant..".png^techage_appl_distri_blue.png",
	}
	tiles.act = {
		-- up, down, right, left, back, front
		{
			image = "techage_filling4_ta#.png^techage_appl_distri4.png^techage_frame4_ta#_top"..variant..".png^techage_appl_color_top4.png",
			backface_culling = false,
			animation = {
				type = "vertical_frames",
				aspect_w = 32,
				aspect_h = 32,
				length = 1.0,
			},
		},
		"techage_filling_ta#.png^techage_frame_ta#_top"..variant..".png^(techage_appl_color_top.png^[transformFY)",
		"techage_filling_ta#.png^techage_frame_ta#"..variant..".png^techage_appl_distri_yellow.png",
		"techage_filling_ta#.png^techage_frame_ta#"..variant..".png^techage_appl_distri_green.png",
		"techage_filling_ta#.png^techage_frame_ta#"..variant..".png^techage_appl_distri_red.png",
		"techage_filling_ta#.png^techage_frame_ta#"..variant..".png^techage_appl_distri_blue.png",
	}
	return tiles
end

local tubing = {
	on_pull_item = function(pos, in_dir, num)
		local inv = M(pos):get_inventory()
		return techage.get_items(pos, inv, "src", num)
	end,
	on_push_item = function(pos, in_dir, stack)
		CRD(pos).State:start_if_standby(pos)
		local inv = M(pos):get_inventory()
		return techage.put_items(inv, "src", stack)
	end,
	on_unpull_item = function(pos, in_dir, stack)
		local inv = M(pos):get_inventory()
		return techage.put_items(inv, "src", stack)
	end,
	on_recv_message = function(pos, src, topic, payload)
		if topic == "info" then
			return INFO
		elseif topic == "port" then
			-- "red"/"green"/"blue"/"yellow" = "on"/"off"
			local slot, val = techage.ident_value(payload)
			if val == "" then
				return read_filter_settings(pos, slot)
			else
				return change_filter_settings(pos, slot, val)
			end
		else		
			return CRD(pos).State:on_receive_message(pos, topic, payload)
		end
	end,
	
	on_node_load = function(pos)
		CRD(pos).State:on_node_load(pos)
	end,
}

local def = {
	cycle_time = CYCLE_TIME,
	standby_ticks = STANDBY_TICKS,
	formspec = formspec,
	tubing = tubing,
	after_place_node = function(pos, placer)
		local meta = M(pos)
		local filter = {false,false,false,false}
		meta:set_string("filter", minetest.serialize(filter))
		local inv = meta:get_inventory()
		inv:set_size('src', 8)
		inv:set_size('yellow', 6)
		inv:set_size('green', 6)
		inv:set_size('red', 6)
		inv:set_size('blue', 6)
	end,
	can_dig = can_dig,
	node_timer = keep_running,
	on_receive_fields = on_receive_fields,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take,
	tubelib2_on_update2 = tubelib2_on_update2,

	on_metadata_inventory_move = function(pos, from_list, from_index, to_list)
		if from_list ~= "src" or to_list ~= "src" then
			filter_settings(pos)
			local nvm = techage.get_nvm(pos)
			M(pos):set_string("formspec", formspec(CRD(pos).State, pos, nvm))
		end
	end,
	on_metadata_inventory_put = function(pos, listname)
		if listname ~= "src" then
			filter_settings(pos)
			local nvm = techage.get_nvm(pos)
			M(pos):set_string("formspec", formspec(CRD(pos).State, pos, nvm))
		end
	end,
	on_metadata_inventory_take = function(pos, listname)
		if listname ~= "src" then
			filter_settings(pos)
			local nvm = techage.get_nvm(pos)
			M(pos):set_string("formspec", formspec(CRD(pos).State, pos, nvm))
		end
	end,

	groups = {choppy=2, cracky=2, crumbly=2},
	sounds = default.node_sound_wood_defaults(),
	num_items = {0,4,12,24},
}

local node_name_ta2, node_name_ta3, node_name_ta4 = techage.register_consumer(
	"distributor",
	S("Distributor"),
	get_tiles(false),
	def
)

local hp_def = table.copy(def)

hp_def.after_place_node = function(pos, placer)
	local meta = M(pos)
	local nvm = techage.get_nvm(pos)
	nvm.high_performance = true
	local filter = {false,false,false,false}
	meta:set_string("filter", minetest.serialize(filter))
	local inv = meta:get_inventory()
	inv:set_size('src', 8)
	inv:set_size('yellow', 8)
	inv:set_size('green', 8)
	inv:set_size('red', 8)
	inv:set_size('blue', 8)
end
hp_def.num_items = {0,0,0,36}

local _, _, node_name_ta4_hp = techage.register_consumer(
	"high_performance_distributor", S("High Performance Distributor"),
	get_tiles(true),
	hp_def,
	{false, false, false, true}
)

minetest.register_craft({
	output = node_name_ta2.." 2",
	recipe = {
		{"group:wood", "techage:iron_ingot", "group:wood"},
		{"techage:tubeS", "default:mese_crystal", "techage:tubeS"},
		{"group:wood", "techage:iron_ingot", "group:wood"},
	},
})

minetest.register_craft({
	output = node_name_ta3,
	recipe = {
		{"", "techage:iron_ingot", ""},
		{"", node_name_ta2, ""},
		{"", "techage:vacuum_tube", ""},
	},
})

minetest.register_craft({
	output = node_name_ta4,
	recipe = {
		{"", "techage:iron_ingot", ""},
		{"", node_name_ta3, ""},
		{"", "techage:ta4_wlanchip", ""},
	},
})


minetest.register_craft({
	output = node_name_ta4_hp,
	recipe = {
		{node_name_ta4, "default:copper_ingot"},
		{"default:mese_crystal_fragment", node_name_ta4},
	},
})
