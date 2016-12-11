#if defined _rpg_jail_included_
#endinput
#endif
#define _rpg_jail_included_

/*
		Puts a client in jail
		
		@Param1 -> int initiator
		@Param2 -> int target <- goes to jail
		
		@return none
	*/
native void jail_putInJail(int initiator, int target);

/*
		frees a client from jail
		
		@Param1 -> int client
		
		@return none
	*/
native int jail_freeFromJail(int client);

/*
		checks if a client is in jail
		
		@Param1 -> int client
		
		@return true or false
	*/
native bool jail_isInJail(int client); 