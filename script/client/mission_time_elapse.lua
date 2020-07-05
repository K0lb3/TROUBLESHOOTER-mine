function OnTimeElapsingStarted(elapsedTime, nextTeam)
	local nextTeamRelation = GetRelationWithPlayer(nextTeam);
	if nextTeamRelation ~= 'Team' then
		EnableAcceleration(GetOption().Gameplay.OtherActionAccel);
		if elapsedTime > 0 then
			UpdateTurnFlow('NPCTurn');
		end
	end
end

function OnTimeElapsingEnded(elapsedTime, nextTeam)
	local nextTeamRelation = GetRelationWithPlayer(nextTeam);
	if nextTeamRelation == 'Team' and elapsedTime > 0 then
		UpdateTurnFlow('UserTurn');
	end
end