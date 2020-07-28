-- reward exp
function Get_Reward_Exp(self, expTaker)
	
	local masteryTable = GetMastery(expTaker);
	local mastery_Individualism = GetMasteryMastered(masteryTable, 'Individualism');
	local mastery_Learning = GetMasteryMastered(masteryTable, 'Learning');
	local mastery_Understanding = GetMasteryMastered(masteryTable, 'Understanding');
	local mastery_Insight = GetMasteryMastered(masteryTable, 'Insight');
	local mastery_Accounting = GetMasteryMastered(masteryTable, 'Accounting');
	local company = GetCompany(expTaker);
	local thokCount = 0;
	if company then
		thokCount = GetCompanyInstantProperty(company, 'TreasureHouseOfKnowledgeAmount') or 0;
	end
	
	-- 1. 기본 경험치 정하기.
	local baseExp = self.MaxHP;
	local baseExpDenominator = 8;
	baseExp = self.MaxHP/baseExpDenominator;
	
	-- 2. 경험치 배율 정하기
	local ratio = 1;
	if mastery_Individualism then
		ratio = ratio + mastery_Individualism.ApplyAmount/100;
	end
	if mastery_Learning then
		ratio = ratio + mastery_Learning.ApplyAmount/100;
	end
	if mastery_Understanding then
		ratio = ratio + mastery_Understanding.ApplyAmount/100;
	end	
	if mastery_Insight then
		ratio = ratio + mastery_Insight.ApplyAmount/100;
	end
	if mastery_Accounting then
		ratio = ratio + mastery_Accounting.ApplyAmount/100;
	end
	if thokCount > 0 then
		ratio = ratio + thokCount / 100;
	end
	
	-- 3. 미션 내부 레벨 보정도
	local mission = GetMission(expTaker);
	local missionlevelDiff = math.max(-10, math.min(10, mission.Lv - expTaker.Lv));
	local missionMultiplyExp = 0.2;
	if missionlevelDiff < 0 then
		missionMultiplyExp = 0.1;
	end
	ratio = math.max(0.5, ratio + missionMultiplyExp * missionlevelDiff);
	
	-- 4. 공격자와 전투 불능자의 레벨 보정도.
	local expTakerToDeadLevelEXPRatio = ( 2 * self.Lv )/ ( self.Lv  + expTaker.Lv);	
	local result = self.Grade.ExpRatio * baseExp * expTakerToDeadLevelEXPRatio * ratio;	
	result = math.max(1, math.floor(result));
	
	--------------------------------------------------------
	-- 클래스 경험치
	--------------------------------------------------------
	-- 획득한 경험치를 직업 등급으로 나눕니다. 높은 등급일수록 경험치 획득이 낮아지도록...	
	local resultJob = result * (1 / expTaker.Job.Grade);
	-- 그리고 최대 보정을 합니다. 아무리 빨리 올려도 해당 레벨 필요경험치의 (1/(10 * math.floor(직업레벨/2)) 를 넘지 않습니다.	
	local nextExp = GetNextExp(expTaker.JobExpType, expTaker.JobLv);
	local maxJobExpByOnce = nextExp  / ( 20 * ( math.max(1, math.floor(expTaker.JobLv/2))));
	if resultJob > maxJobExpByOnce  then
		local penalyAmount = math.min(maxJobExpByOnce, (resultJob - maxJobExpByOnce) * 0.25);
		resultJob = resultJob + penalyAmount;
	end	
	resultJob = math.max(1, math.floor(resultJob));
	
	--------------------------------------------------------
	-- 휴식 경험치
	--------------------------------------------------------
	local ApplyRestExp = function(expKey, upExp)
		local restExp = expTaker[expKey];
		if restExp > 0 then
			if upExp * 2 <= restExp then
				upExp = upExp * 2;
				restExp = restExp - upExp;
			else
				local left = upExp - restExp / 2;
				upExp = restExp + left;
				restExp = 0;
			end
		end
		return math.max(1, math.floor(upExp));
	end
	local Rresult, RresultJob = ApplyRestExp('RestExp', result), ApplyRestExp('RestJobExp', resultJob);
	result, resultJob = Rresult, RresultJob;
	--------------------------------------------------------
	-- 완료.
	--------------------------------------------------------
	return result, resultJob;
end
-- Monster.xml / rewards
function GetRewardItem(company, self, expTaker, isOverKill, isPerfectKill, safetyFeverNow)
	local list = {};
	-- 1. 플레이어는 아이템 드랍하지 않는다.
	local monsterType = GetInstantProperty(self, 'MonsterType');
	if monsterType == nil then
		return list;
	end
	
	local monsterList = GetClassList('Monster');
	local itemList = GetClassList('Item');
	local itemDropList = SafeIndex(monsterList[monsterType], 'Rewards');
	if itemDropList == nil then
		return list;
	end
	
	local masteryTable = GetMastery(expTaker);
	local mastery_Scavenger = GetMasteryMastered(masteryTable, 'Scavenger');
	local mastery_TreasureHunter = GetMasteryMastered(masteryTable, 'TreasureHunter');
	local mastery_AliBaba = GetMasteryMastered(masteryTable, 'AliBaba');
	local mastery_TreasureIsland = GetMasteryMastered(masteryTable, 'TreasureIsland');
	local mastery_TreasureOfKing = GetMasteryMastered(masteryTable, 'TreasureOfKing');
	local mastery_MaterialCollector = GetMasteryMastered(masteryTable, 'MaterialCollector');
	local mastery_LegendaryServant = GetMasteryMastered(masteryTable, 'LegendaryServant');
	local mastery_GreedBeast = GetMasteryMastered(masteryTable, 'GreedBeast');
	local mastery_GreedEye = GetMasteryMastered(masteryTable, 'GreedEye');
	local mastery_DisposalMaterials = GetMasteryMastered(masteryTable, 'DisposalMaterials');
	local mastery_TannerSet3 = GetMasteryMastered(masteryTable, 'TannerSet3');
	local mastery_WreckingSet3 = GetMasteryMastered(masteryTable, 'WreckingSet3');
	local mastery_CollectorSet3 = GetMasteryMastered(masteryTable, 'CollectorSet3');
	local mastery_JewelCollectorSet3 = GetMasteryMastered(masteryTable, 'JewelCollectorSet3');
	local mastery_ExtractorSet3 = GetMasteryMastered(masteryTable, 'ExtractorSet3');
	local mastery_ExtractorSet_Refine3 = GetMasteryMastered(masteryTable, 'ExtractorSet_Refine3');

	local buff_Food_Joy = GetBuff(expTaker, 'Food_Joy');
	local buff_Food_Joy2 = GetBuff(expTaker, 'Food_Joy2');
	local buff_Food_Joy3 = GetBuff(expTaker, 'Food_Joy3');

	local dailyHuntingNow = GetInstantProperty(expTaker, 'DailyHuntingNow');
	local dismantlingSpecialist = GetInstantProperty(expTaker, 'DismantlingSpecialist');
	
	-- 0.1%를 최소 수치로 하고 진행합니다.
	local totalProb = 1000;
	local picker = RandomPicker.new();
	for index, value in ipairs (itemDropList) do
		local item = itemList[value.Item];
		if SafeIndex(item, 'name') then
			-- 드랍율 가져오기.
			local curProb = GetMonterRewardDropRatio(self, item)
			-- 음식 세트 효과 아이템 확률
			if buff_Food_Joy then
				curProb = curProb + curProb * buff_Food_Joy.ApplyAmount/100;
			end
			if buff_Food_Joy2 then
				curProb = curProb + curProb * buff_Food_Joy2.ApplyAmount/100;
			end
			if buff_Food_Joy3 then
				curProb = curProb + curProb * buff_Food_Joy3.ApplyAmount/100;
			end
			-- 회사 특성 청소부 아이템 확률 10% 
			if mastery_Scavenger then
				curProb = curProb + curProb * mastery_Scavenger.ApplyAmount/100;
			end
			-- 특성 보물 사냥꾼 아이템 확률 2배 
			if mastery_TreasureHunter then
				curProb = curProb * (1 + mastery_TreasureHunter.ApplyAmount / 100);
			end	
			-- 특성 알리바바 고급 이상 아이템 확률 3배
			-- 랭크 Weight 1 하급 2 일반 3 고급 4 희귀 5 영웅 6 전설 7 유니크
			if mastery_AliBaba and item.Rank.Weight > 2 then
				curProb = curProb * (1 + mastery_AliBaba.ApplyAmount / 100);
			end
			-- 특성 보물섬 희귀 이상 아이템 확률 3배
			if mastery_TreasureIsland and item.Rank.Weight > 3 then
				curProb = curProb * (1 + mastery_TreasureIsland.ApplyAmount / 100);
			end	
			-- 왕의 재보
			if mastery_TreasureOfKing and item.Rank.Weight > 4 then
				curProb = curProb * (1 + mastery_TreasureOfKing.ApplyAmount / 100);
			end
			-- 특성 탐욕의 눈 보석 아이템 확률 X배
			if mastery_GreedEye and item.Type.name == 'Jewel' then
				local applyAmount = mastery_GreedEye.CustomCacheData[item.Rank.name];
				if applyAmount then
					curProb = curProb * (1 + applyAmount / 100);
				end
			end
			-- 특성 능숙한 해체 부품 아이템 확률 X배
			if mastery_DisposalMaterials and item.Type.name == 'Parts' then
				local applyAmount = mastery_DisposalMaterials.CustomCacheData[item.Rank.name];
				if applyAmount then
					curProb = curProb * (1 + applyAmount / 100);
				end
			end
			-- 특성 재료수집가 재료 아이템 확률 3배
			if mastery_MaterialCollector and item.Category.name == 'Material' then
				curProb = curProb * (1 + mastery_MaterialCollector.ApplyAmount / 100);
			end	
			-- 특성 전문 무두장이 - 3 세트 가죽, 비늘 아이템 확률 X배
			if mastery_TannerSet3 and (item.Type.name == 'Skin' or item.Type.name == 'Scale') then
				curProb = curProb * (1 + mastery_TannerSet3.ApplyAmount / 100);
			end
			-- 특성 전문 철거업자 - 3 세트 부품 재료 아이템 확률 X배
			if mastery_WreckingSet3 and item.Type.name == 'Parts' then
				curProb = curProb * (1 + mastery_WreckingSet3.ApplyAmount / 100);
			end
			-- 특성 전문 수집업자 - 3 세트 부품 재료 아이템 확률 X배
			if mastery_CollectorSet3 and item.Category.name == 'Material' then
				curProb = curProb * (1 + mastery_CollectorSet3.ApplyAmount / 100);
			end
			-- 특성 전문 보석 세공사 - 3 세트 보석 아이템 확률 X배
			if mastery_JewelCollectorSet3 and item.Type.name == 'Jewel' then
				curProb = curProb * (1 + mastery_JewelCollectorSet3.ApplyAmount / 100);
			end
			-- 특성 전문 추출업자 - 3 세트 이능석 아이템 확률 X배
			if mastery_ExtractorSet3 and item.Type.name == 'PsionicStone' then
				curProb = curProb * (1 + mastery_ExtractorSet3.ApplyAmount / 100);
			end
			if mastery_ExtractorSet_Refine3 and item.Type.name == 'PsionicStone' then
				curProb = curProb * (1 + mastery_ExtractorSet_Refine3.ApplyAmount / 100);
			end
			-- 해체 전문가
			if self.Race.name == 'Machine' and dismantlingSpecialist and item.Category.name == 'Material' then
				local applyAmount = SafeIndex(GetClassList('Mastery'), 'DismantlingSpecialist', 'ApplyAmount');
				if applyAmount then
					curProb = curProb * (1 + applyAmount / 100);
				end
			end
			-- 오버킬.
			if isOverKill then
				if item.Rank.Weight > 2 then
					curProb = curProb * 1.1;
				end
				if item.Rank.Weight > 3 then
					curProb = curProb * 1.25;
				end
				if item.Rank.Weight > 4 then
					curProb = curProb * 1.5;
				end
			end
			-- 퍼펙트 킬
			if isPerfectKill then
				if item.Rank.Weight > 2 then
					curProb = curProb * 1.1;
				end
				if item.Rank.Weight > 3 then
					curProb = curProb * 1.25;
				end
				if item.Rank.Weight > 4 then
					curProb = curProb * 1.5;
				end			
			end
			-- 치안도 피버
			if safetyFeverNow then
				if item.Rank.Weight > 2 then
					curProb = curProb * 2;
				end
			end
			-- 사냥꾼의 일상
			if dailyHuntingNow and self.Race.name == 'Beast' and item.Category.name == 'Material' then
				local applyAmount = SafeIndex(GetClassList('Mastery'), 'LifeOfHunter', 'ApplyAmount');
				if applyAmount then
					curProb = curProb * (1 + applyAmount / 100);
				end
			end
			-- 영웅, 전설템 획득 여부
			if item.Rank.Weight > 4 then
				curProb = curProb + company.Luck_Spoils;
			end	
			-- 정수형으로 변환
			curProb = math.floor(curProb);
			picker:addChoice(curProb, value);
			totalProb = totalProb - curProb;
		end
	end
	-- 실패할 확률을 넣습니다.
	picker:addChoice(math.max(0, totalProb), { Item = 'None' } );
	
	local selReward = picker:pick();
	if not selReward or selReward.Item == 'None' then
		company.Luck_Spoils = company.Luck_Spoils + math.random(1,3);
		return list;
	end
	local item = itemList[selReward.Item];
	-- 영웅급 이상 아이템 을 획득하면 초기화.
	if item.Rank.Weight > 4 then
		company.Luck_Spoils = 0;
	else
		company.Luck_Spoils = company.Luck_Spoils + math.random(1,3);
	end
	
	-- 아이템 개수
	local itemCount = math.random(selReward.Min, selReward.Max);	
	local multiplier = 0;
	-- 특성 전설의 일꾼 재료 아이템 개수 2배
	if mastery_LegendaryServant and item.Category.name == 'Material' then
		multiplier = multiplier + mastery_LegendaryServant.ApplyAmount;
	end
	-- 특성 탐욕의 야수 재료 아이템 개수 +200%
	if mastery_GreedBeast and item.Category.name == 'Material' then
		multiplier = multiplier + mastery_GreedBeast.ApplyAmount;
	end
	-- 특성 전문 무두장이 - 3 세트 가죽, 비늘 아이템 개수 +200%
	if mastery_TannerSet3 and (item.Type.name == 'Skin' or item.Type.name == 'Scale') then
		multiplier = multiplier + mastery_TannerSet3.ApplyAmount2;
	end
	-- 특성 전문 철거업자 - 3 세트 부품 아이템 개수 +X%
	if mastery_WreckingSet3 and item.Type.name == 'Parts' then
		multiplier = multiplier + mastery_WreckingSet3.ApplyAmount2;
	end
	-- 특성 전문 수집업자 - 3 세트 재료 아이템 개수 +X%
	if mastery_CollectorSet3 and item.Category.name == 'Material' then
		multiplier = multiplier + mastery_CollectorSet3.ApplyAmount2;
	end
	-- 특성 전문 보석 세공사 - 3 세트 보석 아이템 개수 +X%
	if mastery_JewelCollectorSet3 and item.Type.name == 'Jewel' then
		multiplier = multiplier + mastery_JewelCollectorSet3.ApplyAmount2;
	end
	-- 특성 전문 추출업자 - 3 세트 이능석 아이템 개수 +X%
	if mastery_ExtractorSet3 and item.Type.name == 'PsionicStone' then
		multiplier = multiplier + mastery_ExtractorSet3.ApplyAmount2;
	end
	if mastery_ExtractorSet_Refine3 and item.Type.name == 'PsionicStone' then
		multiplier = multiplier + mastery_ExtractorSet_Refine3.ApplyAmount2;
	end
	-- 사냥꾼의 일상
	if dailyHuntingNow and self.Race.name == 'Beast' and item.Category.name == 'Material' then
		multiplier = multiplier + (SafeIndex(GetClassList('Mastery'), 'LifeOfHunter', 'ApplyAmount2') or 200);
	end
	-- 해체전문가
	if self.Race.name == 'Machine' and dismantlingSpecialist and item.Category.name == 'Material' then
		multiplier = multiplier + (SafeIndex(GetClassList('Mastery'), 'DismantlingSpecialist', 'ApplyAmount2') or 200);
	end
	itemCount = math.floor(itemCount * (1 + multiplier / 100));
	
	local itemProps = nil;
	if selReward.Option ~= nil then
		itemProps = {};
		for key, value in pairs(selReward.Option) do
			itemProps['Option/'..key] = value;
		end
	end
	
	table.insert(list, { Item = selReward.Item, Count = itemCount, ItemProps = itemProps });
	return list;
end
function AcquireRewardMastery(dead, expTaker, isOverKill, isPerfectKill, safetyFeverNow)
	local company = GetCompany(expTaker);
	if not company then
		return;
	end
	
	local picker = RandomPicker.new();
	local candidateMasteryList = GetCurrentMasteryList(GetMastery(dead));
	local currentMasterMateryCount = 0;

	for _, mastery in ipairs(candidateMasteryList) do
		local prop = mastery.Category.Prob;
		local tech = GetWithoutError(company.Technique, mastery.name);
		if prop > 0 then
			if tech and tech.Opened then
				currentMasterMateryCount = currentMasterMateryCount + 1;
			end
		end
	end
	
	for _, mastery in ipairs(candidateMasteryList) do
		local prop = mastery.Category.Prob;
		local tech = GetWithoutError(company.Technique, mastery.name);
		if prop > 0 and tech and currentMasterMateryCount > 0 then			
			if not tech.Opened then
				prop =  prop * currentMasterMateryCount;		
			else
				prop = 10 + math.max(0, ( 4 - dead.Grade.Weight)) * 5;
			end
		end
		if prop > 0 then
			picker:addChoice(prop, mastery);
		end
	end
	if picker:size() == 0 then
		return;
	end
	local pickedMastery = picker:pick();
	if pickedMastery == nil then
		return;
	end
	
	local masteryTable = GetMastery(expTaker);
	local mastery_Expertise = GetMasteryMastered(masteryTable, 'Expertise');
	local mastery_Informant = GetMasteryMastered(masteryTable, 'Informant');
	
	local specialMasteryRatio = 1;
	-- 100%
	if mastery_Expertise then
		specialMasteryRatio = specialMasteryRatio + specialMasteryRatio * mastery_Expertise.ApplyAmount/100;
	end
	-- 100%
	if mastery_Informant then
		specialMasteryRatio = specialMasteryRatio + specialMasteryRatio * mastery_Informant.ApplyAmount/100;
	end
	-- 음식 세트 효과 아이템 확률
	local buff_Food_Joy = GetBuff(expTaker, 'Food_Joy');
	local buff_Food_Joy2 = GetBuff(expTaker, 'Food_Joy2');
	local buff_Food_Joy3 = GetBuff(expTaker, 'Food_Joy3');
	if buff_Food_Joy then
		specialMasteryRatio = specialMasteryRatio + specialMasteryRatio * buff_Food_Joy.ApplyAmount/100;
	end
	if buff_Food_Joy2 then
		specialMasteryRatio = specialMasteryRatio + specialMasteryRatio * buff_Food_Joy2.ApplyAmount/100;
	end
	if buff_Food_Joy3 then
		specialMasteryRatio = specialMasteryRatio + specialMasteryRatio * buff_Food_Joy3.ApplyAmount/100;
	end	
	-- 50%
	if isOverKill then
		specialMasteryRatio = specialMasteryRatio * 1.1;
	end
	-- 50%
	if isPerfectKill then
		specialMasteryRatio = specialMasteryRatio * 1.1;
	end
	-- 100%
	if safetyFeverNow then
		specialMasteryRatio = specialMasteryRatio * 2;
	end
	
	local deadGradeRatio = dead.Grade.MasteryRatio;
	local curGP = company.Mastery[pickedMastery.name].GP;
	
	local mission = GetMission(expTaker);
	local dc = GetMissionDatabaseCommiter(mission);
	
	local prob = specialMasteryRatio * deadGradeRatio * pickedMastery.MasterRate + curGP;
	if pickedMastery.MasterRate <= 0 then -- MasterRate가 0이면 획득 불가. GP 보정도 적용 안 됨
		prob = 0;
	end	
	local pickedMastery_Tech = GetWithoutError(company.Technique, pickedMastery.name);
	if pickedMastery_Tech and pickedMastery_Tech.Opened and prob < 95 and prob > 30 then
		prob = math.max(30, prob * math.random(50, 100)/100);
	end
	-- PC 인경우 확률 낮추기 로직
	local monsterType = GetInstantProperty(dead, 'MonsterType');
	if monsterType == nil then
		local deadMasteryTable = GetMastery(dead);
		local deadMasteryCount = 0;
		for key, mastery in pairs(deadMasteryTable) do
			deadMasteryCount = deadMasteryCount + 1;
		end
		if deadMasteryCount < 5 then
			prob = prob * 0.25;
		end
	end
	if not RandomTest(prob) then
		if pickedMastery.MasterRate <= 0 then -- GP 적용이 안 되므로, 증가도 안 시킴
			return;
		end
		local addGP = deadGradeRatio * 4;
		dc:AddCompanyProperty(company, string.format('Mastery/%s/GP', pickedMastery.name), addGP);
		company.Mastery[pickedMastery.name].GP = curGP + addGP;
		return;
	end
	
	local acquireAcount = 1;
	local unlockTechnique = dc:AcquireMastery(company, pickedMastery.name, acquireAcount);
	if unlockTechnique then
		local technique = GetWithoutError(company.Technique, pickedMastery.name);
		if technique then
		   technique.Opened = true;
		end
	end
	dc:UpdateCompanyProperty(company, string.format('Mastery/%s/GP', pickedMastery.name), 0);
	company.Mastery[pickedMastery.name].GP = 0;
	
	-- 튜토리얼 해야되는지 판단.
	local isTutorial = false;
	if not company.Progress.Tutorial.AcquiredMastery then
		-- 마스터리 획득했다고 알려주고...
		-- 로비갈때 튜토리얼하라고 알려주고...
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/AcquiredMastery', true);
		company.Progress.Tutorial.AcquiredMastery = true;
		isTutorial = company.Progress.Tutorial.AcquiredMastery;
	end	
	return pickedMastery, acquireAcount, isTutorial, unlockTechnique;
end

function AddRewardItem(obj, itemType, itemCount, itemProps)
	local company = GetCompany(obj);
	if not company then
		return;
	end
	local rewardItems = GetCompanyInstantProperty(company, 'RewardItems') or {};
	table.insert(rewardItems, { Type = itemType, Count = itemCount, Props = itemProps, LuckyNumber = math.random() * 100 });
	SetCompanyInstantProperty(company, 'RewardItems', rewardItems);
end

function GetRewardLostProbability(item, elapsedTimeSec)
	local baseLostProb = item.Rank.LossProbability;
	local lossProbabilityTime = item.Rank.LossProbabilityTime;
	
	local timeLostProb = 1;
	local elapsedTimeMin = elapsedTimeSec / 60;
	if elapsedTimeMin < 5 then
		timeLostProb = 10 * lossProbabilityTime;
	elseif elapsedTimeMin < 10 then
		timeLostProb = 8 * lossProbabilityTime;
	elseif elapsedTimeMin < 15 then
		timeLostProb = 6 * lossProbabilityTime;
	elseif elapsedTimeMin < 20 then
		timeLostProb = 4 * lossProbabilityTime;
	elseif elapsedTimeMin < 25 then
		timeLostProb = 2 * lossProbabilityTime;
	else
		timeLostProb = 1 * lossProbabilityTime;
	end
	
	return math.min(100, baseLostProb + timeLostProb);
end
function Get_Reward_JobExp(self, ability)
	local abilitySlotTypeList = GetClassList('AbilitySlotType');	
	local abilityTypeList = GetClassList('AbilityType');	
	local baseExp  = 10 + ability.Cost;
	local expRatio = 1;
	if ability.SlotType ~= 'None' then
		expRatio = expRatio * abilitySlotTypeList[ability.SlotType].EXPRatio;
	end
	if ability.Type ~= 'None' then
		expRatio = expRatio * abilityTypeList[ability.Type].EXPRatio;
	end
	local result = expRatio * baseExp;
	result = math.max(0, math.floor(result));
	return result;
end