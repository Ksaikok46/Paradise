/**
 * # Light item
 *
 * Parent type of light fittings (Light bulbs, light tubes)
 *
 * Will fit into empty [/obj/machinery/light] of the corresponding type
 */
/obj/item/light
	icon = 'icons/obj/lighting.dmi'
	force = 2
	throwforce = 5
	w_class = WEIGHT_CLASS_TINY
	blocks_emissive = FALSE
	/// Light status (LIGHT_OK | LIGHT_BURNED | LIGHT_BROKEN)
	var/status = LIGHT_OK
	/// How many times has the light been switched on/off?
	var/switchcount = 0
	/// Materials the light is made of
	materials = list(MAT_GLASS=100)
	/// Is the light rigged to explode?
	var/rigged = FALSE
	/// Light range
	var/brightness_range = 2
	/// Light intensity
	var/brightness_power = 1
	/// Light colour
	var/brightness_color = null

/obj/item/light/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/caltrop, force)
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_entered),
	)
	AddElement(/datum/element/connect_loc, loc_connections)

/obj/item/light/proc/on_entered(datum/source, mob/living/arrived, atom/old_loc, list/atom/old_locs)
	SIGNAL_HANDLER

	if(!isliving(arrived) || arrived.incorporeal_move || (arrived.movement_type & MOVETYPES_NOT_TOUCHING_GROUND))
		return

	playsound(loc, 'sound/effects/glass_step.ogg', 50, TRUE)
	if(status == LIGHT_BURNED || status == LIGHT_OK)
		shatter()

/obj/item/light/decompile_act(obj/item/matter_decompiler/C, mob/user)
	C.stored_comms["glass"] += 1
	C.stored_comms["metal"] += 1
	qdel(src)
	return TRUE

/**
 * # Light Tube
 *
 * For use in an empty [/obj/machinery/light]
 */
/obj/item/light/tube
	name = "light tube"
	desc = "A replacement light tube."
	icon_state = "ltube"
	base_icon_state = "ltube"
	item_state = "c_tube"
	brightness_range = 8

/obj/item/light/tube/large
	w_class = WEIGHT_CLASS_SMALL
	name = "large light tube"
	brightness_range = 15
	brightness_power = 2

/**
 * # Light Bulb
 *
 * For use in an empty [/obj/machinery/light/small]
 */
/obj/item/light/bulb
	name = "light bulb"
	desc = "A replacement light bulb."
	icon_state = "lbulb"
	base_icon_state = "lbulb"
	item_state = "contvapour"
	brightness_range = 5

/obj/item/light/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	..()
	shatter()

/obj/item/light/update_icon_state()
	switch(status)
		if(LIGHT_OK)
			icon_state = base_icon_state
		if(LIGHT_BURNED)
			icon_state = "[base_icon_state]-burned"
		if(LIGHT_BROKEN)
			icon_state = "[base_icon_state]-broken"

/obj/item/light/update_desc(updates = ALL)
	. = ..()
	switch(status)
		if(LIGHT_OK)
			desc = "A replacement [name]."
		if(LIGHT_BURNED)
			desc = "A burnt-out [name]."
		if(LIGHT_BROKEN)
			desc = "A broken [name]."

/obj/item/light/attackby(obj/item/I, mob/user, params)
	if(issyringe(I))
		add_fingerprint(user)
		var/obj/item/reagent_containers/syringe/syringe = I
		if(syringe.mode != 1)	// injecting
			to_chat(user, span_warning("The [syringe.name] should be in inject mode."))
			return ATTACK_CHAIN_PROCEED
		if(!syringe.reagents.total_volume)
			to_chat(user, span_warning("The [syringe.name] is empty."))
			return ATTACK_CHAIN_PROCEED
		to_chat(user, span_notice("You have injected the solution into [src]."))
		if(syringe.reagents.has_reagent("plasma", 5) || syringe.reagents.has_reagent("plasma_dust", 5))
			rigged = TRUE
			log_admin("LOG: [key_name(user)] injected [src] with plasma, rigging it to explode.")
			message_admins("LOG: [key_name_admin(user)] injected [src] with plasma, rigging it to explode.")
		syringe.reagents.clear_reagents()
		syringe.update_icon()
		return ATTACK_CHAIN_PROCEED_SUCCESS

	return ..()

/obj/item/light/attack(mob/living/target, mob/living/user, params, def_zone, skip_attack_anim = FALSE)
	. = ..()
	if(ATTACK_CHAIN_SUCCESS_CHECK(.))
		shatter()

/obj/item/light/attack_obj(obj/object, mob/living/user, params)
	. = ..()
	if(ATTACK_CHAIN_SUCCESS_CHECK(.))
		shatter()

/obj/item/light/proc/shatter()
	. = FALSE
	if(status == LIGHT_OK || status == LIGHT_BURNED)
		visible_message(span_warning("[src] shatters."), span_warning("You hear a small glass object shatter."))
		status = LIGHT_BROKEN
		force = 5
		sharp = TRUE
		playsound(loc, 'sound/effects/glasshit.ogg', 75, TRUE)
		update_appearance(UPDATE_ICON_STATE|UPDATE_DESC)
		return TRUE

/obj/item/light/suicide_act(mob/living/carbon/human/user)
	user.visible_message("<span class=suicide>[user] touches [src], burning [user.p_their()] hands off!</span>", "<span class=suicide>You touch [src], burning your hands off!</span>")

	for(var/oname in list(BODY_ZONE_PRECISE_L_HAND, BODY_ZONE_PRECISE_R_HAND))
		var/obj/item/organ/external/limb = user.get_organ(oname)
		if(limb)
			limb.droplimb(0, DROPLIMB_BURN)
	return FIRELOSS
