/datum/species/mush //mush mush codecuck
	name = "Mushroomperson"
	plural_form = "Mushroompeople"
	id = SPECIES_MUSHROOM
	chat_color = COLOR_CARGO_BROWN
	inherent_traits = list(
		TRAIT_FIXED_MUTANT_COLORS,
		TRAIT_MUTANT_COLORS,
		TRAIT_NOBREATH,
	)
	inherent_factions = list(FACTION_MUSHROOM)

	fixed_mut_color = "#DBBF92"

	changesource_flags = MIRROR_BADMIN | WABBAJACK | ERT_SPAWN
	no_equip_flags = ITEM_SLOT_MASK | ITEM_SLOT_OCLOTHING | ITEM_SLOT_GLOVES | ITEM_SLOT_FEET | ITEM_SLOT_ICLOTHING

	heatmod = 1.5

	mutanttongue = /obj/item/organ/tongue/mush
	mutanteyes = /obj/item/organ/eyes/night_vision/mushroom
	mutantlungs = null
	cosmetic_organs = list(
		/obj/item/organ/mushroom_cap = "Round",
	)
	species_language_holder = /datum/language_holder/mushroom

	bodypart_overrides = list(
		BODY_ZONE_L_ARM = /obj/item/bodypart/arm/left/mushroom,
		BODY_ZONE_R_ARM = /obj/item/bodypart/arm/right/mushroom,
		BODY_ZONE_HEAD = /obj/item/bodypart/head/mushroom,
		BODY_ZONE_L_LEG = /obj/item/bodypart/leg/left/mushroom,
		BODY_ZONE_R_LEG = /obj/item/bodypart/leg/right/mushroom,
		BODY_ZONE_CHEST = /obj/item/bodypart/chest/mushroom,
	)
	var/datum/martial_art/mushpunch/mush

/datum/species/mush/check_roundstart_eligible()
	return FALSE //hard locked out of roundstart on the order of design lead kor, this can be removed in the future when planetstation is here OR SOMETHING but right now we have a problem with races.

/datum/species/mush/on_species_gain(mob/living/carbon/C, datum/species/old_species)
	. = ..()
	if(ishuman(C))
		var/mob/living/carbon/human/H = C
		mush = new(null)
		mush.teach(H)

/datum/species/mush/on_species_loss(mob/living/carbon/C)
	. = ..()
	if(mush)
		mush.remove(C)
		QDEL_NULL(mush)

/datum/species/mush/handle_chemical(datum/reagent/chem, mob/living/carbon/human/affected, seconds_per_tick, times_fired)
	. = ..()
	if(. & COMSIG_MOB_STOP_REAGENT_CHECK)
		return
	if(chem.type == /datum/reagent/toxin/plantbgone/weedkiller)
		affected.adjustToxLoss(3 * REM * seconds_per_tick)
