/*
	Gets the Object that is in the Players Crosshair
*/
stock int getClientViewObject(int client) {
	float m_vecOrigin[3];
	float m_angRotation[3];
	GetClientEyePosition(client, m_vecOrigin);
	GetClientEyeAngles(client, m_angRotation);
	Handle tr = TR_TraceRayFilterEx(m_vecOrigin, m_angRotation, MASK_VISIBLE, RayType_Infinite, TRDontHitSelf, client);
	int pEntity = -1;
	if (TR_DidHit(tr)) {
		pEntity = TR_GetEntityIndex(tr);
		delete tr;
		if (!isValidClient(client))
			return -1;
		if (!IsValidEntity(pEntity))
			return -1;
		if (isValidClient(pEntity))
			return -1;
		float playerPos[3];
		float entPos[3];
		GetClientAbsOrigin(client, playerPos);
		GetEntPropVector(pEntity, Prop_Data, "m_vecOrigin", entPos);
		if (GetVectorDistance(playerPos, entPos) > 100.0)
			return -1;
		return pEntity;
	}
	delete tr;
	return -1;
}

stock bool TRDontHitSelf(int entity, int mask, any data) {
	if (entity == data)
		return false;
	return true;
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}

stock bool isVipRank1(int client) {
	return CheckCommandAccess(client, "sm_rpvip1", ADMFLAG_CUSTOM5, true);
}

stock bool isVipRank2(int client) {
	return CheckCommandAccess(client, "sm_rpvip2", ADMFLAG_CUSTOM6, true);
} 