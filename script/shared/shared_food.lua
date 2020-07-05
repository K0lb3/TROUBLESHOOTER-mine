--------------------------------------------------------------------------
-- Ǫ����� �ֹ� ����Ʈ 
--------------------------------------------------------------------------
function GetFoodEffectAndValue(curOrderList)

	local foodTypeList = GetClassList('FoodType');
	local foodSubTypeList = GetClassList('FoodSubType');
	local foodSetList = GetClassList('FoodSet');
	
	-- 1. �⺻ �� ����
	local result_Condition = 0;
	local result_Satiety = 0;
	local result_Refresh = 0;
	local desc_food = '';
	local setEffect = nil;
	local chatType = nil;
	local data = { 
		Type = {}, 
		SubType = {}	
	};
	
	-- Type �� �ʱ�ȭ
	for key, value in pairs (foodTypeList) do
		if not data.Type[key] then
			data.Type[key] = 0;
		end
	end
	-- SubType �� �ʱ�ȭ
	for key, value in pairs (foodSubTypeList) do
		if not data.SubType[key] then
			data.SubType[key] = 0;
		end
	end
	
	local amount_Condition = 0;
	local amount_Satiety = 0;
	local amount_Refresh = 0;
	
	for i = 1, #curOrderList do
		local curFood = curOrderList[i];
		amount_Condition = amount_Condition + curFood.CP;
		amount_Satiety = amount_Satiety + curFood.Satiety;
		amount_Refresh = amount_Refresh + curFood.Refresh;
		
		-- 1) Ÿ�� ����
		data.Type[curFood.Type.name] = data.Type[curFood.Type.name] + 1;
		-- 2) ���� Ÿ�� ����.
		data.SubType[curFood.SubType.name] = data.SubType[curFood.SubType.name] + 1;
	
		if desc_food == '' then
			desc_food = curFood.Title
		else
			desc_food = desc_food..', '..curFood.Title;
		end
	end
-----------------------------------------------------------------------------
	--- 2. �ó��� ����Ʈ.	
-----------------------------------------------------------------------------
	local ratio_Condition = 0;
	local ratio_Satiety = 0;
	local ratio_Refresh = 0;
-----------------------------------------------------------------------------	
	-- 2-1. Ÿ�Կ� ���� �ó���
	-- Type: MainDish / SideDish / Beverage
-----------------------------------------------------------------------------	
	local count_Beverage = data.Type['Beverage'];
	local count_SideDish = data.Type['SideDish'];
	local count_MainDish = data.Type['MainDish'];
	local totalCount_Type = count_Beverage + count_SideDish + count_MainDish;

	-- 1) ���ᰡ 2�� �̻��� ���
	-- ���� 1�� �� û������ 3% ���� / �������� 3% ����	
	if count_Beverage > 1 then
		ratio_Refresh = ratio_Refresh + 3 * count_Beverage;
		ratio_Satiety = ratio_Satiety - 3 * count_Beverage;
	end
	-- 2) ����� �丮�� 2�� �̻��� ���
	-- ����� �丮 1�� �� �������� 3% ����/ û������ 3% ����.
	if count_SideDish > 1 then
		ratio_Satiety = ratio_Satiety + 3 * count_SideDish;
		ratio_Refresh = ratio_Refresh - 3 * count_SideDish;			
	end
	-- 3) �丮�� 2�� �̻��� ���
	-- ����� �丮 1�� �� �ǿ�, �������� 3% ����.
	if count_MainDish > 1 then
		ratio_Condition = ratio_Condition + 3 * count_MainDish;
		ratio_Satiety = ratio_Satiety + 3 * count_MainDish;
	end
	-- 4) �丮 1, ����� �丮 1, ���� 1 ������ ����
	-- �ǿ� ���� 15%
	if count_Beverage == 1 and count_SideDish == 1 and count_MainDish == 1 then
		ratio_Condition = ratio_Condition + 15;
	end	
	-- 5) �丮 1,  ���� 1 ������ ����
	-- �ǿ� ���� 8% / ������ 3% ����.
	if count_Beverage == 1 and count_MainDish == 1 then
		ratio_Condition = ratio_Condition + 8;
		ratio_Satiety = ratio_Satiety - 3;
	end		
	-- 5) ����� �丮 1,  ���� 1 ������ ����
	-- �ǿ� ���� 5% / ������ 3% ����.
	if count_Beverage == 1 and count_SideDish == 1 then
		ratio_Condition = ratio_Condition + 5;
		ratio_Satiety = ratio_Satiety - 3;
	end		
-----------------------------------------------------------------------------	
	-- 2-1. ���� Ÿ�Կ� ���� �ó���
	-- SubType: Hot / Cool / Sweet / GoodSmell / Fresh / Clean	
-----------------------------------------------------------------------------		

	local count_Hot = data.SubType['Hot'];
	local count_Cool = data.SubType['Cool'];
	local count_Sweet = data.SubType['Sweet'];
	local count_GoodSmell = data.SubType['GoodSmell'];
	local count_Fresh = data.SubType['Fresh'];
	local count_Clean = data.SubType['Clean'];
	local totalCount = count_Hot + count_Cool + count_Sweet + count_GoodSmell + count_Fresh + count_Clean;
	
	-- 1) ������ �Ӽ����θ� ������ ���.
	-- ������ �Ӽ� ���� 1���� �������� 3% �����մϴ�.
	if count_Hot > 1 and count_Hot == totalCount then
		ratio_Satiety = ratio_Satiety - 3 * count_Hot;
	end
	-- 2) �ÿ��� �Ӽ����θ� ������ ���
	-- û���� �Ӽ� ���� 1���� û������ 3% �����մϴ�.
	if count_Cool > 1 and count_Cool == totalCount then
		ratio_Refresh = ratio_Refresh - 3 * count_Cool;
	end
	-- 3) ������ �Ӽ����θ� ������ ���
	-- ������ �Ӽ� ���� 1���� �� �ֹ� �ǿ� �������� 3% �����մϴ�.
	-- ������ �Ӽ� ���� 1���� �������� 3% �����մϴ�.
	if count_Sweet > 1 and count_Sweet == totalCount then
		ratio_Condition = ratio_Condition + 3 * count_Sweet;
		ratio_Satiety = ratio_Satiety + 3 * count_Sweet;	
	end	
	-- 4) ���� ���� �Ӽ����θ� ������ ���
	-- ���� ���� �Ӽ� ���� 1���� �������� û������ 3% �����մϴ�.
	if count_GoodSmell > 1 and count_GoodSmell == totalCount then
		ratio_Satiety = ratio_Satiety - 3 * count_GoodSmell;
		ratio_Refresh = ratio_Refresh - 3 * count_GoodSmell;
	end
	-- 5) ��ŭ�� �Ӽ����θ� ������ ���
	-- ��ŭ�� �Ӽ� ���� 1���� �� �ֹ� �ǿ� �������� 3% �����մϴ�.
	-- ��ŭ�� �Ӽ� ���� 1���� û������ 3% �����մϴ�.
	if count_Fresh > 1 and count_Fresh == totalCount then
		ratio_Condition = ratio_Condition + 3 * count_Fresh;
		ratio_Refresh = ratio_Refresh + 3 * count_Fresh;	
	end
	-- 6) ����� �Ӽ����θ� ������ ���
	-- ����� �Ӽ� ���� 1���� �� �ֹ� �ǿ� �������� 3% �����մϴ�.
	if count_Clean > 1 and count_Clean == totalCount then
		ratio_Condition = ratio_Condition - 3 * count_Clean;
	end	
	-- 7) ������ �Ӽ��� �ÿ��� �Ӽ��� ���� �����ϴ� ���
	-- ������ �Ӽ��� �ÿ��� �Ӽ� ���� 1���� �ǿ� �������� 3% �����մϴ�.
	if count_Hot > 0 and count_Cool > 0 and ( count_Hot + count_Cool ) == totalCount then
		ratio_Condition = ratio_Condition - 3 * ( count_Hot + count_Cool);
	end
	-- 8) ����� �Ӽ� �� ������ �Ӽ��� ���� �����ϴ� ���
	-- ����� �Ӽ� 1���� �� �ֹ� �ǿ� �������� 3% �����մϴ�
	-- ������ �Ӽ� 1���� �� �ֹ� �������� 3% �����մϴ�.
	if count_Sweet > 0 and count_Clean > 0 and ( count_Sweet + count_Clean ) == totalCount  then
		ratio_Condition = ratio_Condition + 3 * count_Clean;
		ratio_Satiety = ratio_Satiety + 3 * count_Sweet;
	end
	-- 9) ������ �Ӽ��� ���� ���� �Ӽ��� ���� �����ϴ� ���
	-- ���� ���� �Ӽ� 1�� �� �ǿ��� 3% �����մϴ�.
	-- ������ �Ӽ� 1���� �������� 3% �����մϴ�.	
	if count_Hot > 0 and count_GoodSmell > 0 and ( count_Hot + count_GoodSmell ) == totalCount then
		ratio_Condition = ratio_Condition + 3 * count_GoodSmell;
		ratio_Satiety = ratio_Satiety - 3 * count_Hot;
	end
	-- 10) ������ �Ӽ��� ������ �Ӽ��� ���� �����ϴ� ���
	-- ������ �Ӽ� 1�� �� �ǿ��� 3% �����մϴ�.
	-- ������ �Ӽ� 1���� �������� 3% �����մϴ�.	
	if count_Hot > 0 and count_Sweet > 0 and ( count_Hot + count_Sweet ) == totalCount then
		ratio_Condition = ratio_Condition + 3 * count_Hot;
		ratio_Satiety = ratio_Satiety + 3 * count_Sweet;
	end	
	-- 11) �ÿ��� �Ӽ��� ������ �Ӽ��� ���� �����ϴ� ���
	-- �ÿ��� �Ӽ��� ������ �Ӽ� 1���� �ǿ��� 3% �����մϴ�.
	if count_Cool > 0 and count_Sweet > 0 and ( count_Cool + count_Sweet ) == totalCount then
		ratio_Condition = ratio_Condition + 3 * ( count_Cool + count_Sweet );
	end		
	-- 12) ����� �Ӽ��� ���� ���� �Ӽ��� ���� �����ϴ� ���
	-- ����� �Ӽ��� ���� ���� �Ӽ� 1���� �������� û������ 3% �����մϴ�.
	if count_Clean > 0 and count_GoodSmell > 0 and ( count_Clean + count_GoodSmell ) == totalCount then
		ratio_Satiety = ratio_Satiety - 3 * ( count_Clean + count_GoodSmell );
		ratio_Refresh = ratio_Refresh - 3 * ( count_Clean + count_GoodSmell );
	end
	-- 13) ������ �Ӽ��� ���� ���� �Ӽ��� ������ �Ӽ��� ���� �����ϴ� ���
	-- ������ �Ӽ� 1���� �������� 3% �����մϴ�.
	-- ������ �Ӽ� + ���� ���� �Ӽ� 1�� �� �ǿ��� 3% �����մϴ�.
	if count_Hot > 0 and count_GoodSmell > 0 and count_Sweet > 0 and ( count_Hot + count_GoodSmell + count_Sweet) == totalCount then
		ratio_Condition = ratio_Condition + 3 * ( count_GoodSmell + count_Sweet );
		ratio_Satiety = ratio_Satiety - 3 * count_Hot;
	end	
	-- 14) ������ �Ӽ��� ���� ���� �Ӽ��� ����� �Ӽ��� ���� �����ϴ� ���
	-- ������ �Ӽ� 1�� �� �ǿ��� 3% �����մϴ�
	-- ����� �Ӽ��� ���� ���� �Ӽ� 1���� �������� û������ 3% �����մϴ�.
	if count_Hot > 0 and count_GoodSmell > 0 and count_Clean > 0 and ( count_Hot + count_GoodSmell + count_Clean) == totalCount then
		ratio_Condition = ratio_Condition + 3 * count_Hot;
		ratio_Satiety = ratio_Satiety - 3 * ( count_GoodSmell + count_Clean );
		ratio_Refresh = ratio_Refresh - 3 * ( count_GoodSmell + count_Clean );
	end		
	-- 15) �ÿ��� �Ӽ��� ��ŭ�� �Ӽ��� ������ �Ӽ��� ���� �����ϴ� ���
	-- �ÿ��� �Ӽ��� ������ �Ӽ� + ��ŭ�� �Ӽ� 1���� �ǿ��� 3% �����մϴ�.
	if count_Cool > 0 and count_Fresh > 0 and count_Sweet > 0 and ( count_Cool + count_Fresh + count_Sweet) == totalCount then
		ratio_Condition = ratio_Condition + 3 * ( count_Cool + count_Fresh + count_Sweet);
	end	
	result_Condition = math.max(0, math.floor(amount_Condition * ( 100 + ratio_Condition )/100));
	result_Satiety = math.max(0, math.floor(amount_Satiety * ( 100 + ratio_Satiety )/100));
	result_Refresh = math.max(0, math.floor(amount_Refresh * ( 100 + ratio_Refresh )/100));
-----------------------------------------------------------------------------	
-- 3-1. ��Ʈ ����Ʈ 
-----------------------------------------------------------------------------			
	-- ��Ʈ ����Ʈ üũ�ؼ� �Ѱ������.	
	local setEffectName = GetSetEffectByOrderList(curOrderList);
	if setEffectName ~= 'None' then
		local curSetRffect = foodSetList[setEffectName];
		if curSetRffect then
			setEffect = curSetRffect;
		end
	end
	
-----------------------------------------------------------------------------	
-- 4-1. ��� Ÿ�� ����Ʈ 
-- Drinking_Hot / Drinking_Cool / Eat_Light / Eat_Heavy
-----------------------------------------------------------------------------	
	
	-- 1) ����θ� �����Ǿ� ���� ���.
	if count_Beverage == totalCount_Type then
		if count_Hot == totalCount then
			chatType = 'Drinking_Hot';
		elseif count_Cool == totalCount then
			chatType = 'Drinking_Cool';
		end
	elseif  totalCount_Type < 5 and 
		( 
			totalCount_Type == ( count_Beverage + count_SideDish) or  totalCount_Type == ( count_Beverage + count_MainDish ) 
		)
	then
		-- 2) �ֹ��� 4�� ������ ���ÿ� ���� �� ( �丮 or ����� �丮) �����Ǿ� ���� ���.
		chatType = 'Eat_Light';
	else
		chatType = 'Eat_Heavy';
	end
 	return result_Condition, result_Satiety, result_Refresh, setEffect, desc_food, chatType;
end
--------------------------------------------------------------------------
-- ��õ �޴��� ��Ʈ ����Ʈ 
--------------------------------------------------------------------------
function CP_FoodShop_RecommendSetList(self)
	local ret = {};

	local enableMenuSet = {};
	for _, menuInfo in ipairs(self.MenuList) do
		if menuInfo.Friendship == 'None' and menuInfo.Checker == 'None' then
			enableMenuSet[menuInfo.Food] = true;
		end
	end

	local columnList = { 'Food1', 'Food2', 'Food3' };
	local checkFunc = function(setCls)
		for _, column in ipairs(columnList) do
			local food = setCls[column];
			if food ~= 'None' and not enableMenuSet[food] then
				return false;
			end
		end
		return true;
	end;
	
	for _, setCls in pairs(GetClassList('FoodSet')) do
		if checkFunc(setCls) then
			table.insert(ret, setCls);
		end
	end
	
	return ret;
end
--------------------------------------------------------------------------
-- ���� �޴��� ���� ��Ʈ
--------------------------------------------------------------------------
function GetSetEffectByOrderList(orderList)
	-- ���� Ż��
	if #orderList <= 1 or #orderList > 3 then
		return 'None';
	end
	
	local columnList = { 'Food1', 'Food2', 'Food3' };
	for _, setCls in pairs(GetClassList('FoodSet')) do
		local setMenuList = {};
		for _, column in ipairs(columnList) do
			local food = setCls[column];
			if food ~= 'None' then
				table.insert(setMenuList, food);
			end
		end
		if #setMenuList == #orderList then
			local setMenuSet = {};
			for _, foodName in ipairs(setMenuList) do
				setMenuSet[foodName] = true;
			end
			local valid = true;
			for _, foodCls in ipairs(orderList) do
				if not setMenuSet[foodCls.name] then
					valid = false;
					break;
				end
			end
			if valid then
				return setCls.name;
			end
		end
	end
	return 'None';
end
--------------------------------------------------------------------------
-- Ǫ�弼Ʈ desc �����. CP ��.
--------------------------------------------------------------------------
function CalculatedProperty_FoodSetDesc(obj, arg)
	local idspace = GetIdspace(obj);
	local desc = obj[arg .. '_Format'];
	local foodList = GetClassList('Food');
	
	-- 1. �丮 ���� �ֱ�.
	local foodCompositionMaxCount = 3;
	local foodCompositionText = '';
	for i = 1, foodCompositionMaxCount do
		local curFoodKey = obj['Food'..i];
		if curFoodKey ~= 'None' then
			local curFoodName = '- Error: Unknown Food -';
			local curFood = foodList[curFoodKey];
			if curFood then
				curFoodName = curFood.Title;
			end
			if foodCompositionText == '' then
				foodCompositionText = curFoodName
			else
				foodCompositionText = foodCompositionText..'\n'..curFoodName;
			end
		end
	end	
	if desc == '' then
		desc = desc..foodCompositionText;
	else
		desc = desc..'\n\n'..foodCompositionText;
	end
	
	-- 2. �ߵ� ���� �ֱ�
	local foodConditionText = FormatMessage("[colour='FFFFFF00']"..GuideMessage('FoodSetConditionMessage'), 
		{
			Status = "[colour='FFFFFFFF']"..obj.RequireType.Title.."[colour='FFFFFF00']", 
			Value = "[colour='FFFFFFFF']"..obj.RequireValue..'%'.."[colour='FFFFFF00']"
		}
	);
	desc = desc..'\n\n'..foodConditionText;
	
	-- 3. ȿ�� �ֱ�
	local foodEffectTitle = "[colour='FFFFFFC8']"..GetWord('FoodSetEffect');
	local foodEffectText = FormatMessage("[colour='FF00C8FF']"..GuideMessage('FoodSetEffectMessage'), 
		{
			Buff = "[colour='FFFFFFFF']"..obj.Buff.Title.."[colour='FF00C8FF']"
		}
	);
	desc = desc..'\n\n'..foodEffectTitle..'\n'..foodEffectText;
	
	-- 4. ���� �ֱ�
	local foodBuffText = string.format("[colour='FFFFFFFF']%s\n%s", obj.Buff.Title, obj.Buff.Desc);
	desc = desc..'\n\n'..foodBuffText;
	
	-- 5. ��� �ֱ�
	desc = desc..'\n\n'.."[colour='FFF3B0A8']"..GuideMessage('FoodAlertSetEffectMessage');
		
	desc = KoreanPostpositionProcessCpp(desc);
	return desc;
end
--------------------------------------------------------------------------
-- Ǫ�� �ֹ� ����
--------------------------------------------------------------------------
function GetFoodOrderPrice(menus, orderList)
	local menuInfoMap = {};
	for _, menuInfo in ipairs(menus) do
		menuInfoMap[menuInfo.Food] = menuInfo;
	end

	local orderPrice = 0;
	for _, foodName in ipairs(orderList) do
		local menuInfo = menuInfoMap[foodName];
		if not menuInfo then
			isEnable = false;
			reason = 'NotExistMenu';
		end
		orderPrice = orderPrice + menuInfo.Price;
	end
	
	local recommendMenuCount = table.count(menus, function(menuInfo) return menuInfo.Recommend end);
	local recommendOrderCount = table.count(orderList, function(foodName) return menuInfoMap[foodName].Recommend end);
	-- ��õ �޴��� ��ġ�� ����, ��õ �޴� ���� ����
	if recommendMenuCount > 0 and recommendMenuCount == recommendOrderCount and recommendMenuCount == #orderList then
		local recommendDiscount = GetSystemConstant('FoodShopRecommendDiscount');
		orderPrice = math.floor(orderPrice * (1 - recommendDiscount / 100));
	end
	
	return orderPrice;
end
function IsEnableFoodOrder(company, menus, orderList, rosterList)
	local isEnable = true;
	local reason = '';

	local orderPrice = GetFoodOrderPrice(menus, orderList);
	local totalPrice = orderPrice * #rosterList;
	
	-- ���� ����
	local hasAlcohol = false;
	local foodList = GetClassList('Food');
	for _, foodName in ipairs(orderList) do
		local foodCls = foodList[foodName];
		if foodCls and foodCls.IsAlcohol then
			hasAlcohol = true;
			break;
		end
	end
	-- �̼����� ����
	local hasMinor = false;
	local pcMap = {};
	local pcList = {};
	if IsClient() then
		local session = GetSession();
		pcList = table.filter(session.rosters, function(pc) return pc.RosterType == 'Pc'; end);
	else
		pcList = GetAllRoster(company, 'Pc');
	end
	for _, pc in ipairs(pcList) do
		pcMap[pc.RosterKey] = pc;
	end	
	for _, rosterKey in ipairs(rosterList) do
		local pc = pcMap[rosterKey];
		if pc and pc.IsMinor then
			hasMinor = true;
			break;
		end
	end
	if hasAlcohol and hasMinor then
		isEnable = false;
		reason = 'MinorAlcohol';
	end
	return isEnable, totalPrice, reason;
end
-- ��� ���.
function GetFoodRestActionType(curOrderList)
	local amount_Condition, amount_Satiety, amount_Refresh, setEffect, desc_food, reactionChatType = GetFoodEffectAndValue(curOrderList);
	if not reactionChatType then
		reactionChatType = 'Eat_Heavy';
	end
	return reactionChatType;
end