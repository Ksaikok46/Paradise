/// Pure Black and white colorblindness. Every species except Vulpkanins and Tajarans will have this.
#define GREYSCALE_COLOR_REPLACE list( \
	"red" = "grey", \
	"blue" = "grey", \
	"green" = "grey", \
	"orange" = "light grey", \
	"yellow" = "light grey", \
	"brown" = "grey", \
	"gold" = "light grey", \
	"cyan" = "silver", \
	"magenta" = "grey", \
	"purple" = "grey", \
	"pink" = "light grey" \
)

/obj/item/organ/internal/eyes
	name = "eyeballs"
	desc = "Парный орган, отвечающий за зрение — восприятие света и его трансформацию в видимое изображение. Эти принадлежали человеку."
	gender = PLURAL
	icon_state = "eyes"
	parent_organ_zone = BODY_ZONE_HEAD
	slot = INTERNAL_ORGAN_EYES
	var/eye_colour = "#000000" // Should never be null
	var/list/colourmatrix = null
	var/list/colourblind_matrix = MATRIX_GREYSCALE //Special colourblindness parameters. By default, it's black-and-white.
	var/list/replace_colours = GREYSCALE_COLOR_REPLACE
	/// Gets set by eye-dependent disabilities such as colourblindness so the eyes can transfer the disability during transplantation.
	var/list/dependent_disabilities
	var/weld_proof = null //If set, the eyes will not take damage during welding. eg. IPC optical sensors do not take damage when they weld things while all other eyes will.
	min_broken_damage = EYE_BROKEN_THRESHOLD // for a smoother transition from blur to blindness

	var/vision_flags = NONE
	var/see_invisible = SEE_INVISIBLE_LIVING
	/// How much darkness to cut out of your view (basically, night vision)
	var/lighting_cutoff = null
	/// List of color cutoffs from eyes, or null if not applicable
	var/list/color_cutoffs = null
	/// Modifies examine time for living mobs. Uses in /mob/living/run_examinate(atom/target)
	var/examine_mod = 1
	var/shine_in_dark = FALSE

/obj/item/organ/internal/eyes/get_ru_names()
	return list(
		NOMINATIVE = "глаза человека",
		GENITIVE = "глаз человека",
		DATIVE = "глазам человека",
		ACCUSATIVE = "глаза человека",
		INSTRUMENTAL = "глазами человека",
		PREPOSITIONAL = "глазах человека",
	)

/obj/item/organ/internal/eyes/proc/update_colour()
	dna.write_eyes_attributes(src)

/obj/item/organ/internal/eyes/proc/generate_icon(mob/living/carbon/human/HA)
	var/mob/living/carbon/human/H = HA
	if(!istype(H))
		H = owner
	var/icon/eyes_icon = new /icon('icons/mob/human_face.dmi', H.dna.species.eyes)
	eyes_icon.Blend(eye_colour, ICON_ADD)

	return eyes_icon

/obj/item/organ/internal/eyes/proc/get_colourmatrix() //Returns a special colour matrix if the eyes are organic and the mob is colourblind, otherwise it uses the current one.
	if(!is_robotic() && HAS_TRAIT(owner, TRAIT_COLORBLIND))
		return colourblind_matrix
	else
		return colourmatrix

/obj/item/organ/internal/eyes/proc/shine()
	if(is_robotic() || shine_in_dark)
		return TRUE

/obj/item/organ/internal/eyes/insert(mob/living/carbon/human/target, special = ORGAN_MANIPULATION_DEFAULT)
	. = ..()
	if(ishuman(target) && eye_colour)
		target.update_body() //Apply our eye colour to the target.

	//If the eyes are colourblind and we're not, carry over the gene.
	if(!HAS_TRAIT(target, TRAIT_COLORBLIND) && LAZYIN(dependent_disabilities, TRAIT_COLORBLIND))
		LAZYREMOVE(dependent_disabilities, TRAIT_COLORBLIND)
		target.force_gene_block(GLOB.colourblindblock, TRUE)
	else
		//If we're here, that means the mob acquired the colourblindness gene while they didn't have eyes. Better handle it.
		target.update_client_colour()

/obj/item/organ/internal/eyes/remove(mob/living/carbon/target, special = ORGAN_MANIPULATION_DEFAULT)
	//If special is set, that means these eyes are getting deleted (i.e. during set_species())
	if(special == ORGAN_MANIPULATION_DEFAULT && HAS_TRAIT(target, TRAIT_COLORBLIND))
		LAZYOR(dependent_disabilities, TRAIT_COLORBLIND)
		target.force_gene_block(GLOB.colourblindblock, FALSE)
	return ..()

/obj/item/organ/internal/eyes/surgeryize()
	if(!owner)
		return
	owner.CureNearsighted()
	owner.CureBlind()
	owner.SetEyeBlurry(0)
	owner.SetEyeBlind(0)

/obj/item/organ/internal/eyes/has_damage()
	. = ..()
	if(.)
		return .
	if(owner.AmountEyeBlurry() || owner.AmountBlinded())
		return TRUE
	if(HAS_TRAIT(owner, TRAIT_NEARSIGHTED))
		return TRUE
	if(HAS_TRAIT(owner, TRAIT_BLIND))
		return TRUE

/obj/item/organ/internal/eyes/robotize(make_tough = FALSE)
	colourmatrix = null
	..() //Make sure the organ's got the robotic status indicators before updating the client colour.
	if(owner)
		owner.update_client_colour(0)

/obj/item/organ/internal/eyes/cybernetic
	name = "cybernetic eyes"
	desc = "Электронное устройство, имитирующее работу органических глаз. Функционально не имеет никаких отличий от органического аналога, кроме производственных затрат."
	icon_state = "eyes-c"
	origin_tech = "biotech=4"
	status = ORGAN_ROBOT
	pickup_sound = 'sound/items/handling/pickup/component_pickup.ogg'
	drop_sound = 'sound/items/handling/drop/component_drop.ogg'
	shine_in_dark = TRUE

/obj/item/organ/internal/eyes/cybernetic/get_ru_names()
	return list(
		NOMINATIVE = "кибернетические глаза",
		GENITIVE = "кибернетических глаз",
		DATIVE = "кибернетическим глазам",
		ACCUSATIVE = "кибернетические глаза",
		INSTRUMENTAL = "кибернетическими глазами",
		PREPOSITIONAL = "кибернетических глазах",
	)

/obj/item/organ/internal/eyes/on_life()
	var/update_flags = STATUS_UPDATE_NONE
	if(ishuman(owner) && owner.glasses)
		var/obj/item/clothing/glasses/G = owner.glasses
		if(G.heal_bodypart == INTERNAL_ORGAN_EYES && iscarbon(owner))
			var/mob/living/carbon/C = owner
			var/obj/item/organ/internal/eyes/E = C.get_int_organ(/obj/item/organ/internal/eyes)
			if(istype(E))
				E.heal_internal_damage(G.heal_rate)
				owner.AdjustEyeBlurry(-2 SECONDS)
	return ..() | update_flags

#define NIGHTVISION_LIGHT_OFF 0
#define NIGHTVISION_LIGHT_LOW 1
#define NIGHTVISION_LIGHT_MID 2
#define NIGHTVISION_LIGHT_HIG 3

/obj/item/organ/internal/eyes/night_vision
	abstract_type = /obj/item/organ/internal/eyes/night_vision
	actions_types = list(/datum/action/item_action/organ_action/use)

	// These lists are used as the color cutoff for the eye
	// They need to be filled out for subtypes
	var/list/low_light_cutoff
	var/list/medium_light_cutoff
	var/list/high_light_cutoff
	var/light_level = NIGHTVISION_LIGHT_OFF

/obj/item/organ/internal/eyes/night_vision/Initialize(mapload)
	. = ..()
	//if(PERFORM_ALL_TESTS(focus_only/nightvision_color_cutoffs))
	if(type != /obj/item/organ/internal/eyes/night_vision && (length(low_light_cutoff) != 3 || length(medium_light_cutoff) != 3 || length(high_light_cutoff) != 3))
		stack_trace("[type] did not have fully filled out color cutoff lists")
	if(low_light_cutoff)
		color_cutoffs = low_light_cutoff.Copy()
	light_level = NIGHTVISION_LIGHT_LOW

/obj/item/organ/internal/eyes/night_vision/ui_action_click()
	vision_flags = initial(vision_flags)
	switch(light_level)
		if(NIGHTVISION_LIGHT_OFF)
			color_cutoffs = low_light_cutoff.Copy()
			light_level = NIGHTVISION_LIGHT_LOW
		if(NIGHTVISION_LIGHT_LOW)
			color_cutoffs = medium_light_cutoff.Copy()
			light_level = NIGHTVISION_LIGHT_MID
		if(NIGHTVISION_LIGHT_MID)
			color_cutoffs = high_light_cutoff.Copy()
			light_level = NIGHTVISION_LIGHT_HIG
		else
			color_cutoffs = null
			light_level = NIGHTVISION_LIGHT_OFF
	owner.update_sight()

/obj/item/organ/internal/eyes/alien
	name = "alien eyes"
	desc = "It turned out they had them after all!"
	vision_flags = SEE_MOBS
	color_cutoffs = list(25, 5, 42)

#undef NIGHTVISION_LIGHT_OFF
#undef NIGHTVISION_LIGHT_LOW
#undef NIGHTVISION_LIGHT_MID
#undef NIGHTVISION_LIGHT_HIG

#undef GREYSCALE_COLOR_REPLACE
