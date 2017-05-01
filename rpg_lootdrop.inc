/** Double-include prevention */
#if defined _rpg_lootdrop_included_
  #endinput
#endif
#define _rpg_lootdrop_included_

/*
	Spawns a pile of money
		
	@Param1 -> float posX
	@Param2 -> float posY
	@Param3 -> float posZ
	@Param4 -> int amount
		
		
	@return entity Id
*/
native int rpg_spawnMoneyLoot(float posx, float posy, float posz, int amount);
