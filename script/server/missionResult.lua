function OnEndMission(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute)
	-- 미션 정보
	local mid = GetMissionID(company);
	local lastTarget = GetLastAbilityUser(mid);
	-- 미출전 유닛 필터링
	lineup = table.filter(lineup, function(pc)
		if pc.RosterType == 'Pc' then
			return true;
		elseif pc.RosterType == 'Beast' then
			return not pc.Stored and GetInstantProperty(pc.Object, 'SummonBefore');
		elseif pc.RosterType == 'Machine' then
			return GetInstantProperty(pc.Object, 'SummonBefore');
		else
			return false;
		end
	end);
	local lineupPc = table.filter(lineup, function(pc) return pc.RosterType == 'Pc' end);
	local lineupObjKeyMap = {};
	for _, pc in ipairs (lineup) do
		local target = pc.Object;
		lineupObjKeyMap[GetObjKey(target)] = pc;
	end
	
	-- 마지막 미션 저장
	dc:UpdateCompanyProperty(company, 'LastMission', mission.name);

	-- 1. 미션 종료 값 초기화.
	local list = {};
	list.Company = {};
	list.Result = {};
	list.Roster = {};
	list.Item = {};
	
	-- 2. 마지막 타겟 여부
	local lastTargetKey = nil;
	if lastTarget ~= nil then
		lastTargetKey = GetObjKey(lastTarget);
	end
	
	-- 3. 아이템 정보 정리.
	local itemClsList = GetClassList('Item');
	local itemStack = {};
	local itemStackLost = {};
	
	local lostShopIndex = 1;
	local itemOptionCls = GetClassList('ItemOption').Normal;
	local optionSetBase = ClassToTable(itemOptionCls);
	optionSetBase.name = nil;
	local addLostShopItem = nil;
	local weaponShopOpened = company.Progress.Character.Pierto > 0;
	if weaponShopOpened then
		addLostShopItem = function(itemInfo)		-- 유실물 상점 갱신
			if lostShopIndex > #company.LostShop.ItemList then
				LogAndPrint('유실물 상점 슬롯이 가득찼습니다..', company.CompanyName, itemInfo);
				return;
			end
			local shopKeyHead = 'LostShop/ItemList/'..lostShopIndex..'/';
			lostShopIndex = lostShopIndex + 1;
			dc:UpdateCompanyProperty(company, shopKeyHead .. 'Item', itemInfo.Type);
			dc:UpdateCompanyProperty(company, shopKeyHead .. 'Stock', itemInfo.Count);
			local option = Linq.new(itemInfo.Props or {})
				:where(function(kv) return string.find(kv[1], '^Option/') ~= nil end)
				:select(function(kv) return {string.gsub(kv[1], '^Option/', ''), kv[2]}; end)
				:toMap();
			if #option > 0 then
				local optionSet = table.deepcopy(optionSetBase);		-- 사용되지 않은 옵션 컬럼
				for optionKey, optionValue in pairs(option) do
					dc:UpdateCompanyProperty(company, shopKeyHead ..'Option/'..optionKey, optionValue);
					optionSet[optionKey] = nil;
				end
				for untouchedKey, baseValue in pairs(optionSet) do
					local optionKey = shopKeyHead .. 'Option/' ..untouchedKey;
					if SafeIndex(company, unpack(string.split(optionKey, '/'))) ~= baseValue then
						-- 다른 경우만 갱신
						dc:UpdateCompanyProperty(company, optionKey, baseValue);
					end
				end
			else
				dc:UpdateCompanyProperty(company, shopKeyHead .. 'Option/OptionKey', 'None');
				option = nil;
			end
			local sellPrice = ItemCalculateSellPrice(GetClassList('Item')[itemInfo.Type], option);
			dc:UpdateCompanyProperty(company, shopKeyHead .. 'Price', sellPrice * 3);
		end
	else
		addLostShopItem = function() end;
	end
	
	local addStackFunc = function(stackList, itemInfo)
		if stackList[itemInfo.Type] == nil then
			stackList[itemInfo.Type] = itemInfo.Count;
		else
			stackList[itemInfo.Type] = stackList[itemInfo.Type] + itemInfo.Count;
		end
	end;
	-- 3-1) 이미 획득 처리가 된 아이템들
	for index, value in ipairs(itemGetResults) do
		local itemCls = itemClsList[value.Type];
		if itemCls.Stackable then
			addStackFunc(itemStack, value);
		else	
			table.insert(list.Item, { Type = value.Type, Count = value.Count, Props = value.Props });
		end
	end
	-- 3-2) 획득, 유실 처리가 필요한 아이템들 (Stackable은 따로 분류해서 개수를 합침)
	local disableLostItem = false;
	-- 관할 구역 보너스 - 유실물 정보
	if IsEnableAllowDivisionBonus(company, 'LostProperty') then
		disableLostItem = true;
	end	
	-- 유실물 수거 가방
	local amuletCollectorSetCount = 0;
	for _, pc in ipairs(lineup) do
		local obj = pc.Object;
		if not IsDead(obj) and IsValidPosition(mission, GetPosition(obj)) then
			local mastery_Amulet_Collector_Set = GetMasteryMastered(GetMastery(obj), 'Amulet_Collector_Set');
			if mastery_Amulet_Collector_Set then
				disableLostItem = true;
				amuletCollectorSetCount = amuletCollectorSetCount + 1;
			end
		end	
	end
	local hasLostCandidateItem = false;
	local elapsedTimeReal = GetMissionElapsedTimeReal(mission);
	local rewardItems = GetCompanyInstantProperty(company, 'RewardItems') or {};
	for _, reward in ipairs(rewardItems) do
		local itemCls = itemClsList[reward.Type];
		local lostProb = GetRewardLostProbability(itemCls, elapsedTimeReal);
		local luckyNumber = reward.LuckyNumber or math.random() * 100;	-- 없는경우 이전 버전에서 얻은 아이템이므로 기존과 같이 매번 새로 계산한다.
		if not win and lostProb > luckyNumber then
			hasLostCandidateItem = true;
			if not disableLostItem then
				reward.Lost = true;
			end
		end
		if not reward.Lost then
			dc:GiveItem(company, reward.Type, reward.Count, true, '', reward.Props);
		end
		if itemCls.Stackable then
			if reward.Lost then
				addStackFunc(itemStackLost, reward);
			else
				addStackFunc(itemStack, reward);
			end
		else
			table.insert(list.Item, reward);
			if reward.Lost then
				addLostShopItem(reward);
			end
		end
	end
	-- 유실물 수거 가방
	if win and amuletCollectorSetCount > 0 and not hasLostCandidateItem then
		local mastery = GetClassList('Mastery')['Amulet_Collector_Set'];
		local baseCount = mastery.ApplyAmount;
		local pickItems = PickAmuletCollectorSetEquipment(company, mission.name, lineup, baseCount, rewardItems, 'Rare');
		if amuletCollectorSetCount > baseCount then
			local addPickItems = PickAmuletCollectorSetEquipment(company, mission.name, lineup, amuletCollectorSetCount - baseCount, rewardItems, 'Uncommon');
			table.append(pickItems, addPickItems);
		end
		for _, rewardItem in ipairs(pickItems) do
			dc:GiveItem(company, rewardItem, 1, true, '');
			table.insert(list.Item, { Type = rewardItem, Count = 1, Reason = mastery.name });
		end
	end
	-- 3-3) Stackable 아이템들을 추가
	for type, count in pairs(itemStack) do
		table.insert(list.Item, { Type = type, Count = count });
	end
	for type, count in pairs(itemStackLost) do
		local lostItemInfo = { Type = type, Count = count, Lost = true };
		table.insert(list.Item, lostItemInfo);
		addLostShopItem(lostItemInfo);
	end
	if weaponShopOpened then
		dc:UpdateCompanyProperty(company, 'LostShop/ActiveSlot', lostShopIndex - 1);
		if lostShopIndex > 1 then
			dc:UpdateCompanyProperty(company, 'LostShop/IsNew', true);
		end
	end
	
	-- 4. 미션 랭크 찾기.
	local clearRank, battleDuration, aliveCount, killEnemyCount, rescueCount = GetMissionResult(mission, company, lineupPc, win, isSurrender);
	list.Result.BattleDuration = battleDuration;
	list.Result.AliveCount = aliveCount;
	list.Result.KillEnemyCount = killEnemyCount;
	list.Result.RescueCount = rescueCount;
	
	-- 5. 회사 정보 업데이트
	-- 1) 중도 종료는 무조건 Escape
	local rewardExp = 0;
	
	if not isSurrender then
		rewardExp = UpdateComapnyPropertyByMissionResult(mission, dc, company, clearRank);
	end	
	list.Company.RewardExp = rewardExp;
	
	if win and mission.EnableMissionCount then
		dc:AddCompanyProperty(company, 'OfficeRentCounter', 1);
	end
	-- 2) 아이템 획득 Luck 추가.
	dc:UpdateCompanyProperty(company, 'Luck_Spoils', company.Luck_Spoils);
		
	-- 6. PC 정보 업데이트 
	local durationPenaltyCP = math.min(math.floor(battleDuration / 90) * 3, 100);
	-- 체크포인트 리로드 의욕 처리
	LogAndPrint('OnEndMission', mission.Instance.CheckPointReloadCount);
	durationPenaltyCP = durationPenaltyCP + mission.Instance.CheckPointReloadCount * 50;
	-- 라인업 (인간, 야수, 기계)
	for index, pc in ipairs (lineup) do
		---- P1. 미션 결과에 따라 TP 일괄 적용 ----
		local target = pc.Object;
		local pcLv = target.Lv;
		-- 버그로 인한 임시방편처리.
		if pcLv == 0 then
			pcLv = 1;
		end

		local baseExp = pc.Exp;
		local levelUp = target.Lv - pc.Lv;
		local remainExp = target.Exp;
		
		-- 직업 경험치 처리
		local jobLvEnd = target.JobLv;
		local jobExpEnd = target.JobExp;
		local jobLvStart = pc.JobLv;
		local jobExpStart = pc.JobExp;
		if pc.RosterType == 'Pc' then
			dc:UpdatePCProperty(pc, string.format('EnableJobs/%s/Lv', target.Job.name), jobLvEnd);
			dc:UpdatePCProperty(pc, string.format('EnableJobs/%s/Exp', target.Job.name), jobExpEnd);
		elseif pc.RosterType == 'Beast' or pc.RosterType == 'Machine' then
			if pc.JobLv ~= jobLvEnd then
				dc:UpdatePCProperty(pc, 'JobLv', jobLvEnd);
			end
			if pc.JobExp ~= jobExpEnd then
				dc:UpdatePCProperty(pc, 'JobExp', jobExpEnd);
			end
		end
		
		local rewardMasteries = {};
		if pc.RosterType == 'Pc' then
			rewardMasteries = GetRewardMasteriesByJobLevel(company, pc, target.Job.name, jobLvStart + 1, jobLvEnd);
		elseif pc.RosterType == 'Beast' then
			rewardMasteries = GetRewardMasteriesByJobLevel_Beast(company, pc, jobLvStart + 1, jobLvEnd);
		elseif pc.RosterType == 'Machine' then
			rewardMasteries = GetRewardMasteriesByJobLevel_Machine(company, pc, jobLvStart + 1, jobLvEnd);
		end
		for _, mastery in ipairs(rewardMasteries) do
			local techName = mastery.name;
			dc:UpdateCompanyProperty(company, string.format('Technique/%s/Opened', techName), true);
			dc:UpdateCompanyProperty(company, string.format('Technique/%s/IsNew', techName), true);
		end
		
		local result = { 
			Exp = {
				Base = baseExp,
				LevelUP = levelUp,
				Level = pcLv,
				Result = remainExp
			},
			JobExp = {
				Base = jobExpStart,
				Result = jobExpEnd,
				LevelUP = jobLvEnd - jobLvStart,
				Level = jobLvEnd
			},
			CP = {
				Base = 0,
				Result = 0,
				MaxCP = 1
			},
			Stats = table.shallowcopy(GetUnitStats(target)),
		};
		list.Roster[GetObjKey(target)] = result;

		if pc.RosterType == 'Pc' then
			local baseCP = GetInstantProperty(target, 'CPAtMissionStart');
			local hpState, penaltyCP = GetMissionResultObjectState(target, clearRank, company);
			local penaltyTotalCP = penaltyCP + durationPenaltyCP;
			-- 사망/패배 페널티가 없는 상황에서는 패배 시에 CP 페널티도 없다.
			if not win and not mission.EnableDeadPenalty then
				penaltyTotalCP = 0;
			end
			local totalCP = math.min(pc.OverChargeCP, math.max(0, baseCP - penaltyTotalCP));
			
			result.State = hpState;
			result.CP = { Base = math.floor(baseCP), Result = totalCP, MaxCP = pc.OverChargeCP };
			
			local pauseRestoreAmount = pc:CalcRestoreCP(GetMissionPausedTimeReal(mission));
			local nextSatiety = GetMissionResultSatiety(target, battleDuration);
			local nextRefresh = GetMissionResultRefresh(target, battleDuration);
			UpdateRosterConditionPoint(dc, pc, baseCP - penaltyTotalCP + pauseRestoreAmount, nextSatiety, nextRefresh);
			
			if pc.FoodSetEffect ~= 'None' then
				dc:UpdatePCProperty(pc, 'FoodSetEffect', 'None');			
			end
		elseif pc.RosterType == 'Beast' then
			local baseCP = pc.CP;
			local hpState = GetMissionResultObjectState(target, clearRank, company);
			local addCP = GetAddResultCP_Beast(target, win);		
			local totalCP = math.clamp(baseCP + addCP, 0, pc.MaxCP);
			
			result.State = hpState;
			result.CP = { Base = math.floor(baseCP), Result = totalCP, MaxCP = pc.OverChargeCP };
			
			if pc.CP ~= totalCP then
				dc:UpdatePCProperty(pc, 'CP', totalCP);
			end
		elseif pc.RosterType == 'Machine' then
			local penaltyCP, penaltyMaxCP;
			local baseCP = pc.CP;
			local hpState, penaltyCP, penaltyMaxCP = GetMissionResultObjectState_Machine(target, clearRank, company);
			local totalMaxCP = math.max(pc.MaxCP - penaltyMaxCP, 100);	-- MaxCP는 최소 100 유지
			local totalCP = math.clamp(baseCP - penaltyCP, 0, totalMaxCP);
			
			result.State = hpState;
			result.CP = { Base = math.floor(baseCP), Result = totalCP, MaxCP = totalMaxCP };
			
			if pc.CP ~= totalCP then
				dc:UpdatePCProperty(pc, 'CP', totalCP);
			end
			if pc.MaxCP ~= totalMaxCP then
				dc:UpdatePCProperty(pc, 'MaxCP', totalMaxCP);
			end
		end
		
		-- 승리 시 임금 카운터 증가
		if win and pc.RosterType == 'Pc' and mission.EnableMissionCount then
			dc:AddPCProperty(pc, 'SalaryCounter', 1);
		end
		
		-- 휴식 경험치 갱신
		local restExp, restJobExp = CalculateRestExpRatio(pc, target.RestExp, target.RestJobExp);
		dc:UpdatePCProperty(pc, 'RestExp', restExp);
		dc:UpdatePCProperty(pc, 'RestJobExp', restJobExp);
		dc:UpdatePCProperty(pc, 'LastMissionPlayTime', os.time());
	end
	
	-- 6.5	길들인 야수 영입
	local tamingList = GetCompanyInstantProperty(company, 'TamingList') or {};
	for _, objKey in ipairs(tamingList) do
		local target = GetUnit(mission, objKey, true);
		if target then
			local rosterKey = string.format('Beast_%d', company.BeastIndex);
			dc:AddCompanyProperty(company, 'BeastIndex', 1);
			company.BeastIndex = company.BeastIndex + 1; -- 길들인 야수가 여러 마리일 때를 위한 임시 적용
			local beastType = GetInstantProperty(target, 'BeastType');
			local evolutionMastery = GetInstantProperty(target, 'EvolutionMastery');
			dc:NewBeast(company, rosterKey, beastType);
			dc:UpdatePCProperty(nil, 'Lv', target.Lv);
			dc:UpdatePCProperty(nil, 'Exp', target.Exp);
			dc:UpdatePCProperty(nil, 'JobLv', target.JobLv);
			dc:UpdatePCProperty(nil, 'JobExp', target.JobExp);
			-- 테이머 정보
			local tamerKey = target.Tamer;
			if tamerKey and tamerKey ~= '' then
				local tamerPcInfo = lineupObjKeyMap[tamerKey];
				if tamerPcInfo then
					dc:UpdatePCProperty(nil, 'Tamer', tamerPcInfo.RosterKey);
				end
			end
			local beastTypeCls = GetClassList('BeastType')[beastType];
			-- 진화 특성
			for i = 1, beastTypeCls.EvolutionMaxStage do 
				local masteryName = evolutionMastery[i];
				if masteryName then
					dc:UpdatePCProperty(nil, string.format('EvolutionMastery%d', i), masteryName);
				end
			end
			
			if beastTypeCls.Monster.Grade == 'Legend' then
				dc:UpdatePCProperty(nil, 'LegendaryTamed', true);
			end
			
			local baseLv = beastTypeCls.Monster.Lv;
			local levelUp = target.Lv - baseLv;
			local dummyPc = { RosterType = 'Beast', BeastType = beastTypeCls };
			local rewardMasteries = GetRewardMasteriesByJobLevel_Beast(company, dummyPc, 1, target.JobLv);
			for _, mastery in ipairs(rewardMasteries) do
				local techName = mastery.name;
				dc:UpdateCompanyProperty(company, string.format('Technique/%s/Opened', techName), true);
				dc:UpdateCompanyProperty(company, string.format('Technique/%s/IsNew', techName), true);
			end
			local hpState = GetMissionResultObjectState(target, clearRank, company);
			local baseCP = 70;
			list.Roster[GetObjKey(target)] = { 
				State = hpState, 
				Exp = {
					Base = 0,
					LevelUP = levelUp,
					Level = target.Lv,
					Result = target.Exp
				},
				JobExp = {
					Base = 0,
					Result = target.JobExp,
					LevelUP = target.JobLv - 1,
					Level = target.JobLv
				},
				CP = {
					Base = baseCP,
					Result = baseCP,
					MaxCP = 100
				},
				Stats = table.shallowcopy(GetUnitStats(target)),
			};
		end
	end
	
	-- 6.75	NPC 유저 멤버
	local playerUnits = GetTeamUnits(mission, GetUserTeam(company), true, false);
	for _, target in ipairs(playerUnits) do
		local objKey = GetObjKey(target);
		if lineupObjKeyMap[objKey] == nil and GetInstantProperty(target, 'CUSTOM_USER_MEMBER') then
			local hpState = GetMissionResultObjectState(target, clearRank, company);
			list.Roster[objKey] = { 
				State = hpState,
				Stats = table.shallowcopy(GetUnitStats(target)),
			};
		end
	end	
		
	-- 7. 아이템 소모 관련 처리들
	-- 소모된 아이템 얻기
	local equipmentClsList = GetClassList('Equipment');
	for i, obj in ipairs(lineupPc) do
		for _, equipmentCls in pairs(equipmentClsList) do
			local slotType = equipmentCls.name;
			local item = obj.Object[slotType];
			if item and item.name then
				local unequipResult = CalcItemUnequipResult(item, obj.Object);
				if item.IsGhost and item.IsLoot then	-- 미션에서 준 Ghost 아이템 -> 원래 장비 복원
					dc:CancelUnequipItem(obj, slotType);
				elseif unequipResult == 'Consumed' and not item.IsLoot then	-- 들고온 아이템을 소모함 -> 소모시킴
					dc:UseItem(obj, slotType);
				elseif unequipResult == 'Unequip' and item.IsLoot then	-- 미션에서 얻은 아이템인데 소모하지 않았음 -> 장착
					dc:EquipNewItem(obj, item.name, slotType);
					if item.Option.OptionKey ~= 'None' then
						dc:UpdateLastRefItemProperty('Option/OptionKey', item.Option.OptionKey);
						for index = 1, 5 do
							local typeKey = string.format('Type%d', index);
							local valueKey = string.format('Value%d', index);
							if item.Option[typeKey] ~= 'None' then
								dc:UpdateLastRefItemProperty('Option/'..typeKey, item.Option[typeKey]);
								dc:UpdateLastRefItemProperty('Option/'..valueKey, item.Option[valueKey]);
							end
						end	
					end
				end
			end
		end
	end
	list.Result.Win = win;
	list.Result.LastAttacker = lastTargetKey;
	list.Result.Rank = clearRank;
	
	local worldProperty = GetWorldProperty();
	local zoneProperty = nil;
	local missionRankCls = nil;
	local totalIncreasedReputation = 0;

	-- 8. 활동 진행현황 갱신
	if missionAttribute and mission.EnableMissionCount then
		local questType = missionAttribute.QuestType;
		local reward = 0;
		local site = nil;
		local reputationBonus = 0;
		local safetyRatio = 0;
		local eventGenType = missionAttribute.EventGenType;
		local isScenario = false;
		local directMissionInfo = missionAttribute.DirectMissionInfo;
		if questType ~= nil then
			local questCls = GetClassList('Quest')[questType];
			reward = SafeIndex(questCls, 'Grade', 'Reward') or 0;
			site = questCls.Site;
			missionRankCls = questCls.Rank;
		elseif eventGenType ~= nil then
			local eventGenCls = GetClassList('ZoneEventGen')[eventGenType];
			reward = SafeIndex(eventGenCls, 'Grade', 'Reward') or 0;
			site = eventGenCls.Slot;
			missionRankCls = eventGenCls.Rank;
			zoneProperty = worldProperty.ZoneState[eventGenCls.Zone];
			safetyRatio = zoneProperty.Safty / zoneProperty.MaxSafty;
			if safetyRatio <= 0.2 then
				reputationBonus = 10;
			end
			isScenario = eventGenCls.Group == 'Scenario';
		elseif directMissionInfo ~= nil then
			local grade = directMissionInfo.Grade or 'Bronze';
			reward = SafeIndex(GetClassList('Grade'), grade, 'Reward') or 0;
			site = directMissionInfo.Site;
			-- 더미용 미션 랭크 클래스 생성
			missionRankCls = {RewardRatio = directMissionInfo.RewardRatio, Lv = directMissionInfo.Lv};
			isScenario = true;
		end
		-- 사건 해결 보상금은 승리했을 때만 적용된다.
		-- 해당 미션의 랭크에 따라 비용이 증가. Rank
		-- 해당 미션의 레벨에 따라 비용이 증가. 
		if win and reward > 0 then
			if missionRankCls then
				reward = reward * missionRankCls.RewardRatio / 100;
				reward = reward + math.floor(missionRankCls.Lv/5) * 50;
			end
			if safetyRatio < 0.2 then
				reward = reward * 0.75;
			elseif safetyRatio < 0.5 then
				reward = reward * 0.9;
			elseif safetyRatio < 0.8 then
				reward = reward * 1;
			elseif safetyRatio < 1 then
				reward = reward * 1.1;
			elseif safetyRatio == 1 then
				reward = reward * 1.25;
			end
			if company.CompanyMastery == 'CustomerSatisfaction' then
				reward = reward + reward * GetClassList('Mastery').CustomerSatisfaction.ApplyAmount / 100;
			end
			dc:AddCompanyProperty(company, 'CurrentReward', reward);
		end
		list.Result.CurrentReward = reward;
		-- 평판은 패배, 포기 시에도 적용된다.
		if site ~= nil then
			local reputationIncreaseAmount = 0;
			local siteCls = GetClassList('Site')[site];
			zoneProperty = worldProperty.ZoneState[siteCls.Zone];	-- 뭔가 중복계산같지만 귀찮아..
			local reputationTarget = siteCls.Section;
			
			local reputationIncreaseMap = {};
			local AddReputationLv = function(target, addLv)
				reputationIncreaseMap[target] = (reputationIncreaseMap[target] or 0) + addLv;
			end;
			
			if win then
				local reputationBase = 0;
				if mission.Type.name == 'CivilRescue' then
					local rescueRatio = rescueCount / mission.CitizenCount;
					if rescueRatio >= 1.0 then
						reputationBase = 30;
					elseif rescueRatio >= 0.75 then
						reputationBase = 20;
					elseif rescueRatio >= 0.5 then
						reputationBase = 10;
					elseif rescueRatio >= 0.25 then
						reputationBase = 0;
					elseif rescueRatio > 0 then
						reputationBase = -10;
					else
						reputationBase = -20;
					end
				else
					reputationBase = 10;
				end
				reputationIncreaseAmount = reputationBase + reputationBonus;
			else
				local reputationBase = 0;
				if mission.Type.name == 'CivilRescue' then
					reputationBase = -20;
				else
					reputationBase = -10;
				end
				reputationIncreaseAmount = reputationBase;
			end
			local reputationMultiplier = 0;
			-- 거주구 보너스
			local residenceBonus = GetSectionTypeBonusValue(company.Reputation, 'Residence');
			if residenceBonus > 0 and reputationIncreaseAmount > 0 then
				reputationMultiplier = reputationMultiplier + residenceBonus;
			end
			if reputationMultiplier ~= 0 then
				reputationIncreaseAmount = math.floor(reputationIncreaseAmount * (1 + reputationMultiplier / 100));
			end
			if reputationIncreaseAmount ~= 0 then
				AddReputationLv(reputationTarget, reputationIncreaseAmount);
			end
			
			if win then
				-- 활동 보고서 카운터 증가
				local historyIndex = company.ActivityReportCounter + 1;
				dc:AddCompanyProperty(company, 'ActivityReportCounter', 1);
				-- 패배했는데 평판이 오르는 경우는 없다고 가정한다.
				dc:UpdateCompanyProperty(company, string.format('ActivityReport/History/%d/Section', historyIndex), reputationTarget);
				dc:UpdateCompanyProperty(company, string.format('ActivityReport/History/%d/Reputation', historyIndex), reputationIncreaseAmount);

				-- 관할 구역 보너스
				local curSection = company.Reputation[reputationTarget];
				local ForeachAllowDivisionBonus = function(company, bonusType, doFunc)
					local isEnable, bonusCls, bonusSectionList = IsEnableAllowDivisionBonus(company, bonusType);
					if not isEnable then
						return;
					end
					for _, bonusSection in ipairs(bonusSectionList) do
						doFunc(bonusCls, bonusSection);
					end
				end;
				local GetBonusIndex = function(bonusCls, bonusSection)
					for i, info in ipairs(bonusSection.Bonus) do
						if info.Type == bonusCls.name then
							return i;
						end
					end
					return nil;
				end;
				-- 1) 상인조합
				ForeachAllowDivisionBonus(company, 'MerchantsAssociation', function(bonusCls, bonusSection)
					-- Business 타입에 전부 적용
					local applySectionList = GetDivisionList(company.Reputation, 'Business');
					for _, applySection in ipairs(applySectionList) do
						AddReputationLv(applySection.name, bonusCls.ApplyAmount);
					end
				end);
				-- 2) 노동조합
				ForeachAllowDivisionBonus(company, 'LaborAssociation', function(bonusCls, bonusSection)
					-- Industry 타입에 전부 적용
					local applySectionList = GetDivisionList(company.Reputation, 'Industry');
					for _, applySection in ipairs(applySectionList) do
						AddReputationLv(applySection.name, bonusCls.ApplyAmount);
					end
				end);
				-- 3) 시민 응원
				ForeachAllowDivisionBonus(company, 'CivilCheer', function(bonusCls, bonusSection)
					-- Residence 타입에 전부 적용
					local applySectionList = GetDivisionList(company.Reputation, 'Residence');
					for _, applySection in ipairs(applySectionList) do
						AddReputationLv(applySection.name, bonusCls.ApplyAmount);
					end
				end);
				-- 4) 전폭적인 지지
				ForeachAllowDivisionBonus(company, 'EntireConfidence', function(bonusCls, bonusSection)
					-- 발동한 보너스 지구의 Divison에 전부 적용
					local applySectionList = GetDivisionList(company.Reputation, nil, bonusSection.Division.name);
					for _, applySection in ipairs(applySectionList) do
						AddReputationLv(applySection.name, bonusCls.ApplyAmount);
					end
				end);
				-- 5) 검문
				ForeachAllowDivisionBonus(company, 'Check', function(bonusCls, bonusSection)
					-- 모든 지구에 전부 적용
					local applySectionList = GetDivisionList(company.Reputation);
					for _, applySection in ipairs(applySectionList) do
						AddReputationLv(applySection.name, bonusCls.ApplyAmount);
					end
				end);
				-- 6) 암거래 적발
				ForeachAllowDivisionBonus(company, 'BlackMarket', function(bonusCls, bonusSection)
					-- Business 타입에 전부 적용
					local applySectionList = GetDivisionList(company.Reputation, 'Business');
					for _, applySection in ipairs(applySectionList) do
						if applySection.Division.name == curSection.Division.name then
							-- 같은 Divison은 감소
							AddReputationLv(applySection.name, -bonusCls.ApplyAmount2);
						else
							AddReputationLv(applySection.name, bonusCls.ApplyAmount2);
						end
					end
				end);
				-- 7) 보고서 결산 (물품 지원: XX, 암거래 적발, 기술 협약, 정보상)
				local bonusCountTypeList = {
					'SupportItem_Potion', 'SupportItem_RareEquipment',
					'SupportItem_RareArmor', 'SupportItem_RareMaterial',
					'SupportItem_RareAccessory', 'SupportItem_RareWeapon',
					'SupportItem_Extractor', 'SupportItem_Psistone',
					'BlackMarket', 'TechnicalAgreements', 'InformationMerchant',
				};
				for _, bonusType in ipairs(bonusCountTypeList) do
					ForeachAllowDivisionBonus(company, bonusType, function(bonusCls, bonusSection)
						local bonusIndex = GetBonusIndex(bonusCls, bonusSection);
						-- 아니 이게 없으면 어떻게 해...
						if not bonusIndex then
							return;
						end
						-- 일단 발동한 보너스 횟수를 기록해둠
						dc:AddCompanyProperty(company, string.format('ActivityReport/ReputationBonus/%s/%d', bonusSection.name, bonusIndex), 1);
					end);
				end
				-- 8) 보고서 결산 특수 처리 (넉넉한 후원, 현장 수습)
				-- 8-1) 넉넉한 후원
				ForeachAllowDivisionBonus(company, 'EnoughSupport', function(bonusCls, bonusSection)
					-- 넉넉한 후원 발동에 따른 추가 보상 수치를 미션 히스토리에 기록해둠
					local rewardIncreaseAmount = math.floor(reward * bonusCls.ApplyAmount / 100);
					dc:UpdateCompanyProperty(company, string.format('ActivityReport/History/%d/EnoughSupport', historyIndex), rewardIncreaseAmount);
				end);
				-- 8-2) 현장 수습
				ForeachAllowDivisionBonus(company, 'FieldControl', function(bonusCls, bonusSection)
					-- 현장 수습 발동 정보를 미션 히스토리에 기록해둠
					dc:UpdateCompanyProperty(company, string.format('ActivityReport/History/%d/FieldControlSection', historyIndex), bonusSection.name);
					dc:UpdateCompanyProperty(company, string.format('ActivityReport/History/%d/FieldControlMission', historyIndex), mission.name);
				end);
			end
			
			-- 평판 적용
			for target, addLv in pairs(reputationIncreaseMap) do
				dc:AddCompanyProperty(company, string.format('Reputation/%s/Lv', target), addLv, 0, company.Reputation[target].MaxLv);
				if addLv > 0 then
					totalIncreasedReputation = totalIncreasedReputation + addLv;
				end
			end
		end
		
		if win then
			dc:AddCompanyProperty(company, string.format('ActivityReport/Activities/%s/Clear', mission.Type.name), 1);
			
			if isScenario and IsSingleplayMode() then
				dc:AddCompanyProperty(company, 'Singleplay/ScenarioClearCount', 1);
			end
		end
	end
	
	-- 9. 지역 치안도 증가
	if missionRankCls ~= nil and zoneProperty ~= nil and not zoneProperty.SafetyFever and mission.EnableMissionCount then
		if IsSingleplayMode() then
			if totalIncreasedReputation > 0 then
				dc:AddCompanyProperty(company, 'Singleplay/SafetyStack', totalIncreasedReputation);
			end
		else
			AddWorldProperty(string.format('ZoneState/%s/Safty', zoneProperty.name), missionRankCls.Lv, string.format('Mission:%s', mission.name), 0, zoneProperty.MaxSafty);
		end
		
	end
	
	-- 10. 미션 프로퍼티 갱신.
	local isTroublebookMission = false;
	if missionAttribute and missionAttribute.TroubleBookEpisode then
		isTroublebookMission = true;
	end
	-- 10 - 1. 미션 완료 프로퍼티.
	if win and not company.MissionCleared[mission.name] then
		dc:UpdateCompanyProperty(company, string.format('MissionCleared/%s', mission.name), true);
	end
	-- 10 - 2. 커스텀 프로퍼티.
	local script = _G['MissionResult_Custom_' ..mission.name];
	if script then
		script(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission);
	end
	MissionResult_Custom_Common(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission);
	
	-- 11. 적 정예화 숫자 제어를 위한 프로퍼티 갱신
	if mission.EnableEnemyGradeUp then
		if win then
			if RandomTest( company.EnemyGradeUpClearCount * 10 ) then
				dc:UpdateCompanyProperty(company, 'EnemyGradeUpClearCount', math.random(0, math.max(1, math.floor(company.EnemyGradeUpClearCount/2))));
			else
				dc:AddCompanyProperty(company, 'EnemyGradeUpClearCount', 1);
			end
			dc:UpdateCompanyProperty(company, 'EnemyGradeUpFailCount', 0);
		else
			dc:AddCompanyProperty(company, 'EnemyGradeUpFailCount', 1);
			dc:UpdateCompanyProperty(company, 'EnemyGradeUpClearCount', 0);
		end
	end
	
	-- 12. 회사 & 로스터 통계 갱신
	UpdateCompanyAndRosterStats(mission, dc, company, lineup, missionAttribute, win);
	
	-- 13. 불법 오브젝트 파괴 보상메일 전송
	if win and mission.Instance.IllegalObjectReward > 0 then
		local clearList = {};
		for key, obstacle in pairs(mission.Instance.Obstacle) do
			if obstacle.DestroyCount > 0 then
				clearList[key] = obstacle.DestroyCount;
			end
		end
		clearList.IllegalObjectRewardTotal = mission.Instance.IllegalObjectReward;
		local bonusRatio = 1 + company.MissionStatus.DestroyRewardBonus / 100;
		dc:GiveSystemMail(company, 'IllegalObjectReward', 'IllegalObjectReward', 'IllegalObjectReward', 'Vill', mission.Instance.IllegalObjectReward * bonusRatio, clearList, nil, 'General');
	end
	
	-- 14. 시민 감사 메일 전송
	if win then
		local mailList = GetCompanyInstantProperty(company, 'MailList') or {};
		for _, mailInfo in ipairs(mailList) do
			dc:GiveSystemMail(company, mailInfo.MailKey, mailInfo.MailKey, mailInfo.MailKey, mailInfo.ItemType, mailInfo.ItemCount, mailInfo.MailProperty, nil, 'General');
		end
		
	end

	return list;
end
------------------- 미션 결과용 현재 캐릭터의 HP 상태를 받아오는 함수 ------------
function GetMissionResultObjectState(obj, missionRank, company)

	local missionMemberState = GetClassList('MissionMemberState');
	local masteryTable = GetMastery(obj);
	
	local succ, state = pcall(GetMissionResultObjectStateByHPRatio, obj.LowestHP, obj.LowestHP/obj.MaxHP);
	if not succ then
		LogAndPrint('ERROR', 'GetMissionResultObjectState', state);
		state = 'Normal';
	end
	if missionRank == 'Escape' and state ~= 'Coma' then
		state = 'Escape';
	end
	
	-- 피깍인거에 따른 패널티 보정값
	local penaltyCP = missionMemberState[state].CPAmount;
		
	-- 특성 소속감.
	local mastery_SenseOfBelonging = GetMasteryMastered(masteryTable, 'SenseOfBelonging');
	if mastery_SenseOfBelonging then
		penaltyCP = penaltyCP * (100 - mastery_SenseOfBelonging.ApplyAmount)/100;
	end
	
	-- 특성 몰입
	local mastery_Immersion = GetMasteryMastered(masteryTable, 'Immersion');
	if mastery_Immersion then
		penaltyCP = penaltyCP * (100 - mastery_Immersion.ApplyAmount)/100;
	end	
	-- 특성 패배자.	
	if state == 'Escape' then
		local mastery_Vanquished = GetMasteryMastered(masteryTable, 'Vanquished');
		if mastery_Vanquished then
			penaltyCP = penaltyCP * (100 - mastery_Vanquished.ApplyAmount)/100;
		end
	end	
	-- 평판 중앙 지구 보너스
	local centerAreaBonus = GetDivisionTypeBonusValue(company.Reputation, 'Area_Center');
	if centerAreaBonus > 0 then
		penaltyCP = penaltyCP * (100 - centerAreaBonus)/100;
	end

	return state, penaltyCP;
end
function GetMissionResultObjectState_Machine(obj, missionRank, company)
	local summonCount = GetInstantProperty(obj, 'SummonCount') or 0;
	if summonCount <= 0 then
		return 'Normal', 0, 0;
	end

	local missionMemberState = GetClassList('MissionMemberState');
			
	local state = GetMissionResultObjectStateByHPRatio(obj.LowestHP, obj.LowestHP/obj.MaxHP);
	local realState = state;	
	if missionRank == 'Escape' and state ~= 'Coma' then
		state = 'Escape';
	end
	
	-- 피깍인거에 따른 패널티 보정값
	local penaltyCP = missionMemberState[state].BrokenAmount;
	local penaltyMaxCP = missionMemberState[realState].BrokenMaxAmount;
	
	return state, penaltyCP, penaltyMaxCP;
end
------------------------------------------------------------------------
-- 미션 종료시 미션 랭크 결정하는 함수.
-----------------------------------------------------------------------
function GetMissionResult(mission, company, lineup, win, isSurrender)

	-- 평가 요소는 아래의 4요소. 미션 진행 시간 / 살아남은 캐릭터 수 / 죽인 적 수 / 구조자 수
	local battleDuration = GetMissionElapsedTime(mission);
	local aliveCount = #lineup;
	local killEnemyCount = 0;
	local rescueCount = 0;
	
	-- 0. 팀의 남은 유닛 수 적용
	aliveCount = GetTeamCount(GetMissionID(mission), GetUserTeam(company));
	
	-- 0. 팀의 통계 수치 적용
	local companyStats = GetCompanyStats(company);
	killEnemyCount = companyStats.EnemyKill;
	rescueCount = companyStats.Rescue;
	
	-- 1. 중도 종료는 무조건 Escape
	if isSurrender then
		return 'Escape', battleDuration, aliveCount, killEnemyCount, rescueCount;
	end
	-- 2. 패배 종료는 무조건 Terrible
	if not win then
		return 'Terrible', battleDuration, aliveCount, killEnemyCount, rescueCount;
	end

	-- 3. 미션 랭크 점수내기
	local evaluationCount = 0;
	local rankPoint = 0;
	-- 1) 시간 계산하기. 0 이면 평가하지 않는 미션.
	if mission.TargetTime > 0 and battleDuration > 0 then
		local timeRatio = math.max(0, (2 - battleDuration/mission.TargetTime));
		local curTimePoint = 50 * timeRatio;
		rankPoint = rankPoint + curTimePoint;
		evaluationCount = evaluationCount + 1;
		LogAndPrint('MissionRank Time Point :: ', curTimePoint);
	end
	-- 2) 살아남은 아군 수
	if #lineup > 0 then
		local aliveCountPoint = math.floor(aliveCount/#lineup * 100);
		rankPoint = rankPoint + aliveCountPoint;
		evaluationCount = evaluationCount + 1;
		LogAndPrint('MissionRank Alive Point :: ', aliveCountPoint);
	end
	-- 3). 적군 처치 수
	if mission.TargetKillCount > 0 then
		local killPoint = 100 * math.min(1, math.max(0, killEnemyCount/mission.TargetKillCount));
		rankPoint = rankPoint + killPoint;
		evaluationCount = evaluationCount + 1;
		LogAndPrint('MissionRank Kill Point :: ', killPoint);
	end
	-- 4) 구조자 수
	if mission.TargetRescueCount > 0 then
		local rescuePoint = 100 * math.min(1, math.max(0, rescueCount/mission.TargetRescueCount));
		rankPoint = rankPoint + rescuePoint;
		evaluationCount = evaluationCount + 1;
		LogAndPrint('MissionRank escue Point :: ', rescuePoint);
	end
	
	-- 4. 미션 점수 평균 내기
	local missionRank = '';
	local averagePoint = math.max(0, math.floor(rankPoint/evaluationCount));
	if averagePoint < 20 then
		missionRank = 'Terrible';
	elseif averagePoint < 40 then
		missionRank = 'Bad';
	elseif averagePoint < 60 then	
		missionRank = 'Normal';
	elseif averagePoint < 80 then
		missionRank = 'Good';
	elseif averagePoint < 90 then	
		missionRank = 'Excellent';
	else
		missionRank = 'Perfect';
	end
	return missionRank, battleDuration, aliveCount, killEnemyCount, rescueCount;
end
------------------------------------------------------------------------
-- 미션 종료시 미션 랭크에 따라 회사 정보 업데이트
-----------------------------------------------------------------------
function UpdateComapnyPropertyByMissionResult(mission, dc, company, missionRank)
	LogAndPrint('Mission', mission, mission.name);
	-- 1. 미션 프로퍼티 업데이트
	-- 완료시간 / 클리어 횟수 / 완료 값.
	local completeCount = 1;
	-- 2. 회사 경험치 증가.
	local rewardExp = GetCompanyExpByMission(company, mission, missionRank, completeCount);
	UpdateCompanyExp(dc, company, rewardExp);
	return rewardExp;
end
------------------------------------------------------------------------
-- 미션 종료시 미션 결과에 따른 회사 통계 업데이트
-----------------------------------------------------------------------
function UpdateCompanyAndRosterStats(mission, dc, company, lineup, missionAttribute, win)
	-- 튜토리얼 미션에선 아무것도 갱신하지 않는다.
	if mission.Tutorial then
		return;
	end

	local troubleBookMission = false;
	if missionAttribute then
		local troubleBookEpisode = SafeIndex(missionAttribute, 'TroubleBookEpisode');
		troubleBookMission = troubleBookEpisode ~= nil;
	end
	
	-- 트러블북 미션은 시도 회수만 갱신한다.
	if troubleBookMission then
		-- 총 사건 연구수(트러블북)
		dc:AddCompanyProperty(company, 'Stats/MissionTroublebook', 1);
	end
	
	local siteSection = nil;
	if missionAttribute then
		local site = nil;
		local questType = missionAttribute.QuestType;
		local eventGenType = missionAttribute.EventGenType;
		local directMissionInfo = missionAttribute.DirectMissionInfo;
		if questType ~= nil then
			site = GetClassList('Quest')[questType].Site;
		elseif eventGenType ~= nil then
			site = GetClassList('ZoneEventGen')[eventGenType].Slot;
		elseif directMissionInfo ~= nil then
			site = directMissionInfo.Site;
		end
		if site ~= nil then
			siteSection = GetClassList('Site')[site].Section;
		end
	end
	
	-- 1. 회사 통계 갱신
	do
		dc:AddCompanyProperty(company, 'Stats/MissionTotal', 1);
		
		if win then
			-- 총 사건 해결 수 (트러블북 제외)
			dc:AddCompanyProperty(company, 'Stats/MissionClear', 1);
			-- 난이도 별 총 사건 해결 수
			dc:AddCompanyProperty(company, string.format('Stats/MissionClearDifficulty/%s', mission.Difficulty.name), 1);
			-- 미션 타입별 사건 해결 수
			if mission.Type.name then
				dc:AddCompanyProperty(company, string.format('Stats/MissionClearType/%s', mission.Type.name), 1);
			end
			-- 지역별 사건 해결 수 (Reputation 별)
			if siteSection then
				dc:AddCompanyProperty(company, string.format('Stats/MissionClearReputation/%s', siteSection), 1);
			end
		elseif mission.EnableDeadPenalty then
			-- 미션 패배 수
			dc:AddCompanyProperty(company, 'Stats/MissionFail', 1);
		end
		
		-- 전투 불능 수
		local unitDeadCount = 0;
		for index, pc in ipairs (lineup) do
			if IsDead(pc.Object) and pc.RosterType ~= 'Beast' then
				local customUserMember = GetInstantProperty(pc.Object, 'CUSTOM_USER_MEMBER');
				if type(customUserMember) ~= 'boolean' or customUserMember == true then
					unitDeadCount = unitDeadCount + 1;
				end
			end
		end
		if unitDeadCount > 0 and mission.EnableDeadPenalty then
			dc:AddCompanyProperty(company, 'Stats/UnitDead', unitDeadCount);
		end
		
		local companyStats = GetCompanyStats(company);
		-- 처치한 적 총 수
		if companyStats.EnemyKill > 0 then
			dc:AddCompanyProperty(company, 'Stats/EnemyKill', companyStats.EnemyKill);
		end
		-- 1 미션당 처치하는 불량배수
		local newEnemyKill = company.Stats.EnemyKill + companyStats.EnemyKill;
		local newMissionTotal = company.Stats.MissionTotal + 1;
		local newEnemyKillPerMission = math.floor(newEnemyKill / newMissionTotal * 100 + 0.5) / 100;
		if company.Stats.EnemyKillPerMission ~= newEnemyKillPerMission then
			dc:UpdateCompanyProperty(company, 'Stats/EnemyKillPerMission', newEnemyKillPerMission);
		end
		
		local addStatList = {
			'LegendaryBeastKill', 'LegendaryMachineKill', 'GiantKill',
			'ExtractPsionicStone', 'RewardItemMaterial', 'UseAbilityStandBy',
			'UseAbilityConceal', 'Rescue', 'Destruction',
			'OpenChest', 'LuckAdded', 'DodgeOnCover',
			'MissionClearWithBeast', 'TamingSuccessCount', 'TrapUseCount',
			'ProtocolUseCount', 'PerformanceFinishCount', 'HackingSuccessCount',
		};
		for _, stat in ipairs(addStatList) do
			if companyStats[stat] > 0 then
				dc:AddCompanyProperty(company, 'Stats/'..stat, companyStats[stat]);
			end
		end
	end
	
	-- 2. 각 사원별 통계 갱신
	for index, pc in ipairs (lineup) do
		local obj = pc.Object;
	
		dc:AddPCProperty(pc, 'Stats/MissionTotal', 1);
		
		-- 사원별 미션 사건 해결수
		if win then
			dc:AddPCProperty(pc, 'Stats/MissionClear', 1);
		end
		-- 사원별 전투 불능 된 수
		if IsDead(obj) and pc.RosterType ~= 'Beast' and mission.EnableDeadPenalty then
			local customUserMember = GetInstantProperty(obj, 'CUSTOM_USER_MEMBER');
			if type(customUserMember) ~= 'boolean' or customUserMember == true then
				dc:AddPCProperty(pc, 'Stats/UnitDead', 1);
			end
		end

		local unitStats = GetUnitStats(obj);
		-- 사원별 처치한 적 총 수
		if unitStats.EnemyKill > 0 then
			dc:AddPCProperty(pc, 'Stats/EnemyKill', unitStats.EnemyKill);
		end
		-- 사원별 미션당 처치하는 불량배수
		local newEnemyKill = pc.Stats.EnemyKill + unitStats.EnemyKill;
		local newMissionTotal = pc.Stats.MissionTotal + 1;
		local newEnemyKillPerMission = math.floor(newEnemyKill / newMissionTotal * 100 + 0.5) / 100;
		if pc.Stats.EnemyKillPerMission ~= newEnemyKillPerMission then
			dc:UpdatePCProperty(pc, 'Stats/EnemyKillPerMission', newEnemyKillPerMission);
		end
		
		local addStatList = {
			'Rescue', 'Destruction',
			'Attack', 'AttackDamage', 'AttackHit', 'AttackCritical',
			'Defence', 'DefenceDamage', 'DefenceDodge', 'DefenceBlock',
			'Heal',
		};
		for _, stat in ipairs(addStatList) do
			if unitStats[stat] > 0 then
				dc:AddPCProperty(pc, 'Stats/'..stat, unitStats[stat]);
			end
		end
	end
end
function GetMissionResultSatiety(target, battleDuration)
	local curSt = GetInstantProperty(target, 'SatietyAtMissionStart');
	local addSt = GetInstantProperty(target, 'AddSatiety') or 0;
	return math.max(0, curSt + addSt + CalcMissionRestoreByPcStatus('Satiety', battleDuration));
end
function GetMissionResultRefresh(target, battleDuration)
	local curSt = GetInstantProperty(target, 'RefreshAtMissionStart');
	local addSt = GetInstantProperty(target, 'AddRefresh') or 0;
	return math.max(0, curSt + addSt + CalcMissionRestoreByPcStatus('Refresh', battleDuration));
end
------------------------------------------------------------------------
-- 유실물 수거 가방 아이템 선정
-----------------------------------------------------------------------
local g_amuletCollectorSetCandidateSet = {};
function PickAmuletCollectorSetEquipment(company, missionName, roster, pickCount, rewardItems, baseRank)
	local rankInfoSet = {
		Rare = {
			Rare = { Prob = 70 },
			Epic = { Prob = 20, Next = 'Rare' },
			Legend = { Prob = 10, Next = 'Epic' },
		},
		Uncommon = {
			Uncommon = { Prob = 60 },
			Rare = { Prob = 30, Next = 'Uncommon' },
			Epic = { Prob = 9, Next = 'Rare' },
			Legend = { Prob = 1, Next = 'Epic' },
		},
	};
	
	local categorySet = { Weapon = true, Armor = true, Accessory = true };

	if g_amuletCollectorSetCandidateSet[baseRank] == nil then
		local candidateSet = {};
		local pcList = GetClassList('Pc');
		for rank, _ in pairs(rankInfoSet[baseRank]) do
			candidateSet[rank] = {};
			for _, pcCls in pairs(pcList) do
				candidateSet[rank][pcCls.name] = {};
			end
		end
		local equipPosList = GetClassList('ItemEquipmentPosition');
		local itemList = GetClassList('Item');
		for _, pcCls in pairs(pcList) do
			-- 캐릭터가 착용 가능한 아이템 Type들을 뽑음
			local equipTypeSet = {};
			for equipPos, _ in pairs(equipPosList) do
				local equipTypeList = GetWithoutError(pcCls.Object, 'EnableEquip'..equipPos);
				if equipTypeList then
					for _, equipType in ipairs(equipTypeList) do
						equipTypeSet[equipType] = true;
					end
				end
			end
			for key, item in pairs(itemList) do
				if rankInfoSet[baseRank][item.Rank.name] and equipTypeSet[item.Type.name] and categorySet[item.Category.name] then
					local candidateList = SafeIndex(candidateSet, item.Rank.name, pcCls.name);
					if candidateList ~= nil then
						table.insert(candidateList, key);
					end
				end
			end
		end
		g_amuletCollectorSetCandidateSet[baseRank] = candidateSet;
	end
		
	-- 현재 회사가 획득 가능한 아이템 셋
	local itemFilter = {};
	local itemEnemiesAmountMap = {};
	local monsterList = GetClassList('Monster');
	local enemiesAmountList = GetClassList('MissionEnemiesAmount');
	local missionCls = GetClassList('Mission')[missionName];
	for _, info in ipairs(missionCls.Enemies) do
		local monCls = monsterList[info.Type];
		local tmInfo = GetWithoutError(company.Troublemaker, info.Type);
		local enemiesAmount = SafeIndex(enemiesAmountList, info.Amount, 'Max') or 0;
		if monCls and tmInfo and tmInfo.Exp > 0 and enemiesAmount > 0 then
			for _, reward in ipairs(monCls.Rewards) do
				itemEnemiesAmountMap[reward.Item] = (itemEnemiesAmountMap[reward.Item] or 0) + enemiesAmount;
			end
		end
	end
	local rewardItemSet = {};
	for _, reward in ipairs(rewardItems) do
		rewardItemSet[reward.Type] = true;
	end
	for itemName, enemiesAmount in pairs(itemEnemiesAmountMap) do
		-- 드랍하는 적이 미션에 1명 뿐인 템은 못 얻은 경우에만 후보에 추가
		if enemiesAmount > 1 or not rewardItemSet[itemName] then
			itemFilter[itemName] = true;
		end
	end
	
	if IsLobbyServer() then
		roster = GetAllRoster(company);
	end
	local maxRequireLv = 0;
	for _, pcInfo in ipairs(roster) do
		local requireLv = math.floor(pcInfo.Lv / 5) * 5;
		maxRequireLv = math.max(maxRequireLv, requireLv);
	end
	
	local pickItems = {};
	
	for i = 1, pickCount do
		local rankPicker = RandomPicker.new();
		for rank, info in pairs(rankInfoSet[baseRank]) do
			rankPicker:addChoice(info.Prob, rank);
		end
		local pickItem = nil;
		local pickRank = rankPicker:pick();		
		while pickRank ~= nil do
			local candidateList = {};
			-- 로스터 멤버 당
			for _, pcInfo in ipairs(roster) do
				for fixRequireLv = 0, maxRequireLv, 5 do
					local candidateListByRoster = SafeIndex(g_amuletCollectorSetCandidateSet[baseRank], pickRank, pcInfo.name);
					-- 회사가 획득 가능한 것만
					candidateListByRoster = table.filter(candidateListByRoster, function(itemName)
						return itemFilter[itemName];
					end);
					-- RequireLv이 맞는 것만
					local testRequireLv = math.floor(pcInfo.Lv / 5) * 5;
					testRequireLv = math.max(testRequireLv - fixRequireLv, 0);
					local itemList = GetClassList('Item');
					candidateListByRoster = table.filter(candidateListByRoster, function(itemName)
						local itemCls = itemList[itemName];
						return itemCls.RequireLv == testRequireLv;
					end);
					if #candidateListByRoster > 0 then
						table.append(candidateList, candidateListByRoster);
						break;
					end
				end
			end
			if #candidateList > 0 then
				pickItem = candidateList[math.random(1, #candidateList)];
				break;
			end
			pickRank = rankInfoSet[baseRank][pickRank].Next;
		end
		if pickItem ~= nil then
			table.insert(pickItems, pickItem);
			-- 드랍하는 적이 미션에 1명 뿐인 템을 얻었으면, 다음 후보에서 제외
			if itemEnemiesAmountMap[pickItem] == 1 then
				itemFilter[pickItem] = nil;
			end
		end
	end
	
	return pickItems;
end