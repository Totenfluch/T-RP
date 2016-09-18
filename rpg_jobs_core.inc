#if defined _rpg_jobs_core_included_
  #endinput
#endif
#define _rpg_jobs_core_included_

	/*
		Gets a clients job
		
		@Param1 -> int client
		@Param2 -> char jobBuffer[128]
		
		@return none
	*/
native void jobs_getActiveJob(int client, char jobBuffer[128]);
	
	/*
		Check if the given job is the Active
		
		@Param1 -> int client
		@Param2 -> char job[128]
		
		@return true or false
	*/
native bool jobs_isActiveJob(int client, char job[128]);
	
	/*
		Get current Job experience
		
		@Param1 -> int client
		
		@return none
	*/
native int jobs_getExperience(int client);
	
	/*
		add to current job experience
		
		@Param1 -> int client
		@Param2 -> int amount
		@Param3- > char jobname[128];
		
		@return none
	*/
native void jobs_addExperience(int client, int amount, char jobname[128]);
	
	/*
		removes experience from the client
		
		@Param1 -> int client
		@Param2 -> int amount
		@Param3- > char jobname[128];
		
		@return none
	*/
native void jobs_removeExperience(int client, int amount, char jobname[128]);
	
	/*
		Get current Job level
		
		@Param1 -> int client
		
		@return int current_job_level
	*/
native int jobs_getLevel(int client);
	
	/*
		Starts the progressbar
		
		@Param1 -> int client
		@Param2 -> float time
		@Param3 -> char info[64]
		
		@return none
	*/
native void jobs_startProgressBar(int client, float time, char info[64]);
	
	/*
		Stops the progressbar
		
		@Param1 -> int client
		
		@return none
	*/
native void jobs_stopProgressBar(int client);
	
	/*
		Forward on Job Accepted
		
		@Param1 -> int client
		@Param3 -> char jobname[128]
		
		@return -
	*/
forward void jobs_OnJobAccepted(int client, char jobname[128]);
	
	/*
		Forward on Job Quit
		
		@Param1 -> int client
		@Param3 -> char jobname[128]
		
		@return -
	*/
forward void jobs_OnJobQuit(int client, char jobname[128]);
	
	/*
		Forward on Client job levelup
		
		@Param1 -> int client
		@Param2 -> int newLevel
		@Param3 -> char jobname[128]
		
		@return -
	*/
forward void jobs_OnJobLevelUp(int client, int newLevel, char jobname[128]);
	
	/*
		Forward on Client ProgressBarFinished
		
		@Param1 -> int client
		@Param3 -> char info[64]
		
		@return -
	*/
forward void jobs_OnProgressBarFinished(int client, char info[64]);
	
	/*
		Forward on Client ProgressBarInterrupted
		
		@Param1 -> int client
		@Param3 -> char info[64]
		
		@return -
	*/
forward void jobs_OnProgressBarInterrupted(int client, char info[64]);