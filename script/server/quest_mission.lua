function ProgressQuestTargetCount(user, questInfo, questCls, ds, count, updateCountSub, noDBUpdate)
	local dc = GetMissionDatabaseCommiter(user);
	local maxCount = questCls.Type.MaxCountGetter(questCls);
	if questInfo.Progress.TargetCount == maxCount then
		return;
	end
	local nextCount = math.min(maxCount, questInfo.Progress.TargetCount + count);
	if not noDBUpdate then
		dc:UpdateQuestProperty(user, questCls.name, 'TargetCount', nextCount);
	end
	questInfo.Progress.TargetCount = nextCount;	-- 디비 적용이 바로 안되기 때문에 여기서 메모리상으로 올려준다.
	
	if updateCountSub ~= nil then
		if not noDBUpdate then
			dc:UpdateQuestProperty(user, questCls.name, 'TargetCountSub', updateCountSub);
		end
		questInfo.Progress.TargetCountSub = updateCountSub;
	end
	ds:UpdateQuestProgress(questCls.name);
	if questInfo.Progress.TargetCount == maxCount then
		return Result_FireWorldEvent('QuestProgressSatisfied', {QuestType = questCls.name});
	end
end

function OnUnitDead_CollectItem_Kill(user, questInfo, questCls, eventArg, ds)
	if eventArg.Killer == nil or GetCompany(GetExpTaker(eventArg.Killer)) ~= user then
		return;
	end
	
	local dead = eventArg.Unit;
	local ratio = 0;
	for _, target in ipairs(questCls.TargetMonster) do
		local tp = target.Type;
		if tp == 'Monster' then
			if target.Target == FindBaseMonsterTypeWithCache(dead) then
				ratio = target.Ratio;
				break;
			end
		elseif tp == 'Race' then
			if target.Target == dead.Race.name then
				ratio = target.Ratio;
				break;
			end
		elseif tp == 'Job' then
			if target.Target == dead.Job.name then
				ratio = target.Ratio;
				break;
			end
		end
	end
	
	if ratio == 0 then
		return;
	end
	
	ratio = ratio + questInfo.Progress.TargetCountSub;		-- 확률 보정
	
	if GetInstantProperty(dead, 'MonsterType') ~= FindBaseMonsterTypeWithCache(dead) then
		ratio = ratio + 25;	-- 정예
	end
	
	if RandomTest(100 - ratio) then
		local dc = GetMissionDatabaseCommiter(user);
		questInfo.Progress.TargetCountSub = questInfo.Progress.TargetCountSub + 5;
		dc:UpdateQuestProperty(user, questCls.name, 'TargetCountSub', questInfo.Progress.TargetCountSub);
		return;
	end
	return ProgressQuestTargetCount(user, questInfo, questCls, ds, 1, 0);
end
function OnUnitItemAcquired_CollectItem(user, questInfo, questCls, eventArg, ds)
	if GetCompany(GetExpTaker(eventArg.Unit)) ~= user then
		return;
	end
	if eventArg.Item.name ~= questCls.Target then
		return;
	end
	return ProgressQuestTargetCount(user, questInfo, questCls, ds, eventArg.Item.Amount, 0, true);
end
function OnCollectItemCollected_CollectItem_Property(user, questInfo, questCls, eventArg, ds)
	if eventArg.CollectItemSet ~= questCls.Target then
		return;
	end
	return ProgressQuestTargetCount(user, questInfo, questCls, ds, 1);
end
function OnArrestUnitKilled_ArrestGen_Property(user, questInfo, questCls, eventArg, ds)
	if eventArg.ArrestSet ~= questCls.Target then
		return;
	end
	return ProgressQuestTargetCount(user, questInfo, questCls, ds, 1);
end
function OnUnitDead_Assassination_Organization(user, questInfo, questCls, eventArg, ds)
	if eventArg.Killer.Team ~= GetUserTeam(user) then
		-- 설마 킬러가 내편인데 아군을 잡는다거나 하진 않겠지?
		return
	end
	
	if questCls.Target ~= eventArg.Unit.Affiliation.name then
		return;
	end
		
	local curCount = questInfo.Progress.TargetCount;
	if curCount >= questCls.TargetCount then
		return;
	end
	
	local mission = GetMission(user);

	-- 메시지 처리 (아직 몰라)
	if curCount == questCls.TargetCount then
		ds:UpdateBattleEvent(GetObjKey(eventArg.Killer), 'AssassinationCompleted', {});
	else
		ds:UpdateBattleEvent(GetObjKey(eventArg.Killer), 'AssassinationProgress', { Current = curCount, Target = questCls.TargetCount });
	end
	
	local dc = GetMissionDatabaseCommiter(mission);
	dc:UpdateQuestProperty(user, questCls.name, 'TargetCount', curCount + 1);
	questInfo.Progress.TargetCount = curCount + 1;	-- 디비 적용이 바로 안되기 때문에 여기서 메모리상으로 올려준다.
end
function OnUnitDead_Assassination_Object(user, questInfo, questCls, eventArg, ds)
	if eventArg.Killer.Team ~= GetUserTeam(user) then
		-- 설마 킬러가 내편인데 아군을 잡는다거나 하진 않겠지?
		return
	end
	
	local quest = GetClassList('Quest')[questInfo.Type];
	
	if quest.Target ~= eventArg.Unit.name then
		return;
	end
	local curCount = questInfo.Progress.TargetCount;
	if curCount >= quest.TargetCount then
		return;
	end
	
	local mission = GetMission(user);

	-- 메시지 처리 (아직 몰라)
	if curCount == questCls.TargetCount then
		ds:UpdateBattleEvent(GetObjKey(eventArg.Killer), 'AssassinationCompleted', {});
	else
		ds:UpdateBattleEvent(GetObjKey(eventArg.Killer), 'AssassinationProgress', { Current = curCount, Target = questCls.TargetCount });
	end
	
	local dc = GetMissionDatabaseCommiter(mission);
	dc:AddQuestProperty(user, quest.name, 'TargetCount', 1);
	questInfo.Progress.TargetCount = curCount + 1;	-- 디비 적용이 바로 안되기 때문에 여기서 메모리상으로 올려준다.
end
function OnMissionEnd_MissionClearQuest(user, questInfo, questCls, eventArg, ds)
	local mission = GetMission(user);
	if mission.name ~= questCls.Target then		-- 대상 미션 여부체크
		return;
	end
	
	if eventArg.Winner == 'enemy' then
		return;
	end
	
	local curCount = questInfo.Progress.TargetCount;
	if curCount >= questCls.TargetCount then
		return;
	end

	local dc = GetMissionDatabaseCommiter(mission);
	dc:AddQuestProperty(user, questCls.name, 'TargetCount', 1);
end
function OnClearCheckPoint_MissionRepeatQuest(user, questInfo, questCls, eventArg, ds)
	local mission = GetMission(user);
	if mission.name ~= questCls.Target then		-- 대상 미션 여부체크
		return;
	end
	
	if questInfo.Progress.CheckPoint[eventArg.CheckPoint] then
		-- 이미 깬곳
		return;
	end
	local dc = GetMissionDatabaseCommiter(mission);
	dc:UpdateQuestProperty(user, questCls.name, 'CheckPoint/'..eventArg.CheckPoint, true);
end