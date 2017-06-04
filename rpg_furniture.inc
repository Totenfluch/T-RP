#if defined _rpg_furniture_included_
#endinput
#endif
#define _rpg_furniture_included_

/*
	@Param1 -> int entity
	@Param2 -> char buffs[64] (buffer)
		
	return true on success false if not
*/
native bool furniture_getBuffs(int entity, char buffer[64]);

/*
	@Param1 -> int entity
	@Param2 -> char flags[8] (buffer)
		
	return true on success false if not
*/
native bool furniture_getFlags(int entity, char buffer[8]);

/*
	@Param1 -> int entity
		
	return int durability // -1 if failed
*/
native int furniture_getDurability(int entity);

/*
	@Param1 -> int entity
	@Param2 -> int amount
		
	return int durability // -1 if failed
*/
native int furniture_setDurability(int entity, int amount);


/*
	@Param1 -> char zone[128]
	return -	
*/
native void furniture_removeAllFurnitureFromApartment(char zone[128]);


/*
	Forward when a Player interacts with a furniture Item
		
	@Param1 -> int entity
	@Param2 -> int client
	@Param3 -> char name[64]
	@Param4 -> char lfBuf[64]
	@Param5 -> char flags[8]
	@Param6 -> char ownerId[20]
	@Param7 -> int durability
*/
forward void furniture_OnFurnitureInteract(int entity, int client, char name[64], char lfBuf[64], char flags[8], char ownerId[20], int durability); 