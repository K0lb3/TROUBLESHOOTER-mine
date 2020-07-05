-- system
-- level up
function LevelUp(self)
	-- 
end
function tableMerge(t1, t2)
   for k,v in pairs(t2) do
		if type(v) == "table" then
			if type(t1[k] or false) == "table" then
				tableMerge(t1[k] or {}, t2[k] or {})
			else
				t1[k] = v
			end
		else
			t1[k] = v
		end
   end
   return t1;
end
function PrimaryUnitDead(eventArg, ds)
	if eventArg.Virtual then
		return;
	end
	local killer = eventArg.Killer;
	local retActions = {};
	-- 킬카운트.
	killer.KillCount = killer.KillCount + 1;
	return unpack(retActions);
end
function IsExpTaker(obj)
	return not GetInstantProperty(obj, 'MonsterType') and not GetInstantProperty(obj, 'NoExpTaker');
end
function NormalUnitDead(eventArg, ds)
	if eventArg.Virtual then
		return;
	end
	-- 경험치 획득이 막혔으면, 획득하지 않는다. (미션 도중 바뀔 수 있으므로, 매번 새로 체크한다.)
	local mission = GetMission(eventArg.Unit);
	if not mission.EnableKillReward and not mission.EnableKillRewardMastery then
		return;
	end
	
	if eventArg.Unit.HP > 0 and not GetInstantProperty(eventArg.Unit, 'RewardWhenResurrect') then
		return;
	end
	local retActions = {};
	local postActions = {};
	local killer = eventArg.Killer;
	local dead = eventArg.Unit;
	local damageInfo = eventArg.DamageInfo;
	local targetInfo = eventArg.TargetInfo;
	local missionSiteCls = GetMissionSiteClass(mission);
	local safetyFeverNow = false;
	if missionSiteCls then
		safetyFeverNow = GetWorldProperty().ZoneState[missionSiteCls.Zone].SafetyFever;
	end
	local mid = GetMissionID(mission);
	-- 킬러가 없으면 경험치를 획득하지 않는다.
	if not killer then
		return;
	end
	-- 데미지가 없으면 시스템에서 죽인 거니까 무시.
	if not damageInfo then
		return;
	end
	if SafeIndex(damageInfo, 'no_reward') then
		return;
	end	
	-- 죽인애가 소환수면 소환사가 경험치를 먹는다.
	local expTaker = nil;
	if damageInfo.damage_type == 'Buff' then
		local buff = damageInfo.damage_invoker;
		expTaker = GetExpTaker(buff);
	else
		expTaker = GetExpTaker(killer);
	end
	if expTaker == nil then
		return;
	end	
	-- 적팀은 경험치를 획득하지 않는다.
	if GetTeam(expTaker) ~= 'player' then
		return;
	end
	-- 자기 자신에게 데미지를 줘서 죽은 경우, 경험치를 획득하지 않는다. (시스템에서 오브젝트를 죽이기 위해 데미지를 준 경우, 자기 자신이 데미지를 준 것으로 간주된다.)
	if expTaker == dead then 
		return;
	end
	-- 죽인 대상이 적대 팀이 아닌 경우 경험치를 먹지 않는다.
	if GetRelation(expTaker, dead) ~= 'Enemy' then
		AddUnitStats(expTaker, 'OtherKill', 1, true);
		return;
	end

	local isOverKill = false;
	local isPerfectKill = false;
	local company = GetCompanyByTeam(mission, GetTeam(expTaker));
		
	local damage = damageInfo.damage_base;
	local prevHP = (targetInfo and targetInfo.PrevHP or 0);
	local overDamage = damage - prevHP;
	local overKillHP = 99999999999;
	local monType = GetInstantProperty(dead, 'MonsterType');
	if monType then
		overKillHP = dead.MaxHP * GetSystemConstant('OverKillRatio');
	end
	if overDamage > overKillHP then
		isOverKill = true;
	end
	if dead.MaxHP == prevHP then
		isPerfectKill = true;
	end
	
	local onDeadCmd = ds:SubscribeFSMEvent(GetObjKey(dead), 'StateChanged', 'OnStateChangedDead', {}, true);
	ds:SetConditional(onDeadCmd);
	
	 -- 1. 경험치 배분
	local expActions = {};
	local fakeExpActions = {};	-- 실제로 적용되지 않지만 연출만 하는 용
	if mission.EnableKillReward then
		local team = GetTeam(expTaker);
		local expAmount, expAmountJob = Get_Reward_Exp(dead, expTaker);
		local bonusExp_OverKill = 0;
		local bonusExp_OverKillJob = 0;
		local bonusExp_PerfectKill = 0;
		local bonusExp_PerfectKillJob = 0;
	
		local isTakeExp = IsExpTaker(expTaker, 'MonsterType');
		if isOverKill then
			bonusExp_OverKill = math.max(1, expAmount) * GetSystemConstant('OverKillReward_Exp') / 100;
			bonusExp_OverKillJob = math.max(1, expAmountJob) * GetSystemConstant('OverKillReward_Exp') / 100;
			if isTakeExp then
				table.insert(expActions, Result_AddExp(expTaker, bonusExp_OverKill, bonusExp_OverKillJob, 'MonsterOverKill'));
				table.insert(postActions, Result_FireWorldEvent('MonsterOverKill', {Unit=expTaker}, nil, true));
			else
				table.insert(fakeExpActions, Result_AddExp(expTaker, 0, 0, 'MonsterOverKill'));
			end
		end
		if isPerfectKill then
			bonusExp_PerfectKill = math.max(1, expAmount) * GetSystemConstant('PerfectKillReward_Exp') / 100;
			bonusExp_PerfectKillJob = math.max(1, expAmountJob) * GetSystemConstant('PerfectKillReward_Exp') / 100;
			if isTakeExp then
				table.insert(expActions, Result_AddExp(expTaker, bonusExp_PerfectKill, bonusExp_PerfectKillJob, 'MonsterPerfectKill'));		
				table.insert(postActions, Result_FireWorldEvent('MonsterPerfectKill', {Unit=expTaker}, nil, true));
			else
				table.insert(fakeExpActions, Result_AddExp(expTaker, 0, 0, 'MonsterPerfectKill'));				
			end
		end
		if isTakeExp then
			table.insert(expActions, Result_AddExp(expTaker, expAmount, expAmountJob, 'MonsterKill'));
		end
		
		local totalGetExp = bonusExp_OverKill + bonusExp_PerfectKill + expAmount;
		local totalGetExpJob = bonusExp_OverKillJob + bonusExp_PerfectKillJob + expAmountJob;

		-- 파티 경험치, 살아있는 로스터 캐릭터들에게 분배함. 몬스터를 죽인자는 제외.
		local rosters = {};
		local teamCount = GetTeamCount(mid, team);
		for i = 1, teamCount do
			local teamMember = GetTeamUnitByIndex(mid, team, i);
			local isTakeExp = IsExpTaker(teamMember);
			if isTakeExp and expTaker ~= teamMember and not IsInvalidPosition(GetPosition(teamMember)) then
				table.insert(rosters, teamMember);
			end
		end
		if #rosters > 0 then
			local curExp = math.max(1, math.floor(0.33 * totalGetExp));
			local curExpJob = math.max(1, math.floor(0.33 * totalGetExpJob));
			if not isTakeExp and #rosters > 0 then
				curExp = curExp + math.max(1, math.floor(totalGetExp / #rosters));
				curExpJob = curExpJob + math.max(1, math.floor(totalGetExpJob / #rosters));
			end
			for _, teamMember in ipairs(rosters) do
				table.insert(expActions, Result_AddExp(teamMember, curExp, curExpJob, 'PartyMonsterKill'));
			end
		end
		
		-- 1.2 경험치 추가 배분 구문.
		-- 동경
		for _, teamMember in ipairs(rosters) do
			local masteryTable_Yearning = GetMastery(teamMember);
			local mastery_Yearning = GetMasteryMastered(masteryTable_Yearning, 'Yearning');
			if mastery_Yearning then
				if expTaker.Lv > teamMember.Lv then
					local addExp = math.max(1, math.floor(totalGetExp * mastery_Yearning.ApplyAmount/100));
					local addExpJob = math.max(1, math.floor(totalGetExpJob * mastery_Yearning.ApplyAmount/100));
					table.insert(expActions, Result_AddExp(teamMember, addExp, addExpJob, mastery_Yearning.name));
				end
			end
		end
		-- 후견인
		local masteryTable_Supporter = GetMastery(expTaker);
		local mastery_Supporter = GetMasteryMastered(masteryTable_Supporter, 'Supporter');
		if mastery_Supporter then
			for _, teamMember in ipairs(rosters) do
				if expTaker.Lv > teamMember.Lv then
					local addExp = math.max(1, math.floor(totalGetExp * mastery_Supporter.ApplyAmount/100));
					local addExpJob = math.max(1, math.floor(totalGetExpJob * mastery_Supporter.ApplyAmount/100));
					table.insert(expActions, Result_AddExp(teamMember, addExp, addExpJob, mastery_Supporter.name));
				end
			end	
		end
		
		-- 개인 경험치 변경자
		for _, action in ipairs(expActions) do
			-- 야수 조련사
			local master = GetUnit(action.target, GetInstantProperty(action.target, 'SummonMaster'));
			if master then
				local mastery_BeastMaster = GetMasteryMastered(GetMastery(master), 'BeastMaster');
				if mastery_BeastMaster then
					local levelDiff = math.max(master.Lv - action.target.Lv, 0);
					local addRatio = math.floor(levelDiff / mastery_BeastMaster.ApplyAmount) * mastery_BeastMaster.ApplyAmount2;
					action.exp = math.floor(action.exp * (1 + addRatio / 100));
				end
			end
		end
		
		-- 오브젝트 키 순서로 정렬
		table.sort(expActions, function(lhs, rhs) return GetObjKey(lhs.target) < GetObjKey(rhs.target); end);
		
		-- 실제 경험치 액션 (유닛 별로 합산)
		local realExpActionMap = {};
		for _, action in ipairs(expActions) do
			local objKey = GetObjKey(action.target);
			local prevAction = realExpActionMap[objKey];
			if prevAction == nil then
				local newAction = table.deepcopy(action);
				newAction.reason = 'NormalUnitDead';	-- 사실 지금은 실제 액션 처리에서 안 쓰여서 필요가 없긴 한다.
				realExpActionMap[objKey] = newAction;
			else
				prevAction.exp = prevAction.exp + action.exp;
				prevAction.job_exp = prevAction.job_exp + action.job_exp;
			end
		end
		for _, action in pairs(realExpActionMap) do
			table.insert(retActions, action);
		end
	else
		-- 경험치 획득이 안 되면, 오버킬, 퍼펙트킬 연출만 한다.
		if isOverKill then
			table.insert(fakeExpActions, Result_AddExp(expTaker, 0, 0, 'MonsterOverKill'));
		end
		if isPerfectKill then
			table.insert(fakeExpActions, Result_AddExp(expTaker, 0, 0, 'MonsterPerfectKill'));				
		end
	end
	
	-- 경험치 획득 연출
	for _, action in ipairs(expActions) do
		local objKey = GetObjKey(action.target);
		action.target.RestExp = math.max(0, action.target.RestExp - action.exp);
		action.target.RestJobExp = math.max(0, action.target.RestJobExp - action.job_exp);
		local addExpCmd = ds:PlayUIEffect(objKey, '_CENTER_', 'AddExp', 6, 2, PackTableToString({exp = action.exp, reason = action.reason, AliveOnly=true}));
		ds:Connect(addExpCmd, onDeadCmd);
		local chatCmd = ds:AddMissionChat('AddExp', 'AddExp', {ObjectKey = objKey, Exp = action.exp, Reason = action.reason});
		ds:Connect(chatCmd, onDeadCmd);
		local chatCmdJob = ds:AddMissionChat('AddExp', 'AddJobExp', {ObjectKey = objKey, Exp = action.job_exp, Reason = action.reason});
		ds:Connect(chatCmdJob, onDeadCmd);
	end
	for _, action in ipairs(fakeExpActions) do
		local objKey = GetObjKey(action.target);
		local addExpCmd = ds:PlayUIEffect(objKey, '_CENTER_', 'AddExp', 6, 2, PackTableToString({exp = 0, reason = action.reason, AliveOnly=true}));
		ds:Connect(addExpCmd, onDeadCmd);
	end
	
	 -- 2. 아이템 배분
	if mission.EnableKillReward then
		-- 특성 보상만 주는 경우엔 아이템을 안 준다.
		local giveItemConverter = BuildGiveItemConverter(killer);
		local rewardItems = GetRewardItem(company, dead, expTaker, isOverKill, isPerfectKill, safetyFeverNow);
		for _, reward in pairs(rewardItems) do
			table.append(retActions, { giveItemConverter(Result_GiveItem(expTaker, reward.Item, reward.Count, reward.ItemProps)) });			
			if company and GetClassList('Item')[reward.Item].Category.name == 'Material' then
				AddCompanyStats(company, 'RewardItemMaterial', 1);
			end
		end
	end
	
	-- 3. 특성 배분
	if not mission.Tutorial then
		local acquiredMastery, acquiredMasteryCount, isTutorial, unlockTechnique = AcquireRewardMastery(dead, expTaker, isOverKill, isPerfectKill, safetyFeverNow);
		if acquiredMastery and acquiredMasteryCount > 0 then
			local masteryEffectID = ds:ShowAcquireMasteryDirecting(GetTeam(expTaker), acquiredMastery.name, acquiredMasteryCount, 'MasteryAcquiredGuideNormal', GetObjKey(expTaker));
			ds:Connect(masteryEffectID, onDeadCmd, 0);
			if isTutorial then
				table.insert(retActions, Result_FireWorldEvent('TutorialMasteryAcquired', {}));
			end
		end
		if unlockTechnique then
			ds:AddMissionChat('UnlockTechnique', 'UnlockTechnique', {ObjectKey = objKey, TechniqueType = acquiredMastery.name});
		end
	end
		
	-- 4. 전투 통계 갱신
	if not dead.Obstacle then
		AddUnitStats(expTaker, 'EnemyKill', 1, true);
		local company = GetCompanyByTeam(mission, GetTeam(expTaker));
		local baseMonType = FindBaseMonsterTypeWithCache(dead);
		if baseMonType ~= nil then
			local baseMonCls = GetClassList('Monster')[baseMonType];
			if company and dead.Race.name == 'Beast' and baseMonType and (baseMonCls.Grade == 'Legend' or baseMonCls.Grade == 'Epic') then
				AddCompanyStats(company, 'LegendaryBeastKill', 1);
			end
			if company and dead.Race.name == 'Machine' and baseMonType then
				AddCompanyStats(company, 'LegendaryMachineKill', 1);
			end
		end
		if company and dead.MaxHP >= killer.MaxHP * 2 then
			AddCompanyStats(company, 'GiantKill', 1);
		end
	else
		AddUnitStats(expTaker, 'Destruction', 1, true);
	end
	-- 5. 도감 경험치 증가.
	AddExp_TroubleMaker(GetMissionDatabaseCommiter(mission), dead, expTaker, damageInfo.AttackerState, isOverKill, isPerfectKill, ds, true);

	-- 6. 업적용 통계 갱신
	if dead.Grade.name == 'Epic' then
		ds:AddSteamStat('KillEpicCount', 1, GetTeam(expTaker));
	end
	if dead.Grade.name == 'Legend' then
		ds:AddSteamStat('KillLegendCount', 1, GetTeam(expTaker));
	end
	
	table.append(retActions, postActions);
	
	return unpack(retActions);
end

function NormalAbilityUsed(eventArg, ds)
	-- 경험치 획득이 막혔으면, 획득하지 않는다. (미션 도중 바뀔 수 있으므로, 매번 새로 체크한다.)
	local mission = GetMission(eventArg.Unit);
	if not mission.EnableKillReward then
		return;
	end
	
	if SafeIndex(eventArg, 'ResultModifier', 'NoReward') then
		return;
	end
	-- 경험치 획득자가 본인이 아니면 무시한다.
	local expTaker = GetExpTaker(eventArg.Unit);
	if expTaker ~= eventArg.Unit then
		return;
	end	
	-- 적팀은 경험치를 획득하지 않는다.
	if GetTeam(expTaker) ~= 'player' then
		return;
	end
	
	local isTakeExp = not GetInstantProperty(expTaker, 'MonsterType');
	if not isTakeExp then
		return;
	end
	
	local reward = Get_Reward_JobExp(expTaker, eventArg.Ability);
	if reward == 0 then
		return;
	end
	
	local objKey = GetObjKey(expTaker);
	ds:AddMissionChat('AddExp', 'AddJobExp', {ObjectKey = objKey, Exp = reward, Reason = 'AbilityUse', Ability = eventArg.Ability.name});
	
	expTaker.RestJobExp = math.max(0, expTaker.RestJobExp - reward);
	return Result_AddExp(expTaker, 0, reward, 'AbilityUsed');
end

function GetCivilRescueReward(ageType)
	local rewardCls = GetClassList('CivilRescueReward')[ageType];
	if not rewardCls or not rewardCls.name or rewardCls.name == 'None' then
		return;
	end
	
	local mailProb = rewardCls.MailProb;
	
	-- 이름을 선택
	local nameList = {};
	for name, _ in pairs(rewardCls.NameSet) do
		table.insert(nameList, name);
	end
	local civilName = nameList[math.random(1, #nameList)];
	
	-- 보상, 메일 내용을 선택
	local itemType = nil;
	local itemCount = nil;
	local mailKey = nil
	
	local itemList = GetClassList('Item');
	local picker = RandomPicker.new();
	for _, reward in ipairs(rewardCls.Rewards) do
		if reward.Item == 'Vill' then
			picker:addChoice(reward.Prob, reward);
		else
			local itemCls = itemList[reward.Item];
			if SafeIndex(itemCls, 'name') then
				picker:addChoice(reward.Prob, reward);
			end
		end
	end
	
	local selReward = picker:pick();
	if selReward then
		itemType = selReward.Item;
		itemCount = math.floor(math.random(selReward.Min, selReward.Max));
		mailKey = selReward.MailContent[math.random(1, #selReward.MailContent)].Mail;
	end
	
	return civilName, mailKey, mailProb, itemType, itemCount;
end
function GlobalCitizenRescued_CheckReward(unit)
	local mission = GetMission(unit);
	if not mission.EnableCivilRescueReward then
		return;
	end
	
	-- AgeType에 따라 확률, 이름, 메일 내용, 보상이 달라짐
	local civilAgeType = unit.Info.AgeType;
	local civilName, mailKey, mailProb, itemType, itemCount = GetCivilRescueReward(civilAgeType);
	if not civilName then
		return;
	end
	
	-- 미션 내 유저들마다 확률 테스트를 하고, 통과하면 메일 전송
	local companies = GetAllCompanyInMission(mission);
	for _, company in ipairs(companies) do
		if RandomTest(mailProb) then
			local mailList = GetCompanyInstantProperty(company, 'MailList') or {};
			local countRatio = 1;
			if itemType == 'Vill' then
				local rescueBonus = company.MissionStatus.RescueRewardBonus;
				-- 남부 지구 보너스
				local southAreaBonus = GetDivisionTypeBonusValue(company.Reputation, 'Area_South');
				if southAreaBonus > 0 then
					-- 관할구역 개수랑 상관없이 고정 100% 증가
					rescueBonus = rescueBonus + 100;
				end
				countRatio = countRatio + rescueBonus / 100;
			end
			table.insert(mailList, { MailKey = mailKey, ItemType = itemType, ItemCount = itemCount * countRatio, MailProperty = {CivilName = civilName, CivilAgeType = civilAgeType }});
			
			SetCompanyInstantProperty(company, 'MailList', mailList);
		end
	end
end
function GlobalCitizenRescued(eventArg, ds)
	local unit = eventArg.Unit;
	local mission = GetMission(unit);
	
	if mission.EnableCivilRescueReward then
		GlobalCitizenRescued_CheckReward(unit);
	end
	
	if eventArg.Company then
		ds:AddSteamStat('CivilRescueCount', 1, GetUserTeam(eventArg.Company));
	end
end
function GlobalCitizenRescueFailed(eventArg, ds)
	ds:UpdateSteamAchievement('SituationCivilDead', true);
end 

function RegisterGlobalEventHandler(mid)
	local mission = GetMission(mid);
	SubscribeGlobalWorldEvent(mid, 'UnitDead', 'PrimaryUnitDead', 0);
	SubscribeGlobalWorldEvent(mid, 'UnitDead', 'NormalUnitDead');
	SubscribeGlobalWorldEvent(mid, 'AbilityUsed', 'NormalAbilityUsed');
	SubscribeGlobalWorldEvent(mid, 'CitizenRescued', 'GlobalCitizenRescued');
	SubscribeGlobalWorldEvent(mid, 'CitizenRescueFailed', 'GlobalCitizenRescueFailed');
	SubscribeGlobalWorldEvent(mid, 'InvestigationPsionicOccured', 'GlobalInvestigationPsionicOccured');
	if mission.EnableAutoEndMission then
		SubscribeGlobalWorldEvent(mid, 'DashboardUpdated', function(eventArg, ds)
			if eventArg.Key ~= DASHBOARD_MAIN_PANEL_KEY then
				return;
			end
			
			local dashboard = GetMissionDashboard(GetMission(mid), eventArg.Key);
			if dashboard.MainObjective.State == 'Completed' then
				return Result_EndMission('player');
			elseif dashboard.MainObjective.State == 'Failed' then
				return Result_EndMission('enemy');
			end
		end);
	end
	
	-- 처음 등장한 적 발견 연출
	local exhausted = false;
	local findEnemyHandler = function(eventArg, ds)
		if exhausted then
			return;
		end
		local unit = eventArg.Unit;
		local patrolObjMove = unit.PreBattleState;
		if patrolObjMove then	-- 이건 순찰을 가진 애가 움직인 경우
			local movePos = eventArg.Position;
			local enemiesWhoSeeThisObj = table.filter(GetNearObject(unit, 15--[[충분한 시야거리]]), function (obj)
				return GetRelation(obj, unit) == 'Enemy'
					and IsInSight(obj, movePos);
			end);
			if #enemiesWhoSeeThisObj > 0 then
				-- 들킴
				unit.Revealed = true;
			end
		elseif GetCompany(unit) ~= nil then
			local visibleEnemiesWhoHavePatrol = table.filter(GetAllUnitInSight(unit, true), function (obj)
				return GetRelation(unit, obj) == 'Enemy'
					and obj.PreBattleState
					and not obj.Revealed;
			end);
			if #visibleEnemiesWhoHavePatrol == 0 then
				return;
			end
			for i, obj in ipairs(visibleEnemiesWhoHavePatrol) do
				obj.Revealed = true;
			end
			local mission = GetMission(mid);
			if not mission.Tutorial and not eventArg.MovingForAbility then
				ds:PlayVoiceAndText(unit, 'Detect', false, 0, -1, 0, true);
				if not eventArg.FindGuideTriggered then
					ds:ChangeCameraTarget(GetObjKey(visibleEnemiesWhoHavePatrol[1]), '_SYSTEM_', false, false, 1);
					ds:Sleep(1);
					ds:ChangeCameraTarget(GetObjKey(unit), '_SYSTEM_', false, true, 0.75);
				end
			end
			exhausted = true;
		end
	end
	SubscribeGlobalWorldEvent(mid, 'UnitMoved', findEnemyHandler, 9);
	
	-- 전투 진행 도우미 효과
	local battleSignalHandler = function(eventArg, ds)
		local company = GetCompany(eventArg.Unit);
		if company == nil then
			return;
		end
		-- 튜토리얼에서 안 나옴
		local mission = GetMission(eventArg.Unit);
		if mission.name == 'Tutorial_CrowBill' then
			return;
		end
	
		local allUnit = GetAllUnitInSight(eventArg.Unit, false);
		local enemies = table.filter(allUnit, function(u)
			return GetRelation(eventArg.Unit, u) == 'Enemy';
		end);
		--LogAndPrint('#enemies', #enemies);
		if #enemies > 0 then
			SetCompanyInstantProperty(company, 'PeaceTime', 0);
			SetCompanyInstantProperty(company, 'PeaceCount', 0);
			SetCompanyInstantProperty(company, 'DisablePeaceCount', false);
			return;
		end
		
		local needDirect = false;
		if eventArg.EventType == 'UnitTurnStart' then
			local peaceTime = GetCompanyInstantProperty(company, 'PeaceTime') or 0;
			-- LogAndPrint('PeaceTime', peaceTime);
			if peaceTime > 150 then
				needDirect = true;
			end
		elseif eventArg.EventType == 'UnitTurnEnd' and eventArg.SystemCall then
			local peaceCount = GetCompanyInstantProperty(company, 'PeaceCount') or 0;
			local disabled = GetCompanyInstantProperty(company, 'DisablePeaceCount') or false;
			peaceCount = peaceCount + 1;
			SetCompanyInstantProperty(company, 'PeaceCount', peaceCount);
			-- LogAndPrint('PeaceCount', peaceCount);
			-- LogAndPrint('DisablePeaceCount', disabled);
			if peaceCount >= 2 and not disabled then
				needDirect = true;
				SetCompanyInstantProperty(company, 'DisablePeaceCount', true);
			end
		end
		if not needDirect then
			return;
		end
		
		SetCompanyInstantProperty(company, 'PeaceTime', 0);
		SetCompanyInstantProperty(company, 'PeaceCount', 0);
		
		local guideMessage = '';
		if not company.Progress.Tutorial.BattleGuideSignal then
			guideMessage = 'BattleGuideSignal';
		elseif not company.Progress.Tutorial.BattleMinimap then
			guideMessage = 'BattleMinimap';
		end
		ds:PlayBattleGuideSignal(GetObjKey(eventArg.Unit), guideMessage);
		if guideMessage ~= '' then
			local mission = GetMission(mid);
			local dc = GetMissionDatabaseCommiter(mission);
			if guideMessage == 'BattleGuideSignal' then
				dc:UpdateCompanyProperty(company, 'Progress/Tutorial/BattleGuideSignal', true);
				company.Progress.Tutorial.BattleGuideSignal = true;
			else
				dc:UpdateCompanyProperty(company, 'Progress/Tutorial/BattleMinimap', true);
				company.Progress.Tutorial.BattleMinimap = true;
			end
		end	
	end;
	
	SubscribeGlobalWorldEvent(mid, 'UnitTurnStart', battleSignalHandler);
	SubscribeGlobalWorldEvent(mid, 'UnitTurnEnd', battleSignalHandler);
	
	-- 전투 진행 도우미 효과 2
	SubscribeGlobalWorldEvent(mid, 'TimeElapsed', function(eventArg, ds)
		for i, company in ipairs(GetAllCompanyInMission(mid)) do
			local peaceTime = GetCompanyInstantProperty(company, 'PeaceTime') or 0;
			SetCompanyInstantProperty(company, 'PeaceTime', peaceTime + eventArg.ElapsedTime);
		end
	end);
	
	SubscribeGlobalWorldEvent(mid, 'TutorialMasteryAcquired', function(eventArg, ds)
		local ownerKey = GetObjKey(eventArg.Unit);
		local ownerCamMoveID = ds:ChangeCameraTarget(ownerKey, '_SYSTEM_', false, false, 1);
		local messageID = ds:Dialog("DialogSystemMessageBox",{ Title = WordText('AcquireMastery'), Message = GuideMessageText('AcquireMastery'), Image = ''});	
		ds:Connect(messageID, ownerCamMoveID, -1);
	end);

	if #(GetAllCompanyInMission(mid)) == 1 then
		-- 1인 미션 한정
		local singleCompany = GetAllCompanyInMission(mid)[1];		
		SubscribeGlobalWorldEvent(mid, 'MissionEnd', function(eventArg, ds)
			local userTeam = GetUserTeam(singleCompany);
			if userTeam ~= eventArg.Winner then
				return;
			end
			
			local teamCount = GetTeamCount(mid, userTeam);
			if not (function()
				for i = 1, teamCount do
					local member = GetTeamUnitByIndex(mid, userTeam, i);
					if member.Race.name == 'Beast' then
						local masterKey = GetInstantProperty(member, 'SummonMaster');
						if masterKey and GetUnit(mid, masterKey) then
							return true;
						end
					end
				end
				return false;
			end)() then
				return;
			end
			
			AddCompanyStats(singleCompany, 'MissionClearWithBeast', 1);
			ds:AddSteamStat('MissionClearWithBeastCount', 1);
		end);
	end
	
	-- 시민구출 미션 한정 종료시 나머지 시민 구하기
	if mission.AutoCivilRescueAll then
		SubscribeGlobalWorldEvent(mid, 'MissionEnd', function(eventArg, ds)
			local citizenCount = GetTeamCount(mid, 'citizen');
			local allCompanies = GetAllCompanyInMission(mid);
			-- 플레이어 팀이 이긴 게 아니면 무시
			local isPlayerWin = false;
			for i, company in ipairs(allCompanies) do
				if eventArg.Winner == GetUserTeam(company) then
					isPlayerWin = true;
					break;
				end
			end
			if not isPlayerWin then
				return;
			end
			local actions = {};
			local dashboardList = GetMissionDashboardByType(mission, 'Rescue');
			for _, info in ipairs(dashboardList) do
				local dashboard = info.Dashboard;
				if dashboard.Left > 0 then 
					table.append(actions, UpdateDashboardCore(mission, info.Key, 'RescueAll'));
				end
			end
			-- 나머지 시민 수는 모든 플레이어에 적용
			for i, company in ipairs(allCompanies) do
				AddCompanyStats(company, 'Rescue', citizenCount);
				ds:AddSteamStat('CivilRescueCount', citizenCount, GetUserTeam(company));
			end
			return unpack(actions);
		end);
	end
	
	-- 미션 AI 보정
	if mission.AICorrection.AttackPassEnabled then
		SubscribeGlobalWorldEvent(mid, 'UnitTurnEnd', function(eventArg, ds)
			if GetTeam(eventArg.Unit) == 'player' or GetInstantProperty(eventArg.Unit, 'AttackPassTriggered') then
				mission.Instance.AIState.RecitalPlayCount = 1;
				SetInstantProperty(eventArg.Unit, 'AttackPassTriggered', nil);
			end
		end);
	end
	
	-- 행운의 숫자 7, 8, 9 획득
	local luckyNumberDataSet = {
		[7] = {Message = 'LuckyNumberSevenAchieved', Mastery = 'LuckyNumberSeven'},
		[8] = {Message = 'LuckyNumberEightAchieved', Mastery = 'LuckyNumberEight'},
		[9] = {Message = 'LuckyNumberNineAchieved', Mastery = 'LuckyNumberNine'}
	};
	SubscribeGlobalWorldEvent(mid, 'BuffAdded', function(eventArg, ds)
		if eventArg.BuffName ~= 'Luck' then
			return;
		end
		local company = GetCompany(eventArg.Unit);
		if company == nil then
			return;
		end
		if company.Stats.LuckAdded >= 9 then
			-- 이미 다 받음
			return;
		end
		local unit = eventArg.Unit;
		
		AddCompanyStats(company, 'LuckAdded', 1);
		
		local nextCount = company.Stats.LuckAdded + GetCompanyStats(company).LuckAdded;
		local achiveData = luckyNumberDataSet[nextCount];
		if achiveData == nil then
			return;
		end
		local frontMsg = ds:ShowFrontmessageWithText(GuideMessageText(achiveData.Message), 'Corn');
		local acquiredMastery = achiveData.Mastery;
		ds:Connect(ds:ShowAcquireMasteryDirecting(GetTeam(unit), acquiredMastery, 1, 'MasteryAcquiredGuideNormal', GetObjKey(unit)), frontMsg, 3);
		local dc = GetMissionDatabaseCommiter(GetMission(unit));
		dc:AcquireMastery(company, acquiredMastery, 1);
	end);
	
	-- 미니맵 적 위치 획득	
	local assistMap = GetWithoutError(mission, 'AssistMap');
	if assistMap and #(GetAllCompanyInMission(mid)) == 1 then
		SubscribeGlobalWorldEvent(mid, 'UnitTurnStart', function(eventArg, ds)
			local company = GetAllCompanyInMission(mid)[1];
			if not company then
				return;
			end
			local enableAssistMap = GetCompanyInstantProperty(company, 'EnableAssistMap');
			if enableAssistMap then
				return;
			end
			local team = GetCompanyTeam(company);
			if GetTeam(eventArg.Unit) ~= team then
				return;
			end
			local enabled = StringToBool(assistMap.Enabled, false);
			if not enabled then
				return;
			end
			local units = GetAllUnit(mission);
			-- 전파 방해기 (같은 팀 제외)
			local jammers = table.filter(units, function(obj)
				return obj.name == 'Object_JammingMachine' and GetTeam(obj) ~= team;
			end);
			if #jammers > 0 then
				return;
			end
			-- 진행 시간
			local elapsedTime = GetMissionElapsedTime(mission) - (GetCompanyInstantProperty(company, 'AssistMapBeginTime') or 0);
			-- 적 필터링
			local enemyTeamSet = {};
			local enemyTeams = GetAllEnemyWithTeam(mission, team);
			for _, enemyTeam in ipairs(enemyTeams) do
				enemyTeamSet[enemyTeam] = true;
			end
			local enemies = table.filter(units, function(obj)
				return enemyTeamSet[GetTeam(obj)];
			end);
			-- 시간 만족 or 적 수 만족 체크
			if elapsedTime < assistMap.PlayTime and #enemies > assistMap.EnemyCount then
				return;
			end
			-- 적 위치 획득
			SetCompanyInstantProperty(company, 'EnableAssistMap', true);
			local actions = {};
			ds:RunScript('EnableAssistMap', { Team = team, Enabled = true });
			RegisterConnectionRestoreRoutine(mid, routinekey, function(ds)
				ds:RunScript('EnableAssistMap', { Team = team, Enabled = true });
			end);
			-- 적이 하나도 없으면 연출 생략
			if #enemies > 0 then
				table.insert(actions, Result_DirectingScript('Direct_EnableAssistMap', { Unit = eventArg.Unit }));
			end
			return unpack(actions);
		end);
		
		SubscribeGlobalWorldEvent(mid, 'UnitDead', function(eventArg, ds)
			if eventArg.Unit.name ~= 'Object_JammingMachine' then
				return;
			end
			local company = GetAllCompanyInMission(mid)[1];
			if not company then
				return;
			end			
			if GetCompanyInstantProperty(company, 'DirectRestoreConnection') then
				return;
			end
			local enabled = StringToBool(assistMap.Enabled, false);
			if not enabled then
				return;
			end
			local actions = {};
			local units = GetAllUnit(mission);
			-- 전파 방해기 (같은 팀 제외)
			local jammers = table.filter(units, function(obj)
				return obj.name == 'Object_JammingMachine' and GetTeam(obj) ~= team;
			end);
			if #jammers > 0 then
				return;
			end
			SetCompanyInstantProperty(company, 'DirectRestoreConnection', true)
			return Result_DirectingScript('Direct_AssistMapRestoreConnection', { Unit = eventArg.Unit });
		end);
	end
end
function Direct_AssistMapRestoreConnection(mid, ds, args)
	local unit = args.Unit;
	local unitKey = GetObjKey(unit);
	-- 상호작용 연출
	local imID = ds:UpdateInteractionMessage(unitKey, 'RestoreConnection');
	local ownerCamMove = ds:ChangeCameraTarget(unitKey, '_SYSTEM_', false, true, 1);
	local playSoundID = ds:PlaySound('Shown_Image.wav', 'Layout', 1);
	ds:Connect(imID, ownerCamMove, -1);
	ds:Connect(playSoundID, imID, 0.25);
end
function Direct_EnableAssistMap(mid, ds, args)
	local unit = args.Unit;
	local unitKey = GetObjKey(unit);
	-- 다이얼로그 연출
	local enableID = ds:EnableIf('TestEnableDetailInteraction');
	local dialogID = ds:Dialog('BattleDialog', { SpeakerInfo = 'VHPD_Assault', SpeakerEmotion = 'Normal', Mode = 'Start', Text = GuideMessageText('AssistMapEnabledDialog'), Type = 'Sub', Slot = 'Center', Effect = 'Appear' });
	local closeID = ds:CloseDialog('BattleDialog');
	ds:Connect(dialogID, enableID, 0);
	ds:Connect(closeID, dialogID, -1);
	-- 상호작용 연출
	local imID = ds:UpdateInteractionMessage(unitKey, 'AssistMap');
	local ownerCamMove = ds:ChangeCameraTarget(unitKey, '_SYSTEM_', false, true, 1);
	local playSoundID = ds:PlaySound('Shown_Image.wav', 'Layout', 1);
	ds:Connect(imID, ownerCamMove, -1);
	ds:Connect(playSoundID, imID, 0.25);
	-- 미니맵 오픈
	local enableID2 = ds:EnableIf('TestEnableDetailInteraction');
	local minimapID = ds:Dialog('Minimap', {});
	ds:Connect(minimapID, enableID2, 0.25);
end
function Direct_AutoPlayReturn(mid, ds, args)
	local unit = args.Unit;
	
	local unitKey = GetObjKey(unit);
	ds:HideBattleStatus(unitKey);
	
	local playSoundID = ds:PlaySound('BattleSystemMessageBox.wav', 'Layout', 1);

	local messageID = ds:ShowFrontmessageWithText(FormatMessageText(GuideMessageText('UnitReturnFromBattleField'), {Unit = ClassDataText('ObjectInfo', unit.Info.name, 'Title')}));
	ds:Connect(playSoundID, messageID, 0);
end

function ProcessAutoPlay_Return(target, ds)
	local setPos = Result_SetPosition(target, InvalidPosition());
	setPos.sequential = true;
	return Result_DirectingScript('Direct_AutoPlayReturn', {Unit = target}), Result_UpdateUserMember(target, GetTeam(target), 'Off'), setPos, Result_FireWorldEvent('UnitBeingExcluded', {Unit = target, AllowInvalidPosition = true, AutoPlay = true}), Result_DestroyObject(target, false, true);
end