/datum/species/lizard
	// Reptilian humanoids with scaled skin and tails.
	name = "\improper Lizardperson"
	plural_form = "Lizardfolk"
	id = SPECIES_LIZARD
	chat_color = COLOR_VIBRANT_LIME
	inherent_traits = list(
		TRAIT_MUTANT_COLORS,
		TRAIT_CAN_USE_FLIGHT_POTION,
		TRAIT_TACKLING_TAILED_DEFENDER,
	)
	inherent_biotypes = MOB_ORGANIC|MOB_HUMANOID|MOB_REPTILE
	mutantlungs = /obj/item/organ/lungs/lizard //underwater breathing baby!
	cosmetic_organs = list(
		/obj/item/organ/horns/lizard = SPRITE_ACCESSORY_NONE,
		/obj/item/organ/frills/lizard = SPRITE_ACCESSORY_NONE,
		/obj/item/organ/snout/lizard = "Round",
		/obj/item/organ/spines/lizard = SPRITE_ACCESSORY_NONE,
		/obj/item/organ/tail/lizard = "Smooth",

		/obj/item/organ/genital/penis = SPRITE_ACCESSORY_NONE,
		/obj/item/organ/genital/testicles = SPRITE_ACCESSORY_NONE,
		/obj/item/organ/genital/breasts = SPRITE_ACCESSORY_NONE,
		/obj/item/organ/genital/vagina = SPRITE_ACCESSORY_NONE,
		/obj/item/organ/genital/anus = SPRITE_ACCESSORY_NONE,
	)
	body_marking_sets = list(
		"Dark Tiger Body",
		"Light Belly",
		"Light Tiger Body",
	)
	mutanttongue = /obj/item/organ/tongue/lizard
	coldmod = 1.5
	heatmod = 0.67
	changesource_flags = MIRROR_BADMIN | WABBAJACK | MIRROR_PRIDE | MIRROR_MAGIC | RACE_SWAP | ERT_SPAWN | SLIME_EXTRACT
	species_cookie = /obj/item/food/meat/slab
	meat = /obj/item/food/meat/slab/human/mutant/lizard
	skinned_type = /obj/item/stack/sheet/animalhide/lizard
	exotic_bloodtype = "L"
	inert_mutation = /datum/mutation/human/firebreath
	death_sound = 'sound/voice/lizard/deathsound.ogg'
	wing_types = list(/obj/item/organ/wings/functional/dragon)
	species_language_holder = /datum/language_holder/lizard
	digitigrade_customization = DIGITIGRADE_OPTIONAL

	// Lizards are coldblooded and can stand a greater temperature range than humans
	bodytemp_heat_damage_limit = BODYTEMP_HEAT_LAVALAND_SAFE
	bodytemp_cold_damage_limit = (BODYTEMP_COLD_DAMAGE_LIMIT - 10)

	ass_image = 'icons/ass/asslizard.png'

	bodypart_overrides = list(
		BODY_ZONE_HEAD = /obj/item/bodypart/head/lizard,
		BODY_ZONE_CHEST = /obj/item/bodypart/chest/lizard,
		BODY_ZONE_L_ARM = /obj/item/bodypart/arm/left/lizard,
		BODY_ZONE_R_ARM = /obj/item/bodypart/arm/right/lizard,
		BODY_ZONE_L_LEG = /obj/item/bodypart/leg/left/lizard,
		BODY_ZONE_R_LEG = /obj/item/bodypart/leg/right/lizard,
	)

	voice_pack = /datum/voice/lizard

/datum/species/lizard/on_species_gain(mob/living/carbon/new_lizard, datum/species/old_species, pref_load)
	. = ..()
	if(ishuman(new_lizard))
		update_mail_goodies(new_lizard)

/datum/species/lizard/update_quirk_mail_goodies(mob/living/carbon/human/recipient, datum/quirk/quirk, list/mail_goodies = list())
	if(istype(quirk, /datum/quirk/blooddeficiency))
		mail_goodies += list(
			/obj/item/reagent_containers/blood/lizard
		)
	return ..()

/// Lizards are cold blooded and do not stabilize body temperature naturally
/datum/species/lizard/body_temperature_core(mob/living/carbon/human/humi, seconds_per_tick, times_fired)
	return

/datum/species/lizard/random_name(gender,unique,lastname)
	if(unique)
		return random_unique_lizard_name(gender)

	var/randname = lizard_name(gender)

	if(lastname)
		randname += " [lastname]"

	return randname


/datum/species/lizard/randomize_features(mob/living/carbon/human/human_mob)
	. = ..()
	randomize_cosmetic_organs(human_mob)
	randomize_markings(human_mob)

/datum/species/lizard/get_species_description()
	return "The militaristic Lizardpeople hail originally from Tizira, but have grown \
		throughout their centuries in the stars to possess a large spacefaring \
		empire: though now they must contend with their younger, more \
		technologically advanced Human neighbours."

/datum/species/lizard/get_species_lore()
	return list(
		"The face of conspiracy theory was changed forever the day mankind met the lizards.",

		"Hailing from the arid world of Tizira, lizards were travelling the stars back when mankind was first discovering how neat trains could be. \
		However, much like the space-fable of the space-tortoise and space-hare, lizards have rejected their kin's motto of \"slow and steady\" \
		in favor of resting on their laurels and getting completely surpassed by 'bald apes', due in no small part to their lack of access to plasma.",

		"The history between lizards and humans has resulted in many conflicts that lizards ended on the losing side of, \
		with the finale being an explosive remodeling of their moon. Today's lizard-human relations are seeing the continuance of a record period of peace.",

		"Lizard culture is inherently militaristic, though the influence the military has on lizard culture \
		begins to lessen the further colonies lie from their homeworld - \
		with some distanced colonies finding themselves subsumed by the cultural practices of other species nearby.",

		"On their homeworld, lizards celebrate their 16th birthday by enrolling in a mandatory 5 year military tour of duty. \
		Roles range from combat to civil service and everything in between. As the old slogan goes: \"Your place will be found!\"",
	)

// Override for the default temperature perks, so we can give our specific "cold blooded" perk.
/datum/species/lizard/create_pref_temperature_perks()
	var/list/to_add = list()

	to_add += list(list(
		SPECIES_PERK_TYPE = SPECIES_NEUTRAL_PERK,
		SPECIES_PERK_ICON = "thermometer-empty",
		SPECIES_PERK_NAME = "Cold-blooded",
		SPECIES_PERK_DESC = "Lizardpeople have higher tolerance for hot temperatures, but lower \
			tolerance for cold temperatures. Additionally, they cannot self-regulate their body temperature - \
			they are as cold or as warm as the environment around them is. Stay warm!",
	))

	return to_add

/*
Lizard subspecies: ASHWALKERS
*/
/datum/species/lizard/ashwalker
	name = "Ash Walker"
	id = SPECIES_LIZARD_ASH
	examine_limb_id = SPECIES_LIZARD
	chat_color = COLOR_MAROON
	mutantlungs = /obj/item/organ/lungs/lizard/lavaland
	mutantbrain = /obj/item/organ/brain/primitive
	inherent_traits = list(
		TRAIT_MUTANT_COLORS,
		TRAIT_VIRUSIMMUNE,
		TRAIT_FORBID_MINING_SHUTTLE_CONSOLE_OUTSIDE_STATION,
	)
	species_language_holder = /datum/language_holder/lizard/ash
	digitigrade_customization = DIGITIGRADE_FORCED
	examine_limb_id = SPECIES_LIZARD
	bodypart_overrides = list(
		BODY_ZONE_HEAD = /obj/item/bodypart/head/lizard/ashwalker,
		BODY_ZONE_CHEST = /obj/item/bodypart/chest/lizard/ashwalker,
		BODY_ZONE_L_ARM = /obj/item/bodypart/arm/left/lizard/ashwalker,
		BODY_ZONE_R_ARM = /obj/item/bodypart/arm/right/lizard/ashwalker,
		BODY_ZONE_L_LEG = /obj/item/bodypart/leg/left/lizard/ashwalker,
		BODY_ZONE_R_LEG = /obj/item/bodypart/leg/right/lizard/ashwalker,
	)

/*
Lizard subspecies: SILVER SCALED
*/
/datum/species/lizard/silverscale
	name = "Silver Scale"
	id = SPECIES_LIZARD_SILVER
	chat_color = COLOR_VERY_LIGHT_GRAY
	inherent_biotypes = MOB_ORGANIC|MOB_HUMANOID|MOB_REPTILE
	inherent_traits = list(
		TRAIT_HOLY,
		TRAIT_NOBREATH,
		TRAIT_PIERCEIMMUNE,
		TRAIT_RESISTHIGHPRESSURE,
		TRAIT_RESISTLOWPRESSURE,
		TRAIT_VIRUSIMMUNE,
		TRAIT_WINE_TASTER,
	)
	mutantlungs = null
	damage_modifier = 10 //very light silvery scales soften blows
	species_language_holder = /datum/language_holder/lizard/silver
	mutanttongue = /obj/item/organ/tongue/lizard/silver
	changesource_flags = MIRROR_BADMIN | MIRROR_MAGIC | RACE_SWAP | ERT_SPAWN
	examine_limb_id = SPECIES_LIZARD
	///stored features for when we turn back off of a silverscale.
	var/list/old_features
	///stored eye color for when we turn back off of a silverscale.
	var/old_eye_color_left
	///see above
	var/old_eye_color_right

/datum/species/lizard/silverscale/on_species_gain(mob/living/carbon/human/new_silverscale, datum/species/old_species, pref_load)
	var/static/list/replaced_features = list(
		"m_color" = "#eeeeee",
		"tail_color" = "#eeeeee",
		"spines_color" = "#eeeeee",
		"snout_color" = "#eeeeee",
		"horns_color" = COLOR_WHITE,
		"frills_color" = "#eeeeee",
	)
	old_eye_color_left = new_silverscale.eye_color_left
	old_eye_color_right = new_silverscale.eye_color_right
	old_features = list()
	for(var/feature in replaced_features)
		old_features[feature] = new_silverscale.dna.features[feature]
		new_silverscale.dna.features[feature] = replaced_features[feature]
	new_silverscale.eye_color_left = "#0000a0"
	new_silverscale.eye_color_right = "#0000a0"
	. = ..()
	new_silverscale.add_filter("silver_glint", 2, outline_filter(size = 2, color = "#ffffff63"))

/datum/species/lizard/silverscale/on_species_loss(mob/living/carbon/human/was_silverscale, datum/species/new_species, pref_load)
	for(var/feature in old_features)
		was_silverscale.dna.features[feature] = old_features[feature]
	if(old_eye_color_left)
		was_silverscale.eye_color_left = old_eye_color_left
	if(old_eye_color_right)
		was_silverscale.eye_color_right = old_eye_color_right
	was_silverscale.remove_filter("silver_glint")
	return ..()
