#if defined _rpg_systemcontroller_included_
#endinput
#endif
#define _rpg_systemcontroller_included_

	/*
		Returns if a client is loaded
		
		@Param1 -> int client
		
		@return boolean loaded or not
	*/
native bool rpg_isClientLoaded(int client);
	
	/*
		Returns if game has started
		
		@Param none
		
		@return boolean started or not
	*/
native bool rpg_hasGameStarted();
	
	/*
		Forward when the game starts
		
		@Params none
		
		@return -
	*/
forward void OnRpStarted();