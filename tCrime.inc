#if defined _rpg_tcrime_included_
#endinput
#endif
#define _rpg_tcrime_included_

/*
		Get the crime amount of client
		@Param1 -> client index

		@return crime amount
	*/
native int tCrime_getCrime(int client);

/*
		Sets the Crime amount on client
		@Param1 -> client index
		@Param2 -> crime amount

		@return -
	*/
native void tCrime_setCrime(int client, int amount);

/*
		Adds the Crime amount on client
		@Param1 -> client index
		@Param2 -> crime amount

		@return -
	*/
native void tCrime_addCrime(int client, int amount);

/*
		Removes the Crime amount on client
		@Param1 -> client index
		@Param2 -> crime amount

		@return -
	*/
native void tCrime_removeCrime(int client, int amount);

/*
		Adds flags to the client
		@Param1 -> client index
		@Param2 -> char flags[64]

		@return -
	*/
native void tCrime_addFlags(int client, char flags[64]);

/*
		Removes flags from the client
		@Param1 -> client index
		@Param2 -> char flags[64]

		@return -
	*/
native void tCrime_removeFlags(int client, char flags[64]);

/*
		Clears flags from the client
		@Param1 -> client index

		@return -
	*/
native void tCrime_clearFlags(int client);

/*
		Sets flags from the client
		@Param1 -> client index

		@return -
	*/
native void tCrime_setFlags(int client);

/*
		Sets flags from the client
		@Param1 -> client index
		@Param2 -> char flagsbuffer[64]
		
		@return -
	*/
native void tCrime_getFlags(int client, char flagbuffer[64]); 