
/**
 * Component for clothing items that can pick up blood from decals and spread it around everywhere when walking, such as shoes or suits with integrated shoes.
 */
/datum/component/bloodysoles
	/// The type of the last grub pool we stepped in, used to decide the type of footprints to make
	var/last_blood_state = BLOOD_STATE_NOT_BLOODY

	/// How much of each grubby type we have on our feet
	var/list/bloody_shoes = list(BLOOD_STATE_HUMAN = 0,BLOOD_STATE_XENO = 0, BLOOD_STATE_OIL = 0, BLOOD_STATE_NOT_BLOODY = 0)

	/// The ITEM_SLOT_* slot the item is equipped on, if it is.
	var/equipped_slot

	/// The parent item but casted into atom type for easier use.
	var/atom/parent_atom

	/// Either the mob carrying the item, or the mob itself for the /feet component subtype
	var/mob/living/carbon/wielder

	/// The world.time when we last picked up blood
	var/last_pickup

/datum/component/bloodysoles/Initialize()
	if(!isclothing(parent))
		return COMPONENT_INCOMPATIBLE
	parent_atom = parent

/datum/component/bloodysoles/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ITEM_EQUIPPED, PROC_REF(on_equip))
	RegisterSignal(parent, COMSIG_ITEM_DROPPED, PROC_REF(on_drop))
	RegisterSignal(parent, COMSIG_COMPONENT_CLEAN_ACT, PROC_REF(on_clean))

/datum/component/bloodysoles/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_ITEM_EQUIPPED)
	UnregisterSignal(parent, COMSIG_ITEM_DROPPED)
	UnregisterSignal(parent, COMSIG_COMPONENT_CLEAN_ACT)
	unregister()

/**
 * Unregisters from the wielder if necessary
 */
/datum/component/bloodysoles/proc/unregister()
	if(!QDELETED(wielder))
		UnregisterSignal(wielder, COMSIG_MOVABLE_MOVED)
		UnregisterSignal(wielder, COMSIG_STEP_ON_BLOOD)
	wielder = null
	equipped_slot = null

/**
 * Returns true if the parent item is obscured by something else that the wielder is wearing
 */
/datum/component/bloodysoles/proc/is_obscured()
	return wielder.check_obscured_slots(TRUE) & equipped_slot

/**
 * Run to update the icon of the parent
 */
/datum/component/bloodysoles/proc/update_icon()
	var/obj/item/parent_item = parent
	parent_item.update_slot_icon()


/datum/component/bloodysoles/proc/reset_bloody_shoes()
	bloody_shoes = list(BLOOD_STATE_HUMAN = 0, BLOOD_STATE_XENO = 0, BLOOD_STATE_OIL = 0, BLOOD_STATE_NOT_BLOODY = 0)
	on_changed_bloody_shoes(BLOOD_STATE_NOT_BLOODY)

///lowers bloody_shoes[index] by adjust_by
/datum/component/bloodysoles/proc/adjust_bloody_shoes(index, adjust_by)
	bloody_shoes[index] = max(bloody_shoes[index] - adjust_by, 0)
	on_changed_bloody_shoes()

/datum/component/bloodysoles/proc/set_bloody_shoes(index, new_value)
	bloody_shoes[index] = new_value
	on_changed_bloody_shoes(index)

///called whenever the value of bloody_soles changes
/datum/component/bloodysoles/proc/on_changed_bloody_shoes(index)
	if(index && index != last_blood_state)
		last_blood_state = index
	if(!wielder)
		return
	if(bloody_shoes[index] <= BLOOD_FOOTPRINTS_MIN * 2)//need twice that amount to make footprints
		UnregisterSignal(wielder, COMSIG_MOVABLE_MOVED)
	else
		RegisterSignal(wielder, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved), override = TRUE)

/**
 * Run to equally share the blood between us and a decal
 */
/datum/component/bloodysoles/proc/share_blood(obj/effect/decal/cleanable/pool)
	// Share the blood between our boots and the blood pool
	var/total_bloodiness = pool.bloodiness + bloody_shoes[pool.blood_state]

	// We can however be limited by how much blood we can hold
	var/new_our_bloodiness = min(BLOOD_ITEM_MAX, total_bloodiness / 2)

	set_bloody_shoes(pool.blood_state, new_our_bloodiness)
	pool.bloodiness = total_bloodiness - new_our_bloodiness // Give the pool the remaining blood incase we were limited

	if(HAS_TRAIT(parent_atom, TRAIT_LIGHT_STEP)) //the character is agile enough to don't mess their clothing and hands just from one blood splatter at floor
		return TRUE

	if(pool.blood_state in GLOB.bloody_blood_states)
		parent_atom.add_blood_DNA(GET_ATOM_BLOOD_DNA(pool))
	update_icon()

/**
 * Find a blood decal on a turf that matches our last_blood_state
 */
/datum/component/bloodysoles/proc/find_pool_by_blood_state(turf/turfLoc, typeFilter = null)
	for(var/obj/effect/decal/cleanable/pool in turfLoc)
		if(pool.blood_state == last_blood_state && (!typeFilter || istype(pool, typeFilter)))
			return pool

/**
 * Adds the parent type to the footprint's shoe_types var
 */
/datum/component/bloodysoles/proc/add_parent_to_footprint(obj/effect/decal/cleanable/blood/footprints/FP)
	FP.shoe_types |= parent.type

/**
 * Called when the parent item is equipped by someone
 *
 * Used to register our wielder
 */
/datum/component/bloodysoles/proc/on_equip(datum/source, mob/equipper, slot)
	SIGNAL_HANDLER

	if(!iscarbon(equipper))
		return
	var/obj/item/parent_item = parent
	if(!(parent_item.slot_flags & slot))
		unregister()
		return

	equipped_slot = slot
	wielder = equipper
	if(bloody_shoes[last_blood_state] > BLOOD_FOOTPRINTS_MIN * 2)
		RegisterSignal(wielder, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(wielder, COMSIG_STEP_ON_BLOOD, PROC_REF(on_step_blood))

/**
 * Called when the parent item has been dropped
 *
 * Used to deregister our wielder
 */
/datum/component/bloodysoles/proc/on_drop(datum/source, mob/dropper)
	SIGNAL_HANDLER

	unregister()

/**
 * Called when the wielder has moved
 *
 * Used to make bloody footprints on the ground
 */
/datum/component/bloodysoles/proc/on_moved(datum/source, OldLoc, Dir, Forced)
	SIGNAL_HANDLER

	if(bloody_shoes[last_blood_state] == 0)
		return
	if(QDELETED(wielder) || is_obscured())
		return
	if(wielder.body_position == LYING_DOWN || !wielder.has_gravity(wielder.loc))
		return

	var/half_our_blood = bloody_shoes[last_blood_state] / 2

	// Add footprints in old loc if we have enough cream
	var/footprint_type = get_footprint_type()
	if(half_our_blood >= BLOOD_FOOTPRINTS_MIN)
		var/turf/oldLocTurf = get_turf(OldLoc)
		var/obj/effect/decal/cleanable/blood/footprints/oldLocFP = find_pool_by_blood_state(oldLocTurf, footprint_type) //always pretend we are stepping on blood for convenience
		//trust me it will be ok the variables are copypasted regardless
		if(oldLocFP)
			// Footprints found in the tile we left, add us to it
			add_parent_to_footprint(oldLocFP)
			if (!(oldLocFP.exited_dirs & wielder.dir))
				oldLocFP.exited_dirs |= wielder.dir
				oldLocFP.update_appearance()
		else if(find_pool_by_blood_state(oldLocTurf))
			// No footprints in the tile we left, but there was some other blood pool there. Add exit footprints on it
			adjust_bloody_shoes(last_blood_state, half_our_blood)
			update_icon()

			oldLocFP = new footprint_type(oldLocTurf)
			if(!QDELETED(oldLocFP)) ///prints merged
				oldLocFP.blood_state = last_blood_state
				oldLocFP.exited_dirs |= wielder.dir
				add_parent_to_footprint(oldLocFP)
				oldLocFP.bloodiness = half_our_blood
				oldLocFP.add_blood_DNA(GET_ATOM_BLOOD_DNA(parent_atom))
				oldLocFP.update_appearance()

			half_our_blood = bloody_shoes[last_blood_state] / 2

	// If we picked up the blood on this tick in on_step_blood, don't make footprints at the same place
	if(last_pickup && last_pickup == world.time)
		return

	// Create new footprints
	if(half_our_blood >= BLOOD_FOOTPRINTS_MIN)
		adjust_bloody_shoes(last_blood_state, half_our_blood)
		update_icon()

		var/obj/effect/decal/cleanable/blood/footprints/FP = new footprint_type(get_turf(parent_atom)) //always pretend we are stepping on blood for convenience
		//trust me it will be ok the variables are copypasted regardless
		if(!QDELETED(FP)) ///prints merged
			FP.blood_state = last_blood_state
			FP.entered_dirs |= wielder.dir
			add_parent_to_footprint(FP)
			FP.bloodiness = half_our_blood
			FP.add_blood_DNA(GET_ATOM_BLOOD_DNA(parent_atom))
			FP.update_appearance()


/**
 * Called when the wielder steps in a pool of blood
 *
 * Used to make the parent item bloody
 */
/datum/component/bloodysoles/proc/on_step_blood(datum/source, obj/effect/decal/cleanable/pool)
	SIGNAL_HANDLER

	if(QDELETED(wielder) || is_obscured())
		return

	if(istype(pool, get_footprint_type()) && pool.blood_state == last_blood_state)
		// The pool we stepped in was actually footprints with the same type
		var/obj/effect/decal/cleanable/blood/footprints/pool_FP = pool //always pretend we are stepping on blood for convenience
		//trust me it will be ok the variables are copypasted regardless
		add_parent_to_footprint(pool_FP)
		if((bloody_shoes[last_blood_state] / 2) >= BLOOD_FOOTPRINTS_MIN && !(pool_FP.entered_dirs & wielder.dir))
			// If our feet are bloody enough, add an entered dir
			pool_FP.entered_dirs |= wielder.dir
			pool_FP.update_appearance()

	share_blood(pool)

	last_pickup = world.time

/**
 * Called when the parent item is being washed
 */
/datum/component/bloodysoles/proc/on_clean(datum/source, clean_types)
	SIGNAL_HANDLER

	if(!(clean_types & CLEAN_TYPE_BLOOD) || last_blood_state == BLOOD_STATE_NOT_BLOODY)
		return NONE

	reset_bloody_shoes()
	update_icon()
	return COMPONENT_CLEANED

/datum/component/bloodysoles/proc/get_footprint_type()
	var/footprint_type = /obj/effect/decal/cleanable/blood/footprints
	switch(last_blood_state)
		if(BLOOD_STATE_CUM)
			footprint_type = /obj/effect/decal/cleanable/blood/footprints/cum
		if(BLOOD_STATE_FEMCUM)
			footprint_type = /obj/effect/decal/cleanable/blood/footprints/cum/femcum
	return footprint_type

/**
 * Like its parent but can be applied to carbon mobs instead of clothing items
 */
/datum/component/bloodysoles/feet
	var/static/mutable_appearance/bloody_feet
	var/static/mutable_appearance/cummy_feet
	var/static/mutable_appearance/femcummy_feet

/datum/component/bloodysoles/feet/Initialize()
	if(!iscarbon(parent))
		return COMPONENT_INCOMPATIBLE
	parent_atom = parent
	wielder = parent

	if(!bloody_feet)
		bloody_feet = mutable_appearance('icons/effects/blood.dmi', "shoeblood", SHOES_LAYER)
	if(!cummy_feet)
		cummy_feet = mutable_appearance('icons/effects/cum.dmi', "shoecum", SHOES_LAYER)
		cummy_feet.color = COLOR_CUM
	if(!femcummy_feet)
		femcummy_feet = mutable_appearance('icons/effects/femcum.dmi', "shoefemcum", SHOES_LAYER)
		femcummy_feet.color = COLOR_FEMCUM

/datum/component/bloodysoles/feet/RegisterWithParent()
	RegisterSignal(parent, COMSIG_COMPONENT_CLEAN_ACT, PROC_REF(on_clean))
	RegisterSignal(parent, COMSIG_STEP_ON_BLOOD, PROC_REF(on_step_blood))
	RegisterSignal(parent, COMSIG_CARBON_UNEQUIP_SHOECOVER, PROC_REF(unequip_shoecover))
	RegisterSignal(parent, COMSIG_CARBON_EQUIP_SHOECOVER, PROC_REF(equip_shoecover))
	RegisterSignal(parent, COMSIG_CARBON_POST_ATTACH_LIMB, PROC_REF(on_attached_limb))
	RegisterSignal(parent, COMSIG_CARBON_POST_REMOVE_LIMB, PROC_REF(on_removed_limb))

/datum/component/bloodysoles/feet/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_COMPONENT_CLEAN_ACT)
	UnregisterSignal(parent, COMSIG_STEP_ON_BLOOD)
	UnregisterSignal(parent, COMSIG_CARBON_UNEQUIP_SHOECOVER)
	UnregisterSignal(parent, COMSIG_CARBON_EQUIP_SHOECOVER)
	UnregisterSignal(parent, COMSIG_CARBON_POST_ATTACH_LIMB)
	UnregisterSignal(parent, COMSIG_CARBON_POST_REMOVE_LIMB)
	unregister()

/datum/component/bloodysoles/feet/update_icon()
	if(!ishuman(wielder) || HAS_TRAIT(wielder, TRAIT_NO_BLOOD_OVERLAY))
		return
	var/mob/living/carbon/human/human_wielder = wielder
	var/chosen_overlay = bloody_feet
	switch(last_blood_state)
		if(BLOOD_STATE_CUM)
			chosen_overlay = cummy_feet
		if(BLOOD_STATE_FEMCUM)
			chosen_overlay = femcummy_feet
	if(bloody_shoes[last_blood_state] > 0 && !is_obscured())
		human_wielder.remove_overlay(SHOES_LAYER)
		if(human_wielder.num_legs >= 2)
			human_wielder.overlays_standing[SHOES_LAYER] = chosen_overlay
		human_wielder.apply_overlay(SHOES_LAYER)
	else
		human_wielder.update_worn_shoes()

/datum/component/bloodysoles/feet/add_parent_to_footprint(obj/effect/decal/cleanable/blood/footprints/FP)
	if(!ishuman(wielder))
		FP.species_types |= "unknown"
		return

	// Find any leg of our human and add that to the footprint, instead of the default which is to just add the human type
	for(var/X in wielder.bodyparts)
		var/obj/item/bodypart/affecting = X
		if(affecting.body_part == LEG_RIGHT || affecting.body_part == LEG_LEFT)
			if(!affecting.bodypart_disabled)
				FP.species_types |= affecting.limb_id
				break


/datum/component/bloodysoles/feet/is_obscured()
	if(wielder.shoes)
		return TRUE
	return wielder.check_obscured_slots(TRUE) & ITEM_SLOT_FEET

/datum/component/bloodysoles/feet/on_moved(datum/source, OldLoc, Dir, Forced)
	if(wielder.num_legs < 2)
		return

	return ..()

/datum/component/bloodysoles/feet/on_step_blood(datum/source, obj/effect/decal/cleanable/pool)
	if(wielder.num_legs < 2)
		return

	return ..()

/datum/component/bloodysoles/feet/proc/unequip_shoecover(datum/source)
	SIGNAL_HANDLER

	update_icon()

/datum/component/bloodysoles/feet/proc/equip_shoecover(datum/source)
	SIGNAL_HANDLER

	update_icon()

/datum/component/bloodysoles/feet/proc/on_attached_limb(mob/living/carbon/source, obj/item/bodypart/limb, special)
	SIGNAL_HANDLER

	if(istype(limb, /obj/item/bodypart/leg))
		update_icon()

/datum/component/bloodysoles/feet/proc/on_removed_limb(mob/living/carbon/source, obj/item/bodypart/limb, special, dismembered)
	SIGNAL_HANDLER

	if(istype(limb, /obj/item/bodypart/leg))
		update_icon()
