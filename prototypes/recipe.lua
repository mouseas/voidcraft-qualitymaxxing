
local function find_ref(name, category)
	local result
	if not category then
		result = data.raw.item[name]
		if not result then result = data.raw.capsule[name] end -- jellynut/yumako aren't in data.raw.item
	else
		result = data.raw[category][name]
	end
	return result
end

local function prismite_oreconv(xinfo, order, tinttbl)
	-- copied wholesale from voidcraft.prototypes.prismite-oreconv
	local recipe_tint = {
		primary = {r = tinttbl[1], g = tinttbl[2]*0.96, b = tinttbl[3], a = 1.000},
		secondary = {r = 0.5*(tinttbl[1]+1), g = tinttbl[2]*0.8, b = 0.5*(tinttbl[3]+1), a = 1.000},
		tertiary = {r = 0.72, g = 0.65, b = 0.4, a = 1.000}, 
		quaternary = {r = 0.84, g = 0.15, b = 0.62, a = 1.000}, 
	}
	
	if not xinfo then xinfo = {} end
	
	-- resolve main ingredient to table, find its reference.
	if not xinfo.main_ingr then
		xinfo.main_ingr = {type="item", name="prismite-ore", amount=5}
	elseif type(xinfo.main_ingr) ~= "table" then
		xinfo.main_ingr = {type="item", name=xinfo.main_ingr, amount=5}
	end
	local prismite_ref = find_ref(xinfo.main_ingr.name)
	
	-- resolve the fluid ingredient
	if not xinfo.fluid_ingr then
		xinfo.fluid_ingr = {type="fluid", name="void-flux", amount=2}
	elseif type(xinfo.fluid_ingr) ~= "table" then
		xinfo.fluid_ingr = {type="fluid", name=xinfo.fluid_ingr, amount=2}
	end
	
	-- resolve product to table, find its reference
	if type(xinfo.product) ~= "table" then
		xinfo.product = {type="item", name=xinfo.product, amount_min=6, amount_max=12}
	end
	local product_ref = find_ref(xinfo.product.name)
	local resultset = { xinfo.product }
	
	-- recipe name
	local recipe_name = xinfo.recipe_name or "mouseas-prismiteconv-" .. xinfo.product.name
	
	-- put together the composite icon and ingredient list
	local iconset = {
			{ icon = product_ref.icon, icon_size = 64 },
			{ icon = prismite_ref.icon, icon_size = 64, scale = 0.25, shift = {-8, -8} },
		}
	if xinfo.fluid_ingr.name ~= "void-flux" then
		-- if the fluid is nonstandard, try to include it in the composite icon.
		local fluid_ref = find_ref(xinfo.fluid_ingr.name, "fluid")
		if fluid_ref then table.insert(iconset, { icon = fluid_ref.icon, icon_size = 64, scale = 0.25, shift = {8, -8} }) end
	end
	
	local ingr = {
			xinfo.main_ingr,
			xinfo.fluid_ingr,
		}
	
	-- is there a secondary ingredient?
	if (xinfo.secondary_ingr) then
		if type(xinfo.secondary_ingr) ~= table then
			xinfo.secondary_ingr = {type="item", name=xinfo.secondary_ingr, amount=1}
		end
		local secondary_ingr_ref = find_ref(xinfo.secondary_ingr.name)
		table.insert(ingr, xinfo.secondary_ingr)
		table.insert(iconset, { icon = secondary_ingr_ref.icon, icon_size = 64, scale = 0.25, shift = {8, 8} })
	end
	
	-- is there a byproduct?
	if (xinfo.byproduct) then
		if type(xinfo.byproduct) ~= "table" then
			xinfo.byproduct = {type="item", name=xinfo.byproduct, amount=1}
		end
		table.insert(resultset, xinfo.byproduct)
	end
	
	-- completed recipe
	local result = {
		type = "recipe",
		name = recipe_name,
		localised_name = { "item-name." .. xinfo.product.name },
		energy_required = xinfo.cost or 2,
		enabled = false,
		category = xinfo.category or VOIDCRAFT.cryo_chemistry_category,
		icons = iconset,
		subgroup = xinfo.subgroup or "vc-prismite-conversions",
		order = order,
		main_product = xinfo.product.name,
		ingredients = ingr,
		results = resultset,
		
		show_amount_in_title = false,
		allow_decomposition = false,
		auto_recycle = false,
		allow_productivity = true,
		allow_quality = true,
		always_show_made_in = true,
		
		crafting_machine_tint = recipe_tint,
	}
	
	-- unlock the recipe in the specified technology
	if not xinfo.tech then xinfo.tech = "s6x-void-prismite-conv" end -- default to Prismaticonversion
	table.insert(data.raw.technology[xinfo.tech].effects, { type = "unlock-recipe", recipe = result.name })
	
	return result
end

-- item subgroups
data:extend({
	{
		type = "item-subgroup",
		name = "vc-qm-ores-minerals",
		order = "vc-qm-o",
		group = "intermediate-products"
	},
	{
		type = "item-subgroup",
		name = "vc-qm-bio",
		order = "vc-qm-o",
		group = "intermediate-products"
	},
	{
		type = "item-subgroup",
		name = "vc-qm-other",
		order = "vc-qm-o",
		group = "intermediate-products"
	},
})

local added_recipes = {
	prismite_oreconv({product="uranium-ore"}, "vf", {0.32, 0.86, 0.2}, {2, 4}),
	prismite_oreconv({product="tungsten-ore", secondary_ingr="tungsten-plate", tech="s6x-void-vulcanus", subgroup="vulcanus-processes"}, "vq-aa", {0.38, 0.32, 0.58}),
	prismite_oreconv({product="holmium-ore", secondary_ingr="holmium-plate", tech="s6x-void-fulgora", subgroup="fulgora-processes"}, "vq-ab", {0.68, 0.28, 0.375}),
	prismite_oreconv({product={name="jellynut", type="item", amount_min=45, amount_max=55}, secondary_ingr="jellynut-seed", tech="s6x-void-gleba", subgroup="vc-qm-bio"}, "vq-ac", {0.75, 0.46, 0.6}),
	prismite_oreconv({product={name="yumako", type="item", amount_min=45, amount_max=55}, secondary_ingr="yumako-seed", tech="s6x-void-gleba", subgroup="vc-qm-bio"}, "vq-ad", {0.8, 0.12, 0.25}),
	prismite_oreconv({product="lithium", secondary_ingr="lithium-plate", tech="s6x-void-aquilo", subgroup="vc-qm-ores-minerals"}, "vq-ae", {0.66, 0.68, 0.58}), -- not really needed: lithium is made with holmium plates
	prismite_oreconv({product="sulfur", tech="s6x-void-sulfur", subgroup="vc-qm-other"}, "vq-ba", {0.82, 0.8, 0.25}),
	prismite_oreconv({product="calcite", tech="s6x-void-vulcanus", subgroup="vulcanus-processes"}, "vq-bb", {0.78, 0.74, 0.74}),
	prismite_oreconv({product={name="raw-fish", type="item", amount=1}, secondary_ingr="spoilage", subgroup="vc-qm-bio"}, "vq-bc", {0.2, 1.0, 0.4}),
	prismite_oreconv({product={name="biter-egg", type="item", amount_min=3, amount_max=6}, main_ingr={type="item", name="orichalcum", amount=5, subgroup="vc-qm-bio"}, tech="s6x-void-biocrafting"}, "vq-bd", {0.78, 0.625, 0.48}),
	prismite_oreconv({product={name="pentapod-egg", type="item", amount_min=3, amount_max=6}, main_ingr={type="item", name="orichalcum", amount=5, subgroup="vc-qm-bio"}, tech="s6x-void-biocrafting"}, "vq-be", {0.5, 0.9, 0.52}),
	prismite_oreconv({product={name="orichalcum", type="item", amount_min=2, amount_max=5}, main_ingr="prismite-crystal", secondary_ingr="orichalcum", tech="s6x-void-orichalcum"}, "vq-bf", {0.36, 0.52, 0.2}),
}

-- cross-mod compatibility
if mods["voidcraft-planetary-compatibility"] then
	if mods["maraxsis"] then
		table.insert(added_recipes, prismite_oreconv({product="sand", tech="mouseas-void-maraxsis", subgroup="vc-qm-ores-minerals"}, "vq-mar-a", {0.78, 0.74, 0.74}))
		table.insert(added_recipes, prismite_oreconv({product="limestone", tech="mouseas-void-maraxsis", subgroup="vc-qm-ores-minerals"}, "vq-mar-b", {1.0, 0.9, 0.7}))
		table.insert(added_recipes, prismite_oreconv({product="maraxsis-coral", tech="mouseas-void-maraxsis", subgroup="vc-qm-bio"}, "vq-mar-c", {0.2, 0.61, 0.5}))
		table.insert(added_recipes, prismite_oreconv({product="maraxsis-tropical-fish", tech="mouseas-void-maraxsis", subgroup="vc-qm-bio"}, "vq-mar-a", {0.92, 0.35, 0.1}))
		table.insert(added_recipes, prismite_oreconv({product="salt", tech="mouseas-void-salt", subgroup="vc-qm-ores-minerals"}, "vq-mar-d", {0.78, 0.74, 0.74}))
	end
	
	if mods["castra"] then
		table.insert(added_recipes, prismite_oreconv({product="gunpowder", tech="mouseas-void-castra", subgroup="vc-qm-other"}, "vq-cas-a", {0.1, 0.1, 0.1}))
		table.insert(added_recipes, prismite_oreconv({product="millerite", tech="mouseas-void-castra", subgroup="vc-qm-ores-minerals"}, "vq-cas-b", {0.9, 0.8, 0.25}))
		table.insert(added_recipes, prismite_oreconv({product="castra-data", secondary_ingr="uranium-ore", tech="mouseas-void-castra", subgroup="vc-qm-other"}, "vq-cas-c", {0.4, 0.2, 0.1}))
	end
	
	if mods["tenebris-prime"] then
		table.insert(added_recipes, prismite_oreconv({product="tenecap", tech="mouseas-void-tenebris-prime", subgroup="vc-qm-bio"}, "vq-tp-a", {0.7, 0.45, 0.3}))
		table.insert(added_recipes, prismite_oreconv({product="lucifunnel", tech="mouseas-void-tenebris-prime", subgroup="vc-qm-bio"}, "vq-tp-b", {0.4, 0.8, 0.7}))
		table.insert(added_recipes, prismite_oreconv({product="quartz-ore", tech="mouseas-void-tenebris-prime", subgroup="vc-qm-ores-minerals"}, "vq-tp-c", {0.95, 0.9, 0.9}))
	end
	
	if mods["metal-and-stars"] then
		data:extend({
			{
				type = "item-subgroup",
				name = "vc-ip-mas",
				order = "vpmas",
				group = "intermediate-products"
			},
		})
		-- shipyard
		table.insert(added_recipes, prismite_oreconv({product={type="item", name="nanites", amount_min=12, amount_max=24}, tech="mouseas-void-mas-shipyard", subgroup="vc-ip-mas"}, "vq-mas-sy-a", {0.92, 0.92, 0.92}))
		-- nix
		table.insert(added_recipes, prismite_oreconv({
			product="dark-matter-chunk", 
			byproduct={type="item", name="antimatter", amount=1, probability=.001}, 
			main_ingr={type="item", name="prismite-crystal", amount=1},
			fluid_ingr={type="fluid", name="dark-matter-fluid", amount=60},
			tech="mouseas-void-mas-nix", 
			subgroup="vc-ip-mas"
		}, "vq-mas-n-a", {0.38, 0.32, 0.58}))
		-- ringworld
		table.insert(added_recipes, prismite_oreconv({product="bitumen", tech="mouseas-void-mas-ringworld", subgroup="vc-ip-mas"}, "vq-mas-rw-a", {0.12, 0.1, 0.1}))
		table.insert(added_recipes, prismite_oreconv({product="gold-ore", tech="mouseas-void-mas-ringworld", subgroup="vc-ip-mas"}, "vq-mas-rw-b", {0.9, 0.8, 0.0}))
		table.insert(added_recipes, prismite_oreconv({product="silica-sand", tech="mouseas-void-mas-ringworld", subgroup="vc-ip-mas"}, "vq-mas-rw-c", {0.8, 0.7, 0.7}))
		--mirandus
		table.insert(added_recipes, prismite_oreconv({product="neodymium-ore", tech="mouseas-void-mas-mirandus", subgroup="vc-ip-mas"}, "vq-mas-m-a", {0.92, 0.92, 0.92}))
		table.insert(added_recipes, prismite_oreconv({product="thorium", tech="mouseas-void-mas-mirandus", subgroup="vc-ip-mas"}, "vq-mas-m-b", {0.57, 0.7, 0.35}))
	end
	
	if mods["Moshine"] then
		-- sand is added by both mods, let's only add the recipe once and let both mods' voidcraft techs unlock it.
		if mods["maraxsis"] then
			table.insert(data.raw.technology["mouseas-void-moshine"].effects, { type = "unlock-recipe", recipe = "mouseas-prismiteconv-sand" })
		else
			table.insert(added_recipes, prismite_oreconv({product="sand", tech="mouseas-void-moshine", subgroup="vc-qm-ores-minerals"}, "vq-mos-a", {0.78, 0.74, 0.74}))
		end
		table.insert(added_recipes, prismite_oreconv({product="neodymium", tech="mouseas-void-moshine", subgroup="vc-qm-ores-minerals"}, "vq-mos-b", {0.9, 0.9, 0.9}))
	end
	
	if mods["secretas"] then
		-- gold ore is added by both mods, let's only add the recipe once and let both mods' voidcraft techs unlock it.
		if mods["metal-and-stars"] then
			table.insert(data.raw.technology["mouseas-void-frozeta"].effects, { type="unlock-recipe", recipe="mouseas-prismiteconv-gold-ore"})
		else
			table.insert(added_recipes, prismite_oreconv({product="gold-ore", tech="mouseas-void-frozeta", subgroup="vc-qm-ores-minerals"}, "vq-sec-a", {0.9, 0.8, 0.0}))
		end
	end
	
	if mods["Cerys-Moon-of-Fulgora"] then
		table.insert(data.raw.technology["cerys-fulgoran-cryogenics"].effects, { type="unlock-recipe", recipe="mouseas-prismiteconv-lithium" })
	end
end

-- add the recipes
data:extend(added_recipes)
