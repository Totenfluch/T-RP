#if defined _rpg_inventory_core_included_
#endinput
#endif
#define _rpg_inventory_core_included_

/*
		Give an Item to a Player
		
		@Param1 -> int client
		@Param2 -> char itemname[128]
		@Param3 -> int weight
		@Param4 -> char flags[64]
		@Param5 -> char category[64]
		@Param6 -> char category2[64]
		@Param7 -> int rarity
		
		@return none
	*/
native void inventory_givePlayerItem(int client, char itemname[128], int weight, char flags[64], char category[64], char category2[64], int rarity, char reason[256]);

/*
		Returns if a Player has a item
	
		@Param1 -> client
		@Param2 -> char itemname[128]
		
		@return true or false
	*/
native bool inventory_hasPlayerItem(int client, char itemname[128]);

/*
		Returns the amount of items a player has
	
		@Param1 -> int client
		@Param2 -> char itemname[128]
		
		@return int amount
	*/
native int inventory_getPlayerItemAmount(int client, char itemname[128]);

/*
		Removes x items from the players inventory
	
		@Param1 -> int client	
		@Param2 -> char itemname[128]
		@Param3 -> int amount
        @Param4 -> char reason[256]
		
		@return true if successfull - false if not (false still removes items!!)
	*/
native bool inventory_removePlayerItems(int client, char itemname[128], int amount, char reason[256]);

/*
		On Item used
		@Param1 -> int client
		@Param2 -> char Itemname[128]
		@Param3 -> int weight
		@Param4 -> category[64]
		@Param5 -> category2[64]
		@Param6 -> int rarity
		@Param7 -> char timestamp[64]
	
	*/
forward void inventory_onItemUsed(int client, char itemname[128], int weight, char category[64], char category2[64], int rarity, char timestamp[64]);
