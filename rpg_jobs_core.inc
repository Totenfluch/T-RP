#if defined _rpg_jobs_core_included_
#endinput
#endif
#define _rpg_jobs_core_included_

/*
		Register a new job - do this OnPluginStart
		
		@Param1 -> char jobname[128]
		@Param2 -> char jobdescription[512]
		@Param3 -> int maxJobLevels
		@Param4 -> int jobExperiencePerLevel
		@Param5 -> float jobExperienceIncreasePercentagePerLevel
		
		
		@return none
	*/
native int jobs_registerJob(char jobname[128], char jobdescription[512], int maxJobLevels, int jobExperiencePerLevel, float jobExperienceIncreasePercentagePerLevel);

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
		Gets the Experience needed for the next level
		
		@Param1 -> int client
		
		@return none
	*/
native int jobs_getExperienceForNextLevel(int client);

/*
		Starts the progressbar
		
		@Param1 -> int client
		@Param2 -> int time
		@Param3 -> char info[64]
		
		@return none
	*/
native void jobs_startProgressBar(int client, int time, char info[64]);

/*
		Returns if the Progressbar is active
		
		@Param1 -> int client
		
		@return true or false
	*/
native bool jobs_isInProgressBar(int client);

/*
		Gives a Job to a client
		
		@Param1 -> int client
		@Param2 -> char jobname[128]
		
		@return none
	*/
native void jobs_giveJob(int client, char jobname[128]);

/*
		Quits the current job of the client
		
		@Param1 -> int client
		
		@return none
	*/
native void jobs_quitJob(int client);

/*
		Stops the progressbar
		
		@Param1 -> int client
		
		@return none
	*/
native void jobs_stopProgressBar(int client);


/*
		Set the Client Job info
		
		@Param1 -> int client
		@Param2 -> char info[128]
		
		@return none
	*/
native void jobs_setCurrentInfo(int client, char info[128]);

/*
		Get the Client Job info
		
		@Param1 -> int client
		@Param2 -> char info[128]
		
		@return none
	*/
native void jobs_getCurrentInfo(int client, char info[128]);

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
		@Param2 -> char info[64]
		
		@return -
	*/
forward void jobs_OnProgressBarInterrupted(int client, char info[64]); 