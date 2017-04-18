/*
MIT License

Copyright (c) 2017 RumbleFrog

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

#pragma semicolon 1

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <morecolors_store>

#pragma newdecls required

ConVar cState;
ConVar cVoteNeeded;

int CurrentState = 0;
float VoteNeeded = 0.6;

int g_Voters = 0;
int g_Votes = 0;
int g_VotesNeeded = 0;
bool g_Voted[MAXPLAYERS+1] = {false, ...};

public Plugin myinfo = 
{
	name = "Player Air Blast",
	author = PLUGIN_AUTHOR,
	description = "A simple plugin that controls the ability to air blast other players as pyro class",
	version = PLUGIN_VERSION,
	url = "https://keybase.io/rumblefrog"
};

public void OnPluginStart()
{
	CreateConVar("pab_version", PLUGIN_VERSION, "Player Airblast Version Control", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	cState = CreateConVar("sm_pab_allow", "0", "Allow player airblast.", FCVAR_NONE, true, 0.0, true, 1.0);
	cVoteNeeded = CreateConVar("sm_pab_needed", "0.6", "Percentage of vote needed to initiate a vote.", FCVAR_NONE, true, 0.0, true, 1.0);
	
	CurrentState = cState.IntValue;
	VoteNeeded = cVoteNeeded.FloatValue;
	
	HookConVarChange(cState, OnStateChange);
	HookConVarChange(cVoteNeeded, OnVoteNeededChange);
	
	RegConsoleCmd("sm_votepab", CmdVotePAB);
}

public void OnMapStart()
{
	g_Voters = 0;
	g_Votes = 0;
	g_VotesNeeded = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			OnClientConnected(i);	
		}	
	}
}

public void OnClientConnected(int client)
{
	if(IsFakeClient(client))
		return;
	
	g_Voted[client] = false;

	g_Voters++;
	g_VotesNeeded = RoundToFloor(float(g_Voters) * VoteNeeded);	
}

public void OnClientDisconnect(int client)
{
	if(IsFakeClient(client))
		return;
	
	if(g_Voted[client])
	{
		g_Votes--;
	}
	
	g_Voters--;
	
	g_VotesNeeded = RoundToFloor(float(g_Voters) * VoteNeeded);
	
	if (g_Votes && g_Voters && g_Votes >= g_VotesNeeded) 
		StartVote();
}

public void OnStateChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	CurrentState = StringToInt(newValue);
}

public void OnVoteNeededChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	VoteNeeded = StringToFloat(newValue);
}

void AttemptVote(int client)
{
	if (g_Voted[client])
	{
		MoreColors_CPrintToChat(client, "{lightseagreen}[PAB] {grey}You already voted");
		return;
	}
	
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	
	g_Votes++;
	g_Voted[client] = true;
	
	MoreColors_CPrintToChatAll("{lightseagreen}[PAB] {chartreuse}%s {grey}wish to toggle {aqua}player airblast{grey}. ({aqua}%d {grey}votes, {aqua}%d {grey}required)", name, g_Votes, g_VotesNeeded);
	
	if (g_Votes >= g_VotesNeeded)
	{
		StartVote();
	}	
}

void StartVote()
{
	if (IsVoteInProgress())
	{
		return;
	}
	
	MoreColors_CPrintToChatAll("{lightseagreen}[PAB] {gray}Vote started for {aqua}player airblast");
	
	Menu menu = new Menu(Handle_VoteMenu);
	
	menu.VoteResultCallback = Handle_VotePABMenu;
	menu.SetTitle("Toggle Player Airblast");
	menu.AddItem("1", "Enable Player Airblast");
	menu.AddItem("0", "Disable Player Airblast");
	menu.ExitButton = false;
	menu.DisplayVoteToAll(30);
}

public void Handle_VotePABMenu(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	int winner = 0;
	if (num_items > 1
	    && (item_info[0][VOTEINFO_ITEM_VOTES] == item_info[1][VOTEINFO_ITEM_VOTES]))
	{
		winner = GetRandomInt(0, 1);
	}
 
	char buffer[16];

	menu.GetItem(item_info[winner][VOTEINFO_ITEM_INDEX], buffer, sizeof(buffer));
		
	MoreColors_CPrintToChatAll("{lightseagreen}[PAB] {gray}Vote ended for {aqua}player airblast");
	
	g_Votes = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		g_Voted[i] = false;
	}
	
	int toggle = StringToInt(buffer);	
	
	CurrentState = toggle;
	
	if (toggle)
		MoreColors_CPrintToChatAll("{lightseagreen}[PAB] {gray}Player airblast has been {aqua}enabled");
	else
		MoreColors_CPrintToChatAll("{lightseagreen}[PAB] {gray}Player airblast has been {aqua}disabled");				
}

public int Handle_VoteMenu(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
		delete menu;
}

public Action CmdVotePAB(int client, int args)
{
	AttemptVote(client);
	
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon)
{
	if (CurrentState)
		return Plugin_Continue;
		
	if (Client_IsValid(iClient))
	{
		if(!(GetEntityFlags(iClient) & FL_NOTARGET))
		{
			SetEntityFlags(iClient, GetEntityFlags(iClient)|FL_NOTARGET);
		}
	}
	
	return Plugin_Continue;
}

stock bool Client_IsValid(int client, bool checkConnected=true)
{
	if (client > 4096) {
		client = EntRefToEntIndex(client);
	}

	if (client < 1 || client > MaxClients) {
		return false;
	}

	if (checkConnected && !IsClientConnected(client)) {
		return false;
	}

	return true;
}