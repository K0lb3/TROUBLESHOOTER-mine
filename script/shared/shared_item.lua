function MakeItemTitle(itemType, optionKey, level)
	local itemCls = GetClassList('Item')[itemType];
	local title = itemCls.Base_Title;
	
	-- 옵션 이름 표시.
	if optionKey and optionKey ~= 'None' then
		local identifyCls = GetClassList('ItemIdentify')[optionKey];
		if identifyCls and identifyCls.name then
			title = string.format(identifyCls.Title, title);
		end
	end
	
	-- 강화 수치 표시.
	if level > 0 then
		title = string.format('%s +%s', title, level);
	end
	return title;
end
function MakeItemTitleWithProperties(itemType, properties)
	local optionKey = 'None';
	local level = 0;
	for key, vale in pairs(properties) do
		if key == 'Option/OptionKey' then
			optionKey = value;
		elseif key == 'Lv' then
			level = tonumber(value);
		end
	end
	return MakeItemTitle(itemType, optionKey, level);
end
function GetItemTitle(obj, arg)
	return MakeItemTitle(obj.name, obj.Option.OptionKey, obj.Lv);
end
-----------------------------------------------------------------
-- 아이템 별 강화 수치에 따른 아이템 수치 증가 폭 결정 함수.
-----------------------------------------------------------------
function GetItemUpgradeStatus(item, lv)
	local base_status = GetBaseStatusByItem(item, item.MainStatus);
	local result = 0;
	if lv == 0 or item.Type.BaseUpgradeStatus == 0 then
		return result;
	end
	if item.MainStatus == 'None' then
		return result;
	end
	-- 최대 레벨.
	if lv > item.MaxLv then
		lv = item.MaxLv;
	end
	
	-- item.MaxLv의 배수로 보정 후 적용
	local maxUpgradeStatus = ( item.Type.BaseUpgradeStatus + item.Type.IncreaseUpgradeStatus * math.floor(item.RequireLv/5)) * 10;
	result = math.ceil(maxUpgradeStatus / item.MaxLv) * lv;
	return ValueLimiting(item.MainStatus, result);
end
-------------------------------------------------------------
-- 강화 가능한지 여부.
-------------------------------------------------------------
function IsEnableUpgradeItem(item, itemCountAcquirer)

	local reason = {};
	local isEnable = true;	
	-- 유효 데이터 처리
	if not item then
		table.insert(reason, 'NotExistItem');
		return false, reason;
	end
	-- 1. 성장할 스탯 여부
	if item.MainStatus == 'None' then
		table.insert(reason, 'NotExistItemMainStatus');
		isEnable = false;
	end
	-- 2. 최대 레벨 여부
	if item.Lv >= item.MaxLv then
		table.insert(reason, 'ItemMaxLvReached');
		isEnable = false;
	end
	-- 3. 카테고리에 의한 강화 가능성 체크
	if not item.Category.IsUpgrade then
		isEnable = false;
		table.insert(reason, 'NotUpgradableItemCategory');
	end
	-- 4. 등급에 의한 강화 가능성 체크
	if not item.Rank.Upgradable then
		isEnable = false;
		table.insert(reason, 'NotUpgradableItemRank');
	end
	-- 5. 재료 체크
	local materialList = GetItemUpgradeMaterial(item);
	for i = 1, #materialList do
		local curMaterialName = materialList[i].Item;
		local curMaterialCount = materialList[i].Amount;
		-- 인벤토리에서 같은 아이템을 찾자 --
		local inventoryMaterialCount = itemCountAcquirer(curMaterialName);
		if inventoryMaterialCount < curMaterialCount then
			isEnable = false;
			table.insert(reason, 'NotEnoughMaterial');
			break;
		end
	end
	return isEnable, reason;
end
-------------------------------------------------------------
-- 분해 가능한지 여부.
-------------------------------------------------------------
function IsEnableDismantleItem(item)

	local reason = {};
	local isEnable = true;	

	-- 유효 데이터 처리
	if not item then
		table.insert(reason, 'NotExistItem');
		return false, reason;
	end
	-- 2. 카테고리에 의한 분해 가능성 체크
	if not item.Category.IsDismantle then
		isEnable = false;
		table.insert(reason, 'NotDismantleItemCategory');
	end
	-- 3. 등급에 의한 분해 가능성 체크
	if not item.Rank.Dismantle then
		isEnable = false;
		table.insert(reason, 'NotDismantleItemRank');
	end
	-- 4. 보호 상태에 의한 분해 가능성 체크
	if item.Protected then
		isEnable = false;
		table.insert(reason, 'ProtectedItem');
	end
	return isEnable, reason;
end
-------------------------------------------------------------
-- 제작 가능한지 여부.
-------------------------------------------------------------
function IsAbleToCraftItem(company, rosters, item)
	local reason = {};
	local isEnable = true;	
	
	-- 언락 처리.
	if not StringToBool(company.WorkshopMenu.Upgrade.Opened, false) then
		table.insert(reason, 'NotEnableUseCraft');
		return false, reason;
	end
	
	-- 유효 데이터 처리
	if not item then
		table.insert(reason, 'NotExistItem');
		return false, reason;
	end
	if craftCount and craftCount <= 0 then
		table.insert(reason, 'InvalidCount');
		return false, reason;
	end
	-- 1. 레시피 존재 여부.
	local recipeList = GetClassList('Recipe');
	local curRecipe = recipeList[item.name];
	if not curRecipe then
		table.insert(reason, 'NotExistItemRecipe');
		return false, reason;
	end
	-- 2. 레시피 제작 가능 타입 여부.
	local companyCraftSkillLevelTable = GetCompanyCraftSkillLevelTable(rosters)
	local curCraftSkillLevel = companyCraftSkillLevelTable[curRecipe.Category];
	if not curCraftSkillLevel then
		curCraftSkillLevel = 0;
	end
	if curCraftSkillLevel < curRecipe.RequireLv then
		table.insert(reason, 'NotEnoughRecipeRequireLv');
		isEnable = false;
	end
	-- 3. 레시피 오픈 여부.	
	if not company.Recipe[curRecipe.name].Opened then
		table.insert(reason, 'NotOpenedRecipe');
		isEnable = false;
	end
	return isEnable, reason;
end
function IsEnableCraftItem(company, rosters, item, craftCount, itemCountAcquirer, inventoryCount)
	local isEnable, reason = IsAbleToCraftItem(company, rosters, item);
	
	local recipeList = GetClassList('Recipe');
	local curRecipe = recipeList[item.name];
	
	-- 4. 재료 체크
	local materialList = curRecipe.RequireMaterials;
	for i = 1, #materialList do
		local curMaterialName = materialList[i].Item;
		local curMaterialCount = materialList[i].Amount;
		-- 인벤토리에서 같은 아이템을 찾자 --
		local inventoryMaterialCount = itemCountAcquirer(curMaterialName);
		if inventoryMaterialCount < curMaterialCount * craftCount then
			isEnable = false;
			table.insert(reason, 'NotEnoughMaterial');
			break;
		end
	end
	-- 5. 인벤토리 체크
	if inventoryCount ~= nil then
		local item = GetClassList('Item')[curRecipe.name];
		if item.Stackable then
			-- 스택 체크
			local curCount = itemCountAcquirer(item.name);
			if curCount + craftCount > item.MaxStack then
				isEnable = false;
				table.insert(reason, 'NotEnoughStack');
			end
			-- 인벤토리에 새로 추가가 필요한 아이템
			if curCount == 0 and inventoryCount + 1 > company.MaxInventoryItemCount then
				isEnable = false;
				table.insert(reason, 'NotEnoughInventory');
			end
		else
			-- 논스택 아이템
			if inventoryCount + craftCount > company.MaxInventoryItemCount  then
				isEnable = false;
				table.insert(reason, 'NotEnoughInventory');
			end
		end
	end
	
	return isEnable, reason;
end
-------------------------------------------------------------
-- 추출 재료 개수
-------------------------------------------------------------
function GetExtractMaterial(itemName)
	local list = {};
	local recipeList = GetClassList('Recipe');
	-- 1. 레시피 존재 여부
	local recipe = GetWithoutError(recipeList, itemName);
	if not recipe then
		return {};
	end
	-- 2. 재료 아이템
	for _, info in ipairs(recipe.RequireMaterials) do
		local minAmount = 0;
		local maxAmount = 1;
		if info.Amount > 1 then
			minAmount = math.round(0.4 * info.Amount);
			maxAmount = math.round(0.6 * info.Amount);
		end
		table.insert(list, { Item = info.Item, MinAmount = minAmount, MaxAmount = maxAmount });
	end
	return list;
end
-------------------------------------------------------------
-- 추출 가능한지 여부.
-------------------------------------------------------------
function IsEnableExtractItem(company, roster, item, extractCount, itemCountAcquirer)

	local reason = {};
	local isEnable = true;	
	
	-- 언락 처리.
	if not StringToBool(company.WorkshopMenu.Upgrade.Opened, false) then
		table.insert(reason, 'NotEnableUseCraft');
		return false, reason;
	end	
	-- 유효 데이터 처리
	if not item then
		table.insert(reason, 'NotExistItem');
		return false, reason;
	end
	if extractCount and extractCount <= 0 then
		table.insert(reason, 'InvalidCount');
		return false, reason;
	end
	
	-- 1. 인벤토리 개수 체크
	if extractCount ~= nil then
		local inventoryMaterialCount = itemCountAcquirer(item.name);
		if extractCount > inventoryMaterialCount then
			isEnable = false;
			table.insert(reason, 'OverCountExtractItem');
		end
	end
	-- 2. 카테고리에 의한 분해 가능성 체크
	if not item.Category.IsExtractable then
		isEnable = false;
		table.insert(reason, 'NotExtractableItemCategory');
	end
	-- 3. 등급에 의한 분해 가능성 체크
	if not item.Rank.Extractable then
		isEnable = false;
		table.insert(reason, 'NotExtractableItemRank');
	end
	-- 4. 타입에 의한 분해 가능성 체크
	if not item.Type.Extractable then
		isEnable = false;
		table.insert(reason, 'NotExtractableItemType');
	end	
	-- 5. 보호 상태에 의한 분해 가능성 체크
	if item.Protected then
		isEnable = false;
		table.insert(reason, 'ProtectedItem');
	end
	-- 7. 레시피 존재 여부.	
	local recipe = GetWithoutError(company.Recipe, item.name);
	if not recipe then
		table.insert(reason, 'NotExistRecipe');
		isEnable = false;
		return isEnable, reason;
	end	
	-- 8. 레시피 제작 가능 타입 여부.
	local companyCraftSkillLevelTable = GetCompanyCraftSkillLevelTable(roster)
	local craftSkillLevel = companyCraftSkillLevelTable[recipe.Category];
	if not craftSkillLevel then
		craftSkillLevel = 0;
	end
	if craftSkillLevel < recipe.RequireLv then
		table.insert(reason, 'NotEnoughRecipeRequireLv');
		isEnable = false;
	end
	-- 9. 레시피 오픈 여부.
	if not recipe.Opened then
		table.insert(reason, 'NotOpenedRecipe');
		isEnable = false;
	end

	return isEnable, reason;
end
----------------------------------------------------------------
-- 현재 추출 가능한 아이템 수
----------------------------------------------------------------
function GetEnableExtractCount(company, itemName, itemCountAcquirer, inventoryCount)
	local result = 0;
	local itemList = GetClassList('Item');
	local materialList = GetExtractMaterial(itemName);
	
	-- 1. 아이템 개수 체크
	local itemCount = itemCountAcquirer(itemName);
	local curItem = itemList[itemName];
	if not curItem.Stackable and itemCount > 0 then
		itemCount = 1;
	end
	result = itemCount;
	
	-- 2. 인벤토리 개수 체크 (아이템 소모로 줄어드는 공간은 체크하지 않음)
	local remainInventoryCount = company.MaxInventoryItemCount - inventoryCount;
	local needInventoryCount = 0;
	for _, info in ipairs(materialList) do
		local curMaterialItem = itemList[info.Item];
		local curMaterialCount = info.MaxAmount;
		if curMaterialItem.Stackable then
			local curCount = itemCountAcquirer(curMaterialItem.name);
			if curCount == 0 then -- 인벤토리에 새로 추가가 필요한 아이템
				remainInventoryCount = remainInventoryCount - 1;
			end
		else
			needInventoryCount = needInventoryCount + curMaterialCount;
		end
	end
	-- Stackable 아이템이 추가될 공간도 부족하다.
	if remainInventoryCount < 0 then
		return 0;
	end	
	if needInventoryCount > 0 then
		local itemCountByInventory = math.floor(remainInventoryCount / needInventoryCount);
		result = math.min(result, itemCountByInventory);
	end

	-- 3. 아이템 스택 개수 체크
	for _, info in ipairs(materialList) do
		local curMaterialItem = itemList[info.Item];
		local curMaterialCount = info.MaxAmount;
		if curMaterialItem.Stackable then
			local curCount = itemCountAcquirer(curMaterialItem.name);
			local maxCount = curMaterialItem.MaxStack - curCount;
			local itemCountByStack = math.floor(maxCount / curMaterialCount);
			result = math.min(result, itemCountByStack);
		end
	end

	return result;
end
----------------------------------------------------------------
-- 현재 제작 가능한 아이템 수
----------------------------------------------------------------
function GetEnableCraftCount(company, recipe, itemCountAcquirer, inventoryCount)
	local result = 0;
	-- 1. 재료 체크
	local materialList = recipe.RequireMaterials;
	for i = 1, #materialList do
		local curMaterialName = materialList[i].Item;
		local curMaterialCount = materialList[i].Amount;
		local inventoryMaterialCount = itemCountAcquirer(curMaterialName);
		local enableCraftCountByMaterial = math.floor(inventoryMaterialCount/curMaterialCount);
		if i == 1 then
			result = enableCraftCountByMaterial;
		else
			result = math.min(result, enableCraftCountByMaterial);
		end
	end
	-- 2. 인벤토리 체크 (재료 소모로 줄어드는 공간은 체크하지 않음)
	if inventoryCount ~= nil then
		local item = GetClassList('Item')[recipe.name];
		local maxCount = 0;
		if item.Stackable then
			local curCount = itemCountAcquirer(item.name);
			if curCount > 0 then	-- 이미 인벤토리에 있는 아이템
				maxCount = item.MaxStack - curCount;
			elseif inventoryCount < company.MaxInventoryItemCount then	-- 인벤토리에 새로 추가가 필요한 아이템
				maxCount = item.MaxStack;
			else	-- 인벤토리에 추가가 안되는 상황
				maxCount = 0;
			end
		else
			maxCount = company.MaxInventoryItemCount - inventoryCount;
		end
		result = math.min(result, maxCount);
	end
	return result;
end
--------------------------------------------------------------------------------
--  회사 제작 최대 레벨 테이블 만들기.
--------------------------------------------------------------------------------
function GetCompanyCraftSkillLevelTable(roster)
	local list = {};
	for _, pcInfo in ipairs(roster) do
		for _, profession in ipairs(pcInfo.Profession) do
			if list[profession.Type] == nil then
				list[profession.Type] = profession.Lv;
			elseif list[profession.Type] < profession.Lv then
				list[profession.Type] = profession.Lv;
			end
		end
	end
	return list;
end
----------------------------------------------------------------
-- 아이템 옵션 스탯
----------------------------------------------------------------
function GetItemOptionStatus(item, arg)
	local result = 0;
	local optionMaxCount = item.Rank.OptionMaxCount;
	if optionMaxCount == 0 then
		return result;
	end
	for i = 1, 5 do
		local typeKey = 'Type'..i;
		local valueKey = 'Value'..i;
		if item.Option[typeKey] == arg then
			result = result + item.Option[valueKey];
		end
	end
	return result;
end
----------------------------------------------------------------
-- 장착 가능한 아이템 인지 ( 상점 용 ) = 지금 당장 차는게 아니고 훗날 찰수 있는지 여부.
----------------------------------------------------------------
function IsEnableEquipItem_EnableEquipCompare(obj, item, levelCheck)
	local equipPosList = item.Type.EquipmentPosition;
	if #equipPosList == 0 or equipPosList[1] == 'None' then
		return false;
	end
	for _, equipPos in ipairs(equipPosList) do
		local enableEquipType = 'EnableEquip'..equipPos;
		for index, value in ipairs (obj[enableEquipType]) do
			if value == item.Type.name then
				if not levelCheck or obj.Lv >= item.RequireLv then
					return true;
				end
			end
		end
	end
	return false;
end
--------------------------------------------------------------
-- 장착 가능한 아이템 인지
---------------------------------------------------------------
function IsEnableEquipItem(obj, item, equipPosition)
	local equipPosList = item.Type.EquipmentPosition;
	if #equipPosList == 0 or equipPosList[1] == 'None' then
		return false;
	end
	if obj.Lv < item.RequireLv then
		return false;
	end	
	if obj.Race.name == 'Machine' then
		if equipPosition == nil then
			equipPosition = equipPosList[1];
		end	
		local prevItem = SafeIndex(obj, equipPosition);
		local prevItemLoad = SafeIndex(prevItem, 'Load') or 0;
		local prevItemMaximumLoad = SafeIndex(prevItem, 'MaximumLoad') or 0;
		local nextLoad = obj.Load - prevItemLoad + item.Load;
		local nextMaximumLoad = obj.MaximumLoad - prevItemMaximumLoad + item.MaximumLoad;
		if nextLoad > nextMaximumLoad then
			return false;
		end
	end	
	for _, equipPos in ipairs(equipPosList) do
		local enableEquipType = 'EnableEquip'..equipPos;
		for index, value in ipairs (obj[enableEquipType]) do
			if value == item.Type.name then
				return true;
			end
		end
	end
	return false;
end
--------------------------------------------------------------
-- 자동 장착을 위한 아이템 슬롯 찾기
---------------------------------------------------------------
function IsEnableEquipPos(obj, equipPos)
	local checkFunc = _G['IsEnableEquipPos_'..equipPos];
	if checkFunc and not checkFunc(obj, equipPos) then
		return false;
	end
	return true;
end
function IsEnableEquipPos_EnableEquip(obj, slotName)
	local enableEquip = GetWithoutError(obj, 'EnableEquip'..slotName);
	if enableEquip and #enableEquip > 0 then
		return true;
	else
		return false;
	end
end
function IsEnableEquipPos_HasMastery(obj, masteryName)
	local masteryTable = GetMastery(obj);
	if not GetMasteryMastered(masteryTable, masteryName) then
		return false;
	end
	return true;
end
function IsEnableEquipPos_Weapon2(obj, equipPos)
	return IsEnableEquipPos_EnableEquip(obj, 'Weapon2');
end
function IsEnableEquipPos_AlchemyBag(obj, equipPos)
	return IsEnableEquipPos_HasMastery(obj, 'AlchemyBag');
end
function IsEnableEquipPos_GrenadeBag(obj, equipPos)
	return IsEnableEquipPos_HasMastery(obj, 'GrenadeBag');
end
function IsEnableEquipPos_DoubleGear(obj, equipPos)
	return IsEnableEquipPos_HasMastery(obj, 'DoubleGear');
end
function IsEnableEquipPos_Module_AuxiliaryWeapon(obj, equipPos)
	return IsEnableEquipPos_HasMastery(obj, 'Module_AuxiliaryWeapon');
end
function IsEnableEquipPos_Module_AssistEquipment(obj, equipPos)
	return IsEnableEquipPos_HasMastery(obj, 'Module_AssistEquipment');
end

function IsEnableEquipPosItem(obj, equipPos, item)
	local enableEquip = GetWithoutError(obj, 'EnableEquip'..equipPos);
	if enableEquip and #enableEquip > 0 then
		for index, value in ipairs(enableEquip) do
			if value == item.Type.name then
				return true;
			end
		end
	end
	return false;
end
function GetAutoEquipmentPosition(obj, item, checkUseCount)
	local equipPosList = item.Type.EquipmentPosition;
	if #equipPosList == 0 or equipPosList[1] == 'None' then
		return nil;
	end
	local enableEquipPosList = {};
	for _, equipPos in ipairs(equipPosList) do
		if IsEnableEquipPos(obj, equipPos) then
			table.insert(enableEquipPosList, equipPos);
		end
	end
	-- 아이템이 장착 가능한 위치만 필터링 (없으면 원래 목록으로)
	local enableEquipPosListByItem = table.filter(enableEquipPosList, function(equipPos)
		return IsEnableEquipPosItem(obj, equipPos, item);
	end);
	if #enableEquipPosListByItem > 0 then
		enableEquipPosList = enableEquipPosListByItem;
	end
	-- 같은 아이템이 장착된 슬롯이 있으면 그걸 줌 (다른 슬롯에 중복 장착이 안 되므로)
	for _, equipPos in ipairs(enableEquipPosList) do
		local equipItem = GetWithoutError(obj, equipPos);
		if equipItem and equipItem.name and equipItem.name == item.name then
			return equipPos;
		end
	end
	-- 비어 있는 슬롯이 있으면 일단 그걸 준다.
	for _, equipPos in ipairs(enableEquipPosList) do
		local equipItem = GetWithoutError(obj, equipPos);
		if equipItem == nil or equipItem.name == nil then
			return equipPos;
		end
		if checkUseCount then
			-- 어빌리티의 UseCount가 0이면, 없는 척 하고 준다.
			local ability = equipItem.Ability;
			if ability and ability.name and ability.IsUseCount and ability.UseCount == 0 then
				return equipPos;
			end
		end
	end
	-- 비어 있는 슬롯이 없으면 그냥 처음 슬롯으로
	return enableEquipPosList[1];
end
--------------------------------------------------------------
-- 비교 대상 아이템 찾기
---------------------------------------------------------------
function GetCompareTargetEquipItem(obj, item, equipPos)
	if equipPos ~= nil then
		return GetWithoutError(obj, equipPos);
	end
	local equipPosList = item.Type.EquipmentPosition;
	if #equipPosList == 0 or equipPosList[1] == 'None' then
		return nil;
	end
	for _, equipPos in ipairs(equipPosList) do
		local equipItem = GetWithoutError(obj, equipPos);
		if equipItem and equipItem.name then
			return equipItem;
		end
	end
	return nil;
end
--------------------------------------------------------------
-- 착용 가능한 아이템 타입인지
---------------------------------------------------------------
function CalculatedProperty_ItemTypeEquipable(itemType, arg)
	local equipPosList = itemType.EquipmentPosition;
	if #equipPosList == 0 or equipPosList[1] == 'None' then
		return false;
	end
	return true;
end
function CalculatedProperty_BaseEquipmentPosition(itemType, arg)
	local equipPosList = itemType.EquipmentPosition;
	if #equipPosList == 0 then
		return 'None';
	end
	return equipPosList[1];
end
function CalculatedProperty_ItemType_IsEquipableMachineParts(itemTypeCls, key)
	local machineCategoryClsList = GetClassList('MachineCategory');
	local testObjects = {};
	for _, cateCls in pairs(machineCategoryClsList) do
		if cateCls.Opened then
			table.insert(testObjects, cateCls.Monster.Object);
		end
	end
	
	for _, equipPos in ipairs(itemTypeCls.EquipmentPosition) do
		for _, obj in ipairs(testObjects) do
			if IsEnableEquipPos(obj, equipPos) then
				return true;
			end
		end
	end
	
	return false;
end
--------------------------------------------------------------
-- 아이템 옵션 ★ 표시
---------------------------------------------------------------
function GetItemOptionGradeByStar(item)
	
	local title = '';
	local point_Option = 0;
	-- 옵션 이름 표시.
	if item then
		point_Option = _GetItemOptionGradeByOption(item.Option);
		-- 옵션 수치 표시.
		if point_Option > 0 then
			local optionValue = '';
			point_Option = math.min(5.99, math.max(1, math.round(point_Option, 2)));
			title = string.format('%s %s', title, string.rep('★', math.floor(point_Option)));
		end
	end
	return title, point_Option;
end

function _GetItemOptionGradeByOption(option)
	local point_Option = 0;
	if option.OptionKey ~= 'None' then
		local statusList = GetClassList('Status');
		local itemIdentifyList = GetClassList('ItemIdentify');
		local optionTitleCls =  itemIdentifyList[option.OptionKey];
		if optionTitleCls and optionTitleCls.name then
			for i = 1, #optionTitleCls.IdentifyOptions do
				local curMaxOptionStatus = optionTitleCls.IdentifyOptions[i].Max;
				if option['Type'..i] ~= 'None' then
					local curStatus = statusList[option['Type'..i]];
					local addValue = 0;
					local ratio = math.round(option['Value'..i]/curMaxOptionStatus,2);	

					if ratio > 0.9 then
						addValue = 1;
					elseif ratio > 0.8 then
						addValue = 0.75;
					elseif ratio > 0.7 then
						addValue = 0.5;
					elseif ratio > 0.5 then
						addValue = 0.25;
					else
						addValue = 0.1;
					end					
					-- 옵션 종류에 따른 가중치. curStatus.OptionRatio
					point_Option = point_Option + ratio * curStatus.OptionRatio + 0.09;
				end
			end			
		end
	end
	return point_Option;
end
---------------------------------------------------------
-- 아이템 강화 시 필요 주재료 카운드.
---------------------------------------------------------
function GetUpgradeItemMainMaterialAmount(item, itemLv)
	local result = 0;
	result = 1 + math.floor(item.RequireLv/5) + itemLv;
	return result;
end
---------------------------------------------------------
-- 아이템 강화 시 필요 주재료 총 소모량
---------------------------------------------------------
function GetUpgradeItemMainMaterialTotalAmount(item, itemLv)
	local result = 0;
	for i = 1, itemLv + 1 do
		result = result + GetUpgradeItemMainMaterialAmount(item, i - 1);
	end
	return result;
end
---------------------------------------------------------
-- 아이템 강화 시 필요 아이템 목록 결정 함수.
---------------------------------------------------------
function GetItemUpgradeMaterial(item)
	local list = {};
	
	if item.Type.ItemUpgradeType == 'None' then
		return list;	
	end
	
	local statusList = GetClassList('Status');
	local itemUpgradeTypeList = GetClassList('ItemUpgradeType');
	local itemUpgradeStatusTypeList = GetClassList('ItemUpgradeStatusType');
	
	-- 1. 주 강화 재료.
	-- 아이템 등급이 재료의 종류를 정하고 아이템 요구 레벨이 개수를 정함.
	-- 1-1. 주 강화 재료 내용 정하기.
	-- 	일반2 / 고급3 / 희귀4 / 영웅5 / 전설6 / 고유7
	local upgradeResultList = itemUpgradeTypeList[item.Type.ItemUpgradeType].ResultMaterial;
	local itemWeight = math.clamp(item.Rank.Weight - 1, 1, #upgradeResultList);
	local upgradeItem = upgradeResultList[itemWeight].Result;
	
	-- 1-2. 주 강화 아이템 필요 카운트 정하기.
	-- 아이템 레벨에 따라 증가.
	local upgradeItemAmount = GetUpgradeItemMainMaterialAmount(item, item.Lv);
	table.insert(list, { Item = upgradeItem, Amount = upgradeItemAmount});
	
	-- 2. MainStatus 재료.
	-- 아이템 옵션과 레벨이 재료의 종류를 정하고 아이템 랭크가 수치가 개수를 정함.
	-- 2-1 아이템 옵션 보상 테이블을 만들자.
	local itemMainStatus = nil;
	local itemMainStatusMaterial = nil;
	if item.MainStatus ~= 'None' then
		itemMainStatus = GetWithoutError(statusList, item.MainStatus);
	end
	if itemMainStatus then
		itemMainStatusMaterial = itemUpgradeStatusTypeList[itemMainStatus.ItemUpgradeType].ResultMaterial;
		local upgradeItemStatusWeight = math.min(#itemMainStatusMaterial, 1 + math.floor(item.RequireLv/10));
		local upgradeStatusItem = itemMainStatusMaterial[upgradeItemStatusWeight].Result;
		local upgradeStatusItemAmount = item.Rank.Weight + 1;
		table.insert(list, { Item = upgradeStatusItem, Amount = upgradeStatusItemAmount});
	end
	return list;
end
---------------------------------------------------------
-- 아이템 추출 시 나오는 아이템 목록 결정 함수.
---------------------------------------------------------
function GetItemDismantleResult(item)
	return _GetItemDismantleResult(item, false, item.Option);
end
function IsBlackIronComponent(itemName)
	local itemList = GetClassList('ItemUpgradeType_BlackIron');
	for key, value in pairs (itemList) do
		if key == itemName then
			return true;
		end
	end
	return false;
end
function _GetItemDismantleResult(item, fullLuck, option)
	local list = {};
	
	if item.Type.ItemUpgradeType == 'None' then
		return list;
	end
	
	local recipeList = GetClassList('Recipe');
	local statusList = GetClassList('Status');
	local itemDismantleTypeList = GetClassList('ItemUpgradeType');
	local itemDismantleStatusTypeList = GetClassList('ItemUpgradeStatusType');
	
	-- 1. 주 분해 재료.
	-- 아이템 등급이 재료의 종류를 정하고 아이템 요구 레벨이 개수를 정함.
	-- 1-1. 주 분해 재료 내용 정하기.
	-- 	일반2 / 고급3 / 희귀4 / 영웅5 / 전설6 / 고유7
	local dismantleResultList = itemDismantleTypeList[item.Type.ItemUpgradeType].ResultMaterial;
	local itemWeight = math.clamp(item.Rank.Weight - 1, 1, #dismantleResultList);
	local dismantleItem = dismantleResultList[itemWeight].Result;
	
	-- 1-2. 주 분해 아이템 획득 카운트 정하기.
	-- 고레벨 아이템이라고 확 늘지 않게 설정.
	local dismantleItemTotalCount = GetUpgradeItemMainMaterialTotalAmount(item, item.Lv);
	local dismantleItemAmount_Min = math.max(1, math.round(0.3 * dismantleItemTotalCount, 1));
	local dismantleItemAmount_Max = math.max(1, math.round(0.1 * math.max(6, item.Lv) * dismantleItemTotalCount, 1));
	local dismantleItemAmount = fullLuck and dismantleItemAmount_Max or math.random(dismantleItemAmount_Min, dismantleItemAmount_Max);
	
	-- 2. 주 서브 분해 재료
	-- 레시피에 흑철 재료를 쓸 경우 추가하도록 함.
	local curRecipe = SafeIndex(recipeList, item.name);
	if curRecipe then
		local dismantleItem2 = nil;
		local dismantleItemAmount2 = nil;
		for index, itemCls in ipairs (curRecipe.RequireMaterials) do
			if IsBlackIronComponent(itemCls.Item) then
				dismantleItem2 = itemCls.Item;
				local minAmount = 1;
				local maxAmount = math.max(itemCls.Amount - 1, 1);
				-- 12.5%
				if itemCls.Amount == 1 then
					minAmount = math.random(1,100) > 75 and 0 or 1;
				end
				dismantleItemAmount2 = fullLuck and maxAmount or math.random(minAmount, maxAmount);
			end
		end
		if dismantleItem2 and dismantleItemAmount2 and dismantleItemAmount2 > 0 then
			table.insert(list, { Item = dismantleItem2, Amount = dismantleItemAmount2});
			dismantleItemAmount = math.max(1, dismantleItemAmount - dismantleItemAmount2);
		end
	end
	
	-- 흑철 부품을 줄경우에는 자홍부품은 줄여주자.
	table.insert(list, { Item = dismantleItem, Amount = dismantleItemAmount});
	
	-- 3. Status 재료.
	-- 아이템 옵션과 레벨이 재료의 종류를 정하고 아이템 랭크가 수치가 개수를 정함.
	-- 3-1 아이템 옵션 보상 테이블을 만들자.
	local picker = RandomPicker.new();
	local isDismantleSubMaterial = false;
	for key, value in pairs (statusList) do
		local itemStatus = GetWithoutError(item, key);
		if itemStatus and itemStatus > 0 then
			
			-- 2-1. 결과 아이템 결정.
			local curItemDismantleStatusList = itemDismantleStatusTypeList[value.ItemUpgradeType].ResultMaterial;
			local upgradeItemStatusWeight = math.min(#curItemDismantleStatusList, 1 + math.floor(item.RequireLv/10));
			local upgradeStatusItem = curItemDismantleStatusList[upgradeItemStatusWeight].Result;
			-- 2-2. 결과 아이템 확률 결정.
			local prop = 10;
			picker:addChoice(prop, upgradeStatusItem);
			isDismantleSubMaterial = true;
		end
	end
	-- 2-2 옵션 별개수 만큼 종류를 뽑는다.
	if isDismantleSubMaterial then
		local optionStarCount = math.floor(_GetItemOptionGradeByOption(option));
		local repeatCount = math.floor(math.min(5, math.max(1, math.round(optionStarCount, 2))));	
		for i = 1, repeatCount do
			local pickedDismantleStatusItem = picker:pick();
			if pickedDismantleStatusItem then
				local maxAmount = math.max(1, item.Rank.Weight - i);
				local amount = fullLuck and maxAmount or math.random(0, maxAmount);
				-- 이미 테이블안에 존재하는 아이템이면 숫자를 합쳐주고 라인은 늘리지 않는다.
				if #list > 0 and amount > 0 then
					local isSameItem = false;
					for index, value in ipairs (list) do
						if value.Item == pickedDismantleStatusItem then
							value.Amount = value.Amount + amount;
							isSameItem = true;
							break;
						end
					end
					if not isSameItem then
						table.insert(list, { Item = pickedDismantleStatusItem, Amount = amount});
					end
				end
			else
				break;
			end
		end
	end
	return list;
end
---------------------------------------------------------
-- 레시피 최대 경험치 
---------------------------------------------------------
function Get_RecipeMaxExp(recipe)
	local result = 25;
	local itemList = GetClassList('Item');
	local item = itemList[recipe.name];
	if item then
		result = result + item.RequireLv;
	end
	return result * 100;
end
---------------------------------------------------------
-- 아이템 어빌리티 조정자
---------------------------------------------------------
-- 어빌리티 자체가 분리됨에 따라 아이템에서 MaxUseCount를 변경할 필요가 없어졌음
-- 사용하는 데이터가 없어졌지만, 기능 필요 시의 예시를 위해 남겨놓음
function ItemAbilityModifier_Extractor(item, ability)
	ability.MaxUseCount = 3;
end

function ItemAbilityModifier_Extractor_Uncommon(item, ability)
	ability.MaxUseCount = 4;
end

function ItemAbilityModifier_Extractor_Rare(item, ability)
	ability.MaxUseCount = 5;
end
--------------------------------------------------------------
-- 아이템 제작시 경험치 획득 숙련도 함수.
---------------------------------------------------------------
function GetCraftExp(itemName, itemCount, isClient)
	local result = 0;
	local itemList = GetClassList('Item');
	local item = itemList[itemName];
	result = 1 + math.floor( item.Rank.CraftExp * item.Type.CraftExpRatio);
	if itemCount > 0 then
		result = result * itemCount + itemCount;
	end
	return result * 100;
end
function GetCraftExp_Additional(recipe, curCraftCount)
	local result = 0;
	result = math.min(1000, recipe.AdditionalCraftExpRatio * curCraftCount);
	return result;
end
--------------------------------------------------------------
-- 세트 아이템 정보
---------------------------------------------------------------
function GetItemSetList(target)
	local itemSetInfoMap = {};
	local equipmentList = GetClassList('Equipment');
	for equipPos, _ in pairs(equipmentList) do
		local equipItem = GetWithoutError(target, equipPos);
		if equipItem and equipItem.name then
			local itemSetInfo = GetItemSetFromItem(equipItem, target);
			if itemSetInfo then
				itemSetInfoMap[itemSetInfo.ItemSet.name] = itemSetInfo;
			end
		end
	end
	local itemSetInfoList = {};
	for _, itemSetInfo in pairs(itemSetInfoMap) do
		table.insert(itemSetInfoList, itemSetInfo);
	end
	return itemSetInfoList;
end
function GetItemSetFromItem(item, target)
	if item.Rank.name ~= 'Set' then
		return nil;
	end
	local itemSetCls = nil;
	for _, value in pairs(GetClassList('ItemSet')) do
		for i = 1, 5 do
			local subItemName = GetWithoutError(value, string.format('Item%d', i));
			if subItemName == item.name then
				itemSetCls = value;
				break;
			end
		end
	end
	if not itemSetCls then
		return nil;
	end
	return GetItemSetInfo(itemSetCls, target);
end
function GetItemSetInfo(itemSetCls, target)
	local itemList = GetClassList('Item');
	local masteryList = GetClassList('Mastery');
	local equipmentList = GetClassList('Equipment');
	
	local equipItemSet = {};
	if target then
		for equipPos, _ in pairs(equipmentList) do
			local equipItem = GetWithoutError(target, equipPos);
			if equipItem and equipItem.name then
				equipItemSet[equipItem.name] = true;
			end
		end
	end

	-- 세트 체크할 아이템
	local items = {};
	local equippedCount = 0;
	for i = 1, 5 do
		local itemName = GetWithoutError(itemSetCls, string.format('Item%d', i));
		if itemName and itemName ~= 'None' then
			local itemCls = itemList[itemName];
			if itemCls then
				local equipped = false;
				if equipItemSet[itemName] then
					equipped = true;
					equippedCount = equippedCount + 1;
				end
				table.insert(items, { Item = itemCls, Equipped = equipped });
			end
		end
	end
	
	-- 세트 개수에 따른 특성
	local masteries = {};
	for i = 1, 5 do
		local masteryName = GetWithoutError(itemSetCls, string.format('Mastery%d', i));
		if masteryName and masteryName ~= 'None' then
			local masteryCls = masteryList[masteryName];
			if masteryCls then
				table.insert(masteries, { Count = i, Mastery = masteryCls, Activated = (i <= equippedCount) });
			end
		end
	end
	
	return { ItemSet = itemSetCls, Items = items, Masteries = masteries };
end
--------------------------------------------------------------
-- NPC 할인율
---------------------------------------------------------------
function GetNpcDiscountRatio(friendship, reputation)
	local discountRatio = 0;
	local info = {};
	-- 우호도 할인
	if friendship and friendship.name then
		local friendshipDiscountRatio = friendship.ShopDiscountRatio;
		if friendshipDiscountRatio > 0 then
			discountRatio = discountRatio + friendshipDiscountRatio;
			table.insert(info, { Type = friendship.name, Value = friendshipDiscountRatio, ValueType = 'Friendship' });
		end
	end
	-- 평판 할인
	if reputation then
		-- 상업 지구 보너스
		local businessBonus = GetSectionTypeBonusValue(reputation, 'Business');
		local reputationDiscountRatio = businessBonus / 100;
		if reputationDiscountRatio > 0 then
			discountRatio = discountRatio + reputationDiscountRatio;
			table.insert(info, { Type = 'Business', Value = reputationDiscountRatio, ValueType = 'ReputationSectorType' });
		end
	end
	return discountRatio, info;
end
----------------------------------------------------------------
-- 기계 제작
----------------------------------------------------------------
function IsEnableCraftMachineType(craftMachineCls, itemType)
	for _, type in ipairs(craftMachineCls.EnableTypes) do
		if type.name == itemType then
			return true;
		end
	end
	return false;
end
local g_craftMachineRemap = {};
function GetCraftMachineCategory(itemType)
	local category = g_craftMachineRemap[itemType];
	if category ~= nil then
		return category;
	end
	for key, cls in pairs(GetClassList('Craft_Machine')) do
		if cls:IsEnableType(itemType) then
			g_craftMachineRemap[itemType] = key;
			return key;
		end
	end
end
----------------------------------------------------------------
-- 무기 코스튬
----------------------------------------------------------------
function CP_WeaponCostume_Title(obj, arg)
	local item = GetWithoutError(obj, 'Item');
	if obj.Base_Title ~= '' then
		return obj.Base_Title;
	elseif SafeIndex(item, 1, 'name') then
		return SafeIndex(item, 1, 'Title');
	else
		return obj.name;	
	end
end
function CP_WeaponCostume_Mesh(obj, arg)
	local item = GetWithoutError(obj, 'Item');
	local baseMesh = GetWithoutError(obj, 'Base_Mesh');
	if baseMesh ~= nil then
		return baseMesh;
	elseif SafeIndex(item, 1, 'name') then
		return SafeIndex(item, 1, 'Mesh');
	end
end
function CalculatedProperty_Item_UnlockWeaponCostume(obj)
	-- 오브젝트는 CP 새로 계산하지 말고, 클래스의 프리로드 데이터로
	if IsObject(obj) then
		return GetHostClass(obj).UnlockWeaponCostume;
	end
	for _, cls in pairs(GetClassList('WeaponCostume')) do
		for _, item in ipairs(cls.Item) do
			if item.name == obj.name then
				return cls.name;
			end		
		end
	end
end
function CP_Preloader_Item_UnlockWeaponCostume(clsList, column)
	local rets = {};
	for _, cls in pairs(GetClassList('WeaponCostume')) do
		for _, item in ipairs(cls.Item) do
			if item.name then
				rets[item.name] = cls.name;
			end
		end
	end
	return rets;
end
function CP_WeaponCostume_Price(obj, arg)
	local result = 0;
	local item = GetWithoutError(obj, 'Item');
	if item and item.name then
		local curItemSellPrice = SafeIndex(item, 1, 'SellPrice');
		if curItemSellPrice then
			result = math.floor(curItemSellPrice * 500)/100;
		end
	end
	result = math.max(obj.Vill_Base, result);
	return result;
end