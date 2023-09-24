/// Which department to put security officers in, when the config is enabled
/datum/preference/choiced/security_department
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	can_randomize = FALSE
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "prefered_security_department"

/datum/preference/choiced/security_department/init_possible_values()
	return GLOB.security_depts_prefs

/datum/preference/choiced/security_department/apply_to_human(mob/living/carbon/human/target, value)
	return

/datum/preference/choiced/security_department/create_default_value(datum/preferences/preferences)
	return SEC_DEPT_NONE

/datum/preference/choiced/security_department/is_accessible(datum/preferences/preferences)
	if (!..() || preferences.current_char_key != "main")
		return FALSE

	return !CONFIG_GET(flag/sec_start_brig)

