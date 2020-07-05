function lc_mission_9_1_custom1(mid, ds, conditionOutput, value, value2)
    local targetObj = GetUnit(mid, 'enemyBoss')
    local result = 0
	if targetObj ~= nil then
		local targetPos = GetPosition(targetObj);
	    local count1 = 0
	    local citizenCount = GetTeamCount(mid, 'citizen');
    	for i = 1, citizenCount do
    		local teamMember = GetTeamUnitByIndex(mid, 'citizen', i);
    		local teamPos = GetPosition(teamMember);
        	local distance = GetDistance3D(targetPos, teamPos);
        	if distance <= 5 then
        	    count1 = count1 + 1
        	end
    	end
	    local enemy1Count = GetTeamCount(mid, 'enemy1');
    	for i = 1, enemy1Count do
    		local teamMember = GetTeamUnitByIndex(mid, 'enemy1', i);
    		local teamPos = GetPosition(teamMember);
        	local distance = GetDistance3D(targetPos, teamPos);
        	if distance <= 5 then
        	    count1 = count1 + 1
        	end
    	end
    	
    	local nearCount = 0
	    local playerCount = GetTeamCount(mid, 'player');
    	for i = 1, playerCount do
    		local teamMember = GetTeamUnitByIndex(mid, 'player', i);
    		local teamPos = GetPosition(teamMember);
        	local distance = GetDistance3D(targetPos, teamPos);
        	if distance <= 5 then
        	    nearCount = nearCount + 1
        	end
    	end
    	if count1 > nearCount then
            return Result_UpdateStageVariable('stage3Flag', 1);
    	end
	end
	
	return
end

function lc_mission_8_1_custom1(mid, ds, conditionOutput, value, value2)
    local count = 0
    for i = 1, 4 do
        if GetStageVariable( GetMission(mid), 'linePoint'..i) == 1 then
            count = count + 1
        end
    end
    return Result_UpdateStageVariable('varDashBoard1', count);
end

function lc_mission_7_2_custom1(mid, ds, conditionOutput, value, value2)
    local count = 0
    for i = 1, 3 do
        if GetStageVariable( GetMission(mid), 'varFlag'..i) == 1 then
            count = count + 1
        end
    end
    return Result_UpdateStageVariable('varDashBoard1', count);
end

function lc_mission_1_3_custom1(mid, ds, conditionOutput, value, value2)
    local count = 0
    for i = 1, 10 do
        if GetStageVariable( GetMission(mid), 'lc_mission_1_3_2_'..i) == 1 then
            count = count + 1
        end
    end
    if count > 0 then
        return Result_UpdateStageVariable('lc_mission_1_3_2_Current', count);
    else
        Result_UpdateStageVariable('lc_mission_1_3_2_1', 1);
        return Result_UpdateStageVariable('lc_mission_1_3_2_Current', 1);
    end
end

function lc_mission_1_3_custom2(mid, ds, conditionOutput, value, value2)
    local count = 0
    for i = 1, 6 do
        if GetStageVariable( GetMission(mid), 'lc_mission_1_3_3_'..i) == 1 then
            count = count + 1
        end
    end
    if count > 0 then
        return Result_UpdateStageVariable('lc_mission_1_3_3_Current', count);
    else
        Result_UpdateStageVariable('lc_mission_1_3_3_1', 1);
        return Result_UpdateStageVariable('lc_mission_1_3_3_Current', 1);
    end
end


function lc_mission_5_4_custom1(mid, ds, conditionOutput, value, value2)
    local count = 0
    for i = 1, 8 do
        if GetStageVariable( GetMission(mid), 'lc_mission_var_'..i) == 1 then
            count = count + 1
        end
    end
    if count > 0 then
        return Result_UpdateStageVariable('lc_mission_var_current', count);
    else
        Result_UpdateStageVariable('lc_mission_var_1', 1);
        return Result_UpdateStageVariable('lc_mission_var_current', 1);
    end
end
