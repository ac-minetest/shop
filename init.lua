local function get_register_formspec(pos)
	local meta = minetest.get_meta(pos)
	local spos = pos.x.. "," ..pos.y .. "," .. pos.z
	local formspec =
		"size[8,6]" ..
		--default.gui_bg ..
		--default.gui_bg_img ..
		--default.gui_slots ..
		"button[0,0;2,1;stock;SELLING]" ..
		"button[3,0;2,1;register;BUYING]" ..
		--"button_exit[7,0;1,1;exit;X]" ..
		"button[7,0;1,1;ok;TRADE]" ..
		"list[nodemeta:" .. spos .. ";sell;2,0;1,1;]" ..
		"list[nodemeta:" .. spos .. ";buy;5,0;1,1;]" ..
		"list[current_player;main;0,2;8,4;]"
	return formspec
end

local formspec_register =
	"size[8,9]" ..
	--default.gui_bg ..
	--default.gui_bg_img ..
	--default.gui_slots ..
	"label[0,0;Register]" ..
	"list[current_name;register;0,0.75;8,4;]" ..
	"list[current_player;main;0,5.25;8,4;]" ..
	"listring[]"

local formspec_stock =
	"size[8,9]" ..
	--default.gui_bg ..
	--default.gui_bg_img ..
	--default.gui_slots ..
	"label[0,0;Stock]" ..
	"list[current_name;stock;0,0.75;8,4;]" ..
	"list[current_player;main;0,5.25;8,4;]" ..
	"listring[]"

minetest.register_privilege("shop_admin", "Shop administration and maintainence")

minetest.register_node("shop:shop", {
	description = "Shop",
	tiles = {
		"shop_shop_topbottom.png",
		"shop_shop_topbottom.png",
		"shop_shop_side.png",
		"shop_shop_side.png",
		"shop_shop_side.png",
		"shop_shop_front.png",
	},
	groups = {choppy = 3, oddly_breakable_by_hand = 1},
	paramtype2 = "facedir",
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		local owner = placer:get_player_name()

		meta:set_string("owner", owner)
		meta:set_string("infotext", "Uncofigured Shop (Owned by " .. owner .. ")")
		meta:set_string("formspec", get_register_formspec(pos))

		if minetest.check_player_privs(owner, "privs") then
			meta:set_int("admin_shop",1);
		end
		
		local inv = meta:get_inventory()
		inv:set_size("buy", 1)
		inv:set_size("sell", 1)
		inv:set_size("stock", 8*4)
		inv:set_size("register", 8*4)
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.get_meta(pos)
		local owner = meta:get_string("owner")
		local player = sender:get_player_name()
		local inv = meta:get_inventory()
		local s = inv:get_list("sell")
		local b = inv:get_list("buy")
		local stk = inv:get_list("stock")
		local reg = inv:get_list("register")
		local pinv = sender:get_inventory()

		if fields.register then
			if player ~= owner and (not minetest.check_player_privs(player, "shop_admin")) then
				minetest.chat_send_player(player, "Only the shop owner can open the register.")
				return
			else
				minetest.show_formspec(player, "shop:shop", formspec_register)
				meta:set_string("infotext", "\nSELLING: " .. s[1]:to_string() .. "\nBUYING : " .. b[1]:to_string() .. "\n".. "owner " .. owner)
			end
		elseif fields.stock then
			if player ~= owner and (not minetest.check_player_privs(player, "shop_admin")) then
				minetest.chat_send_player(player, "Only the shop owner can open the stock.")
				return
			else
				minetest.show_formspec(player, "shop:shop", formspec_stock)
				meta:set_string("infotext", "\nSELLING: " .. s[1]:to_string() .. "\nBUYING : " .. b[1]:to_string() .. "\n".. "owner " .. owner)
			end
		elseif fields.ok then
			
			if player==owner and not minetest.check_player_privs(player, "shop_admin") then 
				minetest.chat_send_player(player, "Can't trade with yourself")
				return
			end
			
			local err = "";
			if meta:get_int("admin_shop")~=1 then -- check shop
				
				if inv:is_empty("sell") or
					inv:is_empty("buy") or
					(not inv:room_for_item("register", b[1])) then
					minetest.chat_send_player(player, "Shop inventory is empty/full.")
					return
				end
			
				if not inv:contains_item("stock", s[1]) then
					err = "Error. Shop out of stock.";
					meta:set_string("infotext", err);
				end
				
				if not inv:room_for_item("register", b[1]) then
					err = "Error. Shop register full.";
					meta:set_string("infotext", err);
				end
			
			end
			
			if not pinv:room_for_item("main", s[1]) then
				err = "Error. You dont have space in your inventory.";
			end
			
			if not pinv:contains_item("main", b[1]) then
				err = "Error. You dont have enough items to pay.";
			end
			
			if err~="" then 
				minetest.chat_send_player(player,err);
				return 
			end
	
			
			pinv:remove_item("main", b[1])
			inv:add_item("register", b[1])
			inv:remove_item("stock", s[1])
			pinv:add_item("main", s[1])
			minetest.chat_send_player(player, "Sold " .. s[1]:to_string() .. " for " .. b[1]:to_string())
			
		end
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		local owner = meta:get_string("owner")
		local inv = meta:get_inventory()
		local s = inv:get_list("sell")
		local n = stack:get_name()
		local playername = player:get_player_name()
		if playername ~= owner and
		    (not minetest.check_player_privs(playername, "shop_admin")) then
			return 0
		else
			return stack:get_count()
		end
	end,
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		local owner = meta:get_string("owner")
		local playername = player:get_player_name()
		if playername ~= owner and
		    (not minetest.check_player_privs(playername, "shop_admin"))then
			return 0
		else
			return stack:get_count()
		end
	end,
	allow_metadata_inventory_move = function(pos, _, _, _, _, count, player)
		local meta = minetest.get_meta(pos)
		local owner = meta:get_string("owner")
		local playername = player:get_player_name()
		if playername ~= owner and
		    (not minetest.check_player_privs(playername, "shop_admin")) then
			return 0
		else
			return count
		end
	end,
	can_dig = function(pos, player) 
                local meta = minetest.get_meta(pos) 
                local owner = meta:get_string("owner") 
                local inv = meta:get_inventory() 
                return player:get_player_name() == owner and
		    inv:is_empty("register") and
		    inv:is_empty("stock") and
		    inv:is_empty("buy") and
		    inv:is_empty("sell")
	end,

})

-- minetest.register_craftitem("shop:coin", {

	-- description = "Gold Coin",
	-- inventory_image = "shop_coin.png",
-- })

-- minetest.register_craft({
	-- output = "shop:coin 9",
	-- recipe = {
		-- {"default:gold_ingot"},
	-- }
-- })

minetest.register_craft({
	output = "default:gold_ingot",
	recipe = {
		{"shop:coin", "shop:coin", "shop:coin"},
		{"shop:coin", "shop:coin", "shop:coin"},
		{"shop:coin", "shop:coin", "shop:coin"}
	}
})

minetest.register_craft({
	output = "shop:shop",
	recipe = {
		{"group:wood", "group:wood", "group:wood"},
		{"group:wood", "default:goldblock", "group:wood"},
		{"group:wood", "group:wood", "group:wood"}
	}
})
