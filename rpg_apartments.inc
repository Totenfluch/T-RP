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
native bool aparments_isClientOwner(int owner, char apartmentId[128]);