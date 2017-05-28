#if defined _rpg_tconomy_included_
#endinput
#endif
#define _rpg_tconomy_included_

/*
        Adds Currency to a Players Account
		
        @Param1 -> int client
        @Param2 -> int amount
        @Param3 -> char reason[256]
	
        @return money after change
    */
native int tConomy_addCurrency(int client, int amount, char reason[256]);

/*
		Removes Currency to a Players Account
		
		@Param1 -> int client
		@Param2 -> int amount
		@Param3 -> char reason[256]
		
		@return money after change
	*/
native int tConomy_removeCurrency(int client, int amount, char reason[256]);

/*
		Sets Currency on a Players Account
		
		@Param1 -> int client
		@Param2 -> int amount
		@Param3 -> char reason[256]
		
		@return money after change
	*/
native int tConomy_setCurrency(int client, int amount, char reason[256]);

/*
		Gets the Clients Currency amount
		
		@Param1 -> int client
		
		@return money owned
	*/
native int tConomy_getCurrency(int client);



/*
		Adds Currency to a Players Bank  Account
		
		@Param1 -> int client
		@Param2 -> int amount
		@Param3 -> char reason[256]
		
		@return money after change
	*/
native int tConomy_addBankCurrency(int client, int amount, char reason[256]);

/*
		Removes Currency to a Players Bank Account
		
		@Param1 -> int client
		@Param2 -> int amount
		@Param3 -> char reason[256]
		
		@return money after change
	*/
native int tConomy_removeBankCurrency(int client, int amount, char reason[256]);

/*
		Sets Currency on a Players Bank Account
		
		@Param1 -> int client
		@Param2 -> int amount
		@Param3 -> char reason[256]
		
		@return money after change
	*/
native int tConomy_setBankCurrency(int client, int amount, char reason[256]);

/*
		Gets the Clients Bank Currency amount
		
		@Param1 -> int client
		
		@return money owned
	*/
native int tConomy_getBankCurrency(int client);

/*
		Return if a client is loaded
		
		@Param1 -> int client
		
		@return true if loaded
	*/
native bool tConomy_isClientLoaded(int client); 