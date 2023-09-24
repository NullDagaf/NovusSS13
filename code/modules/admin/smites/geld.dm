/// Rips off all the genitals off the target
/datum/smite/geld
	name = "Geld"

/datum/smite/geld/effect(client/user, mob/living/target)
	. = ..()

	if (!iscarbon(target))
		to_chat(user, span_warning("This must be used on a carbon mob."), confidential = TRUE)
		return

	var/mob/living/carbon/carbon_target = target
	var/timer = 2 SECONDS
	for (var/obj/item/organ/genital/genital in carbon_target.organs)
		addtimer(CALLBACK(src, PROC_REF(geld), genital, carbon_target), timer)
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(playsound), carbon_target, 'sound/effects/cartoon_pop.ogg', 70), timer)
		addtimer(CALLBACK(carbon_target, TYPE_PROC_REF(/mob/living/, spin), 4, 1), timer - 0.4 SECONDS)
		timer += 2 SECONDS

/datum/smite/geld/proc/geld(obj/item/organ/genital/genital, mob/living/carbon/owner)
	playsound(get_turf(owner), 'sound/effects/dismember.ogg', 80, TRUE)
	genital.Remove(owner)
	genital.add_mob_blood(owner)
	var/turf/owner_location = owner.loc
	if(istype(owner_location))
		owner.add_splatter_floor(owner_location)
	genital.forceMove(owner_location)
	owner.bleed(rand(20, 40))
	var/direction = pick(GLOB.cardinals)
	var/t_range = rand(2,max(genital.throw_range/2, 2))
	genital.throw_at(get_ranged_target_turf(owner, direction, t_range), genital.throw_range, genital.throw_speed)
	owner.Knockdown(4 SECONDS)
	owner.visible_message(span_danger("[owner][owner.p_s()] [genital] flies off in an arc!"), \
						span_userdanger("Your [genital] flies off in an arc!"))
	INVOKE_ASYNC(owner, TYPE_PROC_REF(/mob/living/, emote), "scream")
