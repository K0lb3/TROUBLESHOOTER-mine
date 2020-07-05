function StartQuestCore(dc, company, questClass, arg)
	--- 퀘스트 수락 ---
	-- 퀘스트가 MaxRequestCount 이상이면 더이상 수락 하지 말자
	local allQuests = GetAllQuests(company)
	local progressQuestCount = 0;
	for i, questInfo in ipairs(allQuests) do
		local questStage = questInfo.Stage; -- could be nil
		if questStage == 'InProgress' then
			progressQuestCount = progressQuestCount + 1;
		end
	end
	if progressQuestCount >= company.MaxQuestCount then
		LogAndPrint('Inprogress Quest Count is more than MaxQuestCount');
		return;
	end
	dc:UpdateQuestStage(company, questClass.name, 'InProgress');
	dc:Commit('StartQuestCore');
	local caller = nil;
	if arg ~= nil then
		caller = arg.Caller;
	end
	
	SendNotification(company, 'RequestAccepted', { QuestType = questClass.name, Caller = caller});
end
function RequestStartQuest(dc, company, questClass, arg, ignoreCurrentState)
	local stage, progress = GetQuestState(company, questClass.name);
	if stage ~= 'Requested' and not ignoreCurrentState then
		return;	-- 시작 요청을 씹어버리...는 건데 이래도되나? ㅋㅋ
	end
	
	StartQuestCore(dc, company, questClass, arg);
end
function CompleteQuestCore(dc, company, questClass, progress, rewardIndex, force)
	
	-- 1. 퀘스트 프로퍼티 업데이트
	-- 완료시간 / 클리어 횟수 / 완료 값.
	dc:UpdateQuestStage(company, questClass.name, 'Completed');
	dc:UpdateQuestProperty(company, questClass.name, 'EndTime', os.time());
	dc:AddQuestProperty(company, questClass.name, 'CompleteCount', 1);
	if questClass.Group == 'Repeat' then
		dc:AddQuestProperty(company, questClass.name, 'RepeatCount', 1);
	end
	
	local noti = {
		QuestType = questClass.name,
	};
	
	-- 1.1 퀘스트 타입별 완료처리
	questClass.Type.Completor(dc, company, questClass, noti, force);
	
	-- 2. 보상금 지급
	local rewardVill = questClass.RewardVill;
	if rewardVill > 0 then
		dc:AddCompanyProperty(company, 'Vill', tonumber(rewardVill));
	end
	
	-- 3. 우호도 증가
	local addFriendship = questClass.RewardNPCFriendship;
	local _, _, addFriendship = UpdateFriendship(dc, company, 'Npc', questClass.Client, addFriendship);
	
	-- 3. 회사 경험치 증가.
	local rewardExp = questClass.RewardCompanyExp;
	UpdateCompanyExp(dc, company, rewardExp);
	
	-- 4. 선택 보상 지급
	local reward = nil;
	local rewards = GetWithoutError(questClass, 'Reward');
	if rewards and #rewards >= (rewardIndex or 999) then
		reward = ClassToTable(rewards[rewardIndex]);
		if reward.Type == 'Item' then
			local itemProp = {};
			local option = SafeIndex(reward, 'Option');
			if option then
				for key, value in pairs(option) do
					itemProp['Option/'..key] = value;
				end
			end
			reward.Props = itemProp;
			dc:GiveItem(company, reward.Value, reward.Amount, true, '', reward.Props);
		elseif reward.Type == 'Mastery' then
			dc:AcquireMastery(company, reward.Value, reward.Amount);
		elseif reward.Type == 'Recipe' or reward.Type == 'RandomRecipe' then
			local recipeType = nil;
			if reward.Type == 'Recipe' then
				recipeType = reward.Value;
			else
				local candidates = Linq.new(company.Recipe)
					:select(function(rd) return rd[2] end)
					:where(function(r) return r.Opened and r.Exp < r.MaxExp and #(r.UnLockRecipe) > 0 end);
				if reward.Value ~= 'All' then
					candidates:where(function(r) return r.Category == reward.Value end);
				end
				candidates = candidates:toList();
				recipeType = table.randompick(candidates).name;
				reward.Type = 'Recipe'
				reward.Value = recipeType;
			end
			local recipe = company.Recipe[recipeType];
			local recipeKey = 'Recipe/' .. recipeType;
			if not recipe.Opened then
				dc:UpdateCompanyProperty(company, recipeKey .. '/Opened', true);
				dc:UpdateCompanyProperty(company, recipeKey .. '/IsNew', true);
			end
			local curExp = recipe.Exp;
			local nextExp = math.min(curExp + reward.Amount * 100, recipe.MaxExp);
			local addExp = nextExp - curExp;
			if addExp > 0 then
				dc:AddCompanyProperty(company, recipeKey .. '/Exp', addExp);
				
				if nextExp == recipe.MaxExp then
					-- 레시피 언락하기.
					local recipeList = GetClassList('Recipe');
					for i = 1, #recipe.UnLockRecipe do
						local curUnlockRecipeName = recipe.UnLockRecipe[i];
						local curUnlockRecipe = recipeList[curUnlockRecipeName];
						if curUnlockRecipe then
							dc:UpdateCompanyProperty(company, string.format('Recipe/%s/Opened', curUnlockRecipeName), true);
							dc:UpdateCompanyProperty(company, string.format('Recipe/%s/IsNew', curUnlockRecipeName), true);
						end
					end
				end
			end
		elseif reward.Type == 'Troublemaker' or reward.Type == 'RandomTroublemaker' then
			local tmType = nil;
			if reward.Type == 'Troublemaker' then
				tmType = reward.Value;
			else
				local candidates = Linq.new(company.Troublemaker)
					:select(function(tmd) return tmd[2] end)
					:where(function(tmInfo) return tmInfo.Exp > 0 and tmInfo.Exp < tmInfo.MaxExp end);
				if reward.Value ~= 'All' then
					candidates:where(function(tmInfo) return tmInfo.Category.name == reward.Value end);
				end
				candidates = candidates:toList();
				tmType = table.randompick(candidates).name;
				reward.Type = 'Troublemaker'
				reward.Value = tmType;
			end
			local tm = company.Troublemaker[tmType];
			local nextExp = math.min(tm.Exp + reward.Amount, tm.MaxExp);
			dc:AddCompanyProperty(company, string.format('Troublemaker/%s/Exp', tmType), nextExp - tm.Exp);
		end
	end
	
	-- 6. Commit
	if not dc:Commit('CompleteQuest:'..questClass.name) then
		return false;
	end

	noti.Vill = rewardVill;
	noti.Friendship = addFriendship;
	noti.Exp = rewardExp;
	noti.SelectedReward = reward;
	
	SendNotification(company, 'RequestCompleted', noti);
	return true, rewardInfo;
end
function RequestCompleteQuest(dc, company, questClass, rewardIndex)
	-- 1. 진행 중인 것만 완료
	local stage, progress = GetQuestState(company, questClass.name);
	if stage ~= 'InProgress' then
		return false;
	end
	-- 2. 완료 조건 체크
	local isSuccess = CheckRequestState(company, questClass, progress, LobbyInventoryItemCounter(company));
	if not isSuccess then
		LogAndPrint("Quest Failed!");
		return false;
	end
	return CompleteQuestCore(dc, company, questClass, progress, rewardIndex);
end
function RequestCancelQuest(dc, company, questClass, arg, force)
	local stage, progress = GetQuestState(company, questClass.name);
	if stage == 'NotStarted' or stage == 'Error' then
		LogAndPrint('RequestCancelQuest', 'Cannot Cancel by Stage', questClass.name, stage)
		return;
	end
	-- 취소 불가 퀘스트는 안 사라진다.
	if not force and questClass.DisableCancel then
		LogAndPrint('RequestCancelQuest', 'Cannot Cancel by DisableCancel', questClass.name)
		return;
	end
	-- TODO: 퀘스트 취소함수를 만들면 그거로 갈아치워야 할듯
	dc:UpdateQuestStage(company, questClass.name, 'NotStarted');		
	dc:UpdateQuestProperty(company, questClass.name, 'EndTime', os.time());
	dc:UpdateQuestProperty(company, questClass.name, 'TargetCount', 0);
	dc:Commit('RequestCancelQuest');
	
	if arg ~= nil then
		caller = arg.Caller;
	else
		caller = questClass.Group;
	end
	if questClass.Group == 'Troublesum' or questClass.Group == 'Normal' or questClass.Group == 'Repeat' then
		SendNotification(company, 'RequestCanceled', {QuestType = questClass.name, Caller = caller});
	end
end
function TestQuestClear(user, npc, questType)
	local questCls = GetClassList('Quest')[questType];
	if questCls == nil then
		return false;
	end
	local curState, progress = GetQuestState(user, questType);
	if curState ~= 'InProgress' then
		return false;
	end
	return CheckRequestState(user, questCls, progress, LobbyInventoryItemCounter(user));
end
function TestQuestInProgress(user, npc, questType)
	local questCls = GetClassList('Quest')[questType];
	if questCls == nil then
		return false;
	end
	local curState, progress = GetQuestState(user, questType);
	if curState ~= 'InProgress' then
		return false;
	end
	return true;
end
function ProcessQuestTimeout(dc, user)
	local allQuests = GetAllQuests(user);
	local curTime = os.time();
	local processQuestOne = function(questInfo)
		local endTime = SafeIndex(questInfo, 'Progress', 'EndTime')
		if questInfo.Stage ~= 'Requested' or endTime == nil then
			return;
		end
		if endTime >= curTime then
			return;
		end
		dc:UpdateQuestStage(user, questInfo.Type, 'NotStarted');
	end
	for i, questInfo in ipairs(allQuests) do
		processQuestOne(questInfo);
	end
	dc:Commit('ProcessQuestTimeout');
end
--------------------------------------------------------------------------
-- 퀘스트 데이터에서 일반 타입 
--------------------------------------------------------------------------
function GetQuests(company, quests, stageList, group)
	local list = {};
	for key, value in pairs(quests) do
		for i = 1, #stageList do
			local stageType = stageList[i];
			local stage, progress = GetQuestState(company, key);
			if stageType == stage then
				if value.Group == group then
					table.insert(list, value);
				end
			end
		end
	end
	return list;
end
--------------------------------------------------------------------------
-- 퀘스트 완료 추가 처리
--------------------------------------------------------------------------
function QuestCompletor_None(dc, company, questCls, noti, force)
	-- Do nothing!
end

function QuestCompletor_CollectItem(dc, company, questCls, noti, force)
	if force then
		-- Do nothing!
		return;
	end
	dc:TakeItem(GetInventoryItemByType(company, questCls.Target), questCls.TargetCount);
	noti.TakeItem = {[questCls.Target] = questCls.TargetCount};
end