/obj/item/organ/brain
	name = "brain"
	desc = "Insane in the membrane, insane in the brain."
	icon = 'icons/obj/medical/organs/brain.dmi'
	icon_state = "brain"
	throw_speed = 3
	throw_range = 5
	layer = ABOVE_MOB_LAYER
	plane = GAME_PLANE_UPPER
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_BRAIN
	organ_flags = ORGAN_ORGANIC | ORGAN_VITAL
	visual = TRUE //debrain overlay, basically
	attack_verb_continuous = list("attacks", "slaps", "whacks")
	attack_verb_simple = list("attack", "slap", "whack")

	///The brain's organ variables are significantly more different than the other organs, with half the decay rate for balance reasons, and twice the maxHealth
	decay_factor = STANDARD_ORGAN_DECAY * 0.5 //30 minutes of decaying to result in a fully damaged brain, since a fast decay rate would be unfun gameplay-wise

	maxHealth = BRAIN_DAMAGE_DEATH
	low_threshold = BRAIN_DAMAGE_DEATH * 0.225
	high_threshold = BRAIN_DAMAGE_DEATH * 0.6

	organ_traits = list(TRAIT_ADVANCEDTOOLUSER, TRAIT_LITERATE, TRAIT_CAN_STRIP)

	var/suicided = FALSE
	var/mob/living/brain/brainmob = null
	/// If it's a fake brain with no brainmob assigned. Feedback messages will be faked as if it does have a brainmob. See changelings & dullahans.
	var/decoy_override = FALSE
	/// Two variables necessary for calculating whether we get a brain trauma or not
	var/damage_delta = 0

	/// Brain trauma datums that are currently affecting this brain.
	var/list/datum/brain_trauma/traumas = list()

	/// List of skillchip items, their location should be this brain.
	var/list/obj/item/skillchip/skillchips
	/// Maximum skillchip complexity we can support before they stop working. Do not reference this var directly and instead call get_max_skillchip_complexity()
	var/max_skillchip_complexity = 3
	/// Maximum skillchip slots available. Do not reference this var directly and instead call get_max_skillchip_slots()
	var/max_skillchip_slots = 5

	/// Whether or not we have suffered a hemispherectomy
	var/hemispherectomized = FALSE
	/// Overlay state we use when hemispherectomized, if any
	var/hemispherectomy_overlay = "hemispherectomy"
	/// The hemisphere object we create when we get hemispherectomized
	var/obj/item/hemisphere/hemisphere_type = /obj/item/hemisphere

	/// Stored hemispheres, in case we get a hemisphereaddectomy
	var/list/obj/item/hemisphere/extra_hemispheres
	/// Hemisphereaddectomies are shartcode, so we need to keep track of the organ traits before we got another fucking hemisphere
	var/list/old_organ_traits

	/// Megamind brains are at their peak potential, you can't add more hemispheres to them
	var/megamind = FALSE

/obj/item/organ/brain/Destroy() //copypasted from MMIs.
	if(brainmob)
		QDEL_NULL(brainmob)
	QDEL_LIST(traumas)
	QDEL_LIST(extra_hemispheres)

	destroy_all_skillchips()
	if(owner?.mind) //You aren't allowed to return to brains that don't exist
		owner.mind.set_current(null)
	return ..()

/obj/item/organ/brain/update_overlays()
	. = ..()
	if(hemispherectomized && hemispherectomy_overlay)
		. += hemispherectomy_overlay
	var/hemispheres = LAZYLEN(extra_hemispheres)
	if(hemispheres)
		var/pix_x = -hemispheres
		for(var/obj/item/hemisphere/hemisphere as anything in extra_hemispheres)
			var/mutable_appearance/hemisphere_appearance = mutable_appearance(hemisphere.icon, hemisphere.icon_state)
			hemisphere_appearance.pixel_x = pix_x
			pix_x += 2
			. += hemisphere_appearance

/obj/item/organ/brain/examine(mob/user)
	. = ..()
	if(LAZYLEN(skillchips))
		. += span_info("It has a skillchip embedded in it.")
	if(hemispherectomized)
		. += span_warning("Oh no... This brain has been mutilated...")
	else if(LAZYLEN(extra_hemispheres))
		for(var/hemisphere in extra_hemispheres)
			. += span_warning("It has \a [hemisphere] grafted onto it...")
	if(suicided)
		. += span_deadsay("It's started turning slightly grey. They must not have been able to handle the stress of it all.")
		return
	if((brainmob && (brainmob.client || brainmob.get_ghost())) || decoy_override)
		if(organ_flags & ORGAN_FAILING)
			. += span_notice("It seems to still have a bit of energy within it, but it's rather damaged... You may be able to restore it with some <b>mannitol</b>.")
		else if(damage >= maxHealth*0.5)
			. += span_notice("You can feel the small spark of life still left in this one, but it's got some bruises. You may be able to restore it with some <b>mannitol</b>.")
		else
			. += span_notice("You can feel the small spark of life still left in this one.")
	else
		. += span_deadsay("This one is completely devoid of life.")

/obj/item/organ/brain/attack(mob/living/carbon/C, mob/user)
	if(!istype(C))
		return ..()

	add_fingerprint(user)

	if(user.zone_selected != BODY_ZONE_HEAD)
		return ..()

	var/target_has_brain = C.get_organ_by_type(/obj/item/organ/brain)

	if(!target_has_brain && C.is_eyes_covered())
		to_chat(user, span_warning("You're going to need to remove [C.p_their()] head cover first!"))
		return

	//since these people will be dead M != usr

	if(!target_has_brain)
		if(!C.get_bodypart(BODY_ZONE_HEAD) || !user.temporarilyRemoveItemFromInventory(src))
			return
		var/msg = "[C] has [src] inserted into [C.p_their()] head by [user]."
		if(C == user)
			msg = "[user] inserts [src] into [user.p_their()] head!"

		C.visible_message(span_danger("[msg]"),
						span_userdanger("[msg]"))

		if(C != user)
			to_chat(C, span_notice("[user] inserts [src] into your head."))
			to_chat(user, span_notice("You insert [src] into [C]'s head."))
		else
			to_chat(user, span_notice("You insert [src] into your head.") )

		Insert(C)
	else
		return ..()

/obj/item/organ/brain/attackby(obj/item/O, mob/user, params)
	user.changeNext_move(CLICK_CD_MELEE)

	if(istype(O, /obj/item/borg/apparatus/organ_storage))
		return //Borg organ bags shouldn't be killing brains

	if(damage && O.is_drainable() && O.reagents.has_reagent(/datum/reagent/medicine/mannitol)) //attempt to heal the brain
		. = TRUE //don't do attack animation.
		if(brainmob?.health <= HEALTH_THRESHOLD_DEAD) //if the brain is fucked anyway, do nothing
			to_chat(user, span_warning("[src] is far too damaged, there's nothing else we can do for it!"))
			return

		user.visible_message(span_notice("[user] starts to slowly pour the contents of [O] onto [src]."), span_notice("You start to slowly pour the contents of [O] onto [src]."))
		if(!do_after(user, 3 SECONDS, src))
			to_chat(user, span_warning("You failed to pour the contents of [O] onto [src]!"))
			return

		user.visible_message(span_notice("[user] pours the contents of [O] onto [src], causing it to reform its original shape and turn a slightly brighter shade of pink."), span_notice("You pour the contents of [O] onto [src], causing it to reform its original shape and turn a slightly brighter shade of pink."))
		var/amount = O.reagents.get_reagent_amount(/datum/reagent/medicine/mannitol)
		var/healto = max(0, damage - amount * 2)
		O.reagents.remove_all(ROUND_UP(O.reagents.total_volume / amount * (damage - healto) * 0.5)) //only removes however much solution is needed while also taking into account how much of the solution is mannitol
		set_organ_damage(healto) //heals 2 damage per unit of mannitol, and by using "set_organ_damage", we clear the failing variable if that was up
		return

	// Cutting out skill chips.
	if(length(skillchips) && O.get_sharpness() == SHARP_EDGED)
		to_chat(user,span_notice("You begin to excise skillchips from [src]."))
		if(do_after(user, 15 SECONDS, target = src))
			for(var/chip in skillchips)
				var/obj/item/skillchip/skillchip = chip

				if(!istype(skillchip))
					stack_trace("Item of type [skillchip.type] qdel'd from [src] skillchip list.")
					qdel(skillchip)
					continue

				remove_skillchip(skillchip)

				if(skillchip.removable)
					skillchip.forceMove(drop_location())
					continue

				qdel(skillchip)

			skillchips = null
		return

	if(brainmob) //if we aren't trying to heal the brain, pass the attack onto the brainmob.
		O.attack(brainmob, user) //Oh noooeeeee

	if(O.force != 0 && !(O.item_flags & NOBLUDGEON))
		user.do_attack_animation(src)
		playsound(loc, 'sound/effects/meatslap.ogg', 50)
		set_organ_damage(maxHealth) //fails the brain as the brain was attacked, they're pretty fragile.
		visible_message(span_danger("[user] hits [src] with [O]!"))
		to_chat(user, span_danger("You hit [src] with [O]!"))

/obj/item/organ/brain/Insert(mob/living/carbon/receiver, special = FALSE, drop_if_replaced = TRUE, no_id_transfer = FALSE)
	. = ..()
	if(!.)
		return

	name = initial(name)
	// Special check for if you're trapped in a body you can't control because it's owned by a ling.
	if(receiver?.mind?.has_antag_datum(/datum/antagonist/changeling) && !no_id_transfer)
		if(brainmob && !(receiver.stat == DEAD || (HAS_TRAIT(receiver, TRAIT_DEATHCOMA))))
			to_chat(brainmob, span_danger("You can't feel your body! You're still just a brain!"))
		forceMove(receiver)
		receiver.update_body_parts()
		return

	// Not a ling? Now you get to assume direct control.
	if(brainmob)
		if(receiver.key)
			receiver.ghostize()

		if(brainmob.mind)
			brainmob.mind.transfer_to(receiver)
		else
			receiver.key = brainmob.key

		receiver.set_suicide(HAS_TRAIT(brainmob, TRAIT_SUICIDED))

		QDEL_NULL(brainmob)
	else
		receiver.set_suicide(suicided)

	for(var/datum/brain_trauma/trauma as anything in traumas)
		if(trauma.owner)
			if(trauma.owner == receiver)
				// if we're being special replaced, the trauma is already applied, so this is expected
				// but if we're not... this is likely a bug, and should be reported
				if(!special)
					stack_trace("A brain trauma ([trauma]) is being re-applied to its owning mob ([receiver])!")
				continue

			stack_trace("A brain trauma ([trauma]) is being applied to a new mob ([receiver]) when it's owned by someone else ([trauma.owner])!")
			continue

		trauma.owner = receiver
		trauma.on_gain()

/obj/item/organ/brain/Remove(mob/living/carbon/organ_owner, special = FALSE, no_id_transfer = FALSE)
	// Delete skillchips first as parent proc sets owner to null,
	// and skillchips need to know the brain's owner on try_deactivate_skillchip()
	if(!QDELETED(organ_owner) && length(skillchips))
		if(!special)
			to_chat(organ_owner, span_notice("You feel your skillchips enable emergency power saving mode, deactivating as your brain leaves your body..."))
		for(var/obj/item/skillchip/skillchip as anything in skillchips)
			// Run the try_ proc with force = TRUE.
			skillchip.try_deactivate_skillchip(silent = special, force = TRUE)

	. = ..()

	for(var/datum/brain_trauma/brain_trauma as anything in traumas)
		brain_trauma.on_lose(TRUE)
		brain_trauma.owner = null

	if(!QDELETED(organ_owner))
		organ_owner.clear_mood_event("brain_damage")
		if(!QDELETED(src) && !no_id_transfer)
			transfer_identity(organ_owner, silent = special)

/obj/item/organ/brain/transfer_to_limb(obj/item/bodypart/new_bodypart, special = FALSE)
	. = ..()
	//bastard
	if(!istype(new_bodypart, /obj/item/bodypart/head))
		return
	var/obj/item/bodypart/head/new_head = new_bodypart
	new_head.brain = src
	if(brainmob)
		brainmob.container = null
		new_head.brainmob = brainmob
		brainmob.forceMove(new_head)
		brainmob.set_stat(DEAD) //not exactly sure why this is necessary, but it was in the code before sooo
		brainmob = null

/obj/item/organ/brain/remove_from_limb(obj/item/bodypart/bodypart, special)
	. = ..()
	//bastard
	if(!istype(bodypart, /obj/item/bodypart/head))
		return
	var/obj/item/bodypart/head/head = bodypart
	head.brain = null
	if(head.brainmob)
		head.brainmob.container = null
		brainmob = head.brainmob
		brainmob.forceMove(src)
		head.brainmob = null

/obj/item/organ/brain/apply_organ_damage(damage_amount, maximum = maxHealth, required_organ_flag = NONE)
	. = ..()
	if(!owner)
		return
	if(damage >= (maxHealth * 0.3))
		owner.add_mood_event("brain_damage", /datum/mood_event/brain_damage)
	else
		owner.clear_mood_event("brain_damage")
	if(damage >= maxHealth && (owner.stat < DEAD)) //rip
		to_chat(owner, span_userdanger("The last spark of life in your brain fizzles out..."))
		owner.investigate_log("has been killed by brain damage.", INVESTIGATE_DEATHS)
		owner.death()

/obj/item/organ/brain/check_damage_thresholds(mob/organ_owner)
	. = ..()
	//if we're not more injured than before, return without gambling for a trauma
	if(damage <= prev_damage)
		return

	var/is_boosted = (organ_owner && HAS_MIND_TRAIT(organ_owner, TRAIT_SPECIAL_TRAUMA_BOOST))
	var/effective_prev_damage = (prev_damage/maxHealth * BRAIN_DAMAGE_DEATH)
	var/effective_damage = (damage/maxHealth * BRAIN_DAMAGE_DEATH)
	damage_delta = effective_damage - effective_prev_damage
	if(effective_damage >= BRAIN_DAMAGE_SEVERE)
		//Base chance is the hit damage; for every point of damage past the threshold the chance is increased by 1%
		if(prob(damage_delta * (1 + max(0, (effective_damage - BRAIN_DAMAGE_SEVERE)/100))))
			if(prob(20 + (is_boosted * 30)))
				gain_trauma_type(BRAIN_TRAUMA_SPECIAL, is_boosted ? TRAUMA_RESILIENCE_SURGERY : null, natural_gain = TRUE)
			else
				gain_trauma_type(BRAIN_TRAUMA_SEVERE, natural_gain = TRUE)
	else if(effective_damage >= BRAIN_DAMAGE_MILD)
		//Base chance is the hit damage; for every point of damage past the threshold the chance is increased by 1% //learn how to do your bloody math properly goddamnit
		if(prob(damage_delta * (1 + max(0, (effective_damage - BRAIN_DAMAGE_MILD)/100))))
			gain_trauma_type(BRAIN_TRAUMA_MILD, natural_gain = TRUE)

	if(owner && (owner.stat < UNCONSCIOUS)) //conscious or soft-crit
		var/brain_message
		if(effective_prev_damage < BRAIN_DAMAGE_MILD && effective_damage >= BRAIN_DAMAGE_MILD)
			brain_message = span_warning("You feel lightheaded.")
		else if(effective_prev_damage < BRAIN_DAMAGE_SEVERE && effective_damage >= BRAIN_DAMAGE_SEVERE)
			brain_message = span_warning("You feel less in control of your thoughts.")
		else if(effective_prev_damage < (BRAIN_DAMAGE_DEATH - 20) && effective_damage >= (BRAIN_DAMAGE_DEATH - 20))
			brain_message = span_warning("You can feel your mind flickering on and off...")

		if(.)
			. += "\n[brain_message]"
		else
			return brain_message

/obj/item/organ/brain/before_organ_replacement(obj/item/organ/replacement)
	. = ..()
	var/obj/item/organ/brain/replacement_brain = replacement
	if(!istype(replacement_brain))
		return

	// Transfer over skillcips to the new brain

	// If we have some sort of brain type or subtype change and have skillchips, engage the failsafe procedure!
	if(owner && length(skillchips) && (replacement_brain.type != type))
		activate_skillchip_failsafe(silent = TRUE)

	// Check through all our skillchips, remove them from this brain, add them to the replacement brain.
	for(var/chip in skillchips)
		var/obj/item/skillchip/skillchip = chip

		// We're technically doing a little hackery here by bypassing the procs, but I'm the one who wrote them
		// and when you know the rules, you can break the rules.

		// Technically the owning mob is the same. We don't need to activate or deactivate the skillchips.
		// All the skillchips themselves care about is what brain they're in.
		// Because the new brain will ultimately be owned by the same body, we can safely leave skillchip logic alone.

		// Directly change the new holding_brain.
		skillchip.holding_brain = replacement_brain
		//And move the actual obj into the new brain (contents)
		skillchip.forceMove(replacement_brain)

		// Directly add them to the skillchip list in the new brain.
		LAZYADD(replacement_brain.skillchips, skillchip)

	// Any skillchips has been transferred over, time to empty the list.
	LAZYCLEARLIST(skillchips)

	// Transfer over traumas as well
	for(var/datum/brain_trauma/trauma as anything in traumas)
		remove_trauma_from_traumas(trauma)
		replacement_brain.add_trauma_to_traumas(trauma)

// Brains REALLY like ghosting people - we need special tricks to avoid that, namely removing the old brain with no_id_transfer
/obj/item/organ/brain/replace_into(mob/living/carbon/new_owner, drop_if_replaced = FALSE)
	var/obj/item/organ/brain/old_brain = new_owner.get_organ_slot(ORGAN_SLOT_BRAIN)
	if(old_brain)
		old_brain.Remove(new_owner, special = TRUE, no_id_transfer = TRUE)
		if(drop_if_replaced)
			old_brain.forceMove(new_owner.drop_location())
		else
			qdel(old_brain)
	return Insert(new_owner, special = TRUE, drop_if_replaced = drop_if_replaced, no_id_transfer = TRUE)

/obj/item/organ/brain/machine_wash(obj/machinery/washing_machine/brainwasher)
	. = ..()
	if(HAS_TRAIT(brainwasher, TRAIT_BRAINWASHING))
		set_organ_damage(0)
		cure_all_traumas(TRAUMA_RESILIENCE_HEMISPHERECTOMY)
	else
		set_organ_damage(BRAIN_DAMAGE_DEATH)

// It would be ABSOLUTELY PSYCHOTIC if for some reason a species did not have a brain, but hey, who knows?
/obj/item/organ/brain/get_availability(datum/species/owner_species, mob/living/owner_mob)
	return owner_species.mutantbrain

/// This proc lets the mob's brain decide what bodypart to attack with in an unarmed strike.
/obj/item/organ/brain/proc/get_attacking_limb(mob/living/carbon/human/target)
	var/obj/item/bodypart/arm/active_hand = owner.get_active_hand()
	if((target.body_position == LYING_DOWN) || !active_hand)
		var/obj/item/bodypart/found_bodypart = owner.get_bodypart((active_hand.held_index % RIGHT_HANDS) ? BODY_ZONE_L_LEG : BODY_ZONE_R_LEG)
		return found_bodypart || active_hand
	return active_hand

/obj/item/organ/brain/proc/transfer_identity(mob/living/brainiac, silent = FALSE)
	name = "[brainiac.name]'s [initial(name)]"
	if(brainmob || decoy_override)
		return
	if(!brainiac.mind)
		return

	brainmob = new(src)
	brainmob.name = brainiac.real_name
	brainmob.real_name = brainiac.real_name
	brainmob.timeofdeath = brainiac.timeofdeath

	if(suicided)
		ADD_TRAIT(brainmob, TRAIT_SUICIDED, REF(src))

	if(brainiac.has_dna())
		var/mob/living/carbon/carbon_brainiac = brainiac
		if(!brainmob.stored_dna)
			brainmob.stored_dna = new /datum/dna/stored(brainmob)
		carbon_brainiac.dna.copy_dna(brainmob.stored_dna)
		// Hack, fucked dna needs to follow the brain to prevent memes, so we need to copy over the trait sources and shit
		for(var/source in GET_TRAIT_SOURCES(carbon_brainiac, TRAIT_BADDNA))
			ADD_TRAIT(brainmob, TRAIT_BADDNA, source)
	if(brainiac.mind && brainiac.mind.current)
		brainiac.mind.transfer_to(brainmob)
	if(!silent)
		to_chat(brainmob, span_notice("You feel slightly disoriented. That's normal when you're just a brain."))

/obj/item/organ/brain/zombie
	name = "zombie brain"
	desc = "This glob of green mass can't have much intelligence inside it."
	icon_state = "brain-greyscale"
	color = COLOR_GREEN_GRAY
	organ_traits = list(TRAIT_CAN_STRIP, TRAIT_PRIMITIVE)
	hemispherectomy_overlay = "hemispherectomy-greyscale"
	hemisphere_type = /obj/item/hemisphere/zombie

/obj/item/organ/brain/alien
	name = "alien brain"
	desc = "We barely understand the brains of terrestial animals. Who knows what we may find in the brain of such an advanced species?"
	icon_state = "brain-greyscale"
	color = COLOR_GREEN_GRAY
	organ_traits = list(TRAIT_CAN_STRIP, TRAIT_PRIMITIVE)
	hemispherectomy_overlay = "hemispherectomy-greyscale"
	hemisphere_type = /obj/item/hemisphere/alien

/obj/item/organ/brain/primitive //No like books and stompy metal men
	name = "primitive brain"
	desc = "This juicy piece of meat has a clearly underdeveloped frontal lobe."
	organ_traits = list(TRAIT_ADVANCEDTOOLUSER, TRAIT_CAN_STRIP, TRAIT_PRIMITIVE) // No literacy

/obj/item/organ/brain/golem
	name = "crystalline matrix"
	desc = "This collection of sparkling gems somehow allows a golem to think."
	icon_state = "brain-golem"
	color = COLOR_GOLEM_GRAY
	organ_flags = ORGAN_MINERAL
	organ_traits = list(TRAIT_ADVANCEDTOOLUSER, TRAIT_LITERATE, TRAIT_CAN_STRIP, TRAIT_ROCK_METAMORPHIC)
	hemispherectomy_overlay = "hemispherectomy-golem"
	hemisphere_type = /obj/item/hemisphere/golem

/obj/item/organ/brain/lustrous
	name = "lustrous brain"
	desc = "This is your brain on bluespace dust. Not even once."
	icon_state = "brain-bluespace"
	organ_traits = list(TRAIT_ADVANCEDTOOLUSER, TRAIT_LITERATE, TRAIT_CAN_STRIP, TRAIT_SPECIAL_TRAUMA_BOOST)
	hemispherectomy_overlay = "hemispherectomy-bluespace"
	hemisphere_type = /obj/item/hemisphere/lustrous

/obj/item/organ/brain/lustrous/before_organ_replacement(mob/living/carbon/organ_owner, special)
	. = ..()
	organ_owner.cure_trauma_type(/datum/brain_trauma/special/bluespace_prophet, TRAUMA_RESILIENCE_ABSOLUTE)

/obj/item/organ/brain/lustrous/on_insert(mob/living/carbon/organ_owner, special)
	. = ..()
	organ_owner.gain_trauma(/datum/brain_trauma/special/bluespace_prophet, TRAUMA_RESILIENCE_ABSOLUTE)

////////////////////////////////////TRAUMAS////////////////////////////////////////

/obj/item/organ/brain/proc/has_trauma_type(brain_trauma_type = /datum/brain_trauma, resilience = TRAUMA_RESILIENCE_ABSOLUTE)
	for(var/datum/brain_trauma/trauma as anything in traumas)
		if(istype(trauma, brain_trauma_type) && (trauma.resilience <= resilience))
			return trauma

/obj/item/organ/brain/proc/get_traumas_type(brain_trauma_type = /datum/brain_trauma, resilience = TRAUMA_RESILIENCE_ABSOLUTE)
	. = list()
	for(var/X in traumas)
		var/datum/brain_trauma/BT = X
		if(istype(BT, brain_trauma_type) && (BT.resilience <= resilience))
			. += BT

/obj/item/organ/brain/proc/can_gain_trauma(datum/brain_trauma/trauma, resilience, natural_gain = FALSE)
	if(!ispath(trauma))
		trauma = trauma.type
	if(!initial(trauma.can_gain))
		return FALSE
	if(!resilience)
		resilience = initial(trauma.resilience)

	var/resilience_tier_count = 0
	for(var/X in traumas)
		if(istype(X, trauma))
			return FALSE
		var/datum/brain_trauma/T = X
		if(resilience == T.resilience)
			resilience_tier_count++

	var/max_traumas
	switch(resilience)
		if(TRAUMA_RESILIENCE_BASIC)
			max_traumas = TRAUMA_LIMIT_BASIC
		if(TRAUMA_RESILIENCE_SURGERY)
			max_traumas = TRAUMA_LIMIT_SURGERY
		if(TRAUMA_RESILIENCE_WOUND)
			max_traumas = TRAUMA_LIMIT_WOUND
		if(TRAUMA_RESILIENCE_LOBOTOMY)
			max_traumas = TRAUMA_LIMIT_LOBOTOMY
		if(TRAUMA_RESILIENCE_MAGIC)
			max_traumas = TRAUMA_LIMIT_MAGIC
		if(TRAUMA_RESILIENCE_HEMISPHERECTOMY)
			max_traumas = TRAUMA_LIMIT_HEMISPHERECTOMY
		if(TRAUMA_RESILIENCE_ABSOLUTE)
			max_traumas = TRAUMA_LIMIT_ABSOLUTE

	if(natural_gain && resilience_tier_count >= max_traumas)
		return FALSE
	return TRUE

//Proc to use when directly adding a trauma to the brain, so extra args can be given
/obj/item/organ/brain/proc/gain_trauma(datum/brain_trauma/trauma, resilience, ...)
	var/list/arguments = list()
	if(args.len > 2)
		arguments = args.Copy(3)
	. = brain_gain_trauma(trauma, resilience, arguments)

//Direct trauma gaining proc. Necessary to assign a trauma to its brain. Avoid using directly.
/obj/item/organ/brain/proc/brain_gain_trauma(datum/brain_trauma/trauma, resilience, list/arguments)
	if(!can_gain_trauma(trauma, resilience))
		return FALSE

	var/datum/brain_trauma/actual_trauma
	if(ispath(trauma))
		if(!LAZYLEN(arguments))
			actual_trauma = new trauma() //arglist with an empty list runtimes for some reason
		else
			actual_trauma = new trauma(arglist(arguments))
	else
		actual_trauma = trauma

	if(actual_trauma.brain) //we don't accept used traumas here
		WARNING("brain_gain_trauma was given an already active trauma.")
		return FALSE

	add_trauma_to_traumas(actual_trauma)
	if(owner)
		actual_trauma.owner = owner
		SEND_SIGNAL(owner, COMSIG_CARBON_GAIN_TRAUMA, actual_trauma, resilience, arguments)
		actual_trauma.on_gain()
	if(resilience)
		actual_trauma.resilience = resilience
	SSblackbox.record_feedback("tally", "traumas", 1, actual_trauma.type)
	return actual_trauma

/// Adds the passed trauma instance to our list of traumas and links it to our brain.
/// DOES NOT handle setting up the trauma, that's done by [proc/brain_gain_trauma]!
/obj/item/organ/brain/proc/add_trauma_to_traumas(datum/brain_trauma/trauma)
	trauma.brain = src
	traumas += trauma

/// Removes the passed trauma instance to our list of traumas and links it to our brain
/// DOES NOT handle removing the trauma's effects, that's done by [/datum/brain_trauma/Destroy()]!
/obj/item/organ/brain/proc/remove_trauma_from_traumas(datum/brain_trauma/trauma)
	trauma.brain = null
	traumas -= trauma

//Add a random trauma of a certain subtype
/obj/item/organ/brain/proc/gain_trauma_type(brain_trauma_type = /datum/brain_trauma, resilience, natural_gain = FALSE)
	var/list/datum/brain_trauma/possible_traumas = list()
	for(var/T in subtypesof(brain_trauma_type))
		var/datum/brain_trauma/BT = T
		if(can_gain_trauma(BT, resilience, natural_gain) && initial(BT.random_gain))
			possible_traumas += BT

	if(!LAZYLEN(possible_traumas))
		return

	var/trauma_type = pick(possible_traumas)
	return gain_trauma(trauma_type, resilience)

//Cure a random trauma of a certain resilience level
/obj/item/organ/brain/proc/cure_trauma_type(brain_trauma_type = /datum/brain_trauma, resilience = TRAUMA_RESILIENCE_BASIC)
	var/list/traumas = get_traumas_type(brain_trauma_type, resilience)
	if(LAZYLEN(traumas))
		qdel(pick(traumas))

/obj/item/organ/brain/proc/cure_all_traumas(resilience = TRAUMA_RESILIENCE_BASIC)
	var/amount_cured = 0
	var/list/traumas = get_traumas_type(resilience = resilience)
	for(var/X in traumas)
		qdel(X)
		amount_cured++
	return amount_cured

/// Proc used to hemispherectomize the brain, and create the hemisphere object, plus remove any extra hemispheres
/obj/item/organ/brain/proc/hemispherectomize(mob/living/user, harmful = TRUE)
	var/atom/drop_location = owner?.drop_location() || drop_location()
	if(!hemispherectomized)
		maxHealth *= 0.5
		low_threshold *= 0.5
		high_threshold *= 0.5
		set_organ_damage(src.damage * 0.5)
		if(hemisphere_type)
			var/obj/item/hemisphere = new hemisphere_type(drop_location, src)
			if(user)
				user.put_in_hands(hemisphere)
	if(harmful)
		apply_organ_damage(60)
	//this cures all traumas caused by hemisphereaddectomies, as well as lobotomy ones
	cure_all_traumas(TRAUMA_RESILIENCE_HEMISPHERECTOMY)
	for(var/obj/item/hemisphere/hemisphere as anything in extra_hemispheres)
		//remove the old brain traits, but don't bother with traumas because we just cure everything up to hemisphereaddectomy resilience
		for(var/trait in hemisphere.brain_traits)
			if(trait in old_organ_traits)
				continue
			remove_organ_trait(trait)
		hemisphere.forceMove(drop_location)
		if(user)
			user.put_in_hands(hemisphere)
	extra_hemispheres = null
	old_organ_traits = null
	hemispherectomized = TRUE
	update_appearance()
	return TRUE

/// Proc used to merge a hemisphere into the brain, opposite of hemispherectomize basically
/obj/item/organ/brain/proc/hemisphereaddectomize(mob/living/user, obj/item/hemisphere/hemisphere, harmful = TRUE)
	// hemispherectomizing is a one way street, you can't go back!
	if(hemispherectomized)
		return FALSE
	if(!LAZYLEN(extra_hemispheres))
		old_organ_traits = LAZYCOPY(organ_traits)
	if(harmful)
		apply_organ_damage(60)
	cure_all_traumas(TRAUMA_RESILIENCE_LOBOTOMY)
	for(var/trait in hemisphere.brain_traits)
		if(trait in organ_traits)
			continue
		add_organ_trait(trait)
	for(var/trauma_type in hemisphere.brain_traumas)
		if(!can_gain_trauma(trauma_type, TRAUMA_RESILIENCE_HEMISPHERECTOMY))
			continue
		gain_trauma(trauma_type, TRAUMA_RESILIENCE_HEMISPHERECTOMY)
	if(owner?.mind)
		for(var/memory_path in hemisphere.stored_memories)
			var/datum/memory/memory = hemisphere.stored_memories[memory_path]
			owner.mind.memories[memory_path] = memory.quick_copy_memory(owner.mind)
	hemisphere.forceMove(src)
	LAZYADD(extra_hemispheres, hemisphere)
	if(LAZYLEN(extra_hemispheres) >= 4)
		if(owner)
			var/obj/item/organ/brain/megamind/megamind = new(loc)
			megamind.replace_into(owner)
		else
			new /obj/item/organ/brain/megamind(loc)
			qdel(src)
		return TRUE
	update_appearance()
	return TRUE

/// Proc shared between the hemispherectomy smite and surgery
/obj/item/organ/brain/proc/traumatic_hemispherectomy(mob/living/carbon/victim, silent = FALSE)
	victim ||= owner
	if(!owner)
		return FALSE
	if(victim.mind)
		var/list/antagonist_names = list()
		for(var/datum/antagonist/antagonist as anything in victim.mind.antag_datums)
			if(!(antagonist.antag_flags & FLAG_ANTAG_HEMISPHERECTOMIZABLE))
				continue
			antagonist_names += antagonist.name
			victim.mind.remove_antag_datum(antagonist)
		GLOB.hemispherectomy_victims[victim.mind.name] = antagonist_names
		victim.mind.wipe_memory()
	flash_stroke_screen(victim)
	if(!silent)
		to_chat(victim, span_userdanger(pick(GLOB.brain_injury_messages)))
	// Half of your brain is gone, let's see what kind of crippling brain damage you got as a gift!
	var/traumatic_events = pick(5;1, 4;2, 1;0)
	for(var/i in 1 to traumatic_events)
		if(HAS_MIND_TRAIT(victim, TRAIT_SPECIAL_TRAUMA_BOOST) && prob(50))
			victim.gain_trauma_type(BRAIN_TRAUMA_SPECIAL, TRAUMA_RESILIENCE_MAGIC)
		else
			victim.gain_trauma_type(BRAIN_TRAUMA_SEVERE, TRAUMA_RESILIENCE_MAGIC)
	return TRUE

/// This proc is used to jumpscare the victim with stroke images in certain scenarios
/obj/item/organ/brain/proc/flash_stroke_screen(mob/living/victim, fade_in = 1 SECONDS, fade_out = 1 SECONDS, silent = FALSE)
	victim ||= owner
	if(!victim)
		return
	var/atom/movable/screen/stroke = victim.overlay_fullscreen("stroke", /atom/movable/screen/fullscreen/stroke, rand(1, 9))
	stroke.alpha = 0
	animate(stroke, alpha = 255, time = fade_in, easing = BOUNCE_EASING | EASE_IN | EASE_OUT)
	addtimer(CALLBACK(src, PROC_REF(clear_stroke_screen), victim, fade_out), fade_in)
	if(!silent)
		victim.playsound_local(victim.loc, "sound/hallucinations/lobotomy[rand(1,4)].ogg", vol = 80, vary = FALSE)

/// This clears the victim's screen from the stroke image, if not qdeleted
/obj/item/organ/brain/proc/clear_stroke_screen(mob/living/victim, duration = 1 SECONDS)
	if(QDELETED(victim))
		return
	victim.clear_fullscreen("stroke", duration)
