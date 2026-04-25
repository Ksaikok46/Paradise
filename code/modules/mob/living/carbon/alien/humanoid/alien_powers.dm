/proc/playsound_xenobuild(object)
	var/turf/object_turf = get_turf(object)

	if(!object_turf)
		return

	playsound(object_turf, pick('sound/creatures/alien/xeno_resin_build1.ogg', \
								'sound/creatures/alien/xeno_resin_build2.ogg', \
								'sound/creatures/alien/xeno_resin_build3.ogg'), 30)

//Small sprites
/datum/action/innate/small_sprite_alien
	name = "Переключить спрайт"
	desc = "Остальные продолжат видеть вас огромным."
	button_icon_state = "mech_cycle_equip_off"
	check_flags = AB_CHECK_CONSCIOUS
	var/small = FALSE
	var/small_icon = 'icons/mob/alien.dmi'
	var/small_icon_state = "alienq_running"

/datum/action/innate/small_sprite_alien/praetorian
	small_icon_state = "aliens_running"

/datum/action/innate/small_sprite_alien/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(!.)
		return

	if(!small)
		var/image/I = image(icon = small_icon, icon_state = small_icon_state, loc = owner)
		I.override = TRUE
		I.pixel_w -= owner.pixel_x
		I.pixel_z -= owner.pixel_y
		owner.add_alt_appearance(/datum/atom_hud/alternate_appearance/basic, "smallsprite", I, AA_TARGET_SEE_APPEARANCE | AA_MATCH_TARGET_OVERLAYS)
		small = TRUE
	else
		owner.remove_alt_appearance("smallsprite")
		small = FALSE

