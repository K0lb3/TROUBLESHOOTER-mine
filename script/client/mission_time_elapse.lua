function OnTimeElapsingStarted(elapsedTime, nextTeam, turnTarget)
	local nextTeamRelation = GetRelationWithPlayer(nextTeam);
	if nextTeamRelation ~= 'Team' then
		EnableAcceleration(GetOption().Gameplay.OtherActionAccel);
		if elapsedTime > 0 then
			UpdateTurnFlow('NPCTurn');
		end
	elseif (turnTarget and GetActionController(turnTarget) ~= 'None') then
		EnableAcceleration(GetOption().Gameplay.MyActionAccel);
	end
end

function OnTimeElapsingEnded(elapsedTime, nextTeam, turnTarget)
	local nextTeamRelation = GetRelationWithPlayer(nextTeam);
	if nextTeamRelation == 'Team' and elapsedTime > 0 then
		UpdateTurnFlow('UserTurn');
	end
end