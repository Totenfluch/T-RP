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
		@Param8 -> int slot
	
	*/
forward void inventory_onItemUsed(int client, char itemname[128], int weight, char category[64], char category2[64], int rarity, char timestamp[64], int slot);


/*
		Shows the inventory of client1 to client2
		
		@Param1 -> int client1
		@Param2 -> int client2
		
		@return -
	*/
native void inventory_showInventoryOfClientToOtherClient(int client1, int client2); 


	/*
		Shows the inventory of client1 to client2
		
		@Param1 -> int client1
		@Param2 -> int client2
		@Param3 -> char category[64]
		
		@return -
	*/
native void inventory_showInventoryOfClientToOtherClientByCategory(int client1, int client2, char category[64]); 


	/*
		Blocks the default Item handle
		@Param1-> char Itemname[128];
		@Param2-> int type = 1: Single Item, 2: Category, 3: Category2, 4:Category+Category2
	*/
native void inventory_addItemHandle(char itemname[128], int type);

	/*
		Return the owned items of a client
		
		@Param1 -> int client
		
		return amount of items the client has
	*/
native int inventory_getClientItemsAmount(int client);
	
	/*
		Check if the Item is valid or not
		
		@Param1 -> int client
		@Param2 -> int slot
		
		return true when it is valid false if not
	*/
native bool inventory_isValidItem(int client, int slot);
	
	/*
		Return the Name of an Item Slot
		
		@Param1 -> int client
		@Param2 -> int slot
		@Param3 -> ItemNameBuffer[128]
		@Param4 -> char FilterFlags[8] // leave blank to enforce flags (only usable items)
		
		Saves the ItemName in Param3
		
		return true if usable false if not
	*/
native bool inventory_getItemNameBySlotAndClient(int client, int slot, char ItemNameBuffer[128], char FilterFlags[8]);
	
	/*
		Return the Category of an Item Slot
		
		@Param1 -> int client
		@Param2 -> int slot
		@Param3 -> ItemNameBuffer[128]
		@Param4 -> char FilterFlags[8] // leave blank to enforce flags (only usable items)
		
		Saves the ItemName in Param3
		
		return true if usable false if not
	*/
native bool inventory_getItemCategoryBySlotAndClient(int client, int slot, char ItemNameBuffer[128], char FilterFlags[8]);

/*
	Return the Weight of an Item Slot
		
	@Param1 -> int client
	@Param2 -> int slot
		
	return weight of item if exists otherwise -1
*/
native int inventory_getItemWeightBySlot(int client, int slot);

	/*
		Transfer Item to Container
		
		@Param1 -> int client
		@Param2 -> int slot
		@Param3 -> char containerName[64]
		
		noreturn
	*/
native void inventory_transferItemToContainer(int client, int slot, char containerName[64]);

	/*
		Return the Flags of an Item Slot
		
		@Param1 -> int client
		@Param2 -> int slot
		@Param3 -> char flags[8] 
		
		return - (Saves into Param3)
	*/
native void inventory_getItemFlagsBySlot(int client, int slot, char flags[8]);
	
	
	/*
		Delete Item by Slot
		
		@Param1 -> int client
		@Param2 -> int slot
		@Param3 -> char reason[256]
		
		noreturn
	*/
native void inventory_deleteItemBySlot(int client, int slot, char reason[256]);


	/*
		Transfer Item to other Player by Slot
		
		@Param1 -> int client
		@Param2 -> int target
		@Param3 -> int slot
		@Param4 -> char reason[256]
		
		noreturn
	*/
native void inventory_transferItemToPlayerBySlot(int client, int target, int slot, char reason[256]);

	/*
		Transfer Item from Container
		
		@Param1 -> int client
		@Param2 -> char containerName[64]
		@Param3 -> char uniqueId[64]
		
		@return noreturn
	*/
native void inventory_transferItemFromContainer(int client, char containerName[64], char uniqueId[64]);