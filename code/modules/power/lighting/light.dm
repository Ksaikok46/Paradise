/**
 * # Light fixture
 *
 * The standard light tube fixture
 */
/obj/machinery/light
	name = "light fixture"
	icon = 'icons/obj/lighting.dmi'
	base_icon_state = "tube"
	icon_state = "tube1"
	desc = "A lighting fixture."
	anchored = TRUE
	layer = WALL_OBJ_LAYER
	max_integrity = 10
	armor = list(MELEE = 0, BULLET = 0, LASER = 0, ENERGY = 0, BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)
	use_power = ACTIVE_POWER_USE
	idle_power_usage = 2
	active_power_usage = 20
	power_channel = LIGHT //Lights are calc'd via area so they dont need to be in the machine list
	cares_about_temperature = TRUE
	light_angle = 170
	///What overlay the light should use
	var/overlay_icon = 'icons/obj/lighting_overlay.dmi'
	/// Is the light on or off?
	var/on = FALSE
	/// If the light state has changed since the last 'update()', also update the power requirements
	var/light_state = FALSE
	/// How much power does it use?
	var/static_power_used = 0
	/// Light range (Also used in power calculation)
	var/brightness_range = 8
	/// Light intensity
	var/brightness_power = 1
	/// Light colour when on
	var/brightness_color = LIGHT_COLOR_DEFAULT
	/// Light fixture status (LIGHT_OK | LIGHT_EMPTY | LIGHT_BURNED | LIGHT_BROKEN)
	var/status = LIGHT_OK
	/// Is the light currently flickering?
	var/flickering = FALSE
	/// Was this light extinguished with an antag ability? Used to ovveride flicker events
	var/extinguished = FALSE

	/// Item type of the light bulb
	var/light_type = /obj/item/light/tube
	/// Type of light bulb that goes into the fixture
	var/fitting = "tube"
	/// What light construct type to turn into when we are deconstructed
	var/obj/machinery/light_construct/deconstruct_type = /obj/machinery/light_construct
	/// How many times has the light been switched on/off? (This is used to calc the probability the light burns out)
	var/switchcount = 0
	/// Is the light rigged to explode?
	var/rigged = FALSE
	/// Materials the light is made of
	var/lightmaterials = list(MAT_GLASS=100)

	/// Currently in night shift mode?
	var/nightshift_enabled = FALSE
	/// Allowed to be switched to night shift mode?
	var/nightshift_allowed = TRUE
	/// Light range when in night shift mode
	var/nightshift_light_range = 8
	///Alpha of the nightshift light
	var/nightshift_light_power = 0.45
	///Basecolor of the nightshift light
	var/nightshift_light_color = "#FFDDCC"

	/// If true, the light is in emergency mode
	var/emergency_mode = FALSE
	/// If true, the light swaps over to emergency colour
	var/fire_mode = FALSE
	/// If true, this light cannot ever have an emergency mode
	var/no_emergency = FALSE
	///Multiplier for this light's base brightness during a cascade
	var/bulb_major_emergency_brightness_mul = 0.75
	///Colour of the light when major emergency mode is on
	var/bulb_emergency_colour = "#ff4e4e"
	///Multiplier for this light's base brightness in low power power mode
	var/bulb_low_power_brightness_mul = 0.25
	///Determines the colour of the light while it's in low power mode
	var/bulb_low_power_colour = COLOR_VIVID_RED
	///The multiplier for determining the light's power in low power mode
	var/bulb_low_power_pow_mul = 0.75
	///The minimum value for the light's power in low power mode
	var/bulb_low_power_pow_min = 0.5

	///The Light range to use when working in fire alarm status
	var/fire_brightness = 9
	///The Light power to use when working in fire alarm status
	var/fire_power = 0.5
	///The Light colour to use when working in fire alarm status
	var/fire_colour = COLOR_FIRE_LIGHT_RED
	///Power usage - W per unit of luminosity
	var/power_consumption_rate = 20
	///break if moved, if false also makes it ignore if the wall its on breaks
	var/break_if_moved = TRUE

/**
 * # Small light fixture
 *
 * The smaller light bulb fixture
 */
/obj/machinery/light/small
	icon_state = "bulb1"
	desc = "A compact and cheap light fixture, perfect for keeping maintenance tunnels appropriately spooky."
	base_icon_state = "bulb"
	fitting = "bulb"
	brightness_range = 4
	brightness_color = "#ffebb0"
	nightshift_light_range = 4
	nightshift_light_color = "#ffefa0"
	light_type = /obj/item/light/bulb
	deconstruct_type = /obj/machinery/light_construct/small

/obj/machinery/light/spot
	name = "spotlight"
	light_type = /obj/item/light/tube/large
	brightness_range = 12
	brightness_power = 4

/obj/machinery/light/floor
	name = "floor light"
	desc = "A lightbulb you can walk on without breaking it, amazing."
	icon_state = "floor1"
	base_icon_state = "floor"
	fitting = "bulb"
	light_type = /obj/item/light/bulb
	deconstruct_type = /obj/machinery/light_construct/floor
	brightness_range = 6
	nightshift_light_range = 6
	layer = ABOVE_OPEN_TURF_LAYER
	plane = FLOOR_PLANE

/obj/machinery/light/built
	status = LIGHT_EMPTY

/obj/machinery/light/small/built
	status = LIGHT_EMPTY

/obj/machinery/light/floor/built
	status = LIGHT_EMPTY

// create a new lighting fixture
/obj/machinery/light/Initialize(mapload)
	. = ..()

	if(is_station_level(z))
		RegisterSignal(SSsecurity_level, COMSIG_SECURITY_LEVEL_CHANGE_PLANNED, PROC_REF(on_security_level_change_planned))
		RegisterSignal(SSsecurity_level, COMSIG_SECURITY_LEVEL_CHANGED, PROC_REF(on_security_level_update))

	var/area/our_area = get_area(src)
	if(mapload)
		if(prob(brightness_power))
			break_light_tube(TRUE)
	else
		//sync up nightshift lighting for player made lights
		var/obj/machinery/power/apc/temp_apc = our_area.apc
		nightshift_enabled = temp_apc?.nightshift_lights

	// Light projects out backwards from the dir of the light
	set_light(l_dir = REVERSE_DIR(dir))
	RegisterSignal(src, COMSIG_LIGHT_EATER_ACT, PROC_REF(on_light_eater))
	AddElement(/datum/element/contextual_screentip_bare_hands, lmb_text = "Вытащить лампочку")

	if(our_area && !our_area.requires_power)
		on = TRUE

	LAZYADD(our_area.lights_cache, src)
	update(FALSE, mapload ? FALSE : TRUE)

/obj/machinery/light/proc/on_security_level_change_planned(datum/source, previous_level_number, new_level_number)
	SIGNAL_HANDLER

	if(status != LIGHT_OK)
		return

	if(new_level_number != SEC_LEVEL_EPSILON)
		return

	fire_mode = FALSE
	emergency_mode = TRUE
	on = FALSE
	INVOKE_ASYNC(src, PROC_REF(update), FALSE)

/obj/machinery/light/proc/on_security_level_update(datum/source, previous_level_number, new_level_number)
	SIGNAL_HANDLER

	if(status != LIGHT_OK || !has_power())
		return

	if(new_level_number >= SEC_LEVEL_EPSILON)
		fire_mode = TRUE
		emergency_mode = TRUE
		on = FALSE
	else
		fire_mode = FALSE
		emergency_mode = FALSE
		on = TRUE

	INVOKE_ASYNC(src, PROC_REF(update), FALSE)

/obj/machinery/light/Destroy()
	var/area/A = get_area(src)
	if(A)
		on = FALSE
		LAZYREMOVE(A.lights_cache, src)
	UnregisterSignal(SSsecurity_level, list(COMSIG_SECURITY_LEVEL_CHANGE_PLANNED, COMSIG_SECURITY_LEVEL_CHANGED, COMSIG_LIGHT_EATER_ACT))
	return ..()

/obj/machinery/light/Move()
	if(status != LIGHT_BROKEN && break_if_moved)
		break_light_tube(TRUE)
	return ..()

/obj/machinery/light/setDir(newdir)
	. = ..()
	set_light(l_dir = REVERSE_DIR(dir))

// If we're adjacent to the source, we make this sorta indentation for our light to ensure it stays lit (and to make distances look right)
// By shifting the light position we use forward a bit, towards something that isn't off by 0.5 from being in angle
// Because angle calculation is kinda harsh it's hard to find a happy point between fulldark and fullbright for the corners behind the light. this is good enough tho
/obj/machinery/light/get_light_offset()
	var/list/hand_back = ..()
	var/list/dir_offset = dir2offset(REVERSE_DIR(dir))
	hand_back[1] += dir_offset[1] * 0.5
	hand_back[2] += dir_offset[2] * 0.5
	return hand_back

/obj/machinery/light/floor/get_light_offset()
	return list(0, 0)

/obj/machinery/light/update_icon_state()
	switch(status)
		if(LIGHT_OK)
			if(emergency_mode || fire_mode)
				icon_state = "[base_icon_state]_emergency"
			else
				icon_state = "[base_icon_state]"
		if(LIGHT_EMPTY)
			icon_state = "[base_icon_state]-empty"
			on = FALSE
		if(LIGHT_BURNED)
			icon_state = "[base_icon_state]-burned"
			on = FALSE
		if(LIGHT_BROKEN)
			icon_state = "[base_icon_state]-broken"
			on = FALSE

/obj/machinery/light/update_overlays()
	. = ..()
	if(!on || status != LIGHT_OK)
		return

	. += emissive_appearance(overlay_icon, "[base_icon_state]", src, alpha = src.alpha)

	if(flickering)
		. += mutable_appearance(overlay_icon, "[base_icon_state]_flickering")
		return

	if(nightshift_enabled || emergency_mode)
		. += mutable_appearance(overlay_icon, "[base_icon_state]_emergency")
		return

	if(nightshift_enabled)
		. += mutable_appearance(overlay_icon, "[base_icon_state]_nightshift")
		return

	. += mutable_appearance(overlay_icon, base_icon_state)

/**
 * Updates the light's properties
 *
 * Updates the icon_state, luminosity, colour, and power usage of the light.
 * Also handles rigged light bulbs exploding.
 * Arguments:
 * * trigger - Should this update make the light explode/burn out? (Defaults to TRUE)
 * * play_sound - Will the lightbulb play a sound when it's turned on.
 */
/obj/machinery/light/proc/update(trigger = TRUE, play_sound = TRUE)
	var/area/current_area = get_area(src)
	UnregisterSignal(current_area, COMSIG_AREA_POWER_CHANGE)
	switch(status)
		if(LIGHT_BROKEN, LIGHT_BURNED, LIGHT_EMPTY)
			on = FALSE

	emergency_mode = FALSE
	if(fire_mode)
		set_emergency_lights()

	var/light_range = brightness_range
	var/light_power = brightness_power
	var/light_color = brightness_color
	if(on)
		extinguished = FALSE
		if(color)
			light_color = color

		if(flickering)
			light_range = brightness_range * bulb_low_power_brightness_mul
			light_power = bulb_low_power_pow_mul
			light_color = nightshift_light_color

		else if(fire_mode)
			light_range = fire_brightness
			light_power = fire_power
			light_color = fire_colour

		else if(emergency_mode)
			light_range = brightness_range * bulb_major_emergency_brightness_mul
			light_color = bulb_emergency_colour

		else if(nightshift_enabled)
			light_range = nightshift_light_range
			light_power = nightshift_light_power
			if(!color)
				light_color = nightshift_light_color

		if(cached_color_filter)
			light_color = apply_matrix_to_color(light_color, cached_color_filter["color"], cached_color_filter["space"] || COLORSPACE_RGB)

		var/matching = light && light_range == light.light_range && light_power == light.light_power && light_color == light.light_color
		if(!matching)
			switchcount++
			if(rigged)
				if(status == LIGHT_OK && trigger)
					log_admin("LOG: Rigged light explosion, last touched by [fingerprintslast]")
					message_admins("LOG: Rigged light explosion, last touched by [fingerprintslast]")
					explode()
					return
			// Whichever number is smallest gets set as the prob
			// Each spook adds a 0.5% to 1% chance of burnout
			else if(prob(min(40, switchcount / 10)))
				if(status == LIGHT_OK && trigger)
					burnout()
			else
				use_power = ACTIVE_POWER_USE
				set_light(light_range, light_power, light_color, l_on = on)

	else if(!turned_off())
		set_emergency_lights()
	else
		use_power = IDLE_POWER_USE
		set_light(l_range = 0)

	update_icon()

	active_power_usage = (light_range * light_power * 10)
	if(on != light_state) // Light was turned on/off, so update the power usage
		light_state = on
		if(on)
			static_power_used = active_power_usage * 2 //20W per unit luminosity
			addStaticPower(static_power_used, CHANNEL_STATIC_LIGHT)
		else
			removeStaticPower(static_power_used, CHANNEL_STATIC_LIGHT)
	else
		if(on && (static_power_used != active_power_usage * 2))
			removeStaticPower(static_power_used, CHANNEL_STATIC_LIGHT)
			static_power_used = active_power_usage * 2
			addStaticPower(static_power_used, CHANNEL_STATIC_LIGHT)

	if(play_sound)
		playsound(src, 'sound/machines/light_on.ogg', 60, TRUE)

/obj/machinery/light/proc/burnout()
	status = LIGHT_BURNED

	visible_message(span_boldwarning("[declent_ru(NOMINATIVE)] сгорел[GEND_A_O_I(src)]!"))
	do_sparks(2, TRUE, src)

	on = FALSE
	set_light(0)
	update_icon()

// attempt to set the light's on/off status
// will not switch on if broken/burned/empty
/obj/machinery/light/proc/seton(S)
	on = (S && status == LIGHT_OK)
	update()

// examine verb
/obj/machinery/light/examine(mob/user)
	. = ..()
	if(in_range(user, src))
		switch(status)
			if(LIGHT_OK)
				. += span_notice("It is turned [on ? "on" : "off"].")
			if(LIGHT_EMPTY)
				. += span_notice("The [fitting] has been removed.")
				. += span_notice("The casing can be <b>unscrewed</b>.")
			if(LIGHT_BURNED)
				. += span_notice("The [fitting] is burnt out.")
			if(LIGHT_BROKEN)
				. += span_notice("The [fitting] has been smashed.")

/obj/machinery/light/update_atom_colour()
	..()
	update()

// attack with item - insert light (if right type), otherwise try to break the light
/obj/machinery/light/attackby(obj/item/I, mob/living/user, params)
	if(user.a_intent == INTENT_HARM)
		return ..()

	//Light replacer code
	if(istype(I, /obj/item/lightreplacer))
		add_fingerprint(user)
		var/obj/item/lightreplacer/lightreplacer = I
		lightreplacer.ReplaceLight(src, user)
		return ATTACK_CHAIN_BLOCKED_ALL

	// attempt to insert a light
	if(istype(I, /obj/item/light))
		add_fingerprint(user)
		var/obj/item/light/new_light = I
		if(status != LIGHT_EMPTY)
			to_chat(user, span_warning("There is a [fitting] already inserted."))
			return ATTACK_CHAIN_PROCEED
		if(!istype(I, light_type))
			to_chat(user, span_warning("This type of light requires a [fitting]."))
			return ATTACK_CHAIN_PROCEED
		if(!user.drop_transfer_item_to_loc(new_light, src))
			return ..()
		to_chat(user, span_notice("You have inserted [new_light] into [src]."))
		status = new_light.status
		switchcount = new_light.switchcount
		rigged = new_light.rigged
		if(new_light.brightness_range)
			brightness_range = new_light.brightness_range
		if(new_light.brightness_power)
			new_light.brightness_power = new_light.brightness_power
		if(new_light.brightness_color)
			brightness_color = new_light.brightness_color
		lightmaterials = new_light.materials
		on = has_power()
		update()
		qdel(new_light)
		if(on && rigged)
			log_admin("LOG: Rigged light explosion, last touched by [fingerprintslast]")
			message_admins("LOG: Rigged light explosion, last touched by [fingerprintslast]")
			explode()
		return ATTACK_CHAIN_BLOCKED_ALL

	if(istype(I, /obj/item/toy/crayon/spraycan))
		add_fingerprint(user)
		var/obj/item/toy/crayon/spraycan/spraycan = I
		if(spraycan.colour == light_color)
			return ATTACK_CHAIN_BLOCKED_ALL
		/* Реализация проверки цвета, который был выбран в распылителе
		Если цвет слишком тёмный, то return */
		var/r = hex2num(copytext(spraycan.colour, 2, 4))
		var/g = hex2num(copytext(spraycan.colour, 4, 6))
		var/b = hex2num(copytext(spraycan.colour, 6, 8))

		var/brightness = (0.299 * r + 0.587 * g + 0.114 * b) // Формула для определения яркости цвета(Да, магические числа)
		if(brightness < 100) // Порог яркости
			to_chat(user, span_warning("Выбранный цвет слишком тёмный для того чтоб он мог пропускать свет!"))
			return ATTACK_CHAIN_BLOCKED_ALL
		var/min_rgb = min(r, g, b)
		var/max_rgb = max(r, g, b)
		var/saturation = (max_rgb - min_rgb) / max_rgb
		if(saturation > 0.8) // Максимально допустимая насыщенность
			to_chat(user, span_warning("Цвет слишком насыщенный для освещения!"))
			return ATTACK_CHAIN_BLOCKED_ALL
		/* Конец проверки цвета */
		to_chat(user, span_warning("Вы покрасили [src] при помощи [spraycan.name]!"))
		spraycan.uses--
		color = spraycan.colour
		light_color = spraycan.colour
		playsound(src, 'sound/effects/spray.ogg', 50, TRUE)
		update()
		return ATTACK_CHAIN_BLOCKED_ALL
	return ..()

/obj/machinery/light/screwdriver_act(mob/living/user, obj/item/I)
	if(status != LIGHT_EMPTY)
		return TRUE

	I.play_tool_sound(src)
	user.visible_message(span_notice("[user] opens [src]'s casing."), \
		span_notice("You open [src]'s casing."), span_notice("You hear a screwdriver."))
	deconstruct()
	return TRUE

/obj/machinery/light/deconstruct(disassembled = TRUE)
	if(!(obj_flags & NODECONSTRUCT))
		var/cur_stage = 2
		if(!disassembled)
			cur_stage = 1
		var/obj/machinery/light_construct/newlight = new deconstruct_type(loc)
		newlight.setDir(dir)
		newlight.stage = cur_stage
		if(!disassembled)
			newlight.update_integrity(newlight.max_integrity * 0.5)
			if(status != LIGHT_BROKEN)
				break_light_tube()
			if(status != LIGHT_EMPTY)
				drop_light_tube()
			new /obj/item/stack/cable_coil(loc, 1, "red")
		newlight.update_icon(UPDATE_ICON_STATE)
		transfer_fingerprints_to(newlight)
	qdel(src)

/obj/machinery/light/proceed_attack_results(obj/item/I, mob/living/user, params, def_zone)
	var/initial_status = status

	. = ..()

	if(!ATTACK_CHAIN_SUCCESS_CHECK(.) || !(I.flags & CONDUCT) || !has_power())
		return

	if(status != initial_status && prob(12))	// Proceed only if changed `state` during `take_damage`.
		electrocute_mob(user, get_area(src), src, 0.3, TRUE)

	else if(status == LIGHT_EMPTY && prob(75))
		to_chat(user, span_userdanger("You aimed right into the light socket."))
		electrocute_mob(user, get_area(src), src, randfloat(0.7, 1), TRUE)
		do_sparks(3, TRUE, src)

	add_fingerprint(user)

/obj/machinery/light/take_damage(damage_amount, damage_type = BRUTE, damage_flag = "", sound_effect = TRUE, attack_dir, armour_penetration = 0)
	. = ..()

	if(!. || QDELETED(src))
		return

	if(!prob(1 + . * 5))
		return

	break_light_tube()

/obj/machinery/light/play_attack_sound(damage_amount, damage_type = BRUTE, damage_flag = 0)
	switch(damage_type)
		if(BRUTE)
			switch(status)
				if(LIGHT_EMPTY)
					playsound(loc, 'sound/weapons/smash.ogg', 50, TRUE)
				if(LIGHT_BROKEN)
					playsound(loc, 'sound/effects/hit_on_shattered_glass.ogg', 90, TRUE)
				else
					playsound(loc, 'sound/effects/glasshit.ogg', 90, TRUE)
		if(BURN)
			playsound(loc, 'sound/items/welder.ogg', 100, TRUE)

// returns if the light has power /but/ is manually turned off
// if a light is turned off, it won't activate emergency power
/obj/machinery/light/proc/turned_off()
	var/area/A = get_area(src)
	return !A.lightswitch && A.power_light

// returns whether this light has power
// true if area has power and lightswitch is on
/obj/machinery/light/proc/has_power()
	var/area/A = get_area(src)
	return A.lightswitch && A.power_light

// attempts to set emergency lights
/obj/machinery/light/proc/set_emergency_lights()
	var/area/current_area = get_area(src)
	var/obj/machinery/power/apc/current_apc = current_area.get_apc()
	if(status != LIGHT_OK || !current_apc || flickering || no_emergency)
		emergency_lights_off(current_area, current_apc)
		return
	if(current_apc.emergency_lights || !current_apc.emergency_power)
		emergency_lights_off(current_area, current_apc)
		return
	if(fire_mode)
		set_light(nightshift_light_range, nightshift_light_power, bulb_emergency_colour, l_on = TRUE)
		update_icon()
		return
	emergency_mode = TRUE
	set_light((fitting == "tube" ? 3 : 2), 1, bulb_emergency_colour, l_on = TRUE)
	update_icon()
	RegisterSignal(current_area, COMSIG_AREA_POWER_CHANGE, PROC_REF(update), override = TRUE)

/obj/machinery/light/proc/emergency_lights_off(area/current_area, obj/machinery/power/apc/current_apc)
	set_light(0, 0, 0) //you, sir, are off!
	if(current_apc)
		RegisterSignal(current_area, COMSIG_AREA_POWER_CHANGE, PROC_REF(update), override = TRUE)

/obj/machinery/light/flicker(amount = rand(20, 30))
	set waitfor = FALSE
	if(flickering || !on || status != LIGHT_OK)
		return FALSE

	. = TRUE // did we actually flicker? Send this now because we expect immediate response, before sleeping.
	set_light(
		l_range = brightness_range * bulb_low_power_brightness_mul,
		l_power = bulb_low_power_pow_mul,
		l_color = nightshift_light_color,
	)
	cut_overlays(src)
	stoplag(0.7 SECONDS)

	if(prob(30))
		do_sparks(number = 2, cardinal_only = TRUE, source = src)

	for(var/i in 1 to amount)
		if(status != LIGHT_OK || !has_power())
			break
		flickering = !flickering
		update(FALSE)
		stoplag(pick(list(2 SECONDS, 4 SECONDS, 6 SECONDS)))

	if(has_power())
		on = (status == LIGHT_OK)
	else
		on = FALSE

	flickering = FALSE
	update(FALSE)

// ai attack - toggle emergency lighting
/obj/machinery/light/attack_ai(mob/user)
	no_emergency = !no_emergency
	to_chat(user, span_notice("Emergency lights for this fixture have been [no_emergency ? "disabled" : "enabled"]."))
	update(FALSE)

// attack with hand - remove tube/bulb
// if hands aren't protected and the light is on, burn the player

/obj/machinery/light/attack_hand(mob/user)
	user.changeNext_move(CLICK_CD_MELEE)
	add_fingerprint(user)

	if(status == LIGHT_EMPTY)
		to_chat(user, span_warning("There is no [fitting] in this light."))
		return

	// make it burn hands if not wearing fire-insulated gloves
	if(on)
		var/prot = 0
		var/mob/living/carbon/human/H = user

		if(istype(H))
			if(H.gloves)
				var/obj/item/clothing/gloves/G = H.gloves
				if(G.max_heat_protection_temperature)
					prot = (G.max_heat_protection_temperature > 360)
		else
			prot = 1

		if(prot > 0 || HAS_TRAIT(user, TRAIT_RESIST_HEAT))
			to_chat(user, span_notice("You remove the light [fitting]"))
		else if(HAS_TRAIT(user, TRAIT_TELEKINESIS))
			to_chat(user, span_notice("You telekinetically remove the light [fitting]."))
		else
			if(user.a_intent == INTENT_DISARM || user.a_intent == INTENT_GRAB)
				to_chat(user, span_warning("You try to remove the light [fitting], but you burn your hand on it!"))
				H.apply_damage(5, BURN, def_zone = H.hand ? BODY_ZONE_PRECISE_L_HAND : BODY_ZONE_PRECISE_R_HAND)
				return
			else
				to_chat(user, span_notice("You try to remove the light [fitting], but it's too hot to touch!"))
				return
	else
		to_chat(user, span_notice("You remove the light [fitting]"))
	// create a light tube/bulb item and put it in the user's hand
	drop_light_tube(user)

/obj/machinery/light/proc/set_major_emergency_light()
	emergency_mode = TRUE
	update()

/obj/machinery/light/proc/unset_major_emergency_light()
	emergency_mode = TRUE
	update()

/obj/machinery/light/proc/drop_light_tube(mob/user)
	if(status == LIGHT_EMPTY)
		return

	var/obj/item/light/L = new light_type()
	L.status = status
	L.rigged = rigged
	L.brightness_range = brightness_range
	L.brightness_power = brightness_power
	L.brightness_color = brightness_color
	L.materials = lightmaterials

	// light item inherits the switchcount, then zero it
	L.switchcount = switchcount
	switchcount = 0

	L.update_appearance(UPDATE_ICON_STATE|UPDATE_DESC)
	L.forceMove(loc)

	if(user) //puts it in our active hand
		L.add_fingerprint(user)
		user.put_in_active_hand(L, ignore_anim = FALSE)

	status = LIGHT_EMPTY
	update(FALSE, FALSE)
	return L

/obj/machinery/light/attack_tk(mob/user)
	if(status == LIGHT_EMPTY)
		to_chat(user, "There is no [fitting] in this light.")
		return

	to_chat(user, "You telekinetically remove the light [fitting].")
	// create a light tube/bulb item and put it in the user's hand
	var/obj/item/light/L = drop_light_tube()
	L.attack_tk(user)

/obj/machinery/light/proc/break_light_tube(skip_sound_and_sparks = FALSE, overloaded = FALSE)
	if(status == LIGHT_EMPTY || status == LIGHT_BROKEN)
		return

	if(!skip_sound_and_sparks)
		if(on || overloaded)
			do_sparks(3, TRUE, src)

		playsound(loc, 'sound/effects/glasshit.ogg', 75, TRUE)

	visible_message(span_danger("[src] was just smashed!"), null, span_italics("You hear the tinkle of breaking glass."))
	status = LIGHT_BROKEN
	update()

/obj/machinery/light/proc/fix()
	if(status == LIGHT_OK)
		return
	status = LIGHT_OK
	extinguished = FALSE
	on = TRUE
	update()

/obj/machinery/light/zap_act(power, zap_flags)
	var/explosive = zap_flags & ZAP_MACHINE_EXPLOSIVE
	zap_flags &= ~(ZAP_MACHINE_EXPLOSIVE | ZAP_OBJ_DAMAGE)
	. = ..()
	if(explosive)
		explosion(src, flame_range = 3, adminlog = FALSE)
		qdel(src)

// timed process
// use power

// called when area power state changes
/obj/machinery/light/power_change(forced = FALSE)
	var/area/A = get_area(src)
	if(A)
		seton(A.lightswitch && A.power_light)

// called when on fire
/obj/machinery/light/temperature_expose(exposed_temperature, exposed_volume)
	..()
	if(prob(max(0, exposed_temperature - 673)))   //0% at <400C, 100% at >500C
		break_light_tube()

// explode the light
/obj/machinery/light/proc/explode()
	break_light_tube()	// break it first to give a warning
	addtimer(CALLBACK(src, PROC_REF(actually_explode)), 2)

/obj/machinery/light/proc/actually_explode()
	var/turf/light_turf = get_turf(loc)
	explosion(light_turf, devastation_range = 0, heavy_impact_range = 0, light_impact_range = 2, flash_range = 2, cause = src)
	qdel(src)

/obj/machinery/light/extinguish_light(force = FALSE)
	on = FALSE
	extinguished = TRUE
	emergency_mode = FALSE
	no_emergency = TRUE
	addtimer(CALLBACK(src, PROC_REF(enable_emergency_lighting)), 5 MINUTES, TIMER_UNIQUE|TIMER_OVERRIDE)
	visible_message(span_danger("[src] flickers and falls dark."))
	update(FALSE)

/obj/machinery/light/proc/enable_emergency_lighting()
	visible_message(span_notice("[src]'s emergency lighting flickers back to life."))
	extinguished = FALSE
	no_emergency = FALSE
	update(FALSE)

/obj/machinery/light/proc/on_light_eater(obj/machinery/light/source, datum/light_eater)
	SIGNAL_HANDLER
	break_light_tube()
	return COMPONENT_BLOCK_LIGHT_EATER
