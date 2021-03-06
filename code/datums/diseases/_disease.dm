
//Visibility Flags
#define HIDDEN_SCANNER	1
#define HIDDEN_PANDEMIC	2

//Disease Flags
#define CURABLE		1
#define CAN_CARRY	2
#define CAN_RESIST	3

//Spread Flags
#define SPECIAL 1
#define NON_CONTAGIOUS 2
#define BLOOD 4
#define CONTACT_FEET 8
#define CONTACT_HANDS 16
#define CONTACT_GENERAL 32
#define AIRBORNE 64


//Severity Defines
#define NONTHREAT	"No threat"
#define MINOR		"Minor"
#define MEDIUM		"Medium"
#define HARMFUL		"Harmful"
#define DANGEROUS 	"Dangerous!"
#define BIOHAZARD	"BIOHAZARD THREAT!"


var/list/diseases = typesof(/datum/disease) - /datum/disease


/datum/disease
	//Flags
	var/visibility_flags = 0
	var/disease_flags = CURABLE|CAN_CARRY|CAN_RESIST
	var/spread_flags = AIRBORNE

	//Fluff
	var/form = "Virus"
	var/name = "No disease"
	var/desc = ""
	var/agent = "some microbes"
	var/spread_text = ""
	var/cure_text = ""

	//Stages
	var/stage = 1
	var/max_stages = 0
	var/stage_prob = 4

	//Other
	var/longevity = 150 //Time in ticks disease stays in objects, Syringes and such are infinite.
	var/list/viable_mobtypes = list() //typepaths of viable mobs
	var/mob/living/carbon/affected_mob = null
	var/atom/movable/holder = null
	var/list/cures = list() //list of cures if the disease has the CURABLE flag, these are reagent ids
	var/infectivity = 65
	var/cure_chance = 8
	var/carrier = 0 //If our host is only a carrier
	var/permeability_mod = 1
	var/severity =	NONTHREAT
	var/list/required_organs = list()

	var/list/strain_data = list() //dna_spread special bullshit



/datum/disease/proc/stage_act()
	var/cure = has_cure()

	if(carrier && !cure)
		return

	stage = min(stage, max_stages)

	if(!cure)
		if(prob(stage_prob))
			stage = min(stage + 1,max_stages)
	else
		if(prob(cure_chance))
			stage = max(stage - 1, 1)

	if(disease_flags & CURABLE)
		if(cure && prob(cure_chance))
			cure()


/datum/disease/proc/has_cure()
	if(!(disease_flags & CURABLE))
		return 0

	. = 1
	for(var/C_id in cures)
		if(!affected_mob.reagents.has_reagent(C_id))
			.--
			break //One missing cure is enough to fail


/datum/disease/proc/spread(var/atom/source, var/force_spread = 0)
	if((spread_flags & SPECIAL || spread_flags & NON_CONTAGIOUS || spread_flags & BLOOD) && !force_spread)
		return

	if(affected_mob)
		if( affected_mob.reagents.has_reagent("spaceacillin") || (affected_mob.satiety > 0 && prob(affected_mob.satiety/10)) )
			return

	var/spread_range = 1

	if(force_spread)
		spread_range = force_spread

	if(spread_flags & AIRBORNE)
		spread_range++

	if(!source)
		if(affected_mob)
			source = affected_mob
		else
			return

	if(isturf(source.loc))
		for(var/mob/living/carbon/C in oview(spread_range, source))
			if(isturf(C.loc))
				if(AStar(source.loc, C.loc, /turf/proc/AdjacentTurfs, /turf/proc/Distance, spread_range))
					C.ContractDisease(src)


/datum/disease/proc/process()
	if(!holder)
		SSdisease.processing -= src
		return

	if(prob(infectivity))
		spread(holder)

	if(affected_mob)
		for(var/datum/disease/D in affected_mob.viruses)
			if(D != src)
				if(IsSame(D))
					del(D)

		if(holder == affected_mob)
			if(affected_mob.stat != DEAD)
				stage_act()

	if(!affected_mob)
		if(prob(70))
			if(--longevity<=0)
				cure()


/datum/disease/proc/cure()
	if(affected_mob)
		if(disease_flags & CAN_RESIST)
			if(!(type in affected_mob.resistances))
				affected_mob.resistances += type
				remove_virus()
	del(src)


/datum/disease/New()
	if(required_organs && required_organs.len)
		if(ishuman(affected_mob))
			var/mob/living/carbon/human/H = affected_mob
			for(var/obj/item/organ/O in required_organs)
				if(!locate(O) in H.organs)
					if(!locate(O) in H.internal_organs)
						cure()
						return

	SSdisease.processing += src


/datum/disease/proc/IsSame(var/datum/disease/D)
	if(istype(src, D.type))
		return 1
	return 0


/datum/disease/proc/Copy()
	return new type()


/datum/disease/proc/GetDiseaseID()
	return type


/datum/disease/Del()
	SSdisease.processing.Remove(src)
	..()


/datum/disease/proc/IsSpreadByTouch()
	if(spread_flags & CONTACT_FEET || spread_flags & CONTACT_HANDS || spread_flags & CONTACT_GENERAL)
		return 1
	return 0

//don't use this proc directly. this should only ever be called by cure()
/datum/disease/proc/remove_virus()
	affected_mob.viruses -= src		//remove the datum from the list
	affected_mob.med_hud_set_status()
