private ["_characterID","_temp","_currentWpn","_magazines","_currentmag","_force","_isNewPos","_humanity","_isNewGear","_currentModel","_modelChk","_playerPos","_playerGear","_playerBackp","_backpack","_killsB","_killsH","_medical","_isNewMed","_character","_timeSince","_charPos","_isInVehicle","_distanceFoot","_lastPos","_kills","_headShots","_timeGross","_timeLeft","_onLadder","_isTerminal","_currentAnim","_muzzles","_array","_key","_lastTime","_config","_currentState","_pos","_otheritems","_backy"];
//[player,array]
//diag_log ("UPDATE: " + str(_this) );

//waituntil {(typeName(_this) == "ARRAY");sleep 0.01;};	//seems to cause often infinite waits (but not for first n players)

//this only happens when we don't follow the correct parameter format...
//(like supplying just the player object instead of the array in player_eat.sqf)
//i've fixed this in player_eat so i can comment this part out
/*if ( typeName(_this) == "OBJECT" ) then {
	_this = [_this,[],true];
	//diag_log ("DW_DEBUG: #manual fix _this: " + str(_this));
};*/

//correct
//"UPDATE: [B 1-1-B:1 (THE BEAST) REMOTE,[],true]"
//error
//"UPDATE: B 1-1-B:1 (THE BEAST) REMOTE"

_character = 	_this select 0;
_backy = backpackItems _character;
_otheritems = assignedItems _character;
_magazines = vestItems _character;
_currentmag = currentMagazine _character;
private ["_secmag","_magArray","_weapons"];
_secmag = (handgunMagazine _character) select 0;

_magArray = [];
if (_currentmag != "") then {
_magArray = _magArray + [_currentmag];
};
if (_secmag != "") then {
_magArray = _magArray + [_secmag];
};
_weapons = [primaryWeapon _character, handgunWeapon _character];
if ((_secmag == _currentMag) and (_currentMag != "")) then {
    _magArray = [_currentmag];
};
_force =	_this select 2;
_force =	true;

_characterID =	_character getVariable ["characterID","0"];
_charPos = 		getPosATL _character;
_isInVehicle = 	vehicle _character != _character;
_timeSince = 	0;
_humanity =		0;

//diag_log ("DW_DEBUG: (isnil _characterID): " + str(isnil "_characterID"));
/*
if !(isnil "_characterID") then {
diag_log ("DW_DEBUG: _characterID: " + str(_characterID));
};
*/

if (_character isKindOf "Animal") exitWith {
	diag_log ("ERROR: Cannot Sync Character " + (name _character) + " is an Animal class");
};

if (isnil "_characterID") exitWith {
	diag_log ("ERROR: Cannot Sync Character " + (name _character) + " has nil characterID");	
};

if (_characterID == "0") exitWith {
	diag_log ("ERROR: Cannot Sync Character " + (name _character) + " as no characterID");
};

private["_debug","_distance"];
_debug = getMarkerpos "respawn_west";
_distance = _debug distance _charPos;
if (_distance < 2000) exitWith { 
	diag_log format["ERROR: server_playerSync: Cannot Sync Player %1 [%2]. Position in debug! %3",name _character,_characterID,_charPos];
};

//Check for server initiated updates
_isNewMed =		_character getVariable["medForceUpdate",false];		//Med Update is forced when a player receives some kind of med incident
_isNewPos =		_character getVariable["posForceUpdate",false];		//Med Update is forced when a player receives some kind of med incident
_isNewGear =	(count _magazines) > 0;

//diag_log ("Starting Save... MED: " + str(_isNewMed) + " / POS: " + str(_isNewPos)); sleep 0.05;

//Check for player initiated updates
if (_characterID != "0") then {
	_playerPos =	[];
	_playerGear =	[];
	_playerBackp =	[];
	_medical =		[];
	_distanceFoot =	0;
	
	//diag_log ("Found Character...");
	
	//Check if update is requested
	if (_isNewPos or _force) then {
		//diag_log ("position..." + str(_isNewPos) + " / " + str(_force)); sleep 0.05;
		if (((_charPos select 0) == 0) and ((_charPos select 1) == 0)) then {
			//Zero Position
		} else {
			//diag_log ("getting position..."); sleep 0.05;
			_playerPos = 	[round(direction _character),_charPos];
			_lastPos = 		_character getVariable["lastPos",_charPos];
			if (count _lastPos > 2 and count _charPos > 2) then {
				if (!_isInVehicle) then {
					_distanceFoot = round(_charPos distance _lastPos);
				};
				_character setVariable["lastPos",_charPos];
			};
			if (count _charPos < 3) then {
				_playerPos =	[];
			};
			//diag_log ("position = " + str(_playerPos)); sleep 0.05;
		};
		_character setVariable ["posForceUpdate",false,true];
	};
	if (!_isNewGear) then {
		//diag_log ("gear..."); sleep 0.05;
        _vestMags = vestItems _character;
        waitUntil{!isnil "_vestMags"};
        _arrayM = _magazines + _magArray;
		_playerGear = [[vest _character] + _weapons + _otheritems ,_arrayM];		
		diag_log ("playerGear: " +str(_playerGear) + "_backy gear: " +str(_backy));
		_backpack = unitBackpack _character;
		_playerBackp = [typeOf _backpack,getWeaponCargo _backpack,getMagazineCargo _backpack];
	} else {
		//diag_log ("gear..."); sleep 0.05;
        _vestMags = vestItems _character;
        waitUntil{!isnil "_vestMags"};
        _arrayM = _magazines + _magArray;
		_playerGear = [[vest _character] + _weapons + _otheritems ,_arrayM];		
		diag_log ("playerGear: " +str(_playerGear) + "_backy gear: " +str(_backy));
		_backpack = unitBackpack _character;
		_playerBackp = [typeOf _backpack,getWeaponCargo _backpack,getMagazineCargo _backpack];
	};
	
	if (_isNewMed or _force) then {
		//diag_log ("medical..."); sleep 0.05;
		if (!(_character getVariable["USEC_isDead",false])) then {
			//diag_log ("medical check..."); sleep 0.05;
			_medical = _character call player_sumMedical;
			//diag_log ("medical result..." + str(_medical)); sleep 0.05;
		};
		_character setVariable ["medForceUpdate",false,true];
	};
	
	//Process update
	if (_characterID != "0") then {		
		//Record stats while we're here		
		/*
			Check previous stats against what client had when they logged in
			this helps prevent JIP issues, where a new player wouldn't have received
			the old players updates. Only valid for stats where clients could have
			be recording  results from their local objects (such as agent zombies)
		*/
		_kills = 		["zombieKills",_character] call server_getDiff;
		_killsB = 		["banditKills",_character] call server_getDiff;
		_killsH = 		["humanKills",_character] call server_getDiff;
		_headShots = 	["headShots",_character] call server_getDiff;
		_humanity = 	["humanity",_character] call server_getDiff2;
		//_humanity = 	_character getVariable ["humanity",0];
		_character addScore _kills;		
		/*
			Assess how much time has passed, for recording total time on server
		*/
		_lastTime = 	_character getVariable["lastTime",time];
		_timeGross = 	(time - _lastTime);
		_timeSince = 	floor(_timeGross / 60);
		_timeLeft =		(_timeGross - (_timeSince * 60));
		/*
			Get character state details
		*/
		_currentWpn = 	currentMuzzle _character;
		_currentAnim =	animationState _character;
        if ((animationState player == "sitUnarm_L_idleLoop_inUH1Y") or (animationState player == "amovpsitmstpsnonwnondnon_ground") or (animationState player == "amovpercmstpsnonwnondnon")) then {
            _currentAnim = "amovpercmstpsnonwnondnon";
        };
		_config = 		configFile >> "CfgMovesMaleSdr" >> "States" >> _currentAnim;
		_onLadder =		(getNumber (_config >> "onLadder")) == 1;
		_isTerminal = 	(getNumber (_config >> "terminal")) == 1;
		//_wpnDisabled =	(getNumber (_config >> "disableWeapons")) == 1;
		_currentModel = typeOf _character;
		_modelChk = 	_character getVariable ["model_CHK",""];
		if (_currentModel == _modelChk) then {
			_currentModel = "";
		} else {
			_currentModel = str(_currentModel);
			_character setVariable ["model_CHK",typeOf _character];
		};
		
		if (_onLadder or _isInVehicle or _isTerminal) then {
			_currentAnim = "";
			//If position to be updated, make sure it is at ground level!
			if ((count _playerPos > 0) and !_isTerminal) then {
				_charPos set [2,0];
				_playerPos set[1,_charPos];					
			};
		};
		if (_isInVehicle) then {
			_currentWpn = "";
		} else {
			if ( typeName(_currentWpn) == "STRING" ) then {
				_muzzles = getArray(configFile >> "cfgWeapons" >> _currentWpn >> "muzzles");
				if (count _muzzles > 1) then {
					_currentWpn = currentMuzzle _character;
				};	
			} else {
				//diag_log ("DW_DEBUG: _currentWpn: " + str(_currentWpn));
			_currentWpn = "";
			};
		};
		_temp = round(_character getVariable ["temperature",100]);
		_currentState = [_currentWpn,_currentAnim,_temp];
		/*
			Everything is ready, now publish to HIVE
		*/
		if (count _playerPos > 0) then {
			_array = [];
			{
				if (_x > -20000 and _x < 20000) then {
					_array set [count _array,_x];
				};
			} forEach (_playerPos select 1);
			_playerPos set [1,_array];
		};
		
		if (alive _character) then {
				//Wait for HIVE to be free
				//Send request
				_key = format["CHILD:201:%1:%2:%3:%4:%5:%6:%7:%8:%9:%10:%11:%12:%13:%14:%15:%16:",_characterID,_playerPos,_playerGear,_playerBackp,_medical,false,false,_kills,_headShots,_distanceFoot,_timeSince,_currentState,_killsH,_killsB,_currentModel,_humanity];
				diag_log ("HIVE: WRITE: "+ str(_key) + " / " + _characterID);
				_key call server_hiveWrite;
		};
		
		// If player is in a vehicle, keep its position updated
		if (vehicle _character != _character) then {
			[vehicle _character, "position"] call server_updateObject;
		};
		
		// Force gear updates for nearby vehicles/tents
		_pos = getPosATL _character;
		{
			[_x, "gear"] call server_updateObject;
		} forEach nearestObjects [_pos, ["Car", "Helicopter", "Motorcycle", "Ship", "TentStorage","ACampStorage"], 20];
		//[_charPos] call server_updateNearbyObjects;

		//Reset timer
		if (_timeSince > 0) then {
			_character setVariable ["lastTime",(time - _timeLeft)];
		};
	};
};
