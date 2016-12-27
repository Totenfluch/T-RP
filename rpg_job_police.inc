#if defined _rpg_job_police_included_
  #endinput
#endif
#define _rpg_job_police_included_

	/*
		Return is the Player is cuffed or not
		@Param1-> int client
		
		@return true if cuffed false if not
	
	*/
native bool police_isPlayerCuffed(int client);