/*
TO DO LIST:
- Apply stamina (optional)
Formula: (STAMINA_MAX - ((stam/1000) * STAMINA_RECOVER_RATE))/STAMINA_MAX

STAMINA_MAX = 100
STAMINA_COST_JUMP = 25
STAMINA_COST_FALL = 20
STAMINA_RECOVER_RATE = 19
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION	"1.00"

// Settings
#define HULL_PRECISION	2.5
#define JUMP_VEL 		290.0
#define GROUND_HEIGHT	10.0

new bool:bLateLoad = false;
new bool:g_bAutoEdgeEnabled[MAXPLAYERS+1];

public Plugin:myinfo = 
{
	name = "Auto-Edge-Jump",
	author = "ici",
	version = PLUGIN_VERSION
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	bLateLoad = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	RegConsoleCmd("sm_autoedge", SM_AutoEdge);
	
	if (bLateLoad)
		for (new i = 1; i <= MaxClients; i++)
			if (IsClientConnected(i) && IsClientInGame(i))
				OnClientPutInServer(i);
}

public OnClientPutInServer(client)
{
	g_bAutoEdgeEnabled[client] = false;
}

public Action:SM_AutoEdge(client, args)
{
	if (!client)
	{
		ReplyToCommand(client, "You cannot run this command through the server console.");
		return Plugin_Handled;
	}
	
	g_bAutoEdgeEnabled[client] = !g_bAutoEdgeEnabled[client];
	SayText2(client, "\x01\x07FF0000[ \x07FF6200AutoEdge \x07FF0000] \x07FFFFFF%s.", (g_bAutoEdgeEnabled[client]) ? "Enabled" : "Disabled");
	
	return Plugin_Handled;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	static bool:bOnGround[MAXPLAYERS+1];
	static bool:bLastOnGround[MAXPLAYERS+1];
	
	if (IsFakeClient(client) || !IsPlayerAlive(client) || !g_bAutoEdgeEnabled[client])
		return Plugin_Continue;
	
	bLastOnGround[client] = bOnGround[client];
	
	new flags = GetEntityFlags(client);
	if (flags & FL_ONGROUND)
		bOnGround[client] = true;
	else
		bOnGround[client] = false;
	
	if (bOnGround[client] == false
	|| bLastOnGround[client] == false
	|| flags & FL_INWATER
	|| GetEntityMoveType(client) != MOVETYPE_WALK) return Plugin_Continue;
	
	decl Float:vClientAbsVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vClientAbsVelocity);
	
	new Float:fSpeed = SquareRoot(Pow(vClientAbsVelocity[0], 2.0) + Pow(vClientAbsVelocity[1], 2.0));
	if (fSpeed == 0.0 || fSpeed > 290.0)
		return Plugin_Continue;
	
	if (GroundDistance(client) >= GROUND_HEIGHT)
	{
		//vClientAbsVelocity[2] = JUMP_VEL;
		//SetEntPropEnt(client, Prop_Data, "m_hGroundEntity", INVALID_ENT_REFERENCE);
		//SetEntityFlags(client, (GetEntityFlags(client) & ~FL_ONGROUND));
		//TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vClientAbsVelocity);
		buttons |= IN_JUMP;
	}
	return Plugin_Continue;
}

Float:GroundDistance(client)
{
	decl Float:vClientAbsOrigin[3];
	GetClientAbsOrigin(client, vClientAbsOrigin);
	
	decl Float:vTemp[3];
	vTemp = vClientAbsOrigin;
	vTemp[2] -= 8192.0;
	
	decl Float:vClientMins[3];
	GetClientMins(client, vClientMins);
	vClientMins[0] += HULL_PRECISION;
	vClientMins[1] += HULL_PRECISION;
	
	decl Float:vClientMaxs[3];
	GetClientMaxs(client, vClientMaxs);
	vClientMaxs[0] -= HULL_PRECISION;
	vClientMaxs[1] -= HULL_PRECISION;
	
	decl Handle:hTrace;
	hTrace = TR_TraceHullFilterEx(vClientAbsOrigin, vTemp, vClientMins, vClientMaxs, MASK_PLAYERSOLID_BRUSHONLY, TraceRayDontHitSelf, client);
	
	new Float:fTimeFraction = TR_GetFraction(hTrace);
	CloseHandle(hTrace);
	
	return ((vTemp[2] - vClientAbsOrigin[2]) * -fTimeFraction);
}

public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
	return entity != data && !(0 < entity <= MaxClients);
}

stock SayText2(to, const String:message[], any:...)
{
	new Handle:hBf = StartMessageOne("SayText2", to);
	if (!hBf) return;
	decl String:buffer[1024];
	VFormat(buffer, sizeof(buffer), message, 3);
	BfWriteByte(hBf, to);
	BfWriteByte(hBf, true);
	BfWriteString(hBf, buffer);
	EndMessage();
}
