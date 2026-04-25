#define LIGHT_CONSTRUCT_EMPTY_FRAME 1
#define LIGHT_CONSTRUCT_WIRED 2
#define LIGHT_CONSTRUCT_COMPLETED 3

/**
 * # Light fixture frame
 *
 * Incomplete light tube fixture
 *
 * Becomes a [/obj/machinery/light/built] when completed.
 */
/obj/machinery/light_construct
	name = "light fixture frame"
	desc = "A light fixture under construction."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "tube-construct-stage1"
	anchored = TRUE
	layer = FLY_LAYER
	max_integrity = 50
	armor = list(MELEE = 0, BULLET = 0, LASER = 0, ENERGY = 0, BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)
	/// Construction stage
	var/stage = LIGHT_CONSTRUCT_EMPTY_FRAME
	/// Light bulb type
	var/fixture_type = "tube"
	/// How many metal sheets get given after deconstruction
	var/sheets_refunded = 2
	/// Holder for the completed fixture
	var/obj/machinery/light/construct_type = /obj/machinery/light/built

/obj/machinery/light_construct/Initialize(mapload, ndir, building)
	. = ..()
	update_icon(UPDATE_ICON_STATE)

/obj/machinery/light_construct/examine(mob/user)
	. = ..()
	if(get_dist(user, src) <= 2)
		switch(stage)
			if(LIGHT_CONSTRUCT_EMPTY_FRAME)
				. += span_notice("It's an empty frame <b>bolted</b> to the wall. It needs to be <i>wired</i>.")
			if(LIGHT_CONSTRUCT_WIRED)
				. += span_notice("The frame is <b>wired</b>, but the casing's cover is <i>unscrewed</i>.")
			if(LIGHT_CONSTRUCT_COMPLETED)
				. += span_notice("The casing is <b>screwed</b> shut.")

/obj/machinery/light_construct/update_icon_state()
	icon_state = (stage == LIGHT_CONSTRUCT_WIRED) ? "[fixture_type]-construct-stage2" : "[fixture_type]-construct-stage1"

/obj/machinery/light_construct/wrench_act(mob/living/user, obj/item/I)
	. = TRUE
	switch(stage)
		if(LIGHT_CONSTRUCT_EMPTY_FRAME)
			to_chat(user, span_notice("You begin to dismantle [src]."))
			if(!I.use_tool(src, user, 30, volume = I.tool_volume))
				return
			new /obj/item/stack/sheet/metal(get_turf(loc), sheets_refunded)
			TOOL_DISMANTLE_SUCCESS_MESSAGE
			qdel(src)
		if(LIGHT_CONSTRUCT_WIRED)
			to_chat(user, span_warning("You have to remove the wires first."))
		if(LIGHT_CONSTRUCT_COMPLETED)
			to_chat(user, span_warning("You have to unscrew the case first."))

/obj/machinery/light_construct/wirecutter_act(mob/living/user, obj/item/I)
	if(stage != LIGHT_CONSTRUCT_WIRED)
		return
	if(!I.use_tool(src, user, 0, volume = I.tool_volume))
		return
	. = TRUE
	stage = LIGHT_CONSTRUCT_EMPTY_FRAME
	update_icon(UPDATE_ICON_STATE)
	new /obj/item/stack/cable_coil(get_turf(loc), 1, TRUE, COLOR_RED)
	WIRECUTTER_SNIP_MESSAGE

/obj/machinery/light_construct/screwdriver_act(mob/living/user, obj/item/I)
	if(stage != LIGHT_CONSTRUCT_WIRED)
		return
	. = TRUE
	if(!I.use_tool(src, user, 0, volume = I.tool_volume))
		return
	stage = LIGHT_CONSTRUCT_COMPLETED
	update_icon(UPDATE_ICON_STATE)
	user.visible_message(
		span_notice("[user] has closed [src]'s casing."),
		span_notice("You have closed [src]'s casing."),
		span_italics("You hear a screwdriver."),
	)
	var/obj/machinery/light/newlight = new construct_type(loc)
	newlight.setDir(dir)
	transfer_fingerprints_to(newlight)
	qdel(src)

/obj/machinery/light_construct/attackby(obj/item/I, mob/living/user, params)
	if(user.a_intent == INTENT_HARM)
		return ..()

	if(iscoil(I))
		add_fingerprint(user)
		var/obj/item/stack/cable_coil/coil = I
		if(stage != LIGHT_CONSTRUCT_EMPTY_FRAME)
			to_chat(user, span_warning("You cannot wire [src] right now."))
			return ATTACK_CHAIN_PROCEED
		var/cached_sound = coil.usesound
		if(!coil.use(1))
			to_chat(user, span_warning("You need at least one length of cable to wire [src]."))
			return ATTACK_CHAIN_PROCEED
		stage = LIGHT_CONSTRUCT_WIRED
		update_icon(UPDATE_ICON_STATE)
		playsound(loc, cached_sound, 50, TRUE)
		user.visible_message(
			span_notice("[user] has wired [src]."),
			span_notice("You have wired [src]."),
			span_hear("You hear a noise."),
		)
		return ATTACK_CHAIN_PROCEED_SUCCESS

	return ..()

/obj/machinery/light_construct/blob_act(obj/structure/blob/B)
	if(B && B.loc == loc && !QDELETED(src))
		qdel(src)

/obj/machinery/light_construct/deconstruct(disassembled = TRUE)
	if(!(obj_flags & NODECONSTRUCT))
		new /obj/item/stack/sheet/metal(loc, sheets_refunded)
	qdel(src)

/obj/machinery/light_construct/update_icon_state()
	. = ..()
	if(stage == LIGHT_CONSTRUCT_COMPLETED)
		icon_state = "[fixture_type]-empty"
		return
	icon_state = "[fixture_type]-construct-stage[stage]"

/**
 * # Small light fixture frame
 *
 * Incomplete light bulb fixture
 *
 * Becomes a [/obj/machinery/light/small/built] when completed
 */
/obj/machinery/light_construct/small
	name = "small light fixture frame"
	desc = "A small light fixture under construction."
	icon_state = "bulb-construct-stage1"
	fixture_type = "bulb"
	sheets_refunded = 1
	construct_type = /obj/machinery/light/small/built

/obj/machinery/light_construct/floor
	name = "floor light fixture frame"
	desc = "A floor light fixture under construction."
	icon_state = "floor-construct-stage1"
	layer = ABOVE_OPEN_TURF_LAYER
	plane = FLOOR_PLANE
	fixture_type = "floor"
	sheets_refunded = 3
	construct_type = /obj/machinery/light/floor/built

#undef LIGHT_CONSTRUCT_EMPTY_FRAME
#undef LIGHT_CONSTRUCT_WIRED
#undef LIGHT_CONSTRUCT_COMPLETED
