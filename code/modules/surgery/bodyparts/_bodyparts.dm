/obj/item/bodypart
	name = "limb"
	desc = "Why is it detached..."
	force = 3
	throwforce = 3
	w_class = WEIGHT_CLASS_SMALL
	grind_results = list(
		/datum/reagent/bone_dust = 10,
		/datum/reagent/consumable/liquidgibs = 5,
	) // robotic bodyparts and chests/heads cannot be ground

	/**
	 * The mob that currently "owns" this limb
	 *
	 * DO NOT MODIFY DIRECTLY. Use set_owner()
	 */
	var/mob/living/carbon/owner

	/**
	 * A bitfield of biological states, exclusively used to determine which wounds this limb will get,
	 * as well as how easily it will happen.
	 * Set to BIO_FLESH_BONE because most species have both flesh and bone in their limbs.
	 *
	 * This currently has absolutely no meaning for robotic limbs.
	 */
	var/biological_state = BIO_FLESH_BONE
	/// A bitfield of bodytypes for clothing, surgery, and misc information
	var/bodytype = BODYTYPE_HUMANOID | BODYTYPE_ORGANIC
	/// Same as above, but this purely exists to cache the external bodytypes of organs inside us - Gets updated on synchronize_bodytypes()
	var/external_bodytypes = NONE
	/// Defines when a bodypart should not be changed. Example: BP_BLOCK_CHANGE_SPECIES prevents the limb from being overwritten on species gain
	var/change_exempt_flags = NONE
	/// Random flags that describe this bodypart, such as BODYPART_UNREMOVABLE
	var/bodypart_flags = NONE

	/// BODY_ZONE_CHEST, BODY_ZONE_L_ARM, etc - used for def_zone
	var/body_zone
	/// The body zone of this part in english ("chest", "left arm", etc) without the species attached to it
	var/plaintext_zone
	/// Auxiliary zone, used for rendering only and doesn't actually exist as an object
	var/aux_zone
	/// Bitflag used to check which clothes cover this bodypart
	var/body_part
	/// Are we a hand? if so, which one!
	var/held_index = 0
	/// A speed modifier we apply to the owner when attached, if any. Positive numbers make it move slower, negative numbers make it move faster.
	var/speed_modifier = null

	/// The type of husk for building an icon state when husked
	var/husk_type = "humanoid"
	/// Whether the bodypart (and the owner) is husked.
	var/is_husked = FALSE
	/// Whether the bodypart (and the owner) is invisible through invisibleman trait.
	var/is_invisible = FALSE
	/// The ID of a species used to generate the icon. Needs to match the icon_state portion in the limbs file!
	var/limb_id = SPECIES_HUMAN
	/// Defines what sprite the limb should use if it is also sexually dimorphic.
	var/limb_gender = "m"
	/// Is there a sprite difference between male and female?
	var/is_dimorphic = FALSE
	/// The actual color a limb is drawn as, set by /proc/update_limb()
	var/draw_color //NEVER. EVER. EDIT THIS VALUE OUTSIDE OF UPDATE_LIMB. I WILL FIND YOU. It ruins the limb icon pipeline.

	// Limb disabling variables
	/**
	 * Whether it is possible for the limb to be disabled whatsoever. TRUE means that it is possible.
	 * Defaults to FALSE, as only human limbs can be disabled, and only the appendages.
	 */
	var/can_be_disabled = FALSE
	/**
	 * Controls if the limb is disabled.
	 * TRUE means it is disabled (similar to being removed, but still present for the sake of targeted interactions).
	 */
	var/bodypart_disabled = FALSE
	/**
	 * Handles limb disabling by damage.
	 * If 0 (0%), a limb can't be disabled via damage.
	 * If 1 (100%), it is disabled at max limb damage.
	 * Anything between is the percentage of damage against maximum limb damage needed to disable the limb.
	 */
	var/disabling_threshold_percentage = 0

	// Damage variables
	/// The current amount of brute damage the limb has
	var/brute_dam = 0
	/// The current amount of burn damage the limb has
	var/burn_dam = 0
	/// The maximum brute OR burn damage a bodypart can take. Once we hit this cap, no more damage of either type!
	var/max_damage = 0
	/// A mutiplication of the burn and brute damage that the limb's stored damage contributes to its attached mob's overall wellbeing.
	var/body_damage_coeff = 1

	/// Gradually increases while burning when at full damage, destroys the limb when at 100
	var/cremation_progress = 0

	// Multiplicative damage modifiers
	/// Brute damage gets multiplied by this on receive_damage()
	var/brute_modifier = 1
	/// Burn damage gets multiplied by this on receive_damage()
	var/burn_modifier = 1

	// Subtractive damage modifiers
	/// Amount subtracted from brute damage inflicted on the limb.
	var/brute_reduction = 0
	/// Amount subtracted from burn damage inflicted on the limb.
	var/burn_reduction = 0

	// Coloring and proper item icon update
	/// Skin tone, if we are compatible with those
	var/skin_tone = ""
	/// Species based coloring, if we don't use skin tonies
	var/species_color = ""
	/// An "override" color that can be applied to ANY limb, greyscale or not.
	var/variable_color = ""
	/// Whether or not to use icon_greyscale instead of icon_static
	var/should_draw_greyscale = TRUE

	var/px_x = 0
	var/px_y = 0

	/// The type of damage overlay (if any) to use when this bodypart is bruised/burned.
	var/dmg_overlay_type = "human"
	/// If we're bleeding, which icon are we displaying on this part
	var/bleed_overlay_icon

	// Damage messages used by help_shake_act()
	var/light_brute_msg = "bruised"
	var/medium_brute_msg = "battered"
	var/heavy_brute_msg = "mangled"

	var/light_burn_msg = "numb"
	var/medium_burn_msg = "blistered"
	var/heavy_burn_msg = "peeling away"

	/// Damage messages used by examine(). the desc that is most common accross all bodyparts gets shown
	var/list/damage_examines = list(
		BRUTE = DEFAULT_BRUTE_EXAMINE_TEXT,
		BURN = DEFAULT_BURN_EXAMINE_TEXT,
		CLONE = DEFAULT_CLONE_EXAMINE_TEXT,
	)

	// Wounds related variables
	/// The wounds currently afflicting this body part
	var/list/wounds
	/// The scars currently afflicting this body part
	var/list/scars
	/// Our current cached wound damage multiplier, multiplies both brute and burn damage
	var/wound_damage_multiplier = 1
	/// This number is subtracted from all wound rolls on this bodypart, higher numbers mean more defense, negative means easier to wound
	var/wound_resistance = 0
	/// When this bodypart hits max damage, this number is added to all wound rolls. Obviously only relevant for bodyparts that have damage caps.
	var/maxdamage_wound_penalty = 15

	/// A hat won't cover your face, but a shirt covering your chest will cover your... you know, chest
	var/scars_covered_by_clothes = TRUE
	/// So we know if we need to scream if this limb hits max damage
	var/last_maxed
	/// Our current bleed rate. Cached, update with refresh_bleed_rate()
	var/cached_bleed_rate = 0
	/// How much generic bleedstacks we have on this bodypart
	var/generic_bleedstacks
	/// If we have a gauze wrapping currently applied (not including splints)
	var/obj/item/stack/current_gauze
	/// If something is currently grasping this bodypart and trying to staunch bleeding (see [/obj/item/hand_item/self_grasp])
	var/obj/item/hand_item/self_grasp/grasped_by

	/// List of obj/item's embedded inside us. Managed by embedded components, do not modify directly
	var/list/embedded_objects = list()

	/// A list of all the organs we've got stored inside us
	var/list/obj/item/organ/organs
	/// A list of all bodypart overlays to draw on this limb if possible
	var/list/datum/bodypart_overlay/bodypart_overlays

	/// Type of an attack from this limb does. Arms will do punches, Legs for kicks, and head for bites. (TO ADD: tactical chestbumps)
	var/attack_type = BRUTE
	/// the verb used for an unarmed attack when using this limb, such as arm.unarmed_attack_verb = "punch"
	var/unarmed_attack_verb = "bump"
	/// what visual effect is used when this limb is used to strike someone.
	var/unarmed_attack_effect = ATTACK_EFFECT_PUNCH
	/// Sounds when this bodypart is used in an umarmed attack
	var/sound/unarmed_attack_sound = 'sound/weapons/punch1.ogg'
	/// Sounds when this bodypart misses an unarmed attack
	var/sound/unarmed_miss_sound = 'sound/weapons/punchmiss.ogg'
	/// Lowest possible punch damage this bodypart can give. If this is set to 0, unarmed attacks will always miss.
	var/unarmed_damage_low = 1
	/// Highest possible punch damage this bodypart can ive.
	var/unarmed_damage_high = 1
	/// Damage at which attacks from this bodypart will stun
	var/unarmed_stun_threshold = 2
	/// How many pixels this bodypart will offset the top half of the mob, used for abnormally sized torsos and legs
	var/top_offset = 0

	/// Traits that are given to the holder of the part. If you want an effect that changes this, don't add directly to this. Use the add_bodypart_trait() proc
	var/list/bodypart_traits
	/// The name of the trait source that the organ gives. Should not be altered during the events of gameplay, and will cause problems if it is.
	var/bodypart_trait_source = BODYPART_TRAIT

	/// List of feature offset datums which have actually been instantiated, managed automatically
	var/list/feature_offsets

/obj/item/bodypart/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_ATOM_RESTYLE, PROC_REF(on_attempt_feature_restyle))
	if(can_be_disabled)
		RegisterSignal(src, SIGNAL_ADDTRAIT(TRAIT_PARALYSIS), PROC_REF(on_paralysis_trait_gain))
		RegisterSignal(src, SIGNAL_REMOVETRAIT(TRAIT_PARALYSIS), PROC_REF(on_paralysis_trait_loss))

	if(!IS_ORGANIC_LIMB(src))
		grind_results = null

	name = "[limb_id] [parse_zone(body_zone)]"
	update_icon_dropped()
	refresh_bleed_rate()

/obj/item/bodypart/Destroy()
	if(owner)
		owner.remove_bodypart(src)
		set_owner(null)

	for(var/wound in wounds)
		qdel(wound) // wounds is a lazylist, and each wound removes itself from it on deletion.
	if(length(wounds))
		stack_trace("[type] qdeleted with [length(wounds)] uncleared wounds")
		wounds.Cut()

	for(var/obj/item/organ/organ as anything in organs)
		qdel(organ) // It handles removing its references to this limb on its own.
	if(length(organs))
		stack_trace("[type] qdeleted with [length(organs)] uncleared organs")
		organs.Cut()

	bodypart_overlays?.Cut() // the datums will clear themselves by garbage collection

	QDEL_LIST_ASSOC_VAL(feature_offsets)

	return ..()

/obj/item/bodypart/drop_location()
	return (owner ? owner.drop_location() : ..())

/obj/item/bodypart/forceMove(atom/destination) //Please. Never forcemove a limb if its's actually in use. This is only for borgs.
	SHOULD_CALL_PARENT(TRUE)
	. = ..()
	if(isturf(destination))
		update_icon_dropped()

/obj/item/bodypart/examine(mob/user)
	SHOULD_CALL_PARENT(TRUE)

	. = ..()
	if(brute_dam > DAMAGE_PRECISION)
		. += span_warning("This limb has [brute_dam > 30 ? "severe" : "minor"] bruising.")
	if(burn_dam > DAMAGE_PRECISION)
		. += span_warning("This limb has [burn_dam > 30 ? "severe" : "minor"] burns.")

	if(locate(/datum/wound/blunt) in wounds)
		. += span_warning("The bones in this limb appear badly cracked.")
	if(locate(/datum/wound/slash) in wounds)
		. += span_warning("The flesh on this limb appears badly lacerated.")
	if(locate(/datum/wound/pierce) in wounds)
		. += span_warning("The flesh on this limb appears badly perforated.")
	if(locate(/datum/wound/burn) in wounds)
		. += span_warning("The flesh on this limb appears badly cooked.")

/obj/item/bodypart/setDir(newdir)
	SHOULD_CALL_PARENT(FALSE)
	return //always face south
/**
 * Called when a bodypart is checked for injuries.
 * Returns the messages represeting the bodypart's injuries.
 */
/obj/item/bodypart/proc/check_for_injuries(mob/living/carbon/human/examiner)
	var/list/messages = list()
	var/list/limb_damage = list(BRUTE = brute_dam, BURN = burn_dam)

	SEND_SIGNAL(src, COMSIG_BODYPART_CHECKED_FOR_INJURY, examiner, messages, limb_damage)
	SEND_SIGNAL(examiner, COMSIG_CARBON_CHECKING_BODYPART, src, messages, limb_damage)

	var/shown_brute = limb_damage[BRUTE]
	var/shown_burn = limb_damage[BURN]
	var/status = ""
	var/self_aware = HAS_TRAIT(examiner, TRAIT_SELF_AWARE)

	if(self_aware)
		if(!shown_brute && !shown_burn)
			status = "no damage"
		else
			status = "[shown_brute] brute damage and [shown_burn] burn damage"

	else
		if(shown_brute > (max_damage * 0.8))
			status += heavy_brute_msg
		else if(shown_brute > (max_damage * 0.4))
			status += medium_brute_msg
		else if(shown_brute > DAMAGE_PRECISION)
			status += light_brute_msg

		if(shown_brute > DAMAGE_PRECISION && shown_burn > DAMAGE_PRECISION)
			status += " and "

		if(shown_burn > (max_damage * 0.8))
			status += heavy_burn_msg
		else if(shown_burn > (max_damage * 0.2))
			status += medium_burn_msg
		else if(shown_burn > DAMAGE_PRECISION)
			status += light_burn_msg

		if(status == "")
			status = "OK"

	var/no_damage
	if(status == "OK" || status == "no damage")
		no_damage = TRUE

	var/is_disabled = ""
	if(bodypart_disabled)
		is_disabled = " is disabled"
		if(no_damage)
			is_disabled += " but otherwise"
		else
			is_disabled += " and"

	messages += "\t <span class='[no_damage ? "notice" : "warning"]'>Your [name][is_disabled][self_aware ? " has " : " is "][status].</span>"
	for(var/datum/wound/wound as anything in wounds)
		switch(wound.severity)
			if(WOUND_SEVERITY_TRIVIAL)
				messages += "\t [span_danger("Your [name] is suffering [wound.a_or_from] [lowertext(wound.name)].")]"
			if(WOUND_SEVERITY_MODERATE)
				messages += "\t [span_warning("Your [name] is suffering [wound.a_or_from] [lowertext(wound.name)]!")]"
			if(WOUND_SEVERITY_SEVERE)
				messages += "\t [span_boldwarning("Your [name] is suffering [wound.a_or_from] [lowertext(wound.name)]!!")]"
			if(WOUND_SEVERITY_CRITICAL)
				messages += "\t [span_boldwarning("Your [name] is suffering [wound.a_or_from] [lowertext(wound.name)]!!!")]"

	for(var/obj/item/embedded_thing in embedded_objects)
		var/stuck_word = embedded_thing.isEmbedHarmless() ? "stuck" : "embedded"
		messages += "\t <a href='?src=[REF(examiner)];embedded_object=[REF(embedded_thing)];embedded_limb=[REF(src)]' class='warning'>There is \a [embedded_thing] [stuck_word] in your [name]!</a>"

	return messages

/obj/item/bodypart/blob_act()
	receive_damage(max_damage, wound_bonus = CANT_WOUND)

/obj/item/bodypart/attack(mob/living/carbon/victim, mob/user)
	SHOULD_CALL_PARENT(TRUE)

	if(ishuman(victim))
		var/mob/living/carbon/human/human_victim = victim
		if(HAS_TRAIT(victim, TRAIT_LIMBATTACHMENT))
			if(!human_victim.get_bodypart(body_zone))
				user.temporarilyRemoveItemFromInventory(src, TRUE)
				if(!try_attach_limb(victim))
					to_chat(user, span_warning("[human_victim]'s body rejects [src]!"))
					forceMove(human_victim.loc)
					return
				if(check_for_frankenstein(victim))
					bodypart_flags |= BODYPART_IMPLANTED
				if(human_victim == user)
					human_victim.visible_message(span_warning("[human_victim] jams [src] into [human_victim.p_their()] empty socket!"),\
					span_notice("You force [src] into your empty socket, and it locks into place!"))
				else
					human_victim.visible_message(span_warning("[user] jams [src] into [human_victim]'s empty socket!"),\
					span_notice("[user] forces [src] into your empty socket, and it locks into place!"))
				return
	return ..()

/obj/item/bodypart/attackby(obj/item/weapon, mob/user, params)
	SHOULD_CALL_PARENT(TRUE)

	if(weapon.get_sharpness())
		add_fingerprint(user)
		if(!contents.len)
			to_chat(user, span_warning("There is nothing left inside [src]!"))
			return
		playsound(loc, 'sound/weapons/slice.ogg', 50, TRUE, -1)
		user.visible_message(span_warning("[user] begins to cut open [src]."),\
			span_notice("You begin to cut open [src]..."))
		if(do_after(user, 5 SECONDS, target = src))
			drop_organs(user, violent_removal = TRUE)
		return
	return ..()

/obj/item/bodypart/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	SHOULD_CALL_PARENT(TRUE)

	. = ..()
	if(IS_ORGANIC_LIMB(src))
		playsound(get_turf(src), 'sound/misc/splort.ogg', 50, TRUE, -1)
	pixel_x = rand(-3, 3)
	pixel_y = rand(-3, 3)

//Return TRUE to get whatever mob this is in to update health.
/obj/item/bodypart/proc/on_life(seconds_per_tick, times_fired)
	SHOULD_CALL_PARENT(TRUE)

/**
 * #receive_damage
 *
 * called when a bodypart is taking damage
 * Damage will not exceed max_damage using this proc, and negative damage cannot be used to heal
 * Returns TRUE if damage icon states changes
 * Args:
 * brute - The amount of brute damage dealt.
 * burn - The amount of burn damage dealt.
 * blocked - The amount of damage blocked by armor.
 * update_health - Whether to update the owner's health from receiving the hit.
 * required_bodytype - A bodytype flag requirement to get this damage (ex: BODYTYPE_ORGANIC)
 * wound_bonus - Additional bonus chance to get a wound.
 * bare_wound_bonus - Additional bonus chance to get a wound if the bodypart is naked.
 * sharpness - Flag on whether the attack is edged or pointy
 * attack_direction - The direction the bodypart is attacked from, used to send blood flying in the opposite direction.
 * damage_source - The source of damage, typically a weapon.
 */
/obj/item/bodypart/proc/receive_damage(brute = 0, burn = 0, blocked = 0, updating_health = TRUE, required_bodytype = null, wound_bonus = 0, bare_wound_bonus = 0, sharpness = NONE, attack_direction = null, damage_source)
	SHOULD_CALL_PARENT(TRUE)

	var/hit_percent = (100-blocked)/100
	if((!brute && !burn) || hit_percent <= 0)
		return FALSE
	if(owner && (owner.status_flags & GODMODE))
		return FALSE	//godmode
	if(required_bodytype && !(bodytype & required_bodytype))
		return FALSE

	var/dmg_multi = CONFIG_GET(number/damage_multiplier) * hit_percent
	brute = round(max(brute * brute_modifier * wound_damage_multiplier * dmg_multi, 0), DAMAGE_PRECISION)
	burn = round(max(burn * burn_modifier * wound_damage_multiplier * dmg_multi, 0), DAMAGE_PRECISION)
	brute = max(0, brute - brute_reduction)
	burn = max(0, burn - burn_reduction)

	if(!brute && !burn)
		return FALSE

	/*
	// START WOUND HANDLING
	*/

	// what kind of wounds we're gonna roll for, take the greater between brute and burn, then if it's brute, we subdivide based on sharpness
	var/wounding_type = (brute > burn ? WOUND_BLUNT : WOUND_BURN)
	var/wounding_dmg = max(brute, burn)

	if(wounding_type == WOUND_BLUNT && sharpness)
		if(sharpness & SHARP_EDGED)
			wounding_type = WOUND_SLASH
		else if (sharpness & SHARP_POINTY)
			wounding_type = WOUND_PIERCE

	if(owner)
		var/mangled_state = get_mangled_state()
		var/easy_dismember = HAS_TRAIT(owner, TRAIT_EASYDISMEMBER) // if we have easydismember, we don't reduce damage when redirecting damage to different types (slashing weapons on mangled/skinless limbs attack at 100% instead of 50%)

		//Handling for bone only/flesh only(none right now)/flesh and bone targets
		switch(biological_state)
			// if we're bone only, all cutting attacks go straight to the bone
			if(BIO_BONE)
				if(wounding_type == WOUND_SLASH)
					wounding_type = WOUND_BLUNT
					wounding_dmg *= (easy_dismember ? 1 : 0.6)
				else if(wounding_type == WOUND_PIERCE)
					wounding_type = WOUND_BLUNT
					wounding_dmg *= (easy_dismember ? 1 : 0.75)
				if((mangled_state & BODYPART_MANGLED_BONE) && try_dismember(wounding_type, wounding_dmg, wound_bonus, bare_wound_bonus))
					return
			// note that there's no handling for BIO_FLESH since we don't have any that are that right now (slimepeople maybe someday)
			// standard humanoids
			if(BIO_FLESH_BONE)
				// if we've already mangled the skin (critical slash or piercing wound), then the bone is exposed, and we can damage it with sharp weapons at a reduced rate
				// So a big sharp weapon is still all you need to destroy a limb
				if((mangled_state & BODYPART_MANGLED_FLESH) && !(mangled_state & BODYPART_MANGLED_BONE) && sharpness)
					playsound(src, "sound/effects/wounds/crackandbleed.ogg", 100)
					if(wounding_type == WOUND_SLASH && !easy_dismember)
						wounding_dmg *= 0.6 // edged weapons pass along 60% of their wounding damage to the bone since the power is spread out over a larger area
					if(wounding_type == WOUND_PIERCE && !easy_dismember)
						wounding_dmg *= 0.75 // piercing weapons pass along 75% of their wounding damage to the bone since it's more concentrated
					wounding_type = WOUND_BLUNT
				else if((mangled_state & BODYPART_MANGLED_FLESH) && (mangled_state & BODYPART_MANGLED_BONE) && try_dismember(wounding_type, wounding_dmg, wound_bonus, bare_wound_bonus))
					return

		// now we have our wounding_type and are ready to carry on with wounds and dealing the actual damage
		if(wounding_dmg >= WOUND_MINIMUM_DAMAGE && wound_bonus != CANT_WOUND)
			check_wounding(wounding_type, wounding_dmg, wound_bonus, bare_wound_bonus, attack_direction, damage_source = damage_source)

	for(var/datum/wound/iter_wound as anything in wounds)
		iter_wound.receive_damage(wounding_type, wounding_dmg, wound_bonus)

	/*
	// END WOUND HANDLING
	*/

	//back to our regularly scheduled program, we now actually apply damage if there's room below limb damage cap
	var/can_inflict = max_damage - get_damage()
	var/total_damage = brute + burn
	if(total_damage > can_inflict && total_damage > 0) // TODO: the second part of this check should be removed once disabling is all done
		brute = round(brute * (can_inflict / total_damage),DAMAGE_PRECISION)
		burn = round(burn * (can_inflict / total_damage),DAMAGE_PRECISION)

	if(can_inflict <= 0)
		return FALSE
	if(brute)
		set_brute_dam(brute_dam + brute)
	if(burn)
		set_burn_dam(burn_dam + burn)

	if(owner)
		if(can_be_disabled)
			update_disabled()
		if(updating_health)
			owner.updatehealth()
	return update_bodypart_damage_state() || .

//Heals brute and burn damage for the organ. Returns 1 if the damage-icon states changed at all.
//Damage cannot go below zero.
//Cannot remove negative damage (i.e. apply damage)
/obj/item/bodypart/proc/heal_damage(brute, burn, required_bodytype, updating_health = TRUE)
	SHOULD_CALL_PARENT(TRUE)

	if(required_bodytype && !(bodytype & required_bodytype)) //So we can only heal certain kinds of limbs, ie robotic vs organic.
		return

	if(brute)
		set_brute_dam(round(max(brute_dam - brute, 0), DAMAGE_PRECISION))
	if(burn)
		set_burn_dam(round(max(burn_dam - burn, 0), DAMAGE_PRECISION))

	if(owner)
		if(can_be_disabled)
			update_disabled()
		if(updating_health)
			owner.updatehealth()
	cremation_progress = min(0, cremation_progress - ((brute_dam + burn_dam)*(100/max_damage)))
	return update_bodypart_damage_state()


///Proc to hook behavior associated to the change of the brute_dam variable's value.
/obj/item/bodypart/proc/set_brute_dam(new_value)
	PROTECTED_PROC(TRUE)

	if(brute_dam == new_value)
		return
	. = brute_dam
	brute_dam = new_value


///Proc to hook behavior associated to the change of the burn_dam variable's value.
/obj/item/bodypart/proc/set_burn_dam(new_value)
	PROTECTED_PROC(TRUE)

	if(burn_dam == new_value)
		return
	. = burn_dam
	burn_dam = new_value

//Returns total damage.
/obj/item/bodypart/proc/get_damage()
	var/total = brute_dam + burn_dam
	return total

//Checks disabled status thresholds
/obj/item/bodypart/proc/update_disabled()
	SHOULD_CALL_PARENT(TRUE)

	if(!owner)
		return

	if(!can_be_disabled)
		set_disabled(FALSE)
		CRASH("update_disabled called with can_be_disabled false")

	if(HAS_TRAIT(src, TRAIT_PARALYSIS))
		set_disabled(TRUE)
		return

	var/total_damage = brute_dam + burn_dam

	// this block of checks is for limbs that can be disabled, but not through pure damage (AKA limbs that suffer wounds, human/monkey parts and such)
	if(!disabling_threshold_percentage)
		if(total_damage < max_damage)
			last_maxed = FALSE
		else
			if(!last_maxed && owner.stat < UNCONSCIOUS)
				INVOKE_ASYNC(owner, TYPE_PROC_REF(/mob, emote), "scream")
			last_maxed = TRUE
		set_disabled(FALSE) // we only care about the paralysis trait
		return

	// we're now dealing solely with limbs that can be disabled through pure damage, AKA robot parts
	if(total_damage >= max_damage * disabling_threshold_percentage)
		if(!last_maxed)
			if(owner.stat < UNCONSCIOUS)
				INVOKE_ASYNC(owner, TYPE_PROC_REF(/mob, emote), "scream")
			last_maxed = TRUE
		set_disabled(TRUE)
		return

	if(bodypart_disabled && total_damage <= max_damage * 0.5) // reenable the limb at 50% health
		last_maxed = FALSE
		set_disabled(FALSE)


///Proc to change the value of the `disabled` variable and react to the event of its change.
/obj/item/bodypart/proc/set_disabled(new_disabled)
	SHOULD_CALL_PARENT(TRUE)
	PROTECTED_PROC(TRUE)

	if(bodypart_disabled == new_disabled)
		return
	. = bodypart_disabled
	bodypart_disabled = new_disabled

	if(!owner)
		return
	owner.update_health_hud() //update the healthdoll
	owner.update_body()

/// Proc to change the value of the `owner` variable and react to the event of its change.
/obj/item/bodypart/proc/set_owner(new_owner)
	SHOULD_CALL_PARENT(TRUE)
	if(owner == new_owner)
		return FALSE //`null` is a valid option, so we need to use a num var to make it clear no change was made.
	var/mob/living/carbon/old_owner = owner
	owner = new_owner
	SEND_SIGNAL(src, COMSIG_BODYPART_CHANGED_OWNER, new_owner, old_owner)
	var/needs_update_disabled = FALSE //Only really relevant if there's an owner
	if(old_owner)
		if(held_index)
			old_owner.on_lost_hand(src)
			if(old_owner.hud_used)
				var/atom/movable/screen/inventory/hand/hand = old_owner.hud_used.hand_slots["[held_index]"]
				if(hand)
					hand.update_appearance()
			old_owner.update_worn_gloves()
		if(speed_modifier)
			old_owner.update_bodypart_speed_modifier()
		if(LAZYLEN(bodypart_traits))
			old_owner.remove_traits(bodypart_traits, bodypart_trait_source)
		if(initial(can_be_disabled))
			if(HAS_TRAIT(old_owner, TRAIT_NOLIMBDISABLE))
				if(!owner || !HAS_TRAIT(owner, TRAIT_NOLIMBDISABLE))
					set_can_be_disabled(initial(can_be_disabled))
					needs_update_disabled = TRUE
			UnregisterSignal(old_owner, list(
				SIGNAL_REMOVETRAIT(TRAIT_NOLIMBDISABLE),
				SIGNAL_ADDTRAIT(TRAIT_NOLIMBDISABLE),
				SIGNAL_REMOVETRAIT(TRAIT_NOBLOOD),
				SIGNAL_ADDTRAIT(TRAIT_NOBLOOD),
				))
		UnregisterSignal(old_owner, COMSIG_ATOM_RESTYLE)
	if(owner)
		if(held_index)
			owner.on_added_hand(src, held_index)
			if(owner.hud_used)
				var/atom/movable/screen/inventory/hand/hand = owner.hud_used.hand_slots["[held_index]"]
				if(hand)
					hand.update_appearance()
			owner.update_worn_gloves()
		if(speed_modifier)
			owner.update_bodypart_speed_modifier()
		if(LAZYLEN(bodypart_traits))
			owner.add_traits(bodypart_traits, bodypart_trait_source)
		if(initial(can_be_disabled))
			if(HAS_TRAIT(owner, TRAIT_NOLIMBDISABLE))
				set_can_be_disabled(FALSE)
				needs_update_disabled = FALSE
			RegisterSignal(owner, SIGNAL_REMOVETRAIT(TRAIT_NOLIMBDISABLE), PROC_REF(on_owner_nolimbdisable_trait_loss))
			RegisterSignal(owner, SIGNAL_ADDTRAIT(TRAIT_NOLIMBDISABLE), PROC_REF(on_owner_nolimbdisable_trait_gain))
			// Bleeding stuff
			RegisterSignal(owner, SIGNAL_REMOVETRAIT(TRAIT_NOBLOOD), PROC_REF(on_owner_nobleed_loss))
			RegisterSignal(owner, SIGNAL_ADDTRAIT(TRAIT_NOBLOOD), PROC_REF(on_owner_nobleed_gain))

		if(needs_update_disabled)
			update_disabled()

		RegisterSignal(owner, COMSIG_ATOM_RESTYLE, PROC_REF(on_attempt_feature_restyle_mob))

	refresh_bleed_rate()
	return old_owner

/// Proc to hook behavior on bodypart removals.  Do not directly call. You're looking for [/obj/item/bodypart/proc/drop_limb()].
/obj/item/bodypart/proc/on_removal()
	if(!LAZYLEN(bodypart_traits))
		return

	owner.remove_traits(bodypart_traits, bodypart_trait_source)

/// Proc to change the value of the `can_be_disabled` variable and react to the event of its change.
/obj/item/bodypart/proc/set_can_be_disabled(new_can_be_disabled)
	PROTECTED_PROC(TRUE)
	SHOULD_CALL_PARENT(TRUE)

	if(can_be_disabled == new_can_be_disabled)
		return
	. = can_be_disabled
	can_be_disabled = new_can_be_disabled
	if(can_be_disabled)
		if(owner)
			if(HAS_TRAIT(owner, TRAIT_NOLIMBDISABLE))
				CRASH("set_can_be_disabled to TRUE with for limb whose owner has TRAIT_NOLIMBDISABLE")
			RegisterSignal(owner, SIGNAL_ADDTRAIT(TRAIT_PARALYSIS), PROC_REF(on_paralysis_trait_gain))
			RegisterSignal(owner, SIGNAL_REMOVETRAIT(TRAIT_PARALYSIS), PROC_REF(on_paralysis_trait_loss))
		update_disabled()
	else if(.)
		if(owner)
			UnregisterSignal(owner, list(
				SIGNAL_ADDTRAIT(TRAIT_PARALYSIS),
				SIGNAL_REMOVETRAIT(TRAIT_PARALYSIS),
				))
		set_disabled(FALSE)

///Called when TRAIT_PARALYSIS is added to the limb.
/obj/item/bodypart/proc/on_paralysis_trait_gain(obj/item/bodypart/source)
	PROTECTED_PROC(TRUE)
	SIGNAL_HANDLER

	if(can_be_disabled)
		set_disabled(TRUE)


/// Called when TRAIT_PARALYSIS is removed from the limb.
/obj/item/bodypart/proc/on_paralysis_trait_loss(obj/item/bodypart/source)
	PROTECTED_PROC(TRUE)
	SIGNAL_HANDLER

	if(can_be_disabled)
		update_disabled()

/// Called when TRAIT_NOLIMBDISABLE is added to the owner.
/obj/item/bodypart/proc/on_owner_nolimbdisable_trait_gain(mob/living/carbon/source)
	PROTECTED_PROC(TRUE)
	SIGNAL_HANDLER

	set_can_be_disabled(FALSE)

/// Called when TRAIT_NOLIMBDISABLE is removed from the owner.
/obj/item/bodypart/proc/on_owner_nolimbdisable_trait_loss(mob/living/carbon/source)
	PROTECTED_PROC(TRUE)
	SIGNAL_HANDLER

	set_can_be_disabled(initial(can_be_disabled))

/obj/item/bodypart/deconstruct(disassembled = TRUE)
	SHOULD_CALL_PARENT(TRUE)
	drop_organs()
	return ..()

// INTERNAL PROC, DO NOT USE
/// Properly sets us up to manage an inserted embeded object
/obj/item/bodypart/proc/_embed_object(obj/item/embed)
	if(embed in embedded_objects) // go away
		return
	// We don't need to do anything with projectile embedding, because it will never reach this point
	RegisterSignal(embed, COMSIG_ITEM_EMBEDDING_UPDATE, PROC_REF(embedded_object_changed))
	embedded_objects += embed
	refresh_bleed_rate()

// INTERNAL PROC, DO NOT USE
/// Cleans up any attachment we have to the embedded object, removes it from our list
/obj/item/bodypart/proc/_unembed_object(obj/item/unembed)
	UnregisterSignal(unembed, COMSIG_ITEM_EMBEDDING_UPDATE)
	embedded_objects -= unembed
	refresh_bleed_rate()

/obj/item/bodypart/proc/embedded_object_changed(obj/item/embedded_source)
	SIGNAL_HANDLER
	// Embedded objects effect bleed rate, gotta refresh lads
	refresh_bleed_rate()

/// Sets our generic bleedstacks
/obj/item/bodypart/proc/setBleedStacks(set_to)
	SHOULD_CALL_PARENT(TRUE)
	adjustBleedStacks(set_to - generic_bleedstacks)

/// Modifies our generic bleedstacks. You must use this to change the variable
/// Takes the amount to adjust by, and the lowest amount we're allowed to have post adjust
/obj/item/bodypart/proc/adjustBleedStacks(adjust_by, minimum = -INFINITY)
	if(!adjust_by)
		return
	var/old_bleedstacks = generic_bleedstacks
	generic_bleedstacks = max(generic_bleedstacks + adjust_by, minimum)

	// If we've started or stopped bleeding, we need to refresh our bleed rate
	if((old_bleedstacks <= 0 && generic_bleedstacks > 0) \
		|| (old_bleedstacks > 0 && generic_bleedstacks <= 0))
		refresh_bleed_rate()

/obj/item/bodypart/proc/on_owner_nobleed_loss(datum/source)
	SIGNAL_HANDLER
	refresh_bleed_rate()

/obj/item/bodypart/proc/on_owner_nobleed_gain(datum/source)
	SIGNAL_HANDLER
	refresh_bleed_rate()

/// Refresh the cache of our rate of bleeding sans any modifiers
/// ANYTHING ADDED TO THIS PROC NEEDS TO CALL IT WHEN IT'S EFFECT CHANGES
/obj/item/bodypart/proc/refresh_bleed_rate()
	SHOULD_NOT_OVERRIDE(TRUE)

	var/old_bleed_rate = cached_bleed_rate
	cached_bleed_rate = 0
	if(!owner)
		return

	if(HAS_TRAIT(owner, TRAIT_NOBLOOD) || !IS_ORGANIC_LIMB(src))
		if(cached_bleed_rate != old_bleed_rate)
			update_part_wound_overlay()
		return

	if(generic_bleedstacks > 0)
		cached_bleed_rate += 0.5

	for(var/obj/item/embeddies in embedded_objects)
		if(!embeddies.isEmbedHarmless())
			cached_bleed_rate += 0.25

	for(var/datum/wound/iter_wound as anything in wounds)
		cached_bleed_rate += iter_wound.blood_flow

	if(!cached_bleed_rate)
		QDEL_NULL(grasped_by)

	// Our bleed overlay is based directly off bleed_rate, so go aheead and update that would you?
	if(cached_bleed_rate != old_bleed_rate)
		update_part_wound_overlay()

	return cached_bleed_rate

/// Returns our bleed rate, taking into account laying down and grabbing the limb
/obj/item/bodypart/proc/get_modified_bleed_rate()
	var/bleed_rate = cached_bleed_rate
	if(owner.body_position == LYING_DOWN)
		bleed_rate *= 0.75
	if(grasped_by)
		bleed_rate *= 0.7
	return bleed_rate

/**
 * apply_gauze() is used to- well, apply gauze to a bodypart
 *
 * As of the Wounds 2 PR, all bleeding is now bodypart based rather than the old bleedstacks system, and 90% of standard bleeding comes from flesh wounds (the exception is embedded weapons).
 * The same way bleeding is totaled up by bodyparts, gauze now applies to all wounds on the same part. Thus, having a slash wound, a pierce wound, and a broken bone wound would have the gauze
 * applying blood staunching to the first two wounds, while also acting as a sling for the third one. Once enough blood has been absorbed or all wounds with the ACCEPTS_GAUZE flag have been cleared,
 * the gauze falls off.
 *
 * Arguments:
 * * gauze- Just the gauze stack we're taking a sheet from to apply here
 */
/obj/item/bodypart/proc/apply_gauze(obj/item/stack/gauze)
	if(!istype(gauze) || !gauze.absorption_capacity)
		return
	var/newly_gauzed = FALSE
	if(!current_gauze)
		newly_gauzed = TRUE
	QDEL_NULL(current_gauze)
	current_gauze = new gauze.type(src, 1)
	gauze.use(1)
	if(newly_gauzed)
		SEND_SIGNAL(src, COMSIG_BODYPART_GAUZED, gauze)

/**
 * seep_gauze() is for when a gauze wrapping absorbs blood or pus from wounds, lowering its absorption capacity.
 *
 * The passed amount of seepage is deducted from the bandage's absorption capacity, and if we reach a negative absorption capacity, the bandages falls off and we're left with nothing.
 *
 * Arguments:
 * * seep_amt - How much absorption capacity we're removing from our current bandages (think, how much blood or pus are we soaking up this tick?)
 */
/obj/item/bodypart/proc/seep_gauze(seep_amt = 0)
	if(!current_gauze)
		return
	current_gauze.absorption_capacity -= seep_amt
	if(current_gauze.absorption_capacity <= 0)
		owner.visible_message(span_danger("\The [current_gauze.name] on [owner]'s [name] falls away in rags."), span_warning("\The [current_gauze.name] on your [name] falls away in rags."), vision_distance=COMBAT_MESSAGE_RANGE)
		QDEL_NULL(current_gauze)
		SEND_SIGNAL(src, COMSIG_BODYPART_GAUZE_DESTROYED)

/obj/item/bodypart/emp_act(severity)
	. = ..()
	if(!(. & EMP_PROTECT_CONTENTS))
		for(var/obj/item/organ/organ as anything in organs)
			organ.emp_act(severity)

	if(. & EMP_PROTECT_WIRES || !owner || !IS_ROBOTIC_LIMB(src))
		return FALSE

	owner.visible_message(span_danger("[owner]'s [src.name] seems to malfunction!"))

	var/time_needed = 10 SECONDS
	var/brute_damage = 5 + 1.5 // Augments reduce brute damage by 5.
	var/burn_damage = 4 + 2.5 // As above, but for burn it's 4.

	if(severity == EMP_HEAVY)
		time_needed *= 2
		brute_damage *= 2
		burn_damage *= 2

	receive_damage(brute_damage, burn_damage)
	do_sparks(number = 1, cardinal_only = FALSE, source = owner)
	ADD_TRAIT(src, TRAIT_PARALYSIS, EMP_TRAIT)
	addtimer(CALLBACK(src, PROC_REF(remove_emp_traits)), time_needed)
	return TRUE

/obj/item/bodypart/proc/remove_emp_traits()
	REMOVE_TRAITS_IN(src, EMP_TRAIT)
