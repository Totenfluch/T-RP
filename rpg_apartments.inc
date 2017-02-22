#if defined _rpg_apartments_included_
#endinput
#endif
#define _rpg_apartments_included_

/*
		Allows a Player to an Apartment
		@Param1-> int owner
		@Param2-> int target
		
		@return -
	
	*/
native bool aparments_allowPlayer(int owner, int target);

/*
		Checks if a client is the owner of an Apartment
		@Param1 -> int owner
		@Param2 -> apartmentId[128] (zone ID)
		return true or false
	*/
native bool apartments_isClientOwner(int owner, char apartmentId[128]);


/*
		Returns the Buy Price of an Apartment
		@Param1 -> apartmentId[128] (zone ID)
		return Price or -1 if invalid
	*/
native int apartments_getBuyPrice(char apartmentId[128]); 