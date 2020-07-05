function InitializeWatchtower(towerState, watchtower)
	watchtower.ScentOfPresence = false;	-- 존재의 향기를 지워내다..
	if towerState == 'Destroyed' then
		EnableInteraction(watchtower, 'Repair');
		AddBuff(watchtower, 'Breakdown');
	elseif towerState == 'Active' then
		EnableInteraction(watchtower, 'Deactivate');
		EnableInteraction(watchtower, 'HackOff');
		AddBuff(watchtower, 'DetectingWatchtower');
	else
		EnableInteraction(watchtower, 'Activate');
		EnableInteraction(watchtower, 'HackOff');
		AddBuff(watchtower, 'Dormant');
	end
end

function InitializeSurveillanceNetwork(snObj, onOff)
	SetControllable(snObj, false);
	EnableInteraction(snObj, 'HackOff');
	snObj.ScentOfPresence = false;
	UpdateTemporaryMastery(snObj, 'SurveillanceNetworking', 1);
end

function GetWatchtowerMonsterType(towerState, team)
	local monType = 'Watchtower_' .. towerState;
	if towerState == 'Active' then
		if team == 'enemy' then
			monType = monType .. '_Enemy';
		else
			monType = monType .. '_Player';
		end
	end
	return monType;
end

function ReplaceWatchtower(target, newTowerState, team, ds, refID)
	local replacingMonType = GetWatchtowerMonsterType(newTowerState, team);
	local towerInitializer = function(tower, args)
		SetInstantProperty(tower, 'MonsterType', replacingMonType);
		UNIT_INITIALIZER(tower, tower.Team, {Patrol = false});
		InitializeWatchtower(newTowerState, tower);
	end;
	
	local newObjKey = GenerateUnnamedObjKey(target);
	
	local actions = {};
	table.insert(actions, Result_DestroyObject(target, false));
	table.insert(actions, Result_CreateMonster(newObjKey, replacingMonType, GetPosition(target), team, towerInitializer, nil, 'DoNothingAI', nil, true));
	
	if ds ~= nil then
		if refID == nil then
			refID = ds:Sleep(0);
		end
		
		local lastActionID = nil;
		for _, action in ipairs(actions) do
			local actionID = ds:WorldAction(action);
			ds:Connect(actionID, refID);
			lastActionID = actionID;
		end
		
		return newObjKey, lastActionID;
	else
		return newObjKey, actions;
	end
end