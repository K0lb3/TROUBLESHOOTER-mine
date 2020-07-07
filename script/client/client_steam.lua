-- 스팀 업적
function AddSteamStatByDirecting(args)
	if args.team and args.team ~= GetPlayerTeamName() then
		return;
	end
	AddSteamStat(args.statName, args.addValue, true);
end

function UpdateSteamStatByDirecting(args)
	if args.team and args.team ~= GetPlayerTeamName() then
		return;
	end
	UpdateSteamStat(args.statName, args.value, true);
end

function UpdateSteamAchievementByDirecting(args)
	if args.team and args.team ~= GetPlayerTeamName() then
		return;
	end
	UpdateSteamAchievement(args.achievementName, args.achieved);
end