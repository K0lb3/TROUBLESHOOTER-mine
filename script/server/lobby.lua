local troublesumLastUpdatedTime = os.time();
function LOBBY_ENTER(company, lobbyType, dc)
	local directMission, lineup = MasterLobbyPreenterMission_Script(company, lobbyType, dc);
	if directMission then
		local success = DirectMission(company, directMission, lineup);
		if success then
			return false;
		else
			KickCompany(company, 'BlockedByServerFull');
			return false;
		end
	end
	local changeLobby = MasterLobbyPreenterLobby_Script(company, lobbyType, dc);
	if changeLobby then
		ChangeLocation(company, changeLobby);
		return false;
	end
	
	local rosterList = GetAllRoster(company, 'All');
	local pcIndexSet = {};
	for i, roster in ipairs(rosterList) do
		if roster.RosterType == 'Pc' then
			pcIndexSet[i] = true;
		end
	end
	local rosterCount = #rosterList;
	-- 리셋시 초기화 로직
	if rosterCount == 0 or pcIndexSet[company.LeaderID] == nil then
		local leaderID = 1;
		if not table.empty(pcIndexSet) then
			leaderID = next(pcIndexSet);
		end
		dc:UpdateCompanyProperty(company, 'LeaderID', 1);
	end	
	
	ProcessQuestTimeout(dc, company);
	
	UpdateTroublesumOneUser(dc, company, troublesumLastUpdatedTime);
	dc:Commit('LOBBY_ENTER');
	
	UpdateLobbyCompany(dc, company);
	-- 로스터 CP갱신 -- 처음 로스터를 넣어줄때 당시 시간값으로 업데이트 시간만 세팅해 준다면 입장할때 굳이 갱신하지 않아도 크게 문제없을듯..
	-- 왜냐면 마지막 갱신후부터의 시간만 잴 수 있다면 현재의 CP수치는 언제든 얻을 수 있기 때문에..
	for i, roster in ipairs(GetAllRoster(company)) do
		InvalidateRosterConditionPoint(dc, roster);
	end
	dc:Commit('LOBBY_ENTER2');
	return true;
end
function LOBBY_UPDATE(dc)
	while true do
		Sleep(5000);		
		local startTime = os.clock();
		local updateTime = GetNextTroublesumUpdateTime(troublesumLastUpdatedTime);
		if updateTime < os.time() then
			troublesumLastUpdatedTime = updateTime;
			UpdateTroublesumAllUser(dc, updateTime);
		end
		
		local allUser = GetAllUsers();	-- user == company
		for i, user in pairs(allUser) do
			UpdateLobbyCompany(dc, user);
		end
		--print(os.clock() - startTime);
	end
end
function UpdateRosterCondition(dc, company)
	local awakedRosters = {};
	for i, roster in ipairs(GetAllRoster(company)) do
		if roster.ConditionState == 'Rest' and roster:GetEstimatedCP() >= roster.MaxCP then
			local fatigueMastery = InvalidateRosterConditionPoint(dc, roster);
			table.insert(awakedRosters, {Roster = roster.name, FatigueMastery = fatigueMastery});
		end
	end
	if #awakedRosters > 0 then
		dc:Commit('UpdateLobbyCompany');
		SendNotification(company, 'RosterReadyToWork', awakedRosters);
	end
end
function UpdateLobbyCompany(dc, company)
	local curTime = os.time();
	-- 캐릭터 컨디션 회복
	UpdateRosterCondition(dc, company);
end

function LobbyAction_TechniqueResearch(dc, company, args)
	
	local techniqueName = args.TechniqueName;
	local addMasteries = args.Materials;
	local count = args.Count;
	
	local techniqueList = GetClassList('Technique');
	local tech = techniqueList[techniqueName];
	if not tech and tech.name == nil then
		LogAndPrint('\n[DataError] TechniqueName is Worng : '.. techniqueName);
		return {Success = false, Reward = {}};
	end
	
	local isEnableTechnique, masteryList, reason, _, itemList = IsEnableTechniqueResearch(company, tech, addMasteries, LobbyInventoryItemCounter(company), count);
	if not isEnableTechnique then
		for index, value in ipairs (reason) do
			LogAndPrint('[DataError] LobbyAction ResearchTechnique : '.. value);
		end
		return {Success = false, Reward = {}};
	end
	
	-- 1. 회사 마스터리 Amount 감소시키기
	for i = 1, #masteryList do
		local masteryName = masteryList[i];
		dc:LoseMastery(company, masteryName, count);
	end
	if not tech.System then
		dc:AcquireMastery(company, tech.name, count, true);
	end
	-- 2. 재료 아이템 뺏기
	for itemKey, needCount in pairs(itemList) do
		dc:TakeItem(GetInventoryItemByType(company, itemKey), needCount * count);
	end
	
	-- 2. 언락 테크닉 열어주기.
	local unlockTechniques = {};
	for _, techName in ipairs(tech.UnLockTechnique) do
		local curUnlockTechnique = company.Technique[techName];
		if curUnlockTechnique and curUnlockTechnique.name ~= nil then
			if not curUnlockTechnique.Opened then
				dc:UpdateCompanyProperty(company, string.format('Technique/%s/Opened', curUnlockTechnique.name), true);
				dc:UpdateCompanyProperty(company, string.format('Technique/%s/IsNew', curUnlockTechnique.name), true);
				table.insert(unlockTechniques, curUnlockTechnique.name);
			end
		end
	end
	
	-- 3. 보상 아이템
	local itemRewardCount = 0;
	if tech.RewardItem ~= 'None' then
		local itemList = GetClassList('Item');
		local rewardItem = itemList[tech.RewardItem];
		if rewardItem and rewardItem.name then
			for i = 1, count do
				itemRewardCount = itemRewardCount + math.random(tech.RewardItemMinCount, tech.RewardItemMaxCount);
			end
			dc:GiveItem(company, tech.RewardItem, itemRewardCount);
		end
	end
	
	-- 4. 특성 연구 유무 마킹 (언락 조건 변경 시의 체크용)
	if not company.Technique[tech.name].Researched then
		dc:UpdateCompanyProperty(company, string.format('Technique/%s/Researched', tech.name), true);
	end
	
	SendNotification(company, 'ResearchTechniqueCompleted', 
		{ Type = tech.name, MasteryList = masteryList, Techniques = unlockTechniques, ItemType = tech.RewardItem, ItemCount = itemRewardCount}
	);
	return {Success = true, Reward = masteryList};
end

function LobbyInventoryItemCounter(owner)
	return function(itemName)
		local item = GetInventoryItemByType(owner, itemName);
		if item == nil then
			return 0;
		else
			return item.Amount;
		end
	end;
end
-------------------------------------------------------------------------------
-- 아이템 강화
-------------------------------------------------------------------------------
function LobbyAction_UpgradeItem(dc, company, args)

	if company.LastLocation.LobbyType == 'Office' and (not StringToBool(company.WorkshopMenu.Opened, false) or not StringToBool(company.WorkshopMenu.Upgrade.Opened, false)) then
		LogAndPrint('company.WorkshopMenu.Opened - false');
		return {Success = false, Reward = {}, Level = 0};
	end
	
	local itemAddress = args.ItemAddress;
	local item;
	if itemAddress == 'Inventory' then
		local itemInstanceKey = args.BaseInvKey;
		item = GetInventoryItemByInstanceKey(company, itemInstanceKey);
	elseif itemAddress == 'Equipment' then
		local roster = GetRoster(company, args.Roster);
		if roster then
			item = GetRosterEquipItem(roster, args.EquipPosition);
		end
	end
	if item == nil then
		LogAndPrint('[Upgrade Failed] 대상 아이템을 찾지 못했다. company : ', company.name, ', : args : ', args);
		return {Success = false, Reward = {}, Level = 0};
	end
	
	-- 1. 강화 가능한지 여부 체크.
	local isEnable, reason = IsEnableUpgradeItem(item, LobbyInventoryItemCounter(company));
	if not isEnable then
		LogAndPrint('[Upgrade Failed] 아이템을 강화할 수 없다. company : ', company.name, ', item : ', item.name, ', reason : ', PackTableToStringReadable(reason));
		return {Success = false, Reward = {}, Level = 0};
	end
	
	-- 강화 레벨 올리기.
	local addLv = 1;
	local isLuckUse = false;
	local randomRate = 9 * (1 - item.Lv/item.MaxLv) + math.floor(company.Luck/2);
	if RandomTest(randomRate) then
		addLv = addLv + 1;
		if RandomTest(0.5 * randomRate) then
			addLv = addLv + 1;
		end
		isLuckUse = true;
	end
	addLv = math.min(item.MaxLv - item.Lv, addLv);
	dc:UpdateItemProperty(item, 'Lv', item.Lv + addLv);
	if isLuckUse then
		dc:UpdateCompanyProperty(company, 'Luck', 0);
	else
		dc:UpdateCompanyProperty(company, 'Luck', company.Luck + 1);
	end
	
	-- 2) 재료 뺏기.
	local materialList = GetItemUpgradeMaterial(item);
	local reward = {};
	for index, mt in ipairs (materialList) do
		dc:TakeItem(GetInventoryItemByType(company, mt.Item), mt.Amount);
		table.insert(reward, {ItemName = mt.Item, ItemCount = mt.Amount});
	end
	
	-- 재료 도감 오픈
	if company.Progress.Tutorial.ItemBook == 0 then
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/ItemBook', 1);
	end
	
	return { Success = true, Reward = reward, Level = addLv };
end
-------------------------------------------------------------------------------
-- 아이템 분해
-------------------------------------------------------------------------------
function LobbyAction_DismantleItem(dc, company, args)

	if company.LastLocation.LobbyType == 'Office' and (not StringToBool(company.WorkshopMenu.Opened, false) or not StringToBool(company.WorkshopMenu.Upgrade.Opened, false)) then
		LogAndPrint('company.WorkshopMenu.Opened - false');
		return {Success = false, Reward = {}};
	end
	
	local items = {};
	for _, itemData in ipairs(args.Items) do
		local itemAddress = itemData.ItemAddress;

		local item;
		if itemAddress == 'Inventory' then
			local itemInstanceKey = itemData.BaseInvKey;
			item = GetInventoryItemByInstanceKey(company, itemInstanceKey);
		--[[ 분해는 장비 안함
		elseif itemAddress == 'Equipment' then
			local roster = GetRoster(company, itemData.Roster);
			if roster then
				item = GetRosterEquipItem(roster, itemData.EquipPosition);
			end]]
		end
		if item == nil then
			LogAndPrint('[Dismantle Failed] 대상 아이템을 찾지 못했다. company : ', company.CompanyName, ', itemData : ', itemData);
			return {Success = false, Reward = {}};
		end
		
		-- 1. 분해 가능한지 여부 체크.
		local isEnable, reason = IsEnableDismantleItem(item);
		if not isEnable then
			LogAndPrint('[Dismantle Failed] 아이템을 강화할 수 없다. company : ', company.CompanyName, ', item : ', item.name, ', reason : ', PackTableToStringReadable(reason));
			return {Success = false, Reward = {}};
		end
		
		table.insert(items, item);
	end
	
	local reward = {};
	for _, item in ipairs(items) do
		-- 2. 분해 레벨 빼앗기.
		dc:TakeItem(item, 1);
			
		-- 3. 재료 주기.
		local materialList = GetItemDismantleResult(item);
		for index, mt in ipairs (materialList) do
			reward[mt.Item] = (reward[mt.Item] or 0) + mt.Amount;
		end
	end
	
	local rewardSum = {};
	for itemName, amount in pairs(reward) do
		dc:GiveItem(company, itemName, amount, true);
		table.insert(rewardSum, {ItemName = itemName, ItemCount = amount});
	end
	
	-- 재료 도감 오픈
	if company.Progress.Tutorial.ItemBook == 0 then
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/ItemBook', 1);
	end

	return { Success = true, Reward = rewardSum };
end
--------------------------------------------------------------------
-- 아이템 제작
-------------------------------------------------------------------
function LobbyAction_CraftItem(dc, company, args)
	if company.LastLocation.LobbyType == 'Office' and (not StringToBool(company.WorkshopMenu.Opened, false) or not StringToBool(company.WorkshopMenu.Upgrade.Opened, false)) then
		LogAndPrint('company.WorkshopMenu.Opened - false');
		return {Success = false, Reward = {}, Level = 0};
	end
	
	local recipeList = GetClassList('Recipe');
	local itemList = GetClassList('Item');
	
	local itemName = args.Item;
	local itemCount = args.Count;
	local recipe = recipeList[itemName];	
	local unlockRecipe = {};
	-- 1. 데이터 유효성 체크.
	if recipe == nil then
		LogAndPrint('[DataError] CraftItem/Cilent/requestForm/RecipeName not exit on Recipe.xml',itemName);
		return;
	end
	local item = itemList[recipe.name];
	if item == nil then
		LogAndPrint('[DataError] CraftItem/Cilent/requestForm/RecipeName not exit on item.xml',itemName, item);
		return;
	end	
	-- 2. 제작 가능한지 여부 체크.
	local roster = GetAllRoster(company);
	local enableCraft, reason = IsEnableCraftItem(company, roster, item, itemCount, LobbyInventoryItemCounter(company));
	if not enableCraft then
		for key, value in ipairs (reason) do
			LogAndPrint('[Carft Failed] reason - '..key..': '..value);
		end
		return {Success = false, Reward = {}, UnlockRecipe = unlockRecipe, Exp = 0 };
	end

	-- 3. 숙련도 + 오픈.
	local addExp = GetCraftExp(itemName, itemCount);
	
	-- 추가 숙련도 대상
	local extraRecipes = {};
	for _, r in pairs(company.Recipe) do
		if r.Opened and r.Category == recipe.Category and r.RequireLv <= recipe.RequireLv and r.Exp < r.MaxExp and r.name ~= recipe.name then
			table.insert(extraRecipes, r);
		end
	end
	
	local addExpInfos = {};
	table.insert(addExpInfos, { Recipe = company.Recipe[recipe.name], AddExp = addExp });
	-- 추가 숙련도 분배
	if #extraRecipes > 0 then
		-- 랜덤 후, 장비 착용 레벨 오름차순
		table.shuffle(extraRecipes);
		table.sort(extraRecipes, function (lhs, rhs) return itemList[lhs.name].RequireLv < itemList[rhs.name].RequireLv end);
	
		local extraTotalExp = math.floor(GetCraftExp(itemName, 1) * GetCraftExp_Additional(recipe, itemCount) / 100);
		local quotient = math.floor(extraTotalExp / #extraRecipes);
		local remainder = extraTotalExp - quotient * #extraRecipes;
		
		for i, r in ipairs(extraRecipes) do
			local extraExp = quotient + ((i <= remainder) and 1 or 0);
			table.insert(addExpInfos, { Recipe = r, AddExp = extraExp });
		end
	end
	
	-- 숙련도 + 오픈
	for _, info in ipairs(addExpInfos) do
		local recipe = info.Recipe;
		local addExp = info.AddExp;
		local maxExp = recipe.MaxExp;
		local curExp = recipe.Exp;
		if curExp < maxExp and #recipe.UnLockRecipe > 0 then		
			local dbKey = string.format('Recipe/%s/Exp', recipe.name);
			if addExp + curExp >= maxExp then
				dc:UpdateCompanyProperty(company, dbKey, maxExp);
				-- 레시피 언락하기.
				for i = 1, #recipe.UnLockRecipe do
					local curUnlockRecipeName = recipe.UnLockRecipe[i];
					local curUnlockRecipe = recipeList[curUnlockRecipeName];
					if curUnlockRecipe then
						table.insert(unlockRecipe, curUnlockRecipe.name);
						dc:UpdateCompanyProperty(company, string.format('Recipe/%s/Opened', curUnlockRecipeName), true);
						dc:UpdateCompanyProperty(company, string.format('Recipe/%s/IsNew', curUnlockRecipeName), true);
					end
				end
				addExp = maxExp - curExp;
			else
				dc:AddCompanyProperty(company, dbKey, addExp);
			end
		end
	end
	
	-- 4. 아이템 지급
	local reward = {};
	local materials = recipe.RequireMaterials;
	for i, material in ipairs(materials) do
		dc:TakeItem(GetInventoryItemByType(company, material.Item), material.Amount * itemCount);
		table.insert(reward, {ItemName = material.Item, ItemCount = material.Amount * itemCount});
	end
	dc:GiveItem(company, itemName, itemCount);
	
	-- 재료 도감 오픈
	if company.Progress.Tutorial.ItemBook == 0 then
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/ItemBook', 1);
	end
	
	return {Success = true, Reward = reward, UnlockRecipe = unlockRecipe, Exp = addExp };
end
-------------------------------------------------------------------------------
-- 아이템 추출
-------------------------------------------------------------------------------
function GetExtractMaterialResult(itemName, itemCount)
	local materialList = GetExtractMaterial(itemName);
	local rewardList = table.map(materialList, function(info)
		local itemAmount = 0;
		for i = 1, itemCount do
			local addAmount = 0;
			if info.MinAmount == info.MaxAmount then
				addAmount = info.MaxAmount;
			else
				local minAmount = info.MinAmount;
				if minAmount == 0 and math.random(1,100) <= 75 then
					minAmount = 1;
				end
				addAmount = math.random(minAmount, info.MaxAmount);
			end
			itemAmount = itemAmount + addAmount;
		end
		return { ItemName = info.Item, ItemCount = itemAmount };
	end);
	return rewardList;
end
function LobbyAction_ExtractItem(dc, company, args)
	if company.LastLocation.LobbyType == 'Office' and (not StringToBool(company.WorkshopMenu.Opened, false) or not StringToBool(company.WorkshopMenu.Upgrade.Opened, false)) then
		LogAndPrint('company.WorkshopMenu.Opened - false');
		return {Success = false, Reward = {}};
	end
	
	local itemInstanceKey = args.BaseInvKey;
	local itemCount = args.Count;
	
	local item = GetInventoryItemByInstanceKey(company, itemInstanceKey);
	if item == nil then
		LogAndPrint('[Extract Failed] 대상 아이템을 찾지 못했다. company : ', company.CompanyName, ', itemData : ', itemData);
		return {Success = false, Reward = {}};
	end
	
	-- 1. 추출 가능한지 여부 체크.
	local roster = GetAllRoster(company);
	local isEnable, reason = IsEnableExtractItem(company, roster, item, itemCount, LobbyInventoryItemCounter(company));
	if not isEnable then
		LogAndPrint('[Extract Failed] 아이템을 추출할 수 없다. company : ', company.CompanyName, ', item : ', item.name, ', reason : ', PackTableToStringReadable(reason));
		return {Success = false, Reward = {}};
	end

	-- 2. 추출 아이템 빼앗기.
	dc:TakeItem(item, itemCount);
	
	-- 3. 결과물 주기.
	local rewardList = GetExtractMaterialResult(item.name, itemCount);
	rewardList = table.filter(rewardList, function(info) return info.ItemCount > 0; end);
	
	for _, reward in ipairs(rewardList) do
		dc:GiveItem(company, reward.ItemName, reward.ItemCount, true);
	end
	
	-- 재료 도감 오픈
	if company.Progress.Tutorial.ItemBook == 0 then
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/ItemBook', 1);
	end

	return { Success = true, Reward = rewardList };
end
--------------------------------------------------------------------
-- 아이템 감정
-------------------------------------------------------------------
function LobbyAction_IdentifyItem(dc, company, args)
	if not company.Temporary.NpcDialogMode and not StringToBool(company.WorkshopMenu.Opened, false) then
		return {Success = false, LevelUp = false, Price = 0, FriendshipChange = 0};
	end

	local itemAddress = args.ItemAddress;
	local item;
	if itemAddress == 'Inventory' then
		local itemInstanceKey = args.BaseInvKey;
		item = GetInventoryItemByInstanceKey(company, itemInstanceKey);
	elseif itemAddress == 'Equipment' then
		local roster = GetRoster(company, args.Roster);
		if roster then
			item = GetRosterEquipItem(roster, args.EquipPosition);
		end
	end
	if item == nil then
		LogAndPrint('[Identify Failed] 대상 아이템을 찾지 못했다. company : ', company.name, ', : args : ', args);
		return {Success = false, LevelUp = false, Price = 0, FriendshipChange = 0};
	end
	
	-- 1. 추출 가능한지 여부 체크.
	local isEnableIdentify, reason = IsEnableIdentifyItem(item, company);
	if not isEnableIdentify then
		LogAndPrint('[Identify Failed] 아이템을 감정할 수 없다. company : ', company.name, ', item : ', item.name, ', reason : ', PackTableToStringReadable(reason));
		return {Success = false, LevelUp = false, Price = 0, FriendshipChange = 0};
	end
	
	-- 2. DB 저장용 정보
	local result = ExecuteIdentifyItem(dc, company, item);
	if not result then
		LogAndPrint('[Identify Failed] 아이템 감정에 실패했다. company : ', company.name, ', item : ', item.name);
		return {Success = false, LevelUp = false, Price = 0, FriendshipChange = 0};
	end
	
	
	
	local friendship = 'Neutral';
	local friendshipList = GetClassList('Friendship');
	local shopHost = GetCompanyInstantProperty(company, 'ShopHost');
	if shopHost then
		friendship = company.Npc[shopHost.name].Friendship;
	end	
	local curFriendship = friendshipList[friendship];
	local addFriendship = item.Rank.Weight - 1;
	
	-- 3. 비용 소모
	local consumePrice = GetIdentifyItemPrice(item, curFriendship, company.Reputation);
	dc:AddCompanyProperty(company, 'Vill', -1 * consumePrice);

	-- 4. 우호도.
	local priceFriendship = AddFriendshipByTradingPrice(dc, company, shopHost, consumePrice, {}, function() end);
	local _, _, addFriendship = UpdateFriendship(dc, company, 'Npc', shopHost.name, addFriendship);
	
	
	
	return {Success = true, LevelUp = false, Price = consumePrice, FriendshipChange = priceFriendship + addFriendship};
end
function LobbyAction_IdentifyItems(dc, company, args)
	if not company.Temporary.NpcDialogMode and not StringToBool(company.WorkshopMenu.Opened, false) then
		return {Success = false, LevelUp = false, Price = 0, FriendshipChange = 0};
	end
	
	local items = {};
	for _, itemData in ipairs(args.Items) do
		local itemAddress = itemData.ItemAddress;
		local item;
		if itemAddress == 'Inventory' then
			local itemInstanceKey = itemData.BaseInvKey;
			item = GetInventoryItemByInstanceKey(company, itemInstanceKey);
		elseif itemAddress == 'Equipment' then
			local roster = GetRoster(company, itemData.Roster);
			if roster then
				item = GetRosterEquipItem(roster, itemData.EquipPosition);
			end
		end
		if item == nil then
			LogAndPrint('[Identify Failed] 대상 아이템을 찾지 못했다. company : ', company.name, ', : itemData : ', itemData);
			return {Success = false, LevelUp = false, Price = 0, FriendshipChange = 0};
		end
		
		-- 1. 추출 가능한지 여부 체크.
		local isEnableIdentify, reason = IsEnableIdentifyItem(item, company);
		if not isEnableIdentify then
			LogAndPrint('[Identify Failed] 아이템을 감정할 수 없다. company : ', company.name, ', item : ', item.name, ', reason : ', PackTableToStringReadable(reason));
			return {Success = false, LevelUp = false, Price = 0, FriendshipChange = 0};
		end
		
		table.insert(items, item);
	end
	
	--2. 비용 소모.
	local totalPrice = 0;
	local totalAddFriendShip = 0;	
	local friendship = 'Neutral';
	local friendshipList = GetClassList('Friendship');
	local shopHost = GetCompanyInstantProperty(company, 'ShopHost');
	if shopHost then
		friendship = company.Npc[shopHost.name].Friendship;
	end	
	local curFriendship = friendshipList[friendship];
	for _, item in ipairs(items) do
		local consumePrice = GetIdentifyItemPrice(item, curFriendship, company.Reputation);
		local addFriendship = 1 + math.floor((item.Rank.Weight * math.random(1,3)) * 0.5);
		totalPrice = totalPrice + consumePrice;
		totalAddFriendShip = totalAddFriendShip + addFriendship;
	end
	if company.Vill < totalPrice then
		LogAndPrint('[Identify Failed] 돈이 부족하다. company : ', company.name, ', itemData : ', itemData, ', Vill : ', company.Vill, ', Price : ', totalPrice);
		return {Success = false, LevelUp = false, Price = 0, FriendshipChange = 0};
	end

	-- 2. DB 저장용 정보
	for _, item in ipairs(items) do
		local result = ExecuteIdentifyItem(dc, company, item);
		if not result then
			LogAndPrint('[Identify Failed] 아이템 감정에 실패했다. company : ', company.name, ', item : ', item.name);
			return {Success = false, LevelUp = false, Price = 0, FriendshipChange = 0};
		end
	end
	
	-- 3. 우호도.	
	if shopHost then
		_, _, totalAddFriendShip = UpdateFriendship(dc, company, 'Npc', shopHost.name, totalAddFriendShip);
	end
	-- 4. 비용 소모.
	dc:AddCompanyProperty(company, 'Vill', -1 * totalPrice);	
	return {Success = true, LevelUp = false, Price = totalPrice, FriendshipChange = totalAddFriendShip};
end
-------------------------------------------------------------------------------
-- 아이템 보호
-------------------------------------------------------------------------------
function LobbyAction_ProtectItem(dc, company, args)
	local itemAddress = args.ItemAddress;
	local item = nil;
	if itemAddress == 'Inventory' then
		local itemInstanceKey = args.BaseInvKey;
		item = GetInventoryItemByInstanceKey(company, itemInstanceKey);
	elseif itemAddress == 'Equipment' then
		-- 착용 중인 아이템으로 뭘 함...
	end
	if item == nil then
		LogAndPrint('[Protect Failed] 대상 아이템을 찾지 못했다. company : ', company.name, ', : args : ', args);
		return {Success = false};
	end

	dc:UpdateItemProperty(item, 'Protected', args.Protect);
	return { Success = true };
end
function LobbyAction_ProtectItems(dc, company, args)
	for _, info in ipairs(args.ProtectInfos) do
		local itemAddress = info.ItemAddress;
		local item = nil;
		if itemAddress == 'Inventory' then
			local itemInstanceKey = info.BaseInvKey;
			item = GetInventoryItemByInstanceKey(company, itemInstanceKey);
		elseif itemAddress == 'Equipment' then
			-- 착용 중인 아이템으로 뭘 함...
		end
		if item ~= nil then
			dc:UpdateItemProperty(item, 'Protected', info.Protect);
		end
	end
	return { Success = true };
end
-------------------------------------------------------------------------------
-- 치료?
-------------------------------------------------------------------------------
function LobbyAction_RequestCureRoster(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		return {Success = false};
	end
	
	-- 치료 가능 체크
	if not IsAbleToCure(company, roster) then
		return {Success = false};
	end
	
	-- 빈 슬롯 찾기
	local slotIndex = 0;
	for i = 1, company.MedicalCenter.SlotLimit do
		if company.MedicalCenter.Slot[i] == 'None' then
			slotIndex = i;
			break;
		end
	end
	local cost = GetCureCost(roster);
	
	dc:UpdateCompanyProperty(company, 'RP', company.RP - cost);
	dc:UpdateCompanyProperty(company, 'MedicalCenter/Slot/'..slotIndex, roster.name);
	dc:UpdatePCProperty(roster, 'NowCuring', true);
	
	return {Success = true};
end

function LobbyAction_RequestMaxCureRoster(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		return {Success = false};
	end
	
	-- 치료 가능 체크
	if not IsAbleToMaxCure(company, roster, LobbyInventoryItemCounter(company)) then
		return {Success = false};
	end
	
	local cureItem = GetInventoryItemByType(company, CONST_ITEM_TYPE_MaxCureRoster);
	assert(cureItem.Amount > 0);
	
	dc:TakeItem(cureItem, 1);
	dc:UpdatePCProperty(roster, 'ConditionState', 'Good');
	UpdateRosterConditionPoint(dc, roster, roster.MaxCP);
	
	return {Success = true};
end

function LobbyAction_CancelCureRoster(dc, company, args)
	local index = args.SlotIndex;
	local rosterType = company.MedicalCenter.Slot[index];
	if rosterType == 'None' then
		return {Success = false};
	end
	local roster = GetRoster(company, rosterType);
	if roster == nil then
		return {Success = false};
	end
	
	-- 비용은 필요한가... 없다고 가정
	
	-- 업데이트 전에 Roster의 CP를 현 상태 기준으로 한번 업데이트 쳐줌;
	InvalidateRosterConditionPoint(dc, roster);
	dc:UpdateCompanyProperty(company, 'MedicalCenter/Slot'..index, 'None');
	dc:UpdatePCProperty(roster, 'NowCuring', false);
	
	return {Success = true};
end

function LobbyAction_AddMastery(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('roster not exist');
		return {Success = false};
	end
	
	local masteryName = args.Mastery;
	local masteryTable = GetMastery(roster);
	
	local isEnable, reason = MasteryTrainingTest(roster, company, masteryTable, masteryName);
	if not isEnable then
		LogAndPrint('LobbyAction_AddMastery :', isEnable);
		for index, value in ipairs (reason) do
			LogAndPrint('reason'..index..': '..value);
		end
		return {Success = false};
	end
	
	-- 세트 마스터리 언락
	for _, setMastery in ipairs(GetClassList('Mastery')[masteryName].EnableSetMasteries) do
		local index = 1;
		local fullMastered = true;
		if not company.MasterySetIndex[setMastery.name] then
			repeat
				local m = GetWithoutError(setMastery, 'Mastery'..index);
				if m == nil then
					break;
				end
				
				if m ~= 'None' and m ~= masteryName and not GetMasteryMastered(masteryTable, m) then
					fullMastered = false;
					break;
				end
				index = index + 1;
			until false;
			
			if fullMastered then
				dc:UpdateCompanyProperty(company, 'MasterySetIndex/'..setMastery.name, true);
			end
		end
	end
	
	-- 1) 로스터 마스터리 장착
	dc:UpdateMasteryLv(roster, masteryName, 1);
	-- 2) 회사 마스터리 카운트 감소
	dc:LoseMastery(company, masteryName, 1);
	
	return {Success = true};
end

function LobbyAction_ExtractMastery(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('roster not exist');
		return {Success = false};
	end
	
	local masteryName = args.Mastery;
	local itemCounter = LobbyInventoryItemCounter(company);
	local masteryTable = GetMastery(roster);
	
	-- 추출 가능 여부 체크
	local isEnable, reason = MasteryExtractTest(roster, company, masteryTable, masteryName, itemCounter);
	if not isEnable then
		LogAndPrint('LobbyAction_ExtractMastery :', isEnable);
		for index, value in ipairs (reason) do
			LogAndPrint('reason'..index..': '..value);
		end
		return {Success = false};
	end
	
	local curMastery = masteryTable[masteryName];
	local extractItem = curMastery.ExtractItem;
	
	-- 1) 로스터 마스터리 레벨 초기화
	dc:UpdateMasteryLv(roster, masteryName, 0);
	-- 2) 회사 마스터리 카운트 증가
	dc:AcquireMastery(company, masteryName, 1, true);
	-- 3) 필요 아이템 소모
	if curMastery.Cost > 0 then
		dc:TakeItem(GetInventoryItemByType(company, extractItem), curMastery.Cost);
	end
	
	-- 4) 특성 해제로 사라지는 장착 슬롯에 착용 중인 아이템이 있으면 해제
	local unequipItemSlot = nil;
	if Set.new({'AlchemyBag', 'GrenadeBag', 'DoubleGear', 'Module_AuxiliaryWeapon', 'Module_AssistEquipment'})[masteryName] then
		unequipItemSlot = masteryName;
	end
	if unequipItemSlot then
		local unequipItem = GetWithoutError(roster.Object, unequipItemSlot);
		if unequipItem and unequipItem.name then
			dc:UnequipItem(roster, unequipItemSlot);
		end
	end
		
	return {Success = true};
end

function LobbyAction_ExtractMasteryAll(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('roster not exist');
		return {Success = false, Masteries = {}};
	end
	
	local itemCounter = LobbyInventoryItemCounter(company);
	local masteryTable = GetMastery(roster);
	
	-- 추출 가능 여부 체크
	local isEnable, reason, masteryList, needItemCount = MasteryExtractAllTest(roster, company, masteryTable, itemCounter);
	if not isEnable then
		LogAndPrint('LobbyAction_ExtractMasteryAll :', isEnable);
		for index, value in ipairs (reason) do
			LogAndPrint('reason'..index..': '..value);
		end
		return {Success = false, Masteries = {}};
	end
	
	-- 1) 로스터 마스터리 레벨 초기화
	for _, mastery in ipairs(masteryList) do
		dc:UpdateMasteryLv(roster, mastery.name, 0);
	end
	
	-- 2) 회사 마스터리 카운트 증가
	for _, mastery in ipairs(masteryList) do
		dc:AcquireMastery(company, mastery.name, 1, true);
	end
	
	-- 3) 필요 아이템 소모
	for extractItem, needCount in pairs(needItemCount) do
		if needCount > 0 then
			dc:TakeItem(GetInventoryItemByType(company, extractItem), needCount);
		end
	end
	
	-- 4) 특성 해제로 사라지는 장착 슬롯에 착용 중인 아이템이 있으면 해제
	local unequipItemSlots = {};
	local itemSlotExtentions = Set.new({'AlchemyBag', 'GrenadeBag', 'DoubleGear', 'Module_AuxiliaryWeapon', 'Module_AssistEquipment'});
	for _, mastery in ipairs(masteryList) do
		if itemSlotExtentions[mastery.name] then
			table.insert(unequipItemSlots, mastery.name);
		end
	end
	for _, unequipItemSlot in ipairs(unequipItemSlots) do
		local unequipItem = GetWithoutError(roster.Object, unequipItemSlot);
		if unequipItem and unequipItem.name then
			dc:UnequipItem(roster, unequipItemSlot);
		end
	end
	
	local masteries = table.map(masteryList, function(mastery) return mastery.name end);
	return {Success = true, Masteries = masteries};
end

function LobbyAction_AddMasterySet(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('AddMasterySet - roster not exist', company.CompanyName, args.Roster);
		return {Success = false, Masteries = {}};
	end
	
	local masteryName = args.Mastery;
	local mastery = GetClassList('Mastery')[masteryName];
	local curMasterySetList = GetMasterySetList(mastery);
	if #curMasterySetList == 0 then
		LogAndPrint('AddMasterySet - masterySet not exist', masteryName);
		return {Success = false, Masteries = {}};
	end
	
	local masteryTable = GetMastery(roster);
	local mbm = MasteryBoardManager.new(roster, masteryTable);

	local prevSetMap = {};
	for _, m in ipairs(mbm:getMasteryByCategory('Set')) do
		prevSetMap[m.name] = true;
	end
	
	local isEnable = true;
	local addMasteryList = {};
	for _, subMastery in ipairs(curMasterySetList) do
		local subMasteryName = subMastery.name;
		if not mbm:hasMastery(subMasteryName) then
			if not mbm:isEnableAddMastery(subMasteryName) then
				isEnable = false;
				break;
			end
			mbm:addMastery(subMasteryName, true);
			table.insert(addMasteryList, subMasteryName);
		end
	end
	if not mbm:isValid() then
		isEnable = false;
	end
	if not isEnable then
		return {Success = false, Masteries = {}};
	end
	
	for _, masteryName in ipairs(addMasteryList) do
		if company.Mastery[masteryName].Amount <= 0 then
			return {Success = false, Masteries = {}};
		end
	end
	
	local newSetList = {};
	for _, m in ipairs(mbm:getMasteryByCategory('Set')) do
		if not prevSetMap[m.name] then
			table.insert(newSetList, m.name);
		end
	end
	
	for _, masteryName in ipairs(addMasteryList) do
		-- 1) 로스터 마스터리 장착
		dc:UpdateMasteryLv(roster, masteryName, 1);
		-- 2) 회사 마스터리 카운트 감소
		dc:LoseMastery(company, masteryName, 1);
	end
	
	-- 3) 세트 마스터리 언락
	for _, masteryName in ipairs(newSetList) do
		if not company.MasterySetIndex[masteryName] then
			dc:UpdateCompanyProperty(company, 'MasterySetIndex/'..masteryName, true);
		end
	end
	
	return {Success = true, Masteries = addMasteryList};
end

function LobbyAction_TroublemakerReward(dc, company, args)
	local monName = args.MonName;
	local mon = GetClassList('Monster', monName);
	if mon == nil then
		LogAndPrint(string.format('monster.xml %s not exist', monName));
		return {Success = false, Reward = {}, UnlockTechList = {}};
	end
	-- 보상 받을 여부.
	local isEnable, rewardItem, reason, unlockTechList, unlockRecipeList = TroublemakerRewardTest(company, monName);
	if not isEnable then
		LogAndPrint('LobbyAction_TroublemakerReward :', isEnable);
		for index, value in ipairs (reason) do
			LogAndPrint('reason'..index..': '..value);
		end
		return {Success = false, Reward = {}, UnlockTechList = {}};
	end
	local reward = {};
	if not company.Troublemaker[monName].Reward then
		-- 1) 보상완료 프로퍼티 갱신
		dc:UpdateCompanyProperty(company, string.format('Troublemaker/%s/Reward', monName), true);
		-- 2) 보상아이템 주기.
		dc:GiveItem(company, rewardItem, 1, true, '_INV_FULL_TROUBLEMAKER_REWARD_');
		reward = {Type = rewardItem, Count = 1};
	end
	-- 3) 특성 연구 언락
	for _, techName in ipairs(unlockTechList) do
		dc:UpdateCompanyProperty(company, string.format('Technique/%s/Opened', techName), true);
		dc:UpdateCompanyProperty(company, string.format('Technique/%s/IsNew', techName), true);
	end
	-- 4) 레시피 언락
	if unlockRecipeList then
		for _, recipeName in ipairs(unlockRecipeList) do
			dc:UpdateCompanyProperty(company, string.format('Recipe/%s/Opened', recipeName), true);
			dc:UpdateCompanyProperty(company, string.format('Recipe/%s/IsNew', recipeName), true);
		end
	end
	return {Success = true, Reward = reward, UnlockTechList = unlockTechList, UnlockRecipeList = unlockRecipeList};
end
function RequestLobbyActionCommon(dc, company, requestType, args)
	local f = _G['LobbyAction_' .. requestType];
	if f == nil then
		return {Success = false};
	end
	local bt = os.clock();
--	LogAndPrintDev(requestType, args);
	local response = f(dc, company, args);
	if response.Success then
		response.Success = dc:Commit('LobbyAction:'..requestType);
	else
		dc:Cancel();
	end
	local dt = os.clock() - bt;
	local name = requestType;
	if requestType == 'ShopAction' then
		name = string.format('%s:%s', name, args.Action);
	end
	local etc = '';
	if requestType == 'DismantleItem' then
		etc = tostring(#args.Items);
	elseif requestType == 'CraftItem' then
		etc = tostring(args.Count);
	elseif requestType == 'ShopAction' then
		local count = 0;
		for _, v in pairs(args.Cart) do
			count = count + v;
		end
		etc = tostring(count);
	end
	LogAndPrint('RequestLobbyActionCommon', name, dt, company.CompanyName, etc, args);
--	print('RequestLobbyActionCommon', PackTableToString(response));
	return response;
end
------------------------------------------------------
-- 리더 교체
------------------------------------------------------
function LobbyAction_LeaderChange(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('Roster is nil!');
		return {Success = false};
	end
	return {Success = true};
end
------------------------------------------------------
-- 회사 특성 교체.
------------------------------------------------------
function LobbyAction_ChangeCompnayMastery(dc, company, args)
	local companyMasteryName = args.Mastery;
	if companyMasteryName == nil then
		LogAndPrint('LobbyAction_ChangeCompnayMastery : CompanyMasteryName is nil!');
		return {Success = false};
	end
	local isEnable, vill, reason = IsEnableCahngeCompanyMastery(company, companyMasteryName);
	if not isEnable then
		LogAndPrint('\n[companyMastery Failed] company : ', company.name, ', companyMasteryName : ', companyMasteryName);
		for index, reason in ipairs (reason) do
			LogAndPrint('\nReason:', reason);
		end
		return {Success = false};
	end
	
	-- 회사 특성 바꿔줄게.
	dc:UpdateCompanyProperty(company, 'CompanyMastery', companyMasteryName);	
	dc:AddCompanyProperty(company, 'Vill', -1 * vill);
	return {Success = true};
end
------------------------------------------------------
-- 회사 이름 변경.
------------------------------------------------------
function LobbyAction_ChangeCompanyName(dc, company, args)
	local companyName = args.CompanyName;
	if companyName == nil then
		LogAndPrint('LobbyAction_ChangeCompanyName : companyName is nil!');
		return {Success = false};
	end
	if not ChangeNameTimeTest(company) then
		LogAndPrint('LobbyAction_ChangeCompanyName : not available time  - LastTime : ', company.LastNameChangeTime, ', - os.time : ', os.time());	
		return {Success = false};
	end
	local isEnable, vill, reasons = IsEnableChangeCompanyName(company, companyName);
	if not isEnable then
		LogAndPrint('LobbyAction_ChangeCompanyName : companyName is invalid : ', companyName);
		for index, reason in ipairs(reasons) do
			LogAndPrint('\n - reason:', reason);
		end
		return {Success = false};
	end
	
	-- 회사 이름 바꿔줄게.
	dc:UpdateCompanyName(company, companyName);
	dc:AddCompanyProperty(company, 'Vill', -1 * vill);
	dc:UpdateCompanyProperty(company, 'LastNameChangeTime', os.time());
	dc:UpdateCompanyProperty(company, 'InvalidCompanyName', '');
	return {Success = true};
end
------------------------------------------------------
-- 개인 특성 교체.
------------------------------------------------------
function LobbyAction_ChangeCharacterMastery(dc, company, args)
	local characterMasteryName = args.Mastery;
	if characterMasteryName == nil then
		LogAndPrint('LobbyAction_ChangeCharacterMastery : characterMasteryName is nil!');
		return {Success = false};
	end
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_ChangeCharacterMastery : roster is nil!');
		return {Success = false};
	end
	local itemCounter = LobbyInventoryItemCounter(company);
	local isEnable, trainingManual, reason;
	if roster.RosterType == 'Pc' then
		isEnable, trainingManual, reason = IsEnableChangeCharacterMastery(roster, characterMasteryName, itemCounter);
	elseif roster.RosterType == 'Beast' then
		isEnable, trainingManual, reason = IsEnableChangeCharacterMastery_Beast(roster, characterMasteryName, itemCounter);
	elseif roster.RosterType == 'Machine' then
		isEnable, trainingManual, reason = IsEnableChangeCharacterMastery_Machine(roster, characterMasteryName, itemCounter);
	end
	if not isEnable then
		LogAndPrint('\n[characterMastery Failed] character : ', args.Roster, ', characterMasteryName : ', characterMasteryName);
		for index, reason in ipairs (reason) do
			LogAndPrint('\nReason:', reason);
		end
		return {Success = false};
	end
	
	-- 1) 개인 특성 바꿔줄게.
	if roster.RosterType == 'Pc' then
		dc:UpdatePCProperty(roster, 'BasicMastery', characterMasteryName);
	elseif roster.RosterType == 'Beast' then
		local propName = string.format('EvolutionMastery%d', roster.BeastType.EvolutionStage);
		dc:UpdatePCProperty(roster, propName, characterMasteryName);
	elseif roster.RosterType == 'Machine' then
		local propName = string.format('AIUpgradeMastery%d', roster.AIUpgradeStage-1);
		dc:UpdatePCProperty(roster, propName, characterMasteryName);
	end
	-- 2) 비용 소모
	local needItem = 'Statement_Mastery';
	if roster.RosterType == 'Machine' then
		needItem = 'Statement_Module';
	end
	dc:TakeItem(GetInventoryItemByType(company, needItem), trainingManual);
	
	-- 3) 개인 특성 변경으로 특성판의 일부가 해제되는 처리
	local extractMasteries = args.ExtractMasteries or {};
	
	local masteryList = GetClassList('Mastery');
	local extractNeedCount = 0;	
	for _, masteryName in ipairs(extractMasteries) do
		local mastery = masteryList[masteryName];
		if mastery and mastery.ExtractItem ~= 'None' then
			extractNeedCount = extractNeedCount + mastery.Cost;
		end
	end
	if extractNeedCount > 0 and itemCounter(needItem) < trainingManual + extractNeedCount then
		LogAndPrint('LobbyAction_ChangeCharacterMastery : item is not enough!', itemCounter(needItem), extractNeedCount);
		return {Success = false, Item = '', Count = 0};
	end
	-- 3-1) 특성판 특성 해제
	for _, masteryName in ipairs(extractMasteries) do
		local mastery = masteryList[masteryName];
		if mastery and mastery.ExtractItem ~= 'None' then
			-- 3-1-1) 로스터 마스터리 레벨 초기화
			dc:UpdateMasteryLv(roster, masteryName, 0, boardIndex);
			-- 3-1-2) 회사 마스터리 카운트 증가
			dc:AcquireMastery(company, masteryName, 1, true);
		end
	end
	-- 3-2) 필요 아이템 소모
	if extractNeedCount > 0 then
		dc:TakeItem(GetInventoryItemByType(company, needItem), extractNeedCount);
	end
	-- 3-3) 특성 해제로 사라지는 장착 슬롯에 착용 중인 아이템이 있으면 해제
	local unequipItemSlotList = {};
	local itemSlotExtentions = Set.new({'AlchemyBag', 'GrenadeBag', 'DoubleGear', 'Module_AuxiliaryWeapon', 'Module_AssistEquipment'});
	for _, masteryName in ipairs(extractMasteries) do
		if itemSlotExtentions[masteryName] then
			table.insert(unequipItemSlotList, masteryName);
		end
	end
	for _, unequipItemSlot in ipairs(unequipItemSlotList) do
		local unequipItem = GetWithoutError(roster.Object, unequipItemSlot);
		if unequipItem and unequipItem.name  then
			dc:UnequipItem(roster, unequipItemSlot);
		end
	end	
	
	return {Success = true, Roster = roster.RosterKey, Mastery = characterMasteryName, Item = needItem, Count = trainingManual + extractNeedCount};
end
------------------------------------------------------
-- 오피스 교체
------------------------------------------------------
function LobbyAction_OfficeChange(dc, company, args)
	-- 
	return {Success = true};
end

function LobbyAction_QueryZoneState(dc, company, args)
	local zoneCls = GetClassList('Zone')[args.ZoneType];
	if not CanEnterArea(company, zoneCls) then
		SendNotification(company, 'RestrictedArea', args.ZoneType);
		return;
	end
	local slotInfos = GetZoneEventSlotCompany(company, args.ZoneType);
	SubscribeZoneEventSlotChanged(company, args.ZoneType);
	
	local questInfos = GetQuestEventSlotCompany(company, args.ZoneType);
	
	local zoneState = GetWorldProperty().ZoneState;
	if IsSingleplayMode() then
		zoneState = company.ZoneState;
	end
	local zoneProperty = zoneState[args.ZoneType];
	
	return {QuestInfos = questInfos, SlotInfos = slotInfos, SafetyRatio = zoneProperty.Safty / zoneProperty.MaxSafty};
end
function LobbyAction_UnlinkZoneEventSubscription(dc, company, args)
	UnlinkZoneEventSubscription(company);
	return {};
end
function LobbyAction_CompleteQuest(dc, company, args)
	local questName = args.Quest;
	local questList = GetClassList('Quest');
	local quest = questList[questName];
	local questCheck = SafeIndex(quest, 'name');
	local success = false;
	local rewardInfo = {};
	
	if questCheck == nil then
		LogAndPrint('[Error] CompleteQuest - Quest not exist');
		return {Success = success, Reward = rewardInfo};
	end
	-- 퀘스트 완료 시키자.	
	success, rewardInfo = RequestCompleteQuest(dc, company, quest, nil);
	if not rewardInfo then
		return {Success = success, Reward = {}};
	end
	return {Success = success, Reward = rewardInfo};	
end
function LobbyAction_NotifyMailOpened(dc, company, args)
	local successList = SetMailOpened(company, args.MailIdList);
	return {Success = true, MailIdList = successList};
end

function LobbyAction_RequestActivityReward(dc, company, args)	
	if not ActivityReportTimeTest(company) then
		return {Success = false, Reward = {}, RemainTime = 0};
	end
	
	local vill = 0;
	local items = {};
	local masteries = {};
	-- 1. 기본 보상
	vill = vill + company.CurrentReward;
	
	-- 2. 평판 기본보상 + 특수보상
	for i, division in ipairs(GetClassList('Zone')[company.CurrentZone].Division) do
		local specialRewardCleared = true;
		for j, section in ipairs(division.Section) do
			local reputation = company.Reputation[section.Type];
			if reputation.Opened and reputation.Lv > 0 then
				local lv = math.min(reputation.MaxLv, reputation.Lv);
				vill = vill + reputation.Reward[lv].Vill;
			end
			if reputation.Lv < reputation.MaxLv then
				specialRewardCleared = false;
			end
		end
		if specialRewardCleared then
			local specialReward = division.Reward[company.ActivityReport.SpecialRewardIndex[i]];
			if specialReward ~= nil then
				if specialReward.Type == 'Item' then
					table.insert(items, {Type = specialReward.Value, Count = 1});
				elseif specialReward.Type == 'Vill' then
					vill = vill + specialReward.Value;
				elseif specialReward.Type == 'Mastery' then
					table.insert(masteries, {Type = specialReward.Value, Count = 1});
				end
			end
		end
	end
	
	-- 3. 기기본 보상
	vill = math.floor(vill + company.Grade.BaseReward);
	
	-- 4. 보상 지급
	dc:AddCompanyProperty(company, 'Vill', vill);
	for i, item in ipairs(items) do
		dc:GiveItemMail(company, item.Type, item.Count, '_INV_FULL_ACTIVITY_REPORT_');
	end
	for j, mastery in ipairs(masteries) do
		dc:AcquireMastery(company, mastery.Type, mastery.Count);
	end
	
	-- 5. 보상 시간 갱신
	dc:UpdateCompanyProperty(company, 'LastActivityReportTime', os.time());
	
	-- 6. 초기화
	ResetActivityReport(dc, company);
	
	-- 7. 강제갱신 프로퍼티 초기화
	dc:UpdateCompanyProperty(company, 'Progress/Tutorial/ForceActivityReport', false);

	return {Success = true, Reward = {Vill=vill, Items=items, Masteries =masteries}, RemainTime = 0};
end

function LobbyAction_InvokeClientEvent(dc, company, args)
	local handlerFunc = _G['LobbyClientEvent_' .. (args.EventType or 'None')];
	if handlerFunc == nil then
		return {Success = false};
	end
	
	return {Success = handlerFunc(company)}
end

function LobbyAction_OpenAllowDivision(dc, company, args)
	local section = company.Reputation[args.SectionName];
	if not section or section.Opened then
		return {Success = false};
	end
	
	local isEnable = IsEnableOpenAllowDivision(company, section);
	if not isEnable then
		return {Success = false};
	end
	
	-- 1. 비용 소모
	local openCost = section.Cost;
	dc:AddCompanyProperty(company, 'Vill', -openCost, 0);
	
	-- 2. 지역 오픈
	dc:UpdateCompanyProperty(company, string.format('Reputation/%s/Opened', args.SectionName), true);
	SendNotification(company, 'OpenAllowDivision', { Section = args.SectionName, Vill = openCost } );
	return {Success = true};
end

function LobbyAction_CloseAllowDivision(dc, company, args)
	local section = company.Reputation[args.SectionName];
	if not section or not section.Opened then
		return {Success = false};
	end
	
	local isEnable = IsEnableCloseAllowDivision(company, section);
	if not isEnable then
		return {Success = false};
	end
	
	-- 1. 지역 해제
	dc:UpdateCompanyProperty(company, string.format('Reputation/%s/Opened', args.SectionName), false);
	SendNotification(company, 'CloseAllowDivision', { Section = args.SectionName } );
	return {Success = true};
end

function LobbyAction_ChangeAllowDivisionBonus(dc, company, args)
	local sectionBonus = args.SectionBonus;
	for _, info in ipairs(sectionBonus) do
		(function()
			local section = company.Reputation[info.SectionName];
			if not section or not section.Opened then
				return;
			end
			local bonusIndex = info.BonusIndex;
			if bonusIndex < 1
				or bonusIndex > #section.Bonus then
				return;
			end			
			-- 1. 보너스 변경
			if bonusIndex ~= section.BonusIndex then
				dc:UpdateCompanyProperty(company, string.format('Reputation/%s/BonusIndex', info.SectionName), bonusIndex);
			end
		end)();
	end	
	return {Success = true};
end

function LobbyAction_NewItemConfirmed(dc, company, args)
	local items = table.map(args.Items, function (itemKey) return GetInventoryItemByInstanceKey(company, itemKey) end);
	
	if args.Delayed then
		PreserveNewItemConfirm(company, items);
		return {Success = true};
	end
	
	for i, item in ipairs(items) do
		dc:UpdateItemProperty(item, 'IsNew', false);
	end
	return {Success = true};
end
function LobbyAction_NewMasteryConfirmed(dc, company, args)
	local masteries = args.Masteries;
	for i, masteryName in ipairs(masteries) do
		dc:UpdateCompanyProperty(company, string.format('Mastery/%s/IsNew', masteryName), false);
	end
	return {Success = true};
end
function LobbyAction_NewRosterConfirmed(dc, company, args)
	local rosters = args.Rosters;
	for i, pcName in ipairs(rosters) do
		local roster = GetRoster(company, pcName);
		if roster and roster.name ~= nil then
			dc:UpdatePCProperty(roster, 'IsNew', false);
		end
	end
	return {Success = true};
end
function LobbyAction_NewQuestConfirmed(dc, company, args)
	for i, questType in ipairs(args.Quests) do
		dc:UpdateQuestProperty(company, questType, 'IsNew', false);
	end
	return {Success = true};
end
function LobbyAction_NewCompanyMasteryConfirmed(dc, company, args)
	local masteries = args.Masteries;
	for i, masteryName in ipairs(masteries) do
		dc:UpdateCompanyProperty(company, string.format('CompanyMasteries/%s/IsNew', masteryName), false);
	end
	return {Success = true};
end
function LobbyAction_NewTroublemakerConfirmed(dc, company, args)
	local troublemaker = args.Troublemaker;
	dc:UpdateCompanyProperty(company, string.format('Troublemaker/%s/IsNew', troublemaker), false);
	return {Success = true};
end
function LobbyAction_NewTroublemakersConfirmed(dc, company, args)
	local troublemakers = args.Troublemakers;
	for i, troublemaker in ipairs(troublemakers) do
		dc:UpdateCompanyProperty(company, string.format('Troublemaker/%s/IsNew', troublemaker), false);
	end
	return {Success = true};
end
function LobbyAction_NewTechniqueConfirmed(dc, company, args)
	local techniques = args.Techniques;
	for i, techniqueName in ipairs(techniques) do
		dc:UpdateCompanyProperty(company, string.format('Technique/%s/IsNew', techniqueName), false);
	end
	return {Success = true};
end
function LobbyAction_NewTroubleBookConfirmed(dc, company, args)
	local episode = args.Episode;
	if company.Troublebook[episode].IsNew then
		dc:UpdateCompanyProperty(company, string.format('Troublebook/%s/IsNew', episode), false);
		return {Success = true};
	else
		return {Success = false};
	end
end
function LobbyAction_NewTroubleBookNoticed(dc, company, args)
	local episodes = args.Episodes;
	for i, episode in ipairs(episodes) do
		if not company.Troublebook[episode].Noticed then
			dc:UpdateCompanyProperty(company, string.format('Troublebook/%s/Noticed', episode), true);
		end
	end
	return {Success = true};
end
function LobbyAction_NewScenarioSlotConfirmed(dc, company, args)
	local zoneEvents = args.ZoneEvents;
	for i, zoneEvent in ipairs(zoneEvents) do
		if company.IsNewZoneEvent[zoneEvent] then
			dc:UpdateCompanyProperty(company, string.format('IsNewZoneEvent/%s', zoneEvent), false);
		end
	end
	return {Success = true};
end
function LobbyAction_NewRecipeConfirmed(dc, company, args)
	local recipes = args.Recipes;
	for i, recipeName in ipairs(recipes) do
		dc:UpdateCompanyProperty(company, string.format('Recipe/%s/IsNew', recipeName), false);
	end
	return {Success = true};
end
-- 활동보고 초기화
function ResetActivityReport(dc, company)
	-- 평판 외곽 지구 보너스
	local outsideAreaBonus = GetDivisionTypeBonusValue(company.Reputation, 'Area_Outside');
	
	-- 활동 보고서 초기화
	-- 1. 기본 보상 초기화
	dc:UpdateCompanyProperty(company, 'CurrentReward', 0);
	
	local typeSet = {};
	local divisionSet = {};
	local openedSet = {};
	for _, info in ipairs(company.ActivityReport.History) do
		if info.Section ~= 'None' then
			local section = company.Reputation[info.Section];
			if info.Reputation > 0 then
				typeSet[section.Type.name] = true;
				divisionSet[section.Division.name] = true;
			end
			if section.Opened then
				openedSet[section.name] = true;
			end
		end
	end
	
	-- 2. 평판 감소
	for i, division in ipairs(GetClassList('Zone')[company.CurrentZone].Division) do
		for j, section in ipairs(division.Section) do
			local reputation = company.Reputation[section.Type];
			local addLv = 0;
			if not typeSet[reputation.Type.name] then
				addLv = addLv - 10;
			end
			if not divisionSet[reputation.Division.name] then
				addLv = addLv - 10;
			end
			if reputation.Opened and not openedSet[section.Type] then
				addLv = addLv - 10;
			end
			if outsideAreaBonus > 0 then
				addLv = math.floor(addLv * (1 + outsideAreaBonus / 100));
			end
			local nextLv = math.clamp(reputation.Lv + addLv, 0, reputation.MaxLv);
			if nextLv ~= reputation.Lv then
				dc:UpdateCompanyProperty(company, string.format('Reputation/%s/Lv', section.Type), nextLv);
				dc:UpdateCompanyProperty(company, string.format('Reputation/%s/PrevLv', section.Type), reputation.NextLv);
				dc:UpdateCompanyProperty(company, string.format('Reputation/%s/NextLv', section.Type), nextLv);
			end
		end
	end
	
	-- 3. 활동 기록 초기화
	for missionType, activity in pairs(company.ActivityReport.Activities) do
		dc:UpdateCompanyProperty(company, string.format('ActivityReport/Activities/%s/Clear', missionType), 0);
	end
	for i, info in ipairs(company.ActivityReport.History) do
		if info.Section ~= 'None' then
			dc:UpdateCompanyProperty(company, string.format('ActivityReport/History/%d/Section', i), 'None');
			if info.Reputation > 0 then
				dc:UpdateCompanyProperty(company, string.format('ActivityReport/History/%d/Reputation', i), 0);
			end
			if info.EnoughSupport > 0 then
				dc:UpdateCompanyProperty(company, string.format('ActivityReport/History/%d/EnoughSupport', i), 0);
			end
			if info.FieldControlSection ~= 'None' then
				dc:UpdateCompanyProperty(company, string.format('ActivityReport/History/%d/FieldControlSection', i), 'None');
			end
			if info.FieldControlMission ~= 'None' then
				dc:UpdateCompanyProperty(company, string.format('ActivityReport/History/%d/FieldControlMission', i), 'None');
			end
		end
	end
	for sectionName, bonusCount in pairs(company.ActivityReport.ReputationBonus) do
		for i, count in ipairs(bonusCount) do
			if count > 0 then
				dc:UpdateCompanyProperty(company, string.format('ActivityReport/ReputationBonus/%s/%d', sectionName, i), 0);
			end
		end
	end
	
	-- 4. 반복 퀘스트 회수 제한 초기화
	local questClsList = GetClassList('Quest');
	for questType, questCls in pairs(questClsList) do
		if questCls.Group == 'Repeat' and questCls.RepeatLimit > 0 then
			local curState, progress = GetQuestState(company, questType);
			if progress.RepeatCount and progress.RepeatCount > 0 then
				dc:UpdateQuestProperty(company, questType, 'RepeatCount', 0);
			end
		end
	end
end
-------------------------------------------------------------------------
-- 트러블북 보상받기.
-------------------------------------------------------------------------
function LobbyAction_TroublebookReward(dc, company, args)
	
	local troublebookQuestList = GetClassList('TroublebookQuest');
	
	local questName = args.Quest;
	local troublebookQuest = company.TroublebookQuest[questName];
	if troublebookQuest == nil then
		return {Success = false, Reward ={}};
	end
	local isEnableReward, reason = IsEnableTroublebookReward(company, troublebookQuest, questName);
	if not isEnableReward then
		LogAndPrint('\n=== TroublebookReward Fail Reason ===');
		table.print(reason);
		LogAndPrint('\n=====================================\n');
		return {Success = false, Reward ={}};
	end
	-- 보상 주기.
	local itemList = GetClassList('Item');
	local masteryList = GetClassList('Mastery');
	local curTroublebook = troublebookQuestList[troublebookQuest.name];
	local rewardList = curTroublebook.Rewards

	-- 1. 트러블북 보상 받았다 변경.
	dc:UpdateCompanyProperty(company, string.format('TroublebookQuest/%s/Rewarded', troublebookQuest.name), true);
	
	-- 2. 보상 주기.
	local list = {}
	for index, reward in ipairs (rewardList) do
		if reward.Type == 'Item' then
			local curItem  = itemList[reward.TypeValue];
			if curItem and curItem.name ~= nil then
				dc:GiveItem(company, curItem.name, reward.Value, true);
			end			
		elseif reward.Type == 'Mastery' then
			local curMastery  = masteryList[reward.TypeValue];
			if curMastery and curMastery.name ~= nil then
				dc:AcquireMastery(company, curMastery.name, reward.Value, true);
			end
		elseif reward.Type == 'CompanyMastery' then
			local curMastery  = masteryList[reward.TypeValue];
			if curMastery and curMastery.name ~= nil then
				dc:UpdateCompanyProperty(company, string.format('CompanyMasteries/%s/Opened', curMastery.name), true);
			end
		end
		table.insert(list, ClassToTable(reward));
	end
	return {Success = true, Reward = list};
end

function LobbyAction_UpdateDifficulty(dc, company, args)
	local gameDifficultyClsList = GetClassList('GameDifficulty');
	if gameDifficultyClsList[args.Difficulty] == nil then
		return {Success = false};
	end
	dc:UpdateCompanyProperty(company, 'GameDifficulty', args.Difficulty);
	return {Success = true};
end

function LobbyAction_MasteryPopupConfirmed(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if not roster then
		return {Success = false};
	end
	
	dc:UpdatePCProperty(roster, 'MasteryPopupMessage', '');
	return {Success = true};
end

function OnUpdateWorldProperty_Lobby(keys, commitType)
	if commitType == 'ShopItemUpdate' then
		local allUser = GetAllUsers();	-- user == company
		for i, user in ipairs(allUser) do
			local shopOpened = GetCompanyInstantProperty(user, 'ShopOpened');
			if shopOpened then
				SendNotification(user, 'RefreshShopUI', {});
			end
		end
	elseif commitType == 'SafetyFeverStart' then
		if IsSingleplayMode() then
			return;
		end
		local worldProperty = GetWorldProperty();
		local lobbyDefClsList = GetClassList('LobbyWorldDefinition');
		local allUser = GetAllUsers();
		for _, key in ipairs(keys) do
			local zone = string.match(key, '^ZoneState/([%d%s%w]+)/SafetyFever$');
			if zone then
				local feverTime = SafeIndex(worldProperty, 'ZoneState', zone, 'FeverTime');
				for _, user in ipairs(allUser) do
					if lobbyDefClsList[GetUserLocation(user)].Zone.name == zone then
						SendSystemNotice(user, 'SafetyFeverStart', {ZoneName=zone, OffsetTime = feverTime + GetSystemConstant('ZONE_SAFETY_FEVER_DURATION'), SafetyFeverHour = GetSystemConstant('ZONE_SAFETY_FEVER_DURATION') / 3600, LeftMissionCount = user.ActivityReportDuration - user.ActivityReportCounter});
					end
				end
			end
		end
	elseif commitType == 'SafetyFeverEnd' then
		if IsSingleplayMode() then
			return;
		end
		local lobbyDefClsList = GetClassList('LobbyWorldDefinition');
		local allUser = GetAllUsers();
		for _, key in ipairs(keys) do
			local zone = string.match(key, '^ZoneState/([%d%s%w]+)/SafetyFever$');
			if zone then
				for _, user in ipairs(allUser) do
					if lobbyDefClsList[GetUserLocation(user)].Zone.name == zone then
						SendSystemNotice(user, 'SafetyFeverEnd', {ZoneName=zone});
					end
				end
			end
		end
	end
end

function GetCurrencyAmount(company, currencyCls)
	if currencyCls.Source == 'Property' then
		return SafeIndex(company, unpack(string.split(currencyCls.Target, '/')));
	elseif currencyCls.Source == 'Item' then
		local item = GetInventoryItemByType(company, currencyCls.Target);
		if item == nil then
			return 0;
		else
			return item.Amount;
		end
	end
end
function UpdateCurrencyAmount(dc, company, currencyCls, changeAmount)
	if currencyCls.Source == 'Property' then
		dc:AddCompanyProperty(company, currencyCls.Target, changeAmount);
	elseif currencyCls.Source == 'Item' then
		if changeAmount > 0 then
			dc:GiveItem(company, currencyCls.Target, changeAmount);
		elseif changeAmount < 0 then
			local item = GetInventoryItemByType(company, currencyCls.Target);
			dc:TakeItem(item, - changeAmount);
		end
	end
end

function AddFriendshipByTradingPrice(dc, company, shopHost, totalPrice, response, onFriendshipChanged)
	local addFriendship = 0;
	local FriendshipHurdle = 500;
	local prevLeftPoint = company.Npc[shopHost.name].FriendshipPoint_Sub;
	local accumulatedPrice = totalPrice + prevLeftPoint;
	if accumulatedPrice >= FriendshipHurdle then
		local pureAdd = math.floor(accumulatedPrice/FriendshipHurdle);
		local leftPoint = accumulatedPrice - pureAdd * FriendshipHurdle;
		dc:UpdateCompanyProperty(company, 'Npc/'..shopHost.name..'/FriendshipPoint_Sub', leftPoint);
		addFriendship = pureAdd * 10;
		local newFriendship, newFriendshipPoint, addedFriendship, prevFriendship = UpdateFriendship(dc, company, 'Npc', shopHost.name, addFriendship);
		if newFriendship ~= nil then
			response.Friendship = newFriendship;
			response.FriendshipPoint = newFriendshipPoint;
			addFriendship = addedFriendship;
			
			if newFriendship ~= prevFriendship then
				onFriendshipChanged(newFriendship);
			end
		end
		accumulatedPrice = leftPoint;
	else
		dc:UpdateCompanyProperty(company, 'Npc/'..shopHost.name..'/FriendshipPoint_Sub', accumulatedPrice);
	end
	return addFriendship;
end

function LobbyAction_ShopAction(dc, company, args)
	local response = {};
			
	local shopHost = GetCompanyInstantProperty(company, 'ShopHost');
	local friendship = '';
	local friendshipPoint = 0;
	if shopHost then
		friendship = company.Npc[shopHost.name].Friendship;
		friendshipPoint = company.Npc[shopHost.name].FriendshipPoint;
	end
	
	-- LobbyRequest 폼을 위해 더미라도 데이터를 넣어둬야함.
	response.Friendship = friendship;
	response.FriendshipPoint = friendshipPoint;
	response.Items = {};
	response.LostItems = {};
	response.ValkyrieItems = {};
	response.Success = false;
	response.LastRefreshTime = 0;
	
	
	local shopCls = GetClassList('Shop')[args.ShopType];
	if shopCls == nil then
		return response;
	end
	
	if shopHost == nil and not shopCls.NoneNPCShop then
		-- 상점 호스트가 지원하지 않는 상점이거나 무인상점이 아닌경우는 거래불가.
		return response;
	elseif shopHost ~= nil then
		local validShop = #table.filter(shopHost.Service, function(s) return s.Type == 'Shop' and s.Value == shopCls.name end) >= 1;
		if not validShop then
			return response;
		end
	end
	
	local RefreshItems = function(response, friendship)
		response.Items = BuildShopItemData(company, friendship, shopCls);
		response.LostItems = BuildLostShopItemData(company, friendship, company.LostShop);
		response.ValkyrieItems = BuildValkyrieShopItemData(company, friendship, shopCls);
		response.LastRefreshTime = GetWorldProperty().ShopOptionRefreshTime;
	end
	
	local onFriendshipChanged = function(newFriendship)	
		response.ItemRefreshed = true;
		RefreshItems(response, newFriendship);
	end

	if args.Action == 'Buy' or args.Action == 'LostShop' or args.Action == 'ValkyrieShop' then -- 구매
		local items = nil;
		local currency = nil;
		if args.Action == 'Buy' then
			items = BuildShopItemData(company, friendship, shopCls);
			currency = shopCls.Currency;
		elseif args.Action == 'LostShop' then
			items = BuildLostShopItemData(company, friendship, company.LostShop);
			currency = GetClassList('CurrencyType').Vill;
		elseif args.Action == 'ValkyrieShop' then
			items = BuildValkyrieShopItemData(company, friendship, shopCls);
			currency = GetClassList('CurrencyType').ValkyrieCoin;
		end
		local totalPrice = 0;
		local buyList = {};
		for shopIndex, count in pairs(args.Cart) do
			if args.Action == 'LostShop' then
				count = math.max(0, math.min(count, items[shopIndex].Stock));
			elseif items[shopIndex].GoodsType == 'Recipe' then
				count = math.max(0, math.min(count, 1));
			else
				count = math.max(0, count);
			end
			args.Cart[shopIndex] = count;
			totalPrice = totalPrice + items[shopIndex].Price * count;
			if items[shopIndex].GoodsType == 'Recipe' then
				table.insert(buyList, { GoodsType = 'Recipe', Recipe = items[shopIndex].Recipe });
			else
				table.insert(buyList, { GoodsType = 'Item', Item = items[shopIndex].Item, Count = count, Props = items[shopIndex].Props });
			end
		end
		local currencyAmount = GetCurrencyAmount(company, currency);
		if currencyAmount >= totalPrice then
			local needRefreshShopItems = false;
			for shopIndex, count in pairs(args.Cart) do
				if items[shopIndex].GoodsType == 'Recipe' then
					needRefreshShopItems = true;
					dc:UpdateCompanyProperty(company, string.format('Recipe/%s/Opened', items[shopIndex].Recipe), true);
				else
					dc:GiveItem(company, items[shopIndex].Item, count, false, "", items[shopIndex].Props);
				end
			end
			UpdateCurrencyAmount(dc, company, currency, - totalPrice);
			local addFriendship = 0;
			if shopHost and args.Action ~= 'ValkyrieShop' then
				addFriendship = AddFriendshipByTradingPrice(dc, company, shopHost, totalPrice, response, onFriendshipChanged);
			end
			if args.Action == 'LostShop' then
				for shopIndex, count in pairs(args.Cart) do
					dc:AddCompanyProperty(company, 'LostShop/ItemList/'..items[shopIndex].DBIndex..'/Stock', -count);
				end
			end
			dc:Commit('ShopBuy:'..args.ShopType);
			local noti = { ItemList = buyList, Price = totalPrice, Currency = currency.name };
			if shopHost then
				noti.FriendshipName = ClassDataText('ObjectInfo', shopHost.Info.name, 'Title');
				noti.FriendshipChange = addFriendship;
				friendship = company.Npc[shopHost.name].Friendship;
			end
			SendNotification(company, 'ItemBuy', noti);
			if needRefreshShopItems then
				response.ItemRefreshed = true;
				RefreshItems(response, friendship);
			elseif args.Action == 'LostShop' then
				response.LostItems = BuildLostShopItemData(company, friendship, company.LostShop);
			elseif args.Action == 'ValkyrieShop' then
				response.ValkyrieItems = BuildValkyrieShopItemData(company, friendship, shopCls);
			end
		else
			return response;
		end
	elseif args.Action == 'Sell' then -- 판매
		if not shopCls.SellEnable then
			return response;
		end
		local success =  true;
		local sellList = {};
		local totalPrice = 0;
		for instanceKey, count in pairs(args.Cart) do
			local item = GetInventoryItemByInstanceKey(company, instanceKey);
			if item == nil or count < 0 or item.Amount < count or not item.Sellable then
				success = false;
				LogAndPrint('PlayDialogScript_Shop', 'no item', item);
				break;
			end
			totalPrice = totalPrice + item.SellPrice * count;
			dc:TakeItem(item, count);
			local props = nil;
			if item.Option.OptionKey ~= 'None' then
				props = {};
				for key, value in pairs(item.Option) do
					props['Option/'..key] = value;
				end
			end
			table.insert(sellList, { Item = item.name, Count = count, Props = props });
		end
		if success then
			dc:AddCompanyProperty(company, 'Vill', totalPrice);
			local addFriendship = 0;
			if shopHost then
				addFriendship = AddFriendshipByTradingPrice(dc, company, shopHost, totalPrice, response, onFriendshipChanged);
			end
			dc:Commit('ShopSell:'..args.ShopType);
			local noti = { ItemList = sellList, Price = totalPrice, Currency = 'Vill' };
			if shopHost then
				noti.FriendshipName = ClassDataText('ObjectInfo', shopHost.Info.name, 'Title');
				noti.FriendshipChange = addFriendship;
			end
			SendNotification(company, 'ItemSell', noti);
		else
			dc:Cancel();
			return response;
		end
	elseif args.Action == 'Refresh' then		-- 아이템 갱신
		RefreshItems(response, friendship);
		if shopHost and #response.ValkyrieItems > 0 and not company.Npc[shopHost.name].ValkyrieShopOpened then
			dc:UpdateCompanyProperty(company, string.format('Npc/%s/ValkyrieShopOpened', shopHost.name), true);
			local noti = { NpcName = ClassDataText('ObjectInfo', shopHost.Info.name, 'Title') };
			SendNotification(company, 'ValkyrieShopOpened', noti);
		end
	end
	response.Success = true;
	return response;
end
-- 요리 상점.
function LobbyAction_FoodShopAction(dc, company, args)
	local response = {};
			
	local shopHost = GetCompanyInstantProperty(company, 'ShopHost');
	local friendship = '';
	local friendshipPoint = 0;
	if shopHost then
		friendship = company.Npc[shopHost.name].Friendship;
		friendshipPoint = company.Npc[shopHost.name].FriendshipPoint;
	end
	
	-- LobbyRequest 폼을 위해 더미라도 데이터를 넣어둬야함.
	response.Friendship = friendship;
	response.FriendshipPoint = friendshipPoint;
	response.Items = {};
	response.LostItems = {};
	response.Success = false;
	response.LastRefreshTime = 0;
	
	
	local foodShopCls = GetClassList('FoodShop')[args.ShopType];
	if foodShopCls == nil then
		return response;
	end
	
	if shopHost == nil and not foodShopCls.NoneNPCShop then
		-- 상점 호스트가 지원하지 않는 상점이거나 무인상점이 아닌경우는 거래불가.
		return response;
	elseif shopHost ~= nil then
		local validShop = #table.filter(shopHost.Service, function(s) return s.Type == 'FoodShop' and s.Value == foodShopCls.name end) >= 1;
		if not validShop then
			return response;
		end
	end
	
	local RefreshMenus = function(response, friendship)
		response.Menus = BuildFoodMenuData(company, friendship, foodShopCls);
		response.LastRefreshTime = GetWorldProperty().FoodRecommendRefreshTime;
	end

	if args.Action == 'Buy' then -- 구매
		local menus = BuildFoodMenuData(company, friendship, foodShopCls);
		local currency = foodShopCls.Currency;
		local orderList = SafeIndex(args.Cart, 'Order') or {};
		local rosterList = SafeIndex(args.Cart, 'Roster') or {};
		
		local isEnable, totalPrice, reason = IsEnableFoodOrder(company, menus, orderList, rosterList);
		local currencyAmount = GetCurrencyAmount(company, currency);
		if currencyAmount < totalPrice then
			isEnable = false;
		end
		if not isEnable then
			return response;
		end
		
		local foodList = GetClassList('Food');
		local curOrderList = table.map(orderList, function(foodName) return foodList[foodName] end);
		local amount_Condition, amount_Satiety, amount_Refresh, setEffect = GetFoodEffectAndValue(curOrderList);
		
		local rosterSet = {};
		for _, rosterKey in ipairs(rosterList) do
			rosterSet[rosterKey] = true;
		end
		local rosters = table.filter(GetAllRoster(company), function(roster) return rosterSet[roster.RosterKey]; end);
		
		local reactionType = GetFoodRestActionType(curOrderList);
		local hasFoodSetEffect = false;
		
		-- 2. 로스터 CP 회복.
		local prevCP = {};
		local categoryList = {};
		for i, pc in ipairs(rosters) do
			local addCP, category = GetFoodRestAction(pc, amount_Condition, curOrderList);
			prevCP[pc.name] = pc:GetEstimatedCP();
			local _, nextSatiety, nextRefresh = AddRosterConditionPoint(dc, pc, addCP, amount_Satiety, amount_Refresh);
			local nextSetEffect = pc.FoodSetEffect;
			if addCP >= 0 and setEffect then
				local isEnable = false;
				if setEffect.RequireType.name == 'Satiety' then
					isEnable = nextSatiety / pc.MaxSatiety >= setEffect.RequireValue / 100;
				elseif setEffect.RequireType.name == 'Refresh' then
					isEnable = nextRefresh / pc.MaxRefresh >= setEffect.RequireValue / 100;
				end
				if isEnable then
					nextSetEffect = setEffect.name;
					hasFoodSetEffect = true;
				end
			elseif addCP < 0 then
				nextSetEffect = 'None';
			end
			if pc.FoodSetEffect ~= nextSetEffect then
				dc:UpdatePCProperty(pc, 'FoodSetEffect', nextSetEffect);
			end
			table.insert(categoryList, category);
		end
		local guideTrigger = {};
		if hasFoodSetEffect then
			dc:AddCompanyProperty(company, 'Stats/FoodSetEffectCount', 1);
			local guideTrigger_Gourmand = SafeIndex(company.GuideTrigger, 'Gourmand');
			if guideTrigger_Gourmand and not guideTrigger_Gourmand.Pass and company.Stats.FoodSetEffectCount + 1 >= 10  then
				dc:UpdateCompanyProperty(company, 'GuideTrigger/'..guideTrigger_Gourmand.name..'/Pass', true);
				dc:AcquireMastery(company, guideTrigger_Gourmand.Mastery, 1);
				guideTrigger[guideTrigger_Gourmand.name] = true;
			end
		end
		UpdateCurrencyAmount(dc, company, foodShopCls.Currency, - totalPrice);
		local addFriendship = 0;
		if shopHost  then
			addFriendship = AddFriendshipByTradingPrice(dc, company, shopHost, totalPrice, response, function(newFriendship)
				response.MenuRefreshed = true;
				RefreshMenus(response, newFriendship);
			end);
		end
		dc:Commit('FoodShopBuy:'..args.ShopType);
		local fillData = {};
		for i, roster in ipairs(rosters) do
			local category = categoryList[i];
			table.insert(fillData, {Name = roster.name, StartValue = prevCP[roster.name], EndValue = roster:GetEstimatedCP(), Category = category, RestAction = reactionType});
		end
		local noti = { FillData = fillData, Price = totalPrice, Currency = foodShopCls.Currency.name, HasFoodSetEffect = hasFoodSetEffect, GuideTrigger = guideTrigger };
		if shopHost then
			noti.FriendshipName = ClassDataText('ObjectInfo', shopHost.Info.name, 'Title');
			noti.FriendshipChange = addFriendship;
			friendship = company.Npc[shopHost.name].Friendship;
		end
		SendNotification(company, 'FoodBuy', noti);
	elseif args.Action == 'Refresh' then		-- 아이템 갱신
		RefreshMenus(response, friendship);
	end
	response.Success = true;
	return response;
end
------------------------------------------------------
-- 특성판 관리
------------------------------------------------------
function LobbyAction_ChangeMasteryBoard(dc, company, args)
	local boardIndex = args.MasteryBoardIndex;
	if boardIndex == nil then
		LogAndPrint('LobbyAction_ChangeMasteryBoard : boardIndex is nil!');
		return {Success = false, Item = '', Count = 0};
	end
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_ChangeMasteryBoard : roster is nil!');
		return {Success = false, Item = '', Count = 0};
	end
	-- 클래스 변경 (선체크)
	local job = args.Job;
	if job and job ~= '' then
		-- 전직한 적 없는 직업은 제외
		local enable = IsEnableChangeClassOpened(roster, job);
		if not enable then
			return {Success = false, Item = '', Count = 0};
		end
	end
	
	local masteries = args.Masteries or {};
	
	local itemCounter = LobbyInventoryItemCounter(company);	
	local masteryList = GetClassList('Mastery');
	
	local extractNeedItem = '';
	local extractNeedCount = 0;	
	for _, masteryName in ipairs(masteries) do
		local mastery = masteryList[masteryName];
		if mastery and mastery.ExtractItem ~= 'None' then
			extractNeedCount = extractNeedCount + mastery.Cost;
			extractNeedItem = mastery.ExtractItem;
		end
	end
	
	if extractNeedCount > 0 and itemCounter(extractNeedItem) < extractNeedCount then
		LogAndPrint('LobbyAction_ChangeMasteryBoard : item is not enough!', itemCounter(extractNeedItem), extractNeedCount);
		return {Success = false, Item = '', Count = 0};
	end
	
	-- 클래스 변경
	if job and job ~= '' then
		dc:UpdatePCProperty(roster, 'Object/Job', job);
	end
	
	for _, masteryName in ipairs(masteries) do
		local mastery = masteryList[masteryName];
		if mastery and mastery.ExtractItem ~= 'None' then
			-- 1) 로스터 마스터리 레벨 초기화
			dc:UpdateMasteryLv(roster, masteryName, 0, boardIndex);
			-- 2) 회사 마스터리 카운트 증가
			dc:AcquireMastery(company, masteryName, 1, true);
		end
	end
	if extractNeedCount > 0 then
		-- 3) 필요 아이템 소모
		dc:TakeItem(GetInventoryItemByType(company, extractNeedItem), extractNeedCount);
	end
	
	-- 4) 특성 해제로 사라지는 장착 슬롯에 착용 중인 아이템이 있으면 해제
	local prevMasteryTable = GetMastery(roster, roster.MasteryBoard.Index);
	local nextMasteryTable = GetMastery(roster, boardIndex);
	local removedMasteries = {};
	-- 자동 해제되는 마스터리도 제외해야한다.
	for _, masteryName in ipairs(masteries) do
		local mastery = masteryList[masteryName];
		if mastery and mastery.ExtractItem ~= 'None' then
			removedMasteries[masteryName] = true;
		end
	end
	local unequipMasteryList = {};
	for masteryName, _ in pairs(prevMasteryTable) do
		if not nextMasteryTable[masteryName] or removedMasteries[masteryName] then
			table.insert(unequipMasteryList, masteryName);
		end
	end
	local unequipItemSlotList = {};
	local itemSlotExtentions = Set.new({'AlchemyBag', 'GrenadeBag', 'DoubleGear', 'Module_AuxiliaryWeapon', 'Module_AssistEquipment'});
	for _, masteryName in ipairs(unequipMasteryList) do
		if itemSlotExtentions[masteryName] then
			table.insert(unequipItemSlotList, masteryName);
		end
	end
	for _, unequipItemSlot in ipairs(unequipItemSlotList) do
		local unequipItem = GetWithoutError(roster.Object, unequipItemSlot);
		if unequipItem and unequipItem.name  then
			dc:UnequipItem(roster, unequipItemSlot);
		end
	end
	
	-- 5) 특성판 사용 인덱스 변경
	local curBoardIndex = roster.MasteryBoard.Index;
	if curBoardIndex ~= boardIndex then
		dc:UpdatePCProperty(roster, 'MasteryBoard/Index', boardIndex);
	end
	
	-- 6) 어빌리티 프리셋 업데이트
	local abilitySlotIndex = args.AbilitySlotIndex;
	if abilitySlotIndex and (roster.RosterType == 'Pc' or roster.RosterType == 'Beast') then
		local testJob = roster.Object.Job.name;
		if job and job ~= '' then
			testJob = job;
		end
		local slotManager = AbilitySlotManager.new(roster, abilitySlotIndex, testJob, true);
		local abilityList = GetClassList('Ability');
		local truncated = slotManager:GetTruncatedAbilities();
		if #truncated > 0 then
			table.foreach(truncated, function(i, abl) slotManager:Deactivate(abilityList[abl]); end);
		end
		UpdateRosterAbilitySetting(dc, roster, testJob, slotManager:AggregateChanges(), abilitySlotIndex, slotManager:GetActiveAbilities());
		dc:UpdatePCProperty(roster, 'AbilityPresetIndex', abilitySlotIndex);
	end
	
	return {Success = true, Item = extractNeedItem, Count = extractNeedCount};
end
function LobbyAction_AddMasteryBoard(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_AddMasteryBoard : roster is nil!');
		return {Success = false};
	end 
	local itemCounter = LobbyInventoryItemCounter(company);
	local isEnable, needItem, needCount, reason = IsEnableAddMasteryBoard(roster, itemCounter);
	if not isEnable then
		LogAndPrint('LobbyAction_AddMasteryBoard : roster : ', args.Roster);
		for index, reason in ipairs (reason) do
			LogAndPrint('\nReason:', reason);
		end
		return {Success = false};
	end
	
	-- 기본값이 0부터 시작하지 않으므로, AddPCProperty를 사용하면 안 된다.
	dc:UpdatePCProperty(roster, 'MasteryBoard/Count', roster.MasteryBoard.Count + 1);
	if needItem ~= 'None' and needCount > 0 then
		dc:TakeItem(GetInventoryItemByType(company, needItem), needCount);
	end
	return {Success = true};
end
function LobbyAction_RenameMasteryBoard(dc, company, args)
	local boardIndex = args.MasteryBoardIndex;
	if boardIndex == nil then
		LogAndPrint('LobbyAction_RenameMasteryBoard : boardIndex is nil!');
		return {Success = false};
	end
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_RenameMasteryBoard : roster is nil!');
		return {Success = false};
	end
	if boardIndex >= roster.MasteryBoard.RCount or boardIndex > #roster.MasteryBoard.Board then
		LogAndPrint('LobbyAction_RenameMasteryBoard : boardIndex is invalid!');
		return {Success = false};
	end
	local propName = string.format('MasteryBoard/Board/%d/Title', boardIndex + 1);
	dc:UpdatePCProperty(roster, propName, args.MasteryBoardName);
	return {Success = true};
end
function LobbyAction_SwapMasteryBoardOrder(dc, company, args)
	local boardIndex1 = args.MasteryBoardIndex;
	local boardIndex2 = args.MasteryBoardIndex2;
	if boardIndex1 == nil or boardIndex2 == nil then
		LogAndPrint('LobbyAction_MoveMasteryBoard : boardIndex is nil!');
		return {Success = false};
	end
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_MoveMasteryBoard : roster is nil!');
		return {Success = false};
	end
	if boardIndex1 >= roster.MasteryBoard.RCount or boardIndex1 > #roster.MasteryBoard.Board then
		LogAndPrint('LobbyAction_MoveMasteryBoard : boardIndex1 is invalid!', boardIndex1);
		return {Success = false};
	end
	if boardIndex2 >= roster.MasteryBoard.RCount or boardIndex2 > #roster.MasteryBoard.Board then
		LogAndPrint('LobbyAction_MoveMasteryBoard : boardIndex2 is invalid!', boardIndex2);
		return {Success = false};
	end
	local order1 = roster.MasteryBoard.Board[boardIndex1 + 1].Order;
	local order2 = roster.MasteryBoard.Board[boardIndex2 + 1].Order;
	local propName1 = string.format('MasteryBoard/Board/%d/Order', boardIndex1 + 1);
	local propName2 = string.format('MasteryBoard/Board/%d/Order', boardIndex2 + 1);
	dc:UpdatePCProperty(roster, propName1, order2);
	dc:UpdatePCProperty(roster, propName2, order1);
	return {Success = true};
end
------------------------------------------------------
-- 급여 변경
------------------------------------------------------
function LobbyAction_ChangeSalaryType(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_ChangeSalaryType : roster is nil!');
		return {Success = false, Price = 0};
	end
	local salaryIndex = args.SalaryIndex;
	if salaryIndex == nil then
		LogAndPrint('LobbyAction_ChangeSalaryType : salaryIndex is nil!');
		return {Success = false, Price = 0};
	end
	local salaryType = GetWithoutError(roster, 'SalaryType');
	if salaryType == nil or salaryIndex <= 0 or salaryIndex > #salaryType then
		LogAndPrint('LobbyAction_ChangeSalaryType : salaryIndex is invalid!', roster.name, salaryType);
		return {Success = false, Price = 0};
	end
	local duration = salaryType[salaryIndex].ClearCount;
	if duration == roster.SalaryDuration then
		LogAndPrint('LobbyAction_ChangeSalaryType : same duration!', roster.name, salaryType);
		return {Success = false, Price = 0};
	end
	local needVill = roster.SalaryCounter * roster.Salary;
	if needVill > 0 and company.Vill < needVill then
		LogAndPrint('LobbyAction_ChangeSalaryType : not enough vill!', company.Vill, needVill);
		return {Success = false, Price = 0};
	end
	-- 기존 급여 정산 (일반적인 급여 지급이 아니므로, 다 초기화함)
	if needVill > 0 then
		dc:AddCompanyProperty(company, 'Vill', -needVill);
	end	
	dc:UpdatePCProperty(roster, 'SalaryCounter', 0);
	dc:UpdatePCProperty(roster, 'SalaryCountBonusCont', 0);
	dc:UpdatePCProperty(roster, 'SalaryCountDelayCont', 0);
	dc:UpdatePCProperty(roster, 'SalaryCountNormalCont', 0);
	dc:UpdatePCProperty(roster, 'SalaryNoticed', false);
	-- 급여 조건 변경
	dc:UpdatePCProperty(roster, 'SalaryDuration', duration);
	dc:AddPCProperty(roster, 'SalaryCountChangeType', 1);
	
	return {Success = true, Price = needVill};
end
-- 직업 변경
function LobbyAction_ChangeJob(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	local job = args.Job;
	local masteries = args.Masteries or {};
	
	local itemCounter = LobbyInventoryItemCounter(company);
	local enable, needItem, needCount = IsEnableChangeClass(company, roster, job, itemCounter);
	if not enable then
		return {Success = false, Item = needItem, Count = 0, Abilities = {}, UnlockTechList = {}};
	end

	-- 마스터리 보드 및 해제 할 마스터리 적용
	local boardIndex = args.MasteryBoardIndex or roster.MasteryBoard.Index;
	local boardChangeResponse = LobbyAction_ChangeMasteryBoard(dc, company, {Roster = args.Roster, MasteryBoardIndex = boardIndex, Masteries = args.Masteries});
	if not boardChangeResponse.Success then
		-- 여기서?
		return {Success = false, Item = needItem, Count = 0, Abilities = {}, UnlockTechList = {}};
	end
	
	local unlockTechList = {};
	local jobLv = SafeIndex(roster, 'EnableJobs', job, 'Lv');
	local rewardMasteries = GetRewardMasteriesByJobLevel(company, roster, job, 1, jobLv);
	for _, mastery in ipairs(rewardMasteries) do
		local techName = mastery.name;
		dc:UpdateCompanyProperty(company, string.format('Technique/%s/Opened', techName), true);
		dc:UpdateCompanyProperty(company, string.format('Technique/%s/IsNew', techName), true);
		table.insert(unlockTechList, techName);
	end

	-- 3) 필요 아이템 소모
	if needCount > 0 then
		dc:TakeItem(GetInventoryItemByType(company, needItem), needCount);
	end
	-- 4) 직업 변경
	dc:UpdatePCProperty(roster, 'Object/Job', job);
	-- 5) LastLv 갱신
	local lastLv = SafeIndex(roster, 'EnableJobs', job, 'LastLv');
	-- 6) 보너스 특성판 주기
	local masteryBoardExtended = false;
	if StringToBool(SafeIndex(roster, 'EnableJobs', job, 'ExtraMasteryBoard')) then
		dc:UpdatePCProperty(roster, string.format('EnableJobs/%s/ExtraMasteryBoard', job), false);
		dc:AddPCProperty(roster, 'MasteryBoard/ExtraCount', 1);
		masteryBoardExtended = true;
	end
	if lastLv <= 0 then
		dc:UpdatePCProperty(roster, string.format('EnableJobs/%s/LastLv', job), 1);
	end
	-- 7) 어빌리티 슬롯 변경
	local abilitySlotIndex = args.AbilitySlotIndex or roster.EnableJobs[job].AbilityPresetIndex;
	local slotManager = AbilitySlotManager.new(roster, abilitySlotIndex, job, true);
	local abilityList = GetClassList('Ability');
	local truncated = slotManager:GetTruncatedAbilities();
	if #truncated > 0 then
		table.foreach(truncated, function(i, abl) slotManager:Deactivate(abilityList[abl]); end);
	end
	UpdateRosterAbilitySetting(dc, roster, job, slotManager:AggregateChanges(job), abilitySlotIndex, slotManager:GetActiveAbilities());
	if abilitySlotIndex ~= roster.AbilityPresetIndex then
		dc:UpdatePCProperty(roster, 'AbilityPresetIndex', abilitySlotIndex);
	end
	
	return {Success = true, Item = needItem, Count = needCount + boardChangeResponse.Count, UnlockTechList = unlockTechList, MasteryBoardExtended = masteryBoardExtended};
end
function UpdateRosterAbilitySetting(dc, roster, job, settings, presetSlot, activeAbilities)
	for _, setting in ipairs(settings) do
		local active = setting.Active;
		if roster.RosterType == 'Pc' then
			local activeAbility = roster.EnableJobs[job].ActiveAbility;
			if not (GetWithoutError(activeAbility, setting.Ability) == nil) then
				if StringToBool(roster.EnableJobs[job].ActiveAbility[setting.Ability]) ~= active then
					dc:UpdatePCProperty(roster, 'EnableJobs/'..job..'/ActiveAbility/'..setting.Ability, active);
				end
			else
				LogAndPrint('LobbyAction_UpdateRosterAbilitySetting', 'Error Input', setting);
			end
		elseif roster.RosterType == 'Beast' then
			local activeAbility = roster.ActiveAbility;
			if not (GetWithoutError(activeAbility, setting.Ability) == nil) then
				if roster.ActiveAbility[setting.Ability] ~= active then
					dc:UpdatePCProperty(roster, 'ActiveAbility/'..setting.Ability, active);
				end
			else
				LogAndPrint('LobbyAction_UpdateRosterAbilitySetting', 'Error Input', setting);
			end
		end
	end
	if roster.AbilityPreset.Preset[presetSlot].ActiveAbility.MaxCount ~= #activeAbilities then
		dc:UpdatePCProperty(roster, string.format('AbilityPreset/Preset/%d/ActiveAbility/MaxCount', presetSlot), #activeAbilities);
	end
	table.foreach(activeAbilities, function(i, abl)
		if roster.AbilityPreset.Preset[presetSlot].ActiveAbility[i] ~= abl then
			dc:UpdatePCProperty(roster, string.format('AbilityPreset/Preset/%d/ActiveAbility/%d', presetSlot, i), abl);
		end
	end);
end
-- 어빌리티 세팅 변경
function LobbyAction_UpdateRosterAbilitySetting(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	
	-- Validation
	local abilityList = GetClassList('Ability');
	local slotManager = AbilitySlotManager.new(roster);
	-- 비활성화를 먼저 해야함 (의존성 있는 것부터 적용)
	local deactiveList = table.filter(args.Setting, function(set) return not set.Active end);
	table.scoresort(deactiveList, function(set) return abilityList[set.Ability].MasterAbility == 'None' and 2 or 1 end);
	for _, setting in ipairs(deactiveList) do
		local abilityCls = abilityList[setting.Ability];
		slotManager:Deactivate(abilityCls);
	end
	-- 활성화 (의존성 없는 것부터 적용)
	local activeList = table.filter(args.Setting, function(set) return set.Active end);
	table.scoresort(activeList, function(set) return abilityList[set.Ability].MasterAbility ~= 'None' and 2 or 1 end);
	for _, setting in ipairs(activeList) do
		local abilityCls = abilityList[setting.Ability];
		if not slotManager:Activate(abilityCls) then
			LogAndPrint('Activate Failed - ability:', abilityCls.name, ', setting:', args.Setting);
			return {Success = false};
		end
	end
	if not slotManager:IsValidAndChanged() then
		return {Success = false};
	end
	
	local presetIndex = nil;
	if roster.RosterType == 'Pc' then
		if roster.AbilityPresetIndex == 0 then
			presetIndex = roster.EnableJobs[roster.Object.Job.name].AbilityPresetIndex;
		else
			presetIndex = roster.AbilityPresetIndex;
		end
	else
		presetIndex = roster.AbilityPresetIndex;
	end
	UpdateRosterAbilitySetting(dc, roster, roster.Object.Job.name, args.Setting, presetIndex, slotManager:GetActiveAbilities());
	
	return {Success = true};
end

function LobbyAction_NewClassNoticed(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		return {Success = false};
	end
	
	if not StringToBool(SafeIndex(roster, 'EnableJobs', args.Job, 'IsNew')) then
		return {Success = false};
	end

	dc:UpdatePCProperty(roster, 'EnableJobs/'..args.Job..'/IsNew', false);
	dc:UpdatePCProperty(roster, 'IsNewClass', true);
	return {Success = true};
end

function LobbyAction_NewClassConfirmed(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		return {Success = false};
	end
	
	if not roster.IsNewClass then
		return {Success = false};
	end
	
	dc:UpdatePCProperty(roster, 'IsNewClass', false);
	return {Success = true};
end

function LobbyAction_NewAbilityNoticed(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		return {Success = false};
	end
	
	local currentJob = roster.EnableJobs[roster.Object.Job.name];
	if currentJob.Lv == currentJob.LastLv then
		return {Success = false};
	end
	
	dc:UpdatePCProperty(roster, 'EnableJobs/'..currentJob.name..'/LastLv', currentJob.Lv);
	return {Success = true};
end

function LobbyAction_NewLostShopItemConfirmed(dc, company, args)
	dc:UpdateCompanyProperty(company, 'LostShop/IsNew', false);
	return {Success = true};
end

function LobbyAction_MasteryFavorites(dc, company, args)
	for _, info in ipairs(args.Favorites) do
		local masteryName = info.Name;
		local mastery = company.Mastery[masteryName];
		if mastery ~= nil then
			dc:UpdateCompanyProperty(company, 'Mastery/'..masteryName..'/Favorite', info.Favorite);
		end
	end
	return { Success = true };
end

function LobbyAction_RemoveBeast(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_RemoveBeast : roster is nil!');
		return {Success = false};
	end
	if not IsEnableRemoveBeast(roster) then
		return {Success = false};
	end
	StartLobbyDialog(company, 'RemoveBeast_EntryPoint', {roster_name=args.Roster});
	return {Success = true};
end

function ProgressRemoveBeastAction(ldm, self, company, env, parsedScript)
	local roster = GetRoster(company, parsedScript.RosterName);
	if roster == nil then
		return false;
	end
	if not IsEnableRemoveBeast(roster) then
		return false;
	end
	local dc = ldm:GetDatabaseCommiter();
	-- 1) 특성판 발키리 코인 복원
	local needItemMap = {};
	for i = 1, roster.MasteryBoard.Count do
		local board = roster.MasteryBoard.Board[i];
		local needItem = board.NeedItem;
		local needCount = board.NeedCount;
		if needItem ~= 'None' and needCount > 0 then
			local prevCount = needItemMap[needItem] or 0;
			needItemMap[needItem] = prevCount + needCount;
		end
	end
	if not table.empty(needItemMap) then
		for needItem, needCount in pairs(needItemMap) do
			dc:GiveItem(company, needItem, needCount);
			ldm:AddMissionChat('GiveItem', 'GiveItem', { ItemType = needItem, ItemCount = needCount });
		end
	end
	-- 2) 로스터 삭제
	dc:DeleteRoster(roster);
	return dc:Commit('DialogAction:'..env._cur_dialog.name);
end

function LobbyAction_RenameBeast(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_RenameBeast : roster is nil!');
		return {Success = false};
	end
	dc:UpdatePCProperty(roster, 'RosterTitle', args.BeastName);
	return {Success = true};
end

-- 야수 진화
function LobbyAction_EvolveBeast(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_EvolveBeast : roster is nil!');
		return {Success = false, Item = 'None', Count = 0};
	end
	local beastType = args.BeastType;
	local beastTypeCls = GetClassList('BeastType')[beastType];
	if not beastTypeCls then
		return {Success = false, Item = 'None', Count = 0};
	end	
	
	local itemCounter = LobbyInventoryItemCounter(company);
	local enable, needItem, needCount = IsEnableBeastEvolution(company, roster, beastType, itemCounter);
	if not enable then
		return {Success = false, Item = needItem or 'None', Count = 0};
	end
	-- 1) 필요 아이템 소모
	if needCount and needCount > 0 then
		dc:TakeItem(GetInventoryItemByType(company, needItem), needCount);
	end
	-- 2) 야수 진화
	dc:UpdatePCProperty(roster, 'BeastType', beastType);
	dc:UpdatePCProperty(roster, 'Object', string.format('Object/%s', beastTypeCls.Monster.Object.name));
	dc:UpdatePCProperty(roster, 'Info', string.format('ObjectInfo/%s', beastTypeCls.Monster.Info.name));
	dc:UpdatePCProperty(roster, 'JobLv', 1);
	dc:UpdatePCProperty(roster, 'LastJobLv', 0);
	dc:UpdatePCProperty(roster, 'JobExp', 0);
	-- 2-1) 어빌리티 편성 초기화
	local startAbilities = {};
	for __, abilitySlot in ipairs(beastTypeCls.Abilities) do
		if abilitySlot.RequireLv <= 1 and StringToBool(abilitySlot.Default) and startAbilities[abilitySlot.Name] == nil then
			startAbilities[abilitySlot.Name] = true;
		end
	end
	-- 유효하지 않은 어빌리티 해제
	local activeAbilitySet = table.map(roster.ActiveAbility, function (v) return v; end);
	for abilityName, isActive in pairs(activeAbilitySet) do
		if isActive and not startAbilities[abilityName] then
			dc:UpdatePCProperty(roster, string.format('ActiveAbility/%s', abilityName), false);
			activeAbilitySet[abilityName] = false;
		end
	end
	-- 활성화된 어빌리티가 하나도 없으면 리셋
	for abilityName, _ in pairs(startAbilities) do
		if not activeAbilitySet[abilityName] then
			dc:UpdatePCProperty(roster, string.format('ActiveAbility/%s', abilityName), true);
		end
	end
	-- 2-2) 트러블메이커 정보
	local troublemaker = GetWithoutError(company.Troublemaker, beastType);
	if troublemaker and troublemaker.Exp < troublemaker.MaxExp then
		local point = 1;
		-- 장벽 지구 보너스
		local reputationMultiplier = 0;
		local wallAreaBonus = GetDivisionTypeBonusValue(company.Reputation, 'Area_Wall');
		if wallAreaBonus > 0 then
			reputationMultiplier = reputationMultiplier + wallAreaBonus;
		end
		if reputationMultiplier > 0 then
			point = math.floor(point * (100 + reputationMultiplier) / 100);
		end
		if troublemaker.Exp + point > troublemaker.MaxExp then
			point = troublemaker.MaxExp - troublemaker.Exp;
		end
		dc:AddCompanyProperty(company, string.format('Troublemaker/%s/Exp', troublemaker.name), point);
		if troublemaker.Exp == 0 then
			dc:UpdateCompanyProperty(company, string.format('Troublemaker/%s/IsNew', troublemaker.name), true);
		end
	end
	-- 3) 진화 특성 후보 (프로퍼티로 임시 기록)
	local candidateMasteries = PickBeastUniqueMasteryCandidate(roster, beastTypeCls, false, 4, true);
	for i = 1, 4 do
		dc:UpdatePCProperty(roster, string.format('EvolutionMasteryCandidate%d', i), candidateMasteries[i] or 'None');
	end
	-- 4) 진화 특성 선택
	StartLobbyDialog(company, 'EvolveBeast_EntryPoint', {roster_name=args.Roster, beast_type=args.BeastType, candidate_masteries = candidateMasteries});
	return {Success = true, Item = needItem or 'None', Count = needCount or 0};
end
-- 진화 특성 재선택
function LobbyAction_SelectEvolutionMastery(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_SelectEvolutionMastery : roster is nil!');
		return {Success = false};
	end
	if not IsNeedSelectEvolutionMastery(roster) then
		return {Success = false};
	end
	local beastType = roster.BeastType.name;	
	-- 1) 진화 특성 재선택
	StartLobbyDialog(company, 'EvolveBeast_EntryPoint', {roster_name=args.Roster, beast_type=beastType});
	return {Success = true};
end
------------------------------------------------ 
-- 다이아로그 야수 진화 특성창
------------------------------------------------ 
function ProgressEvolveBeastMasteryAction(ldm, self, company, env, parsedScript)
	local roster = GetRoster(company, parsedScript.RosterName);
	if roster == nil then
		return false;
	end
	local beastTypeCls = GetClassList('BeastType')[parsedScript.BeastType];
	if beastTypeCls == nil then
		return false;
	end
	local candidateMasteries = parsedScript.CandiateMasteries;
	if candidateMasteries == nil or #candidateMasteries < 3 then
		-- 프로퍼티로 복원 시도
		candidateMasteries = {};
		for i = 1, 4 do
			local candidateName = GetWithoutError(roster, string.format('EvolutionMasteryCandidate%d', i));
			LogAndPrint('ProgressEvolveBeastMasteryAction - i:', i, ', candidateName:', candidateName);
			if candidateName and candidateName ~= 'None' then
				table.insert(candidateMasteries, candidateName);
			end
		end
		-- 복원이 안 되었으면 새로 뽑아야지 뭐...
		if #candidateMasteries < 4 then
			candidateMasteries = PickBeastUniqueMasteryCandidate(roster, beastTypeCls, false, 4, true);
		end
	end
	LogAndPrint('ProgressEvolveBeastMasteryAction - candidateMasteries:', candidateMasteries);
	local helpInfo = {};
	for _, masteryType in ipairs({'Training', 'Nature', 'Gene', 'ESP'}) do
		local helpKey = 'EvolutionMastery'..masteryType;
		helpInfo[helpKey] = GetWithoutError(company.Progress.Tutorial, helpKey);
	end
	local id, ok, result = ldm:Dialog('ScoutBeast', {BeastType = beastTypeCls.name, CandidateMasteries = candidateMasteries, TargetKey = roster.RosterKey, HelpInfo = helpInfo});
	
	local dc = ldm:GetDatabaseCommiter();
	dc:UpdatePCProperty(roster, string.format('EvolutionMastery%d', beastTypeCls.EvolutionStage), result.Mastery);
	local newHelpInfo = result.HelpInfo or {};
	for key, value in pairs(newHelpInfo) do
		local prevValue = GetWithoutError(company.Progress.Tutorial, key);
		if prevValue ~= nil and prevValue ~= value then
			dc:UpdateCompanyProperty(company, string.format('Progress/Tutorial/%s', key), value);
		end
	end
	for i = 1, 4 do
		dc:UpdatePCProperty(roster, string.format('EvolutionMasteryCandidate%d', i), 'None');
	end
	
	return dc:Commit('DialogAction:'..env._cur_dialog.name);
end

function LobbyAction_NewEvolutionConfirmed(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		return {Success = false};
	end
	for _, beastType in ipairs(args.BeastTypes) do
		local isNew = GetWithoutError(roster.IsNewEvolution, beastType);
		if isNew then
			dc:UpdatePCProperty(roster, string.format('IsNewEvolution/%s', beastType), false);
		end
	end
	return {Success = true};
end
-- 기계 제작
function LobbyAction_CraftMachine(dc, company, args)
	local isEnable, reason = IsEnableCraftMachine(company, args.MachineType, args.OSType, args.Items, LobbyInventoryItemCounter(company))
	if not isEnable then
		return {Success = false, Mastery = 'None'};
	end
	
	-- 로스터 추가
	local rosterKey = string.format('Machine_%d', company.MachineIndex);
	dc:AddCompanyProperty(company, 'MachineIndex', 1);
	dc:NewMachine(company, rosterKey, args.MachineType);
	dc:Commit('LobbyAction:CraftMachine');
	
	local roster = GetRoster(company, rosterKey);
	if roster == nil then
		return {Success = false, Mastery = 'None'};
	end
	
	-- 아이템 장착, OS 특성 설정
	local equipSlots = { 'Weapon', 'Body', 'Hand', 'Leg', 'Inventory1', 'Inventory2' };
	for _, equipPos in ipairs(equipSlots) do
		local equipItem = args.Items[equipPos];
		if equipItem and equipItem.Item then
			local invItem = GetInventoryItemByType(company, equipItem.Item);
			if invItem then
				dc:EquipItem(roster, invItem, equipPos);
			end
		end
	end
	dc:UpdatePCProperty(roster, 'OSType', args.OSType);
	dc:Commit('LobbyAction:CraftMachine');
	
	-- 제작 고유 특성 설정
	roster = GetRoster(company, rosterKey);
	local craftMastery = GetMasteryForMachineByMachineCracft(roster);
	if craftMastery then
		dc:UpdatePCProperty(roster, 'CraftMastery', craftMastery);
	end
	
	-- 클래스 특성 언락
	local rewardMasteries = GetRewardMasteriesByJobLevel_Machine(company, roster, 1, 1, 1);
	for _, mastery in ipairs(rewardMasteries) do
		local techName = mastery.name;
		local tech = company.Technique[techName];
		if tech and not tech.Opened then
			dc:UpdateCompanyProperty(company, string.format('Technique/%s/Opened', techName), true);
			dc:UpdateCompanyProperty(company, string.format('Technique/%s/IsNew', techName), true);
		end
	end
	
	-- 제작 발주 번호
	dc:UpdatePCProperty(roster, 'CraftKey', args.CraftKey);
	
	return {Success = true, Mastery = craftMastery or 'None'};
end
-- 기계 폐기
function LobbyAction_RemoveMachine(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_RemoveMachine : roster is nil!', company.CompanyName, args.Roster);
		return {Success = false};
	end
	if not IsEnableRemoveMachine(roster) then
		return {Success = false};
	end
	StartLobbyDialog(company, 'RemoveMachine_EntryPoint', {roster_name=args.Roster});
	return {Success = true};
end
function ProgressRemoveMachineAction(ldm, self, company, env, parsedScript)
	local roster = GetRoster(company, parsedScript.RosterName);
	if roster == nil then
		return false;
	end
	if not IsEnableRemoveMachine(roster) then
		return false;
	end
	local dc = ldm:GetDatabaseCommiter();
	-- 1) 특성판 발키리 코인 복원
	local needItemMap = {};
	for i = 1, roster.MasteryBoard.Count do
		local board = roster.MasteryBoard.Board[i];
		local needItem = board.NeedItem;
		local needCount = board.NeedCount;
		if needItem ~= 'None' and needCount > 0 then
			local prevCount = needItemMap[needItem] or 0;
			needItemMap[needItem] = prevCount + needCount;
		end
	end
	if not table.empty(needItemMap) then
		for needItem, needCount in pairs(needItemMap) do
			dc:GiveItem(company, needItem, needCount, true);
			ldm:AddMissionChat('GiveItem', 'GiveItem', { ItemType = needItem, ItemCount = needCount });
		end
	end
	-- 2) 특성판 모듈 해제
	for i = 1, roster.MasteryBoard.Count do
		local boardIndex = i - 1;
		local masteryTable = GetMastery(roster, boardIndex);
		local masteryList = {};
		for masteryName, mastery in pairs(masteryTable) do
			if mastery.Lv > 0 and mastery.Category.EquipSlot ~= 'None' and mastery.ExtractItem ~= 'None' then
				table.insert(masteryList, mastery);
			end
		end
		-- 회사 마스터리 카운트 증가
		for _, mastery in ipairs(masteryList) do
			dc:AcquireMastery(company, mastery.name, 1, true);
		end
	end
	-- 3) 장비 재료 추출
	local extractItemList = {};
	local equipmentList = GetClassList('Equipment');
	-- 추출 가능 아이템 리스트
	for _, equipCls in pairs(equipmentList) do
		local equipPos = equipCls.name;
		local equipItem = GetWithoutError(roster.Object, equipPos);
		if equipItem and equipItem.name then
			local roster = GetAllRoster(company);
			local isEnable, reason = IsEnableExtractItem(company, roster, equipItem);
			if isEnable then
				table.insert(extractItemList, equipItem);
			end
		end
	end
	-- 추출 결과물 주기
	for _, extractItem in ipairs(extractItemList) do
		local rewardList = GetExtractMaterialResult(extractItem.name, 1);
		for _, reward in ipairs(rewardList) do
			dc:GiveItem(company, reward.ItemName, reward.ItemCount, true);
			ldm:AddMissionChat('GiveItem', 'GiveItem', { ItemType = reward.ItemName, ItemCount = reward.ItemCount });
		end
	end
	-- 4) 로스터 삭제
	dc:DeleteRoster(roster);
	return dc:Commit('DialogAction:'..env._cur_dialog.name);
end
-- 기계 이름 변경
function LobbyAction_RenameMachine(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_RenameMachine : roster is nil!', company.CompanyName, args.Roster);
		return {Success = false};
	end
	dc:UpdatePCProperty(roster, 'RosterTitle', args.MachineName);
	return {Success = true};
end
-- 기계 수리
function LobbyAction_RepairMachine(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_RepairMachine : roster is nil!', company.CompanyName, args.Roster);
		return {Success = false, Price = 0};
	end
	local isEnable, reason, repairPrice = IsEnableRepairMachine(company, roster, true);
	if not isEnable then
		return {Success = false, Price = 0};
	end
	dc:AddCompanyProperty(company, 'Vill', -1 * repairPrice);
	dc:UpdatePCProperty(roster, 'CP', roster.MaxCP);
	-- 처음 기계 수리 튜토리얼
	if company.Progress.Tutorial.BrokenMachine == 1 then
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/BrokenMachine', 2);
	end
	return {Success = true, Price = repairPrice};
end
-- 기계 모두 수리
function LobbyAction_RepairAllMachine(dc, company, args)
	local totalPrice = 0;
	local rosters = {};
	for _, roster in ipairs(GetAllRoster(company, 'Machine')) do
		local isEnable, reason, repairPrice = IsEnableRepairMachine(company, roster, true);
		if isEnable then
			totalPrice = totalPrice + repairPrice;
			dc:UpdatePCProperty(roster, 'CP', roster.MaxCP);
			table.insert(rosters, roster.RosterKey);
		end
	end
	dc:AddCompanyProperty(company, 'Vill', -1 * totalPrice);
	return {Success = true, Price = totalPrice, Rosters = rosters};
end
-- 기계 AI 강화
function LobbyAction_UpgradeMachineAI(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_UpgradeMachineAI : roster is nil!');
		return {Success = false, Item = 'None', Count = 0};
	end
	local upgradeStage = args.UpgradeType;
	if upgradeStage <= roster.AIUpgradeStage or upgradeStage > roster.AIUpgradeMaxStage then
		return {Success = false, Item = 'None', Count = 0};
	end
	
	local itemCounter = LobbyInventoryItemCounter(company);
	local enable, needItem, needCount = IsEnableMachineAIUpgrade(company, roster, upgradeStage, itemCounter);
	if not enable then
		return {Success = false, Item = needItem or 'None', Count = 0};
	end
	-- 1) 필요 아이템 소모
	if needCount and needCount > 0 then
		dc:TakeItem(GetInventoryItemByType(company, needItem), needCount);
	end
	-- 2) AI 강화
	dc:UpdatePCProperty(roster, 'AIUpgradeStage', upgradeStage);
	dc:UpdatePCProperty(roster, 'JobLv', 1);
	dc:UpdatePCProperty(roster, 'LastJobLv', 0);
	dc:UpdatePCProperty(roster, 'JobExp', 0);
	
	-- 3) 클래스 특성 언락
	local rewardMasteries = GetRewardMasteriesByJobLevel_Machine(company, roster, 1, 1, upgradeStage);
	for _, mastery in ipairs(rewardMasteries) do
		local techName = mastery.name;
		local tech = company.Technique[techName];
		if tech and not tech.Opened then
			dc:UpdateCompanyProperty(company, string.format('Technique/%s/Opened', techName), true);
			dc:UpdateCompanyProperty(company, string.format('Technique/%s/IsNew', techName), true);
		end
	end
	
	-- 4) 강화 특성 선택
	StartLobbyDialog(company, 'UpgradeMachineAI_EntryPoint', {roster_name=args.Roster, upgrade_stage = upgradeStage});
	return {Success = true, Item = needItem or 'None', Count = needCount or 0};
end
-- AI 강화 특성 재선택
function LobbyAction_SelectAIUpgradeMastery(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_SelectAIUpgradeMastery : roster is nil!');
		return {Success = false};
	end
	local enable, upgradeStage = IsNeedSelectAIUpgradeMastery(roster);
	if not enable then
		return {Success = false};
	end
	-- 1) 강화 특성 재선택
	StartLobbyDialog(company, 'UpgradeMachineAI_EntryPoint', {roster_name=args.Roster, upgrade_stage = upgradeStage});
	return {Success = true};
end
------------------------------------------------ 
-- 다이아로그 AI 강화 특성창
------------------------------------------------ 
function ProgressUpgradeMachineAIMasteryAction(ldm, self, company, env, parsedScript)
	local roster = GetRoster(company, parsedScript.RosterName);
	if roster == nil then
		return false;
	end
	local upgradeStage = parsedScript.UpgradeStage;
	if upgradeStage <= 1 or upgradeStage > roster.AIUpgradeMaxStage then
		return false;
	end
	local candidateMasteries = GetMachineAIUpgradeMasteryCandidate(roster, upgradeStage);
	local id, ok, result = ldm:Dialog('ScoutMachine', {UpgradeType = upgradeStage, CandidateMasteries = candidateMasteries, TargetKey = roster.RosterKey});
	
	local dc = ldm:GetDatabaseCommiter();
	dc:UpdatePCProperty(roster, string.format('AIUpgradeMastery%d', upgradeStage-1), result.Mastery);
	
	return dc:Commit('DialogAction:'..env._cur_dialog.name);
end

function LobbyAction_NewAIUpgradeConfirmed(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		return {Success = false};
	end
	local upgradeType = args.UpgradeType;
	local isNew = StringToBool(roster.MachineType.AIUpgradeType[upgradeType].IsNew, false);
	if isNew then
		dc:UpdatePCProperty(roster, string.format('MachineType/AIUpgradeType/%d/IsNew', upgradeType), 'false');
	end
	
	return {Success = true};
end
-- 기계 변경
function LobbyAction_ChangeMachine(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_ChangeMachine : roster is nil!', company.CompanyName, args.Roster);
		return {Success = false, Reward = {}, WaitDialog = false};
	end
	local isEnable, reason, needUnequip, needEquip, needStatement = IsEnableChangeMachine(company, roster, args.OSType, args.Items, LobbyInventoryItemCounter(company))
	if not isEnable then
		LogAndPrint('LobbyAction_ChangeMachine : faied! - reason:', reason);
		return {Success = false, Reward = {}, WaitDialog = false};
	end
	
	-- 1) OS 타입 변경
	if roster.OSType ~= args.OSType then
		dc:UpdatePCProperty(roster, 'OSType', args.OSType);
		for i = 2, roster.AIUpgradeStage do
			dc:UpdatePCProperty(roster, 'AIUpgradeMastery'..(i - 1), 'None');
		end
	end
	
	-- 2) 기존 아이템 소모 (해제 & 회수)
	for equipPos, _ in pairs(needUnequip) do
		dc:UseItem(roster, equipPos, false);
	end
	
	-- 3) 새 아이템 장착
	for equipPos, itemName in pairs(needEquip) do
		local item = GetInventoryItemByType(company, itemName);
		dc:EquipItem(roster, item, equipPos);
	end
	
	-- 4) 기존 아이템 추출
	local totalRewardList = {};
	local rosterList = GetAllRoster(company);
	local itemList = GetClassList('Item');
	for _, itemName in pairs(needUnequip) do
		local itemCls = itemList[itemName];
		local isEnable, reason = IsEnableExtractItem(company, rosterList, itemCls);
		if isEnable then
			local rewardList = GetExtractMaterialResult(itemName, 1);
			for _, reward in ipairs(rewardList) do
				dc:GiveItem(company, reward.ItemName, reward.ItemCount, true);
			end
			table.append(totalRewardList, rewardList);
		end
	end
	
	-- 5) OS변경에 따른 제작서 소모
	if needStatement > 0 then
		local item = GetInventoryItemByType(company, 'Statement_Module');
		if item.Amount < needStatement then
			dc:Cancel();
			return {Success = false, Reward = {}, WaitDialog = false};
		end
		dc:TakeItem(item, needStatement);
	end
	
	-- 5) 강화 특성 재선택
	local waitDialog = false;
	if roster.OSType ~= args.OSType and roster.AIUpgradeStage > 1 then
		waitDialog = true;
		dc:Commit('LobbyAction:ChangeMachine');
		StartLobbyDialog(company, 'ChangeMachineAI_EntryPoint', {roster_name=args.Roster, upgrade_stage = roster.AIUpgradeStage});
	end
	return {Success = true, Reward = totalRewardList, WaitDialog = waitDialog};
end
-- 야수 보관
function LobbyAction_StoreBeast(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_StoreBeast : roster is nil!', company.CompanyName, args.Roster);
		return {Success = false};
	end
	local isEnable = IsEnableStoreBeast(company, roster);
	if not isEnable then
		LogAndPrint('LobbyAction_StoreBeast : failed!');
		return {Success = false};
	end
	dc:UpdatePCProperty(roster, 'Stored', true);
	return {Success = true};
end
function LobbyAction_PickupBeast(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_PickupBeast : roster is nil!', company.CompanyName, args.Roster);
		return {Success = false};
	end
	local isEnable = IsEnablePickupBeast(company, roster);
	if not isEnable then
		LogAndPrint('LobbyAction_PickupBeast : failed!');
		return {Success = false};
	end
	dc:UpdatePCProperty(roster, 'Stored', false);
	return {Success = true};
end
function LobbyAction_SwapBeast(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_SwapBeast : roster is nil!', company.CompanyName, args.Roster);
		return {Success = false};
	end
	local roster2 = GetRoster(company, args.Roster2);
	if roster2 == nil then
		LogAndPrint('LobbyAction_SwapBeast : roster2 is nil!', company.CompanyName, args.Roster2);
		return {Success = false};
	end
	local isEnable = IsEnableSwapBeast(company, roster, roster2);
	if not isEnable then
		LogAndPrint('IsEnableSwapBeast : failed!');
		return {Success = false};
	end
	dc:UpdatePCProperty(roster, 'Stored', true);
	dc:UpdatePCProperty(roster2, 'Stored', false);
	return {Success = true};
end
function LobbyAction_SaveFormationPreset(dc, company, args)
	local slotIndex = args.SlotIndex;
	local lineup = args.Lineup;
	
	if slotIndex <= 0 or slotIndex > #company.FormationPreset then
		return {Success = false};
	end
	if #lineup > company.FormationPreset[slotIndex].MaxSlot then
		return {Success = false};
	end
	local slotKey = 'FormationPreset/'..slotIndex;
	dc:UpdateCompanyProperty(company, slotKey .. '/MaxCount', #lineup);
	dc:UpdateCompanyProperty(company, slotKey .. '/Opened', true);
	for i, roster in ipairs(lineup) do
		local pc = GetClassList('Pc')[roster];
		if pc == nil then
			dc:Cancel();
			return {Success = false};
		end
		
		dc:UpdateCompanyProperty(company, slotKey .. '/'.. i, roster);
	end
	return {Success = true};
end
function LobbyAction_UpdateFormationPresetSlotName(dc, company, args)
	local slotIndex = args.SlotIndex;
	if slotIndex <= 0 or slotIndex > #company.FormationPreset then
		return {Success = false};
	end
	dc:UpdateCompanyProperty(company, 'FormationPreset/'..slotIndex..'/SlotName', args.SlotName);
	return {Success = true};
end
function LobbyAction_DeleteFormationPreset(dc, company, args)
	local slotIndex = args.SlotIndex;
	if slotIndex <= 0 or slotIndex > #company.FormationPreset then
		return {Success = false};
	end
	
	dc:UpdateCompanyProperty(company, 'FormationPreset/'..slotIndex..'/Opened', false);
	dc:UpdateCompanyProperty(company, 'FormationPreset/'..slotIndex..'/SlotName', '');
	return {Success = true};
end
function LobbyAction_SwitchFormationPreset(dc, company, args)
	local slotIndex = args.SlotIndex;
	local slotIndex2 = args.SlotIndex2;
	if slotIndex <= 0 or slotIndex > #company.FormationPreset or slotIndex2 <= 0 or slotIndex2 > #company.FormationPreset then
		return {Success = false};
	end
	
	local rIndex = company.FormationPreset[slotIndex].SlotIndex == 0 and slotIndex or company.FormationPreset[slotIndex].SlotIndex;
	local rIndex2 = company.FormationPreset[slotIndex2].SlotIndex == 0 and slotIndex2 or company.FormationPreset[slotIndex2].SlotIndex;
	
	LogAndPrint('LobbyAction_SwitchFormationPreset', slotIndex, rIndex, slotIndex2, rIndex2);
	
	dc:UpdateCompanyProperty(company, 'FormationPreset/'..slotIndex..'/SlotIndex', rIndex2);
	dc:UpdateCompanyProperty(company, 'FormationPreset/'..slotIndex2..'/SlotIndex', rIndex);
	return {Success = true};
end
-- 로비 가이드 트리거
function LobbyAction_InvokeLobbyGuideTrigger(dc, company, args)
	local guideTriggers = GetEnableLobbyGuideTrigger(company, args.EventType, args.EventArgs);
	if #guideTriggers == 0 then
		return {Success = false};
	end
	StartLobbyDialog(company, 'PlayDialogFunc', {func = 'ProgressLobbyGuideTrigger', args = { EventType = args.EventType, EventArgs = args.EventArgs }});
	return {Success = true}
end
-- 야수 잠금
function LobbyAction_ToggleLockRoster(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		LogAndPrint('LobbyAction_ToggleLockBeast : roster is nil!', company.CompanyName, args.Roster);
		return {Success = false};
	end
	dc:UpdatePCProperty(roster, 'Locked', not roster.Locked);
	return {Success = true};
end
function LobbyAction_StoreItemToWarehouse(dc, company, args)
	local item = GetInventoryItemByInstanceKey(company, args.ItemInvKey);
	if item == nil then
		return {Success = false};
	end
	local succ, err, errArgs = StoreItemToWarehouse(item, args.Count);
	return {Success = succ, ErrorType = err, ErrorArgs = errArgs};
end

function LobbyAction_RetrieveItemFromWarehouse(dc, company, args)
	local item = GetWarehouseItemByInstanceKey(company, args.ItemInvKey);
	if item == nil then
		return {Success = false};
	end
	local succ, err, errArgs = RetrieveItemFromWarehouse(item, args.Count);
	return {Success = succ, ErrorType = err, ErrorArgs = errArgs};
end

function LobbyAction_ApplyWarehouseExchange(dc, company, args)
	local invToWare = table.map(args.InvToWareItems, function(info)
		return {GetInventoryItemByInstanceKey(company, info.ItemInvKey), info.Count};
	end);
	local wareToInv = table.map(args.WareToInvItems, function(info)
		return {GetWarehouseItemByInstanceKey(company, info.ItemInvKey), info.Count}
	end);
	local succ, err, errArgs = ApplyWarehouseItemExchange(company, invToWare, wareToInv);
	return {Success = succ, ErrorType = err, ErrorArgs = errArgs};
end

function LobbyAction_UpdateAbilityPresetSlotName(dc, company, args)
	local slotIndex = args.SlotIndex;
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		return {Success = false};
	end
	
	if slotIndex <= 0 or slotIndex > #roster.AbilityPreset.Preset then
		return {Success = false};
	end
	dc:UpdatePCProperty(roster, 'AbilityPreset/Preset/'..slotIndex..'/Title', args.SlotName);
	return {Success = true};
end

function LobbyAction_SwitchAbilityPreset(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		return {Success = false};
	end
	
	local slotIndex = args.SlotIndex;
	local slotIndex2 = args.SlotIndex2;
	if slotIndex <= 0 or slotIndex > #roster.AbilityPreset.Preset or slotIndex2 <= 0 or slotIndex2 > #roster.AbilityPreset.Preset then
		--LogAndPrint('LobbyAction_SwitchAbilityPreset', slotIndex, #roster.AbilityPreset.Preset, slotIndex2, #roster.AbilityPreset.Preset);
		return {Success = false};
	end
	
	local rIndex = roster.AbilityPreset.Preset[slotIndex].Order;
	local rIndex2 = roster.AbilityPreset.Preset[slotIndex2].Order;
	
	--LogAndPrint('LobbyAction_SwitchAbilityPreset', slotIndex, rIndex, slotIndex2, rIndex2);
	
	dc:UpdatePCProperty(roster, string.format('AbilityPreset/Preset/%d/Order', slotIndex), rIndex2);
	dc:UpdatePCProperty(roster, string.format('AbilityPreset/Preset/%d/Order', slotIndex2), rIndex);
	return {Success = true};
end

function LobbyAction_UpdateActiveAbilityPreset(dc, company, args)
	local roster = GetRoster(company, args.Roster);
	if roster == nil then
		return {Success = false};
	end
	local slot = args.SlotIndex;
	local slotManager = AbilitySlotManager.new(roster, slot, nil, true);
	local abilityList = GetClassList('Ability');
	local truncated = slotManager:GetTruncatedAbilities();
	if #truncated > 0 then
		table.foreach(truncated, function(i, abl) slotManager:Deactivate(abilityList[abl]); end);
	end
	local changes = slotManager:AggregateChanges();
	UpdateRosterAbilitySetting(dc, roster, roster.Object.Job.name, changes, slot, slotManager:GetActiveAbilities());
	dc:UpdatePCProperty(roster, 'AbilityPresetIndex', slot);
	return {Success = true};
end
-- 로비 이벤트 다시보기
function LobbyAction_InvokeLobbyEvent(dc, company, args)
	local lobbyEventClsList = GetClassList('LobbyEvent');
	local lobbyEventCls = SafeIndex(lobbyEventClsList, args.SectionName, 'Images', args.SlotIndex);
	if not lobbyEventCls then
		return {Success = false};
	end
	local env = { _no_action = true };
	env.event_type = lobbyEventCls.Dialog;
	env.lobby_map = lobbyEventCls.Map;
	env.camera_mode = lobbyEventCls.Camera;
	env._auto_fade_in = StringToBool(lobbyEventCls.AutoFadeIn, true);
	StartLobbyDialog(company, 'LobbyEvent_Common', env);
	return {Success = true};
end
-- 퀘스트 미션 다시하기
function LobbyAction_InvokeQuestMission(dc, company, args)
	local stage, progress = GetQuestState(company, args.Quest);
	if stage ~= 'Completed' then
		return {Success = false};
	end
	local questCls = GetClassList('Quest')[args.Quest];
	if not questCls or not questCls.Mission then
		return {Success = false};
	end
	StartMission(company, questCls.Mission.name, { QuestType = questCls.name, TroubleBookEpisode = 'QuestReplay', ChallengerMode = args.ChallengerMode, QuestReplay = true });
	return {Success = true};
end
-- 무기 코스튬 변경
function LobbyAction_ChangeWeaponCostume(dc, company, args)
	local itemAddress = args.ItemAddress;
	local item;
	if itemAddress == 'Inventory' then
		local itemInstanceKey = args.BaseInvKey;
		item = GetInventoryItemByInstanceKey(company, itemInstanceKey);
	elseif itemAddress == 'Equipment' then
		local roster = GetRoster(company, args.Roster);
		if roster then
			item = GetRosterEquipItem(roster, args.EquipPosition);
		end
	end
	if item == nil then
		LogAndPrint('[ChangeWeaponCostume Failed] 대상 아이템을 찾지 못했다. company : ', company.name, ', : args : ', args);
		return {Success = false};
	end
	
	if args.WeaponCostume and args.WeaponCostume ~= 'None' then
		local weaponCostume = company.WeaponCostume[args.WeaponCostume];
		if not weaponCostume or not weaponCostume.Opened then
			return {Success = false};
		end
		if company.Vill < weaponCostume.Vill then
			return {Success = false};
		end
		dc:UpdateItemProperty(item, 'WeaponCostume', weaponCostume.name);
		if not item.Binded then
			dc:UpdateItemProperty(item, 'Binded', true);
		end
		if weaponCostume.Vill > 0 then
			dc:AddCompanyProperty(company, 'Vill', -1 * weaponCostume.Vill);
		end
	else
		dc:UpdateItemProperty(item, 'WeaponCostume', 'None');
	end	
	
	return {Success = true};
end
function LobbyAction_NewWeaponCostumeConfirmed(dc, company, args)
	local checkedList = args.WeaponCostumes;
	for i, name in ipairs(checkedList) do
		dc:UpdateCompanyProperty(company, string.format('WeaponCostume/%s/IsNew', name), false);
	end
	return {Success = true};
end
function LobbyAction_CompanyNameTest(dc, company, args)
	return {Success = CompanyNameDuplicateTest(args.CompanyName)};
end
function LobbyAction_ToggleMailLock(dc, company, args)
	return {Success = UpdateMailProperty(company, args.MailId, 'Lock', args.Lock)};
end