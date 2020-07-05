function WORLD_UPDATE()
	-- 죽지않고 계속 유지되는 스크립트임
	local lastRiskUpdateTime = os.time();
	local ZoneRiskApplyIntervalSec = 3600;
	
	LogAndPrint('Start World Update');
	
	local shopUpdateDuration = GetSystemConstant('SHOP_ITEM_UPDATE_DURATION');
	local safetyFeverDuration = GetSystemConstant('ZONE_SAFETY_FEVER_DURATION');
	local foodUpdateDuration = GetSystemConstant('FOOD_RECOMMEND_UPDATE_DURATION');
	local mailboxExpireUpdateDuration = GetSystemConstant('MailboxExpireCheckDuration');
	local mailboxReturnUpdateDuration = GetSystemConstant('MailboxReturnCheckDuration');
		
	while true do
		local worldProperty = GetWorldProperty();
		-- 치안도 감소처리
		local now = os.time();
		if not IsSingleplayMode() then
			if now - lastRiskUpdateTime > ZoneRiskApplyIntervalSec then
				lastRiskUpdateTime = now;
				local addProperties = {};
				for zoneType, zoneProperty in pairs(worldProperty.ZoneState) do
					if not zoneProperty.SafetyFever then
						-- 지역의 위험도만큼씩 치안도를 내려야한다.
						local noneFeverTime = now - (zoneProperty.FeverTime + safetyFeverDuration);
						local riskRatio = math.max(1 - math.min(math.floor(noneFeverTime / (24 * 3600)) / 4, 1), 0);
						LogAndPrint('Safty Reduce!', 'NoneFeverTime', noneFeverTime, riskRatio);
						table.insert(addProperties, {Key = string.format('ZoneState/%s/Safty', zoneType), Value = -zoneProperty.Risk * riskRatio, Min = 0, Max = zoneProperty.MaxSafty});
					end
				end
				AddWorldPropertyMulti(addProperties, 'ApplyWorldRisk');
			end
			
			-- 피버 종료
			for zoneType, zoneProperty in pairs(worldProperty.ZoneState) do
				if zoneProperty.SafetyFever and now - zoneProperty.FeverTime > safetyFeverDuration then
					local updateProperties = {};
					zoneProperty.SafetyFever = false;	-- 미리 갱신
					local resetSafty = math.random() * 0.25 + 0.5;	-- 0.5 ~ 0.75
					table.insert(updateProperties, MakeDBUpdateCommand(string.format('ZoneState/%s/Safty', zoneType), zoneProperty.MaxSafty * resetSafty));
					table.insert(updateProperties, MakeDBUpdateCommand(string.format('ZoneState/%s/SafetyFever', zoneType), false));
					UpdateWorldPropertyMulti(updateProperties, 'SafetyFeverEnd');
				end
			end
		end
		
		-- 상점 아이템 옵션 갱신
		if now - worldProperty.ShopOptionRefreshTime > shopUpdateDuration then
			local succ, err = pcall(UpdateShopItemList);
			if not succ then
				LogAndPrint('WORLD_UPDATE', err);
			end
			worldProperty.ShopOptionRefreshTime = now;		-- 디비가 치기전에 먼저 갱신해버리기
		end
		
		-- 음식 추천 갱신
		if now - worldProperty.FoodRecommendRefreshTime > foodUpdateDuration then
			local succ, err = pcall(UpdateFoodRecommendList);
			if not succ then
				LogAndPrint('WORLD_UPDATE', err);
			end
			worldProperty.FoodRecommendRefreshTime = now;		-- 디비가 치기전에 먼저 갱신해버리기
		end
		
		-- 시스템 메일 만료 갱신
		if now - worldProperty.MailboxExpireCheckTime > mailboxExpireUpdateDuration then
			UpdateWorldProperty('MailboxExpireCheckTime', now, 'Mailbox Regular Update Routine');
			RemoveExpiredMails();
			worldProperty.MailboxExpireCheckTime = now;		-- 디비가 치기전에 먼저 갱신해버리기
		end
		
		-- 메일 자동 반송
		if now - worldProperty.MailboxReturnCheckTime > mailboxReturnUpdateDuration then
			UpdateWorldProperty('MailboxReturnCheckTime', now, 'Mailbox Return Update Routine');
			UpdateNeedReturnMails();
			worldProperty.MailboxReturnCheckTime = now;		-- 디비가 치기전에 먼저 갱신해버리기
		end
		
		coroutine.yield();
	end
end

function MakeDBUpdateCommand(key, value)
	return {Key = key, Value = value};
end

function UpdateShopItemList()
	local updateProperties = {};
	local shopList = GetClassList('Shop');
	local itemClsList = GetClassList('Item');
	
	table.insert(updateProperties, MakeDBUpdateCommand('ShopOptionRefreshTime', os.time()));
	
	local AddItemOptionCommand = function(keyHeader, item)
		if not StringToBool(item.RandomOption) then
			return;
		end
		local itemCls = itemClsList[item.Item];
		if itemCls == nil then
			LogAndPrint('UpdateShopItemList', 'No Item!!!', item.Item);
			return;
		end
		local option = GetIdentifyItemOptions(itemCls);
		local identifyOptionValueList, ratio = SampleShopItemOption(option);
		local propertyKeyHeader = keyHeader .. 'Option/';
		table.insert(updateProperties, MakeDBUpdateCommand(propertyKeyHeader .. 'OptionKey', option.name));
		table.insert(updateProperties, MakeDBUpdateCommand(propertyKeyHeader .. 'Ratio', ratio));
		for index, status in ipairs (identifyOptionValueList) do
			table.insert(updateProperties, MakeDBUpdateCommand(propertyKeyHeader .. 'Type' .. index, status.Type));
			table.insert(updateProperties, MakeDBUpdateCommand(propertyKeyHeader .. 'Value' .. index, status.Value));
		end
		for j = #identifyOptionValueList + 1, 5 do	-- 나머지 옵션을 클리어해줌
			table.insert(updateProperties, MakeDBUpdateCommand(propertyKeyHeader .. 'Type' .. j, 'None'));
			table.insert(updateProperties, MakeDBUpdateCommand(propertyKeyHeader .. 'Value' .. j, 0));
		end
	end;
	
	local AddRandomPriceCommand = function(keyHeader, item)
		if item.RandomPriceScript == 'None' then
			return;
		end
		local priceFunc = _G[item.RandomPriceScript];
		if priceFunc then
			local itemCls = itemClsList[item.Item];
			local newPrice = priceFunc(itemCls, item.Price);
			table.insert(updateProperties, MakeDBUpdateCommand(keyHeader .. 'Price', newPrice));
		else	
			table.insert(updateProperties, MakeDBUpdateCommand(keyHeader .. 'Price', item.Price));
		end
	end;
	
	for key, shopCls in pairs(shopList) do
		local itemSlotMap = {};
		local itemNoneSlotMap = {};
		for i, item in ipairs(shopCls.ItemList) do
			(function()
				if item.Slot == nil or item.Rate == nil then
					table.insert(itemNoneSlotMap, {Index = i, Item = item});
					return;
				end
				if itemSlotMap[item.Slot] == nil then
					itemSlotMap[item.Slot] = RandomPicker.new(false);
				end
				itemSlotMap[item.Slot]:addChoice(item.Rate, {Index = i, Item = item});
			end)();
		end
		for slot, itemPicker in pairs(itemSlotMap) do
			local rank = 0;
			while itemPicker:size() > 0 do 
			(function()
				local info = itemPicker:pick();
				local i = info.Index;
				local item = info.Item;
				
				local keyHeader = string.format('ShopOption/%s/ItemList/%d/', key, i);
				
				table.insert(updateProperties, MakeDBUpdateCommand(keyHeader .. 'Rate', rank));
				rank = rank + 1;
				AddItemOptionCommand(keyHeader, item);
				AddRandomPriceCommand(keyHeader, item);
			end)()
			end
		end
		for _, info in ipairs(itemNoneSlotMap) do
			(function()
				local i = info.Index;
				local item = info.Item;
				local keyHeader = string.format('ShopOption/%s/ItemList/%d/', key, i);
				AddItemOptionCommand(keyHeader, item);
				AddRandomPriceCommand(keyHeader, item);
			end)();
		end
	end
	UpdateWorldPropertyMulti(updateProperties, 'ShopItemUpdate');
end

function UpdateFoodRecommendList()
	local updateProperties = {};
	local foodList = GetClassList('Food');
	local foodShopList = GetClassList('FoodShop');
	local foodSetList = GetClassList('FoodSet');
	
	table.insert(updateProperties, MakeDBUpdateCommand('FoodRecommendRefreshTime', os.time()));
		
	for key, foodShopCls in pairs(foodShopList) do
		local setList = foodShopCls.RecommendSetList;
		local menuList = {};
		
		if #setList > 0 and RandomTest(25) then
			-- 추천 가능한 세트 메뉴 중에서 
			local setCls = setList[math.random(1, #setList)];
			local columnList = { 'Food1', 'Food2', 'Food3' };
			for _, column in ipairs(columnList) do
				local food = setCls[column];
				if food and food ~= 'None' then
					table.insert(menuList, food);
				end
			end
		else
			-- 추천 가능한 음료 중 1개, 요리/곁들임 요리 중 1개
			local drinkList = {};
			local dishList = {};
			for _, menuInfo in ipairs(foodShopCls.MenuList) do
				if menuInfo.Friendship == 'None' and menuInfo.Checker == 'None' then
					local foodCls = foodList[menuInfo.Food];
					if foodCls then
						if foodCls.Type.name == 'Beverage' then
							table.insert(drinkList, foodCls.name);
						else
							table.insert(dishList, foodCls.name);						
						end
					end
				end
			end
			if #drinkList > 0 then
				table.insert(menuList, drinkList[math.random(1, #drinkList)]);
			end
			if #dishList > 0 then
				table.insert(menuList, dishList[math.random(1, #dishList)]);
			end
		end
		
		-- 최대 3개까지
		for i = 1, 3 do
			local food = menuList[i] or 'None';
			local key = string.format('FoodRecommend/%s/%d', key, i);
			table.insert(updateProperties, MakeDBUpdateCommand(key, food));
		end
	end
	UpdateWorldPropertyMulti(updateProperties, 'FoodRecommendUpdate');
end

function OnUpdateWorldProperty_Supervisor(keys, commitMsg)
	local worldProperty = GetWorldProperty();
	for _, keyChain in ipairs(keys) do
		
		-- 치안도 피버 체크
		local zoneSaftyKey = string.match(keyChain, '^ZoneState/([%d%s%w]+)/Safty$');
		if zoneSaftyKey then
			local zoneProp = worldProperty.ZoneState[zoneSaftyKey];
			if zoneProp.Safty == zoneProp.MaxSafty and not zoneProp.SafetyFever then
				zoneProp.SafetyFever = true;	-- 미리 갱신
				zoneProp.FeverTime = os.time();
				
				local updateProperties = {};
				table.insert(updateProperties, MakeDBUpdateCommand(string.format('ZoneState/%s/SafetyFever', zoneSaftyKey), true));
				table.insert(updateProperties, MakeDBUpdateCommand(string.format('ZoneState/%s/FeverTime', zoneSaftyKey), zoneProp.FeverTime));
				UpdateWorldPropertyMulti(updateProperties, 'SafetyFeverStart');
			end
		end
	end
end