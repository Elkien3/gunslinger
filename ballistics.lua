gunslinger.penetrate = {} --table for putting in items that bullets can penetrate, and how much speed the bullet will be reduced by. usage: gunslinger.penetrate["default:glass"] = 3
gunslinger.penetrate["default:glass"] = 4
gunslinger.penetrate["default:wood"] = 12
local bullets = {}
local timer = 0
local TICK = .05 --NOTE: I think my math is wrong somewhere, changing this value changes how the bullet behaves, so change only if you know what you are doing
local DEBUG = false
local force = false
minetest.register_entity("gunslinger:bullet", {
    hp_max = 1,
	bullet = {},
    physical = false,
	pointable = false,
	collide_with_objects = false,
   -- weight = 5,
    collisionbox = {0,0,0, 0,0,0},
    visual = "sprite",
    visual_size = {x=.1, y=.1},
    textures = {"gunslinger_bullet.png"}, -- number of required textures depends on visual
    spritediv = {x=1, y=1},
    initial_sprite_basepos = {x=0, y=0},
    is_visible = true,
    makes_footstep_sound = false,
    automatic_rotate = false,
	on_activate = function(self, staticdata, dtime_s)
		minetest.after(TICK, function()
			if not self.bullet then
				self.object:remove()
			end
		end)
	end,
})
function gunslinger.firebullet(player, pos, velocity, drag, def)
	if not pos or not velocity or not drag or not def then return end
	local bullet = {}
	bullet.player = player
	bullet.pos = pos
	bullet.v = velocity
	bullet.drag = drag
	bullet.time = 0
	bullet.start = os.clock()
	bullet.force = true
	bullet.def = def
	bullet.entity = minetest.add_entity(pos, "gunslinger:bullet")
	bullet.entity:set_properties({bullet = bullet})
	table.insert(bullets, bullet)
	force = true
end
minetest.register_globalstep(function(dtime)
	timer = timer + dtime;
	if timer >= TICK or force then
		for id, bullet in pairs(bullets) do
			--local t1 = os.clock()
			if force and not bullet.force then goto continue else bullet.force = false end
			local time = timer
			if bullet.start then
				bullet.time = os.clock() - bullet.start
				time = bullet.time
			else
				bullet.time = bullet.time + timer
			end
			bullet.start = nil
			local speed = vector.length(bullet.v)
			local resistance = {}
			resistance.y = -.001*bullet.drag * (bullet.v.y * speed);
			resistance.x = -.001*bullet.drag * (bullet.v.x * speed);
			resistance.z = -.001*bullet.drag * (bullet.v.z * speed);
			bullet.v = vector.add(bullet.v, resistance)
			bullet.v.y = bullet.v.y - (9.81*time)
			local dir = vector.normalize(bullet.v)
			if bullet.entity then
				bullet.entity:set_pos(bullet.pos)
			else
				bullet.entity = minetest.add_entity(pos, "gunslinger:bullet")
				bullet.entity.bullet = bullet
			end
			if bullet.entity then
				bullet.entity:setvelocity(bullet.v)
			end
			local pos2 = vector.add(bullet.pos, vector.multiply(bullet.v, time))
			local ray = minetest.raycast(bullet.pos, pos2, true, true)
			if DEBUG then
				minetest.add_particle({
					pos = bullet.pos,
					expirationtime = 10,
					size = 4,
					texture = "gunslinger_debug.png"
				})
			end
			for pointed in ray do
				if pointed and pointed.ref and pointed.ref == bullet.player then
					goto next
				end
				local speed = vector.length(bullet.v)
				if pointed.intersection_point and pointed.type == "node" then
					if bullet.lastunder and vector.equals(bullet.lastunder, pointed.under) then goto next end
					if DEBUG then
						minetest.add_particle({
							pos = vector.subtract(pointed.intersection_point, vector.divide(dir, 50)),
							expirationtime = 10,
							size = 6,
							texture = "gunslinger_debug.png",
							vertical = true
						})
					else
						minetest.add_particle({
							pos = vector.subtract(pointed.intersection_point, vector.divide(dir, 50)),
							expirationtime = 10,
							size = 2,
							texture = "gunslinger_decal.png",
							vertical = true
						})
					end
					local name = minetest.get_node(pointed.under).name
					if name and gunslinger.penetrate[name] and  speed/gunslinger.penetrate[name] > 10 then
						local factor = gunslinger.penetrate[name]
						bullet.lastunder = pointed.under
						pos2 = pointed.intersection_point
						force = true
						bullet.force = true
						bullet.v = vector.add(bullet.v, {x=math.random(-1*factor,factor), y=math.random(-1*factor,factor), z=math.random(-1*factor,factor)})
						bullet.v = vector.divide(bullet.v, factor)
					else
						bullet.entity:remove()
						table.remove(bullets, id)
						goto continue
					end
				end
				if pointed.type == "object" then
					local target = pointed.ref
					local point = pointed.intersection_point
					local speedmod = (speed+100)/((bullet.def.speed or 600)+100)
					local dmg = bullet.def.base_dmg * bullet.def.dmg_mult * speedmod

					-- Add 50% damage if headshot
					if point.y > target:get_pos().y + 1.5 then
						dmg = dmg * 1.5
					end

					target:punch(bullet.player, nil, {damage_groups={fleshy=dmg}})
				end
				::next::
			end
			if bullet.time > 10 or vector.length(bullet.v)<10 then bullet.entity:remove() table.remove(bullets, id) end
			--minetest.log("error", (string.format("elapsed time: %.2fms", (os.clock() - t1) * 1000)))
			bullet.pos = pos2
			::continue::
		end
		if not force then
			timer = 0
		else
			force = false
		end
	end
end)