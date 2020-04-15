print("loading...")

local game_scopes = {
	["party"]=true,
	["raid"]=true
}
local game_scope = "party"

local game_modes = {
	["high"]=true,
	["low"]=true,
	["duel"]=true,
}

local game_mode = "high"
local roll_target = "(1-100)"

local players = {}
local needs_to_roll = {}
local player_to_roll = {}
local roll_to_player = {}
local pending_payouts = {}
local game_active = false
local enrollment_open = false

local roll_winner = nil
local roll_loser = nil

local tie_depth  = 0;
local ties = {}
-- -- LOAD FUNCTION --

local function LocalChat(label, msg)
	if(string.len(label) > 0) then
		label = "["..label.."]: ";
	end		
	
	DEFAULT_CHAT_FRAME:AddMessage(ORANGE_FONT_COLOR_CODE..label..msg..FONT_COLOR_CODE_CLOSE);
end

function OnLoadAddon(self)
	LocalChat("", "|cffffff00<Welcome to No Dice Raid Spice!> type /rs [command] to use");

	self:RegisterEvent("CHAT_MSG_RAID");
	self:RegisterEvent("CHAT_MSG_CHANNEL");
	self:RegisterEvent("CHAT_MSG_RAID_LEADER");
	self:RegisterEvent("CHAT_MSG_PARTY_LEADER");
	self:RegisterEvent("CHAT_MSG_PARTY");
	self:RegisterEvent("CHAT_MSG_GUILD");
	self:RegisterEvent("CHAT_MSG_SYSTEM");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterForDrag("LeftButton");
end

function PopulatePlayerRoll(rollMsg)
	local player, junk, roll, range = strsplit(" ", rollMsg);	
	
	if(junk == "rolls")then	
		print("roll detected: "..player)
		if(game_active and not enrollment_open and needs_to_roll[player]) then
			if(range == roll_target) then
				needs_to_roll[player] = nil			
				local num_roll = tonumber(roll);
				player_to_roll[player] = num_roll;
				if(not roll_to_player[tonumber(roll)]) then
					roll_to_player[tonumber(roll)] = {}
				end
				table.insert(roll_to_player[tonumber(roll)], player)	
				LocalChat("Roll", player.." rolled "..roll);
			else
				SendChatMessage("Invalid roll. Use '/roll "..roll_target.."' for this game", "WHISPER", nil, player);
			end
			
			
		else
			SendChatMessage("You already rolled a '"..player_to_roll[player].."'!", "WHISPER", nil, player);			
		end
	end
end

function SetPlayerEnrollment(msg, player)
	if (game_active) then
		if(msg == "1" or msg == "-1") then
			if (enrollment_open) then					
				print("enroll "..player);
				if(msg == "1" and needs_to_roll[player] == nil) then
					SendChatMessage("You have been enrolled into the current game", "WHISPER", nil, player);
					LocalChat("Enrollment", player.." has joined the game.");
					needs_to_roll[player] = true;
					
				elseif(msg == "-1" and needs_to_roll[player]) then
					SendChatMessage("You have been removed from the current game", "WHISPER", nil, player);				
					needs_to_roll[player] = nil;
					LocalChat("Enrollment", player.." has left the game.");
				end		
				
			else
				SendChatMessage("Sorry, the enrollment period for this game has closed", "WHISPER", nil, player);
			end		
		end		
	end
end

function OnEventTrigger(self, event, ...)	

	if (event == "CHAT_MSG_SYSTEM") then
		local msg = ...
		PopulatePlayerRoll(tostring(msg));
	end
	if ((event == "CHAT_MSG_RAID_LEADER" or event == "CHAT_MSG_RAID") and enrollment_open ) then
		local msg, _,_,_,name = ... -- name no realm
		SetPlayerEnrollment(msg, name)
	end

	if ((event == "CHAT_MSG_PARTY_LEADER" or event == "CHAT_MSG_PARTY")and enrollment_open) then
		local msg, fullname = ... -- name no realm	
		local name = strsplit("-", fullname)
		SetPlayerEnrollment(msg, name)
	end

end

function OnSlashCmd(cmd)
	
	local command = "";
	
	for cmd_low in string.gmatch(cmd:lower(), "%S+") do	
	
		if(command == "") then	
		
			if(cmd_low == "start") then
				StartGame();
				
			elseif(cmd_low == "close") then
				CloseEnrollment();
				
			elseif(cmd_low == "warn") then
				WarnEnrollment();
				
			elseif(cmd_low == "render") then
				RenderGameResult();
				
			elseif(cmd_low == "reset") then
				Reset();
				
			elseif(cmd_low == "scope") then
				command = "scope"
				
			elseif(cmd_low == "roll") then
				command = "roll"
				
			elseif(cmd_low == "game") then
				command = "game"
				
			else
				LocalChat("",  "-- RaidSpice Command List --");
				LocalChat("", "game [high|low|duel] - sets the current game mode");
				LocalChat("", "scope [raid|party] - sets the current game chat scope");
				LocalChat("", "roll [number] - sets the roll target for the game");
				LocalChat("", "start - begins a new instance of the game");
				LocalChat("", "warn - reminds players to enroll into an active game");
				LocalChat("", "close - finalize and close the game enrollment period");
				LocalChat("", "render - attempt to finalize and render game results");
				LocalChat("", "reset - force reset any game state");
			end	
		
				
		elseif(command == "scope") then
			if game_scopes[cmd_low] then
				if(not game_active) then
					game_scope = cmd_low:upper();
					LocalChat("", "Scope set to "..game_scope);
				else
					LocalChat("Error", "You cannot change the game scope while a game is active!");
				end	
				
			else
				LocalChat("Error", "Invalid scope. Use ('party' or 'raid')");
			end	
			
		elseif(command == "game") then
			if(game_modes[cmd_low]) then
				if(not game_active) then
					game_mode = cmd_low;
					LocalChat("Notice", "Game mode set to "..cmd_low);
				else
					LocalChat("Error", "You cannot change the game mode while a game is active!");
				end				
			else
				LocalChat("Error", "Invalid game mode. Use ('high', 'low', or 'duel')");
			end
			
		elseif(command == "roll") then	
			if(not game_active) then
				if(string.match(cmd_low, "[0-9]+-[0-9]+")) then
					roll_target = "("..cmd_low..")" 
					LocalChat("", "Roll target set to "..roll_target);
				else
					LocalChat("Error", "Invalid roll format. Use: '[0-9]+-[0-9]+'");
				end				
			else
				LocalChat("Error", "You cannot change the roll target while a game is active!");
			end				
			
		end
		
	end
	
end

SLASH_RaidSpice1 = "/rs";
SlashCmdList["RaidSpice"] = OnSlashCmd

function Elements(some_list)
	local count = 0
	for k, v in pairs(some_list) do
		count = count + 1
	end
	return count;
end

function First(some_table)
	for i, a in pairs(some_table) do
		return a;
	end
end




function MessageToRoll(player)
	SendChatMessage(player.." still needs to /roll "..roll_target, game_scope, nil, nil);
	SendChatMessage("An open game is awaiting your roll. Please /roll "..roll_target, "WHISPER", nil, player);
end

 function HighAndLow()
	
	local high_roll = -1
	local high_count = 0
	local low_roll = -1	
	local low_count = 0
	
				
	for key,value in pairs(roll_to_player) do 
		if(key > high_roll) then 
			high_roll = key 
			high_count = 0
		end
		if(key == high_roll) then
			high_count = high_count + 1
		end		
		if(key < low_roll or low_roll == -1) then 
			low_roll = key 
			low_count = 0
		end			
		if(key == low_roll) then
			low_count = low_count + 1
		end
	end	
	
	return high_roll, high_count, low_roll, low_count
 end

function RenderGameResult()

	if(game_active) then
		if(game_mode == "high" or game_mode == "low") then
						
			local elements = Elements(needs_to_roll);	
			
			if(elements > 0) then
				for player, j in pairs(needs_to_roll) do 
					MessageToRoll(player)		
				end	
			else 
				local high, hcount, low, lcount = HighAndLow();
				
				print(HighAndLow());
	
				if(hcount > 1) then
					SendChatMessage("Tie detected for winner. No payout.", game_scope, nil, nil);
					Reset();
				else
					roll_winner = First(roll_to_player[high]);
				end
				
				if(lcount > 1) then
					SendChatMessage("Tie detected for loser. No payout", game_scope, nil, nil);
					Reset();
				else
					roll_loser = First(roll_to_player[low]);
				end			

				if(game_mode == "high")then
					SendChatMessage(roll_loser.." owes "..roll_winner.." "..high-low.." gold", game_scope, nil, nil);
					Reset();
				elseif(game_mode == "low") then
					SendChatMessage(roll_winner.." owes "..roll_loser.." "..high-low.." gold", game_scope, nil, nil);
					Reset();
				end
				
				
					
			end
		end		
	else
		LocalChat("Error", "No active game to render");
	end	
end

function PromptRoll()
	if (game_mode == "high" or game_mode == "low") then
		SendChatMessage("Players please type /roll "..roll_target, game_scope, nil, nil);
	elseif(game_mode == "duel") then
	end
end

function CloseEnrollment()
	
	if (game_active and enrollment_open) then		
			
		enrollment_open = false;
		
		local total_players = Elements(needs_to_roll)	
		
		if(total_players > 1) then
			SendChatMessage("Enrollment period has ended. "..total_players.." players enrolled.", game_scope, nil, nil);
			PromptRoll();
			
		else
			SendChatMessage("Not enough players... Game cannot proceed", game_scope, nil, nil);
			Reset();
			
		end
	
	else
		LocalChat("Error", "No game is active with an enrollment to close");
	end
end

function WarnEnrollment()
	if(game_active) then
		SendChatMessage("Enrollment period is almost over. Last chance!", game_scope, nil, nil);
	else
		LocalChat("Error", "No game is active to warn");
	end
end

function FromTarget()
	local lowp, highp = strsplit("-", roll_target);
	
	return tonumber(string.match(lowp, "%d+")), tonumber(string.match(highp, "%d+"))
end

function StartGame()
	Reset();	
	
	SendChatMessage("~~~~~~~~~~~~~~~~~~~~~~~~~~~~", game_scope, nil, nil);
	SendChatMessage("~~~~~~ No Dice Raid Spice ~~~~~~", game_scope, nil, nil);
	
	local low, high = FromTarget();
	local risk = high - low;
	
	if(game_mode == "high") then		
		SendChatMessage("Starting 'high roll delta' game...", game_scope, nil, nil);
		SendChatMessage("Objective: Roll the highest number with '/roll "..low.."-"..high.."'", game_scope, nil, nil);
		SendChatMessage("Max Risk: "..risk, game_scope, nil, nil);
	elseif(game_mode == "low") then
		SendChatMessage("Starting 'low roll delta' game...", game_scope, nil, nil);
		SendChatMessage("Objective: Roll the lowest number with '/roll "..low.."-"..high.."'", game_scope, nil, nil);
		SendChatMessage("Max Risk: "..risk, game_scope, nil, nil);
	end
	
	SendChatMessage("To join this game, type '1' in "..game_scope:lower().." chat.", game_scope, nil, nil);
	SendChatMessage("To leave this game, type '-1' in "..game_scope:lower().." chat.", game_scope, nil, nil);
	SendChatMessage("~~~~~~~~~~~~~~~~~~~~~~~~~~~~", game_scope, nil, nil);
	
	game_active = true
	enrollment_open = true
end

function Reset()
	player_to_roll = {}
	roll_to_player = {}
	players = {}
	game_active = false;
	enrollment_open = false;
	do_lose_tie = false;
	do_win_tie = false;
	roll_winner = nil
    roll_loser = nil
	winners_tie = {}
	losers_tie = {}
	LocalChat("Notice","Game Reset!");
end