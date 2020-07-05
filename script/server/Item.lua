-----------------------------------------------------------------------
-- 아이템 감정 테스트 함수.
-----------------------------------------------------------------------
function IsIdentifyTest(company, item)
	local isEnable = false;
	local reason = {};
	return isEnable, reason;
end
-----------------------------------------------------------------------
-- 아이템 생성시 랜덤 옵션 
-----------------------------------------------------------------------
function ExecuteIdentifyItem(dc, company, item)
	-- 1. 부여할 옵션 타입을 정한다.+
	local option = GetIdentifyItemOptions(item);
	if not option then
		LogAndPrint('ExecuteIdentifyItem - not option - item:', item.name);
		return false;
	end

	local luck = 0;
	local luckPropertyName = nil;
	local subPropertyName = nil;
	if item.Rank.Weight == 2 or item.Rank.Weight == 3 then
		luck = company.Luck_Identify1;
		luckPropertyName = 'Luck_Identify1';
		subPropertyName = 'Luck_Identify2';
	elseif item.Rank.Weight == 4 then
		luck = company.Luck_Identify2;
		luckPropertyName = 'Luck_Identify2';
		subPropertyName = 'Luck_Identify3';
	elseif item.Rank.Weight == 5 or item.Rank.Weight == 7 then
		luck = company.Luck_Identify3;
		luckPropertyName = 'Luck_Identify3';
		subPropertyName = 'Luck_Identify2';
	end

	-- 2. 해당 옵션을 기반으로 부여할 수치를 정한다.
	-- { Type = status.Type, Value = curValue, PickValue = pickValue, RangeValue = rangeValue}	
	local identifyOptionValueList, ratio = GetIdentifyItemOptionValue(option, luck);
	if #identifyOptionValueList > 5 or #identifyOptionValueList == 0 then
		LogAndPrint('ExecuteIdentifyItem - #identifyOptionValueList:', #identifyOptionValueList, ', item:', item.name);
		return false;
	end
	--2.1 5성아니면 Luck_Identify 올려주기.
	-- ratio 0.9 이상은 판단하다.
	-- Luck_Identify 은 최대치가 50으로 하자.
	-- 에픽 이상 아이템만 적용.
	if luckPropertyName  then
		if ratio > 0.9 then
			-- 5성 - 초기화
			dc:UpdateCompanyProperty(company, luckPropertyName, 0);
			-- '모두 감정하기' 대응을 위한 프로퍼티 임시 반영
			company[luckPropertyName] = 0;
		elseif luck < 100 then
			-- 랜덤 1 ~ 3.
			local addLuck = math.random(2,3);
			dc:AddCompanyProperty(company, luckPropertyName, addLuck);
			dc:AddCompanyProperty(company, subPropertyName, 1);
			-- '모두 감정하기' 대응을 위한 프로퍼티 임시 반영
			company[luckPropertyName] = company[luckPropertyName] + addLuck;
			company[subPropertyName] = company[subPropertyName] + 1;
		end
	end
	
	-- 3. 타이틀 값 저장.
	dc:UpdateItemProperty(item, 'Option/OptionKey', option.name);
	dc:UpdateItemProperty(item, 'Option/Ratio', ratio);
	-- 4. 랜덤 스탯 저장.
	for index, status in ipairs (identifyOptionValueList) do
		dc:UpdateItemProperty(item, string.format('Option/Type%d', index), status.Type);
		dc:UpdateItemProperty(item, string.format('Option/Value%d', index), status.Value);
	end	
	return true;
end
--------------------------------------------------------------
-- 미션 결과창 소모된 아이템 관련
---------------------------------------------------------------
function CalcItemUnequipResult(item, owner)
	if item == nil or item.IsGhost then
		return "Expire";
	end
	
	if not item.Consumable then
		return "Unequip";
	end
	-- 사용 유무 판단
	local itemAbility = item.Ability;
	if itemAbility.IsUseCount 
		and itemAbility.UseCount < itemAbility.MaxUseCount then
		return "Consumed";
	else
		return "Unequip";
	end
end
--------------------------------------------------------------
-- 등가교환
--------------------------------------------------------------
function BuildExchangeOfEquivalentsItemPicker(company, itemCls, rankUp, levelUp)
	local monClsList = GetClassList('Monster');
	
	local testMonsters = {};
	for _, tm in pairs(company.Troublemaker) do
		if tm.Exp > 0 then
			local monCls = monClsList[tm.name];
			table.insert(testMonsters, monCls);
			if monCls.GradeUp ~= '' then
				local upMon = monClsList[monCls.GradeUp];
				if upMon then
					table.insert(testMonsters, upMon);
				end
			end
		end
	end
	
	local targetRankWeight = itemCls.Rank.Weight;
	if rankUp then
		targetRankWeight = targetRankWeight + 1;
	end
	
	local targetMinRequireLv = itemCls.RequireLv;
	local targetMaxRequireLv = itemCls.RequireLv;
	if levelUp then
		if targetMinRequireLv > 0 then	-- 재료템의 경우는 모두 RequireLv가 0이고 Min값을 올리면 안됨
			targetMinRequireLv = targetMinRequireLv + 1;
		end
		targetMaxRequireLv = targetMaxRequireLv + 10;
	end
	
	local retPicker = RandomPicker.new(true);
	retPicker:addChoice(itemCls.Rank.ItemDropRatio, itemCls.name);		-- 자신 추가
	local itemClsList = GetClassList('Item');
	for _, monCls in ipairs(testMonsters) do
		for __, reward in ipairs(monCls.Rewards) do
		(function()
			local rewardItemCls = itemClsList[reward.Item];
			if itemCls.Category.name ~= rewardItemCls.Category.name then
				return;
			end
			if rewardItemCls.Rank.Weight ~= targetRankWeight then
				return;
			end
			if rewardItemCls.RequireLv < targetMinRequireLv or targetMaxRequireLv < rewardItemCls.RequireLv then
				return;
			end
			retPicker:addChoice(rewardItemCls.Rank.ItemDropRatio, rewardItemCls.name);
		end)();
		end
	end
	return retPicker;
end
function TryExchangeOfEquivalents(company, itemName, amount, prop)
	local itemClsList = GetClassList('Item');
	local itemCls = itemClsList[itemName];
	if itemCls == nil then
		return false, itemName, amount, prop;
	end
	local eoePicker = BuildExchangeOfEquivalentsItemPicker(company, itemCls, RandomTest(5), RandomTest(5));
	
	local pickItemName = eoePicker:pick();
	if pickItemName == itemName then
		return false, itemName, amount, prop;
	end
	
	local weightDiff = itemClsList[pickItemName].Rank.Weight - itemCls.Rank.Weight;
	amount = math.max(1, math.floor(amount * (100 - 25 * weightDiff) / 100));
	
	if prop then
		local itemProperties = {};
		IdentifyItemOptionProperties(itemProperties, itemCls, 50);	-- 조금 좋은 옵션이 뽑히게 해줌
		prop = itemProperties;
	end
	return true, pickItemName, amount, prop;
end

function BuildGiveItemConverter(obj)
	local buff_ExchangeOfEquivalents = GetBuff(obj, 'ExchangeOfEquivalents');
	local company = GetCompany(obj);
	
	if not buff_ExchangeOfEquivalents or not company then
		return function(giveItem)	-- 아무 처리안함
			return giveItem;
		end
	end
	local buffPicker = RandomBuffPicker.new(obj, Linq.new(GetClassList('Buff_Positive'))
		:select(function(pair) return pair[1]; end)
		:toList());
	return function(originalGiveItem)
		local retActions = {};
		local prob = buff_ExchangeOfEquivalents.ApplyAmount;
		local additiveEffect = {};
		if RandomTest(prob) then
			local succ, newItem, newAmount, newProp = TryExchangeOfEquivalents(company, originalGiveItem.item_type, originalGiveItem.amount, originalGiveItem.item_properties);
			if succ then
				local giveItemArg = {};
				giveItemArg.message = 'GiveItemExchangeOfEquivalents';
				giveItemArg.original_item = originalGiveItem.item_type;
				giveItemArg.original_amount = originalGiveItem.amount;
				giveItemArg.original_properties = originalGiveItem.item_properties;
				giveItemArg.additive_effect = additiveEffect;
				originalGiveItem.item_type = newItem;
				originalGiveItem.amount = newAmount;
				originalGiveItem.item_properties = newProp;
				originalGiveItem.give_item_args = giveItemArg;
				
				local addBuff = buffPicker:PickBuff();
				if addBuff then
					InsertBuffActions(retActions, obj, obj, addBuff, 1);
				end
			end
		end
		table.insert(retActions, originalGiveItem);
		return unpack(retActions);
	end
end