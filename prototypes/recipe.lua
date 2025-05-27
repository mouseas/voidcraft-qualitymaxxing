local morph_time = 4
local void_flux_amount = 10
local min_yield = 6
local max_yield = 12
local use_junk_products = true
if (settings.startup["s6x-old-prismorphing"].value) then 
	morph_time = 2
	void_flux_amount = 2
	use_junk_products = false
end


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

local function calculate_recipe_tint(tinttbl)
	return {
		primary = {r = tinttbl[1], g = tinttbl[2]*0.96, b = tinttbl[3], a = 1.000},
		secondary = {r = 0.5*(tinttbl[1]+1), g = tinttbl[2]*0.8, b = 0.5*(tinttbl[3]+1), a = 1.000},
		tertiary = {r = 0.72, g = 0.65, b = 0.4, a = 1.000}, 
		quaternary = {r = 0.84, g = 0.15, b = 0.62, a = 1.000}, 
	}
end

local function prismite_oreconv(xinfo, order, tinttbl)
	-- adapted from voidcraft.prototypes.prismite-oreconv
	local recipe_tint = calculate_recipe_tint(tinttbl)
	
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
		xinfo.fluid_ingr = {type="fluid", name="void-flux", amount=void_flux_amount}
	elseif type(xinfo.fluid_ingr) ~= "table" then
		xinfo.fluid_ingr = {type="fluid", name=xinfo.fluid_ingr, amount=void_flux_amount}
	end
	
	-- resolve product to table, find its reference
	if type(xinfo.product) ~= "table" then
		xinfo.product = {type="item", name=xinfo.product, amount_min=min_yield, amount_max=max_yield}
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
		if (use_junk_products and xinfo.byproduct.is_desirable and not xinfo.byproduct.probability) then
			-- undesirable by products will always be given, but desirable ones should be affected by junk chances
			xinfo.byproduct.probability = 0.85
		end
		table.insert(resultset, xinfo.byproduct)
	end
	
	-- are there junk products?
	if (use_junk_products) then
		if not xinfo.junk_products then 
			-- no junk products, so it'll only make void shards as junk.
			xinfo.junk_products = {}
		elseif type(xinfo.junk_products) == "string" then
			-- only an item name was provided
			xinfo.junk_products = { {type="item", name=xinfo.junk_products, amount_min=min_yield, amount_max=max_yield, probability=0.14 } }
		elseif type(xinfo.junk_products) == "table" and xinfo.junk_products.type then
			-- only one was provided, but we need it to be an array
			xinfo.junk_products = { xinfo.junk_products }
		elseif type(xinfo.junk_products) == "table" and type(xinfo.junk_products[1]) == "string" then
			-- an array of item names was provided, add each as a full product entry, and split the 14% chance between them.
			local junk_count = 0
			local temp_products = {}
			for k, v in pairs(xinfo.junk_products) do
				junk_count = junk_count + 1
				table.insert(temp_products, {type="item", name=v, amount_min=min_yield, amount_max=max_yield})
			end
			for k, v in pairs(temp_products) do
				v.probability = 0.14 / junk_count
			end
			xinfo.junk_products = temp_products
		end
		
		-- add probabilities if they weren't already specified.
		for k, v in pairs(xinfo.junk_products) do
			if not v.probability then v.probability = 0.14 / #xinfo.junk_products end
		end
		
		-- add void shard with 1% chance
		table.insert(xinfo.junk_products, {type="item", name="void-crystal", amount=1, probability=0.01})
		
		-- add all the junk items to the recipe results, and figure out what's needed to get to 100%
		local probability_sum = 0
		for k, p in pairs(xinfo.junk_products) do
			probability_sum = probability_sum + p.probability
			table.insert(resultset, p)
		end
		
		-- determine the probability of the main product
		if probability_sum <= 0 or probability_sum >= 1 then
			log("Warning, total product pobabilities for prismorphing " .. xinfo.product.name .. " junk byproducts were invalid, so we can't automatically calculate the main product's probability. Defaulting to 85%.")
			resultset[1].probability = 0.85
		else
			resultset[1].probability = 1 - probability_sum
		end
	end
	
	-- completed recipe
	local result = {
		type = "recipe",
		name = recipe_name,
		localised_name = { "item-name." .. xinfo.product.name },
		energy_required = xinfo.cost or morph_time,
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
	prismite_oreconv({product="uranium-ore", junk_products="uranium-238"}, "vf", {0.32, 0.86, 0.2}, {2, 4}),
	prismite_oreconv({product="tungsten-ore", secondary_ingr="tungsten-plate", junk_products="stone", tech="s6x-void-vulcanus", subgroup="vulcanus-processes"}, "vq-aa", {0.38, 0.32, 0.58}),
	prismite_oreconv({product="holmium-ore", secondary_ingr="holmium-plate", junk_products="stone", tech="s6x-void-fulgora", subgroup="fulgora-processes"}, "vq-ab", {0.68, 0.28, 0.375}),
	prismite_oreconv({product={name="jellynut", type="item", amount_min=45, amount_max=55}, secondary_ingr="jellynut-seed", junk_products="spoilage", tech="s6x-void-gleba", subgroup="vc-qm-bio"}, "vq-ac", {0.75, 0.46, 0.6}),
	prismite_oreconv({product={name="yumako", type="item", amount_min=45, amount_max=55}, secondary_ingr="yumako-seed", junk_products="spoilage", tech="s6x-void-gleba", subgroup="vc-qm-bio"}, "vq-ad", {0.8, 0.12, 0.25}),
	prismite_oreconv({product="lithium", secondary_ingr="lithium-plate", junk_products="holmium-ore", tech="s6x-void-aquilo", subgroup="vc-qm-ores-minerals"}, "vq-ae", {0.66, 0.68, 0.58}), -- not really needed: lithium is made with holmium plates
	prismite_oreconv({product="sulfur", junk_products="spoilage", tech="s6x-void-sulfur", subgroup="vc-qm-other"}, "vq-ba", {0.82, 0.8, 0.25}),
	prismite_oreconv({product="calcite", junk_products="stone", tech="s6x-void-vulcanus", subgroup="vulcanus-processes"}, "vq-bb", {0.78, 0.74, 0.74}),
	prismite_oreconv({product={name="raw-fish", type="item", amount=1}, secondary_ingr="spoilage", junk_products={type="item", name="spoilage", amount=1}, subgroup="vc-qm-bio"}, "vq-bc", {0.2, 1.0, 0.4}),
	prismite_oreconv({product={name="biter-egg", type="item", amount_min=3, amount_max=6}, main_ingr={type="item", name="orichalcum", amount=5}, junk_products={type="item", name="spoilage", amount_min=3, amount_max=6}, subgroup="vc-qm-bio", tech="s6x-void-biocrafting"}, "vq-bd", {0.78, 0.625, 0.48}),
	prismite_oreconv({product={name="pentapod-egg", type="item", amount_min=3, amount_max=6}, main_ingr={type="item", name="orichalcum", amount=5}, junk_products={type="item", name="spoilage", amount_min=3, amount_max=6}, subgroup="vc-qm-bio", tech="s6x-void-biocrafting"}, "vq-be", {0.5, 0.9, 0.52}),
	prismite_oreconv({product={name="orichalcum", type="item", amount_min=2, amount_max=5}, main_ingr="prismite-crystal", secondary_ingr="orichalcum", junk_products={type="item", name="prismite-crystal", amount_min=2, amount_max=5}, tech="s6x-void-orichalcum"}, "vq-bf", {0.36, 0.52, 0.2}),
	prismite_oreconv({product="solid-fuel", subgroup="vc-qm-other", junk_products="void-fuel"}, "vq-bf", {0.5, 0.5, 0.5}),
	prismite_oreconv({product="ice", junk_products={type="fluid", name="water", amount=100}, subgroup="vc-qm-other"}, "vq-bg", {0.62, 0.62, 0.8}),
}

-- recipe to make promethium chunks. To get more out than you put in, you'll need productivity bonuses.
local promethium_chunk_recipe = prismite_oreconv({
		product={name="promethium-asteroid-chunk", type="item", amount=1},
		subgroup="space-processing",
		main_ingr={name="promethium-asteroid-chunk", type="item", amount=1},
		secondary_ingr="orichalcum",
		tech="promethium-science-pack"
	}, "vc-qm-a", {1.0, 0.2, 0.2})
if not (mods["VoidBlock"] and settings.startup["s6x-location-unlock"].value) then
	-- unless playing Void Block with surface conditions disabled, make sure this recipe is only allowed where promethium science packs are crafted.
	local promethium_science_recipe = data.raw.recipe["promethium-science-pack"]
	promethium_chunk_recipe.surface_conditions = {}
	for k, v in pairs(promethium_science_recipe.surface_conditions) do
		table.insert(promethium_chunk_recipe.surface_conditions, {property=v.property, max=v.max, min=v.min})
	end
end
table.insert(added_recipes, promethium_chunk_recipe)

-- recipe to make void rocket parts 
--[[ deprecated; voidcraft added this directly.
table.insert(added_recipes, {
	type = "recipe",
	name = "mouseas-void-rocket-part",
	localised_name = { "item-name.void-rocket-part" },
	energy_required = 10,
	enabled = false,
	category = "crafting-with-fluid",
	icon = data.raw.item["void-rocket-part"].icon,
	subgroup = "intermediate-product",
	order = "vc-qm-a",
	main_product = "void-rocket-part",
	ingredients = {
		{type="item", name="rocket-fuel", amount=1},
		{type="item", name="processing-unit", amount=1},
		{type="item", name="low-density-structure", amount=1},
		{type="fluid", name="void-flux", amount=20}
	},
	results = {
		{type="item", name="void-rocket-part", amount=1}
	},
	
	show_amount_in_title = false,
	allow_decomposition = false,
	auto_recycle = false,
	allow_productivity = true,
	allow_quality = true,
	always_show_made_in = true,
	
	crafting_machine_tint = calculate_recipe_tint({0.8, 0.3, 0.85}),
})
table.insert(data.raw.technology["s6x-void-rocket"].effects, { type = "unlock-recipe", recipe = "mouseas-void-rocket-part" })
]]

-- recipe to make holmium plates from ore
table.insert(added_recipes, {
	type = "recipe",
	name = "mouseas-smelt-holmium-plate",
	localised_name = { "item-name.holmium-plate" },
	energy_required = 2,
	enabled = false,
	category = "chemistry",
	icons = {
		{ icon = "__space-age__/graphics/icons/holmium-plate.png", icon_size = 64 },
		{ icon = "__Voidcraft__/graphics/icons/prismite-refined.png", icon_size = 64, scale = 0.25, shift = {-8, -8} }
	},
	subgroup = "prismite-smelting",
	order = "zzz-vc-qm-a",
	main_product = "holmium-plate",
	ingredients = {
		{type="item", name="prismite-refined", amount=1},
		{type="item", name="holmium-ore", amount=5},
		{type = "fluid", name = "void-flux", amount = 20},
	},
	results = {
		{type="item", name="holmium-plate", amount=5}
	},
	
	show_amount_in_title = false,
	allow_decomposition = false,
	auto_recycle = false,
	allow_productivity = true,
	allow_quality = true,
	always_show_made_in = true,
	
	crafting_machine_tint = calculate_recipe_tint({0.78, 0.6, 0.64}),
})
table.insert(data.raw.technology["s6x-void-fulgora"].effects, { type = "unlock-recipe", recipe = "mouseas-smelt-holmium-plate" })

-- cross-mod compatibility
if mods["voidcraft-planetary-compatibility"] then
	if mods["maraxsis"] then
		table.insert(added_recipes, prismite_oreconv({product="sand", junk_products="stone", tech="mouseas-void-maraxsis", subgroup="vc-qm-ores-minerals"}, "vq-mar-a", {0.78, 0.74, 0.74}))
		table.insert(added_recipes, prismite_oreconv({product="limestone", junk_products="maraxsis-coral", tech="mouseas-void-maraxsis", subgroup="vc-qm-ores-minerals"}, "vq-mar-b", {1.0, 0.9, 0.7}))
		table.insert(added_recipes, prismite_oreconv({product="maraxsis-coral", junk_products="limestone", tech="mouseas-void-maraxsis", subgroup="vc-qm-bio"}, "vq-mar-c", {0.2, 0.61, 0.5}))
		table.insert(added_recipes, prismite_oreconv({product="maraxsis-tropical-fish", junk_products="maraxsis-coral", tech="mouseas-void-maraxsis", subgroup="vc-qm-bio"}, "vq-mar-a", {0.92, 0.35, 0.1}))
		table.insert(added_recipes, prismite_oreconv({product="salt", junk_products="sand", tech="mouseas-void-salt", subgroup="vc-qm-ores-minerals"}, "vq-mar-d", {0.78, 0.74, 0.74}))
	end
	
	if mods["castra"] then
		table.insert(added_recipes, prismite_oreconv({product="gunpowder", junk_products="carbon", tech="mouseas-void-castra", subgroup="vc-qm-other"}, "vq-cas-a", {0.1, 0.1, 0.1}))
		table.insert(added_recipes, prismite_oreconv({product="millerite", junk_products={"iron-ore", "copper-ore"}, tech="mouseas-void-castra", subgroup="vc-qm-ores-minerals"}, "vq-cas-b", {0.9, 0.8, 0.25}))
		table.insert(added_recipes, prismite_oreconv({product="castra-data", junk_products={"uranium-ore", "gunpowder"}, secondary_ingr="uranium-ore", tech="mouseas-void-castra", subgroup="vc-qm-other"}, "vq-cas-c", {0.4, 0.2, 0.1}))
	end
	
	if mods["tenebris-prime"] then
		table.insert(added_recipes, prismite_oreconv({product="tenecap", junk_products="tenecap-spore", tech="mouseas-void-tenebris-prime", subgroup="vc-qm-bio"}, "vq-tp-a", {0.7, 0.45, 0.3}))
		table.insert(added_recipes, prismite_oreconv({product="lucifunnel", junk_products="luciferin", tech="mouseas-void-tenebris-prime", subgroup="vc-qm-bio"}, "vq-tp-b", {0.4, 0.8, 0.7}))
		table.insert(added_recipes, prismite_oreconv({product="quartz-ore", junk_products="stone", tech="mouseas-void-tenebris-prime", subgroup="vc-qm-ores-minerals"}, "vq-tp-c", {0.95, 0.9, 0.9}))
	end
	
	if mods["metal-and-stars"] then
		local gold_ore_junk = "silica-sand"
		if mods["secretas"] then
			gold_ore_junk = "copper-ore"
		end
		data:extend({
			{
				type = "item-subgroup",
				name = "vc-ip-mas",
				order = "vpmas",
				group = "intermediate-products"
			},
		})
		-- shipyard
		table.insert(added_recipes, prismite_oreconv({product={type="item", name="nanites", amount_min=12, amount_max=24}, junk_products="iron-ore", tech="mouseas-void-mas-shipyard", subgroup="vc-ip-mas"}, "vq-mas-sy-a", {0.92, 0.92, 0.92}))
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
		table.insert(added_recipes, prismite_oreconv({product="bitumen", junk_products="bone-fragments", tech="mouseas-void-mas-ringworld", subgroup="vc-ip-mas"}, "vq-mas-rw-a", {0.12, 0.1, 0.1}))
		table.insert(added_recipes, prismite_oreconv({product="gold-ore", junk_products=gold_ore_junk, tech="mouseas-void-mas-ringworld", subgroup="vc-ip-mas"}, "vq-mas-rw-b", {0.9, 0.8, 0.0}))
		table.insert(added_recipes, prismite_oreconv({product="silica-sand", junk_products="stone", tech="mouseas-void-mas-ringworld", subgroup="vc-ip-mas"}, "vq-mas-rw-c", {0.8, 0.7, 0.7}))
		--mirandus
		table.insert(added_recipes, prismite_oreconv({product="neodymium-ore", junk_products="lithium", tech="mouseas-void-mas-mirandus", subgroup="vc-ip-mas"}, "vq-mas-m-a", {0.92, 0.92, 0.92}))
		table.insert(added_recipes, prismite_oreconv({product="thorium", junk_products="uranium-238", tech="mouseas-void-mas-mirandus", subgroup="vc-ip-mas"}, "vq-mas-m-b", {0.57, 0.7, 0.35}))
	end
	
	if mods["Moshine"] then
		-- sand is added by both mods, let's only add the recipe once and let both mods' voidcraft techs unlock it.
		if mods["maraxsis"] then
			table.insert(data.raw.technology["mouseas-void-moshine"].effects, { type = "unlock-recipe", recipe = "mouseas-prismiteconv-sand" })
		else
			table.insert(added_recipes, prismite_oreconv({product="sand", junk_products="stone", tech="mouseas-void-moshine", subgroup="vc-qm-ores-minerals"}, "vq-mos-a", {0.78, 0.74, 0.74}))
		end
		table.insert(added_recipes, prismite_oreconv({product="neodymium", junk_products="iron-ore", tech="mouseas-void-moshine", subgroup="vc-qm-ores-minerals"}, "vq-mos-b", {0.9, 0.9, 0.9}))
	end
	
	if mods["secretas"] then
		-- gold ore is added by both mods, let's only add the recipe once and let both mods' voidcraft techs unlock it.
		if mods["metal-and-stars"] then
			table.insert(data.raw.technology["mouseas-void-frozeta"].effects, { type="unlock-recipe", recipe="mouseas-prismiteconv-gold-ore"})
		else
			table.insert(added_recipes, prismite_oreconv({product="gold-ore", junk_products="copper-ore", tech="mouseas-void-frozeta", subgroup="vc-qm-ores-minerals"}, "vq-sec-a", {0.9, 0.8, 0.0}))
		end
	end
	
	if mods["Cerys-Moon-of-Fulgora"] then
		table.insert(data.raw.technology["cerys-fulgoran-cryogenics"].effects, { type="unlock-recipe", recipe="mouseas-prismiteconv-lithium" })
	end
end

-- add the recipes
data:extend(added_recipes)
