#if defined _rpg_npc_core_included_
#endinput
#endif
#define _rpg_npc_core_included_

/*
	Registers a new Npc Type
		
	@Param1 -> char NpcType[128]
		
	@return loaded Slot
*/
native void npc_registerNpcType(char npcType[128]);

/*
	Forward when a Client interacted with an NPC
		
	@Param1 -> int client
	@Param2 -> char NpcType[64]
	@Param3 -> char UniqueId[128]
	@Param4 -> int Ent index
		
	@return -
*/
forward void OnNpcInteract(int client, char npcType[64], char UniqueId[128], int entIndex); 