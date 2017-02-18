/** Double-include prevention */
#if defined _rpg_perks_included_
#endinput
#endif
#define _rpg_perks_included_

	/*
		Checks if a Player has a Perk
		@Param1-> int owner
		@Param2-> char Perk[64]
		
		@return true if client has Perk
	
	*/
native bool perks_hasPerk(int client, char perk[64]);
