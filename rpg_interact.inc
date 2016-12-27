#if defined _rpg_interact_included_
  #endinput
#endif
#define _rpg_interact_included_

	/*
		Registers a new Interaction
		@Param1 -> char interaction[64]
		
		@return none
	*/
native void interact_registerInteract(char interaction[64]);
	
	/*
		Forward when a Client uses another Client
		
		@Param1 -> int client
		@Param2 -> int target
		
		@return -
	*/
forward void OnPlayerInteractionStarted(int client, int target);
	
	
	/*
		Forward when a Client interacts with another Client
		
		@Param1 -> int client
		@Param2 -> int target
		@Param2 -> char interaction[64]
		
		@return -
	*/
forward void OnPlayerInteract(int client, int target, char interaction[64]);