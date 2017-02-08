/** Double-include prevention */
#if defined _rpg_licensing_included_
#endinput
#endif
#define _rpg_licensing_included_


/*
		@Params -> void
		
		return true or false
	*/
native bool licensing_isValid();

/*
		@Param1 -> char[64] License Key Buffer
		@Param2 -> char[128] sha1 Buffer
	*/
native void licensing_getChecksums(char licenseBuffer[64], char sha1Buffer[128]);


/*
		Forward when the Token is refreshed
		
		@Param1 -> char[64] ServerToken
		@Param1 -> char[128] Sha1Token
			
		@return -
	*/
forward void licensing_OnTokenRefreshed(char serverToken[64], char sha1Token[128]); 