--------------------------------------------------------------------------
-- 푸드상점 주문 리스트 
--------------------------------------------------------------------------
function GetFoodEffectAndValue(curOrderList)

	local foodTypeList = GetClassList('FoodType');
	local foodSubTypeList = GetClassList('FoodSubType');
	local foodSetList = GetClassList('FoodSet');
	
	-- 1. 기본 값 세팅
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
	
	-- Type 값 초기화
	for key, value in pairs (foodTypeList) do
		if not data.Type[key] then
			data.Type[key] = 0;
		end
	end
	-- SubType 값 초기화
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
		
		-- 1) 타입 세기
		data.Type[curFood.Type.name] = data.Type[curFood.Type.name] + 1;
		-- 2) 서브 타입 세기.
		data.SubType[curFood.SubType.name] = data.SubType[curFood.SubType.name] + 1;
	
		if desc_food == '' then
			desc_food = curFood.Title
		else
			desc_food = desc_food..', '..curFood.Title;
		end
	end
-----------------------------------------------------------------------------
	--- 2. 시너지 리스트.	
-----------------------------------------------------------------------------
	local ratio_Condition = 0;
	local ratio_Satiety = 0;
	local ratio_Refresh = 0;
-----------------------------------------------------------------------------	
	-- 2-1. 타입에 따른 시너지
	-- Type: MainDish / SideDish / Beverage
-----------------------------------------------------------------------------	
	local count_Beverage = data.Type['Beverage'];
	local count_SideDish = data.Type['SideDish'];
	local count_MainDish = data.Type['MainDish'];
	local totalCount_Type = count_Beverage + count_SideDish + count_MainDish;

	-- 1) 음료가 2개 이상인 경우
	-- 음료 1개 당 청량감이 3% 증가 / 포만감이 3% 감소	
	if count_Beverage > 1 then
		ratio_Refresh = ratio_Refresh + 3 * count_Beverage;
		ratio_Satiety = ratio_Satiety - 3 * count_Beverage;
	end
	-- 2) 곁들임 요리가 2개 이상인 경우
	-- 곁들임 요리 1개 당 포만감이 3% 증가/ 청량감이 3% 감소.
	if count_SideDish > 1 then
		ratio_Satiety = ratio_Satiety + 3 * count_SideDish;
		ratio_Refresh = ratio_Refresh - 3 * count_SideDish;			
	end
	-- 3) 요리가 2개 이상인 경우
	-- 곁들임 요리 1개 당 의욕, 포만감이 3% 증가.
	if count_MainDish > 1 then
		ratio_Condition = ratio_Condition + 3 * count_MainDish;
		ratio_Satiety = ratio_Satiety + 3 * count_MainDish;
	end
	-- 4) 요리 1, 곁들임 요리 1, 음료 1 만으로 구성
	-- 의욕 증가 15%
	if count_Beverage == 1 and count_SideDish == 1 and count_MainDish == 1 then
		ratio_Condition = ratio_Condition + 15;
	end	
	-- 5) 요리 1,  음료 1 만으로 구성
	-- 의욕 증가 8% / 포만감 3% 감소.
	if count_Beverage == 1 and count_MainDish == 1 then
		ratio_Condition = ratio_Condition + 8;
		ratio_Satiety = ratio_Satiety - 3;
	end		
	-- 5) 곁들임 요리 1,  음료 1 만으로 구성
	-- 의욕 증가 5% / 포만감 3% 감소.
	if count_Beverage == 1 and count_SideDish == 1 then
		ratio_Condition = ratio_Condition + 5;
		ratio_Satiety = ratio_Satiety - 3;
	end		
-----------------------------------------------------------------------------	
	-- 2-1. 서브 타입에 따른 시너지
	-- SubType: Hot / Cool / Sweet / GoodSmell / Fresh / Clean	
-----------------------------------------------------------------------------		

	local count_Hot = data.SubType['Hot'];
	local count_Cool = data.SubType['Cool'];
	local count_Sweet = data.SubType['Sweet'];
	local count_GoodSmell = data.SubType['GoodSmell'];
	local count_Fresh = data.SubType['Fresh'];
	local count_Clean = data.SubType['Clean'];
	local totalCount = count_Hot + count_Cool + count_Sweet + count_GoodSmell + count_Fresh + count_Clean;
	
	-- 1) 따뜻함 속성으로만 구성된 경우.
	-- 따뜻함 속성 개수 1개당 포만감이 3% 감소합니다.
	if count_Hot > 1 and count_Hot == totalCount then
		ratio_Satiety = ratio_Satiety - 3 * count_Hot;
	end
	-- 2) 시원한 속성으로만 구성된 경우
	-- 청량감 속성 개수 1개당 청량감이 3% 감소합니다.
	if count_Cool > 1 and count_Cool == totalCount then
		ratio_Refresh = ratio_Refresh - 3 * count_Cool;
	end
	-- 3) 달콤한 속성으로만 구성된 경우
	-- 달콤한 속성 개수 1개당 총 주문 의욕 증가량이 3% 증가합니다.
	-- 달콤한 속성 개수 1개당 포만감이 3% 증가합니다.
	if count_Sweet > 1 and count_Sweet == totalCount then
		ratio_Condition = ratio_Condition + 3 * count_Sweet;
		ratio_Satiety = ratio_Satiety + 3 * count_Sweet;	
	end	
	-- 4) 향이 좋은 속성으로만 구성된 경우
	-- 향이 좋은 속성 개수 1개당 포만감과 청량감이 3% 감소합니다.
	if count_GoodSmell > 1 and count_GoodSmell == totalCount then
		ratio_Satiety = ratio_Satiety - 3 * count_GoodSmell;
		ratio_Refresh = ratio_Refresh - 3 * count_GoodSmell;
	end
	-- 5) 상큼한 속성으로만 구성된 경우
	-- 상큼한 속성 개수 1개당 총 주문 의욕 증가량이 3% 증가합니다.
	-- 상큼한 속성 개수 1개당 청량감이 3% 증가합니다.
	if count_Fresh > 1 and count_Fresh == totalCount then
		ratio_Condition = ratio_Condition + 3 * count_Fresh;
		ratio_Refresh = ratio_Refresh + 3 * count_Fresh;	
	end
	-- 6) 담백한 속성으로만 구성된 경우
	-- 담백한 속성 개수 1개당 총 주문 의욕 증가량이 3% 감소합니다.
	if count_Clean > 1 and count_Clean == totalCount then
		ratio_Condition = ratio_Condition - 3 * count_Clean;
	end	
	-- 7) 따뜻함 속성과 시원함 속성이 같이 존재하는 경우
	-- 따뜻함 속성과 시원한 속성 개수 1개당 의욕 증가량이 3% 감소합니다.
	if count_Hot > 0 and count_Cool > 0 and ( count_Hot + count_Cool ) == totalCount then
		ratio_Condition = ratio_Condition - 3 * ( count_Hot + count_Cool);
	end
	-- 8) 담백함 속성 과 달콤한 속성이 같이 존재하는 경우
	-- 담백한 속성 1개당 총 주문 의욕 증가량이 3% 증가합니다
	-- 달콤한 속성 1개당 총 주문 포만감이 3% 증가합니다.
	if count_Sweet > 0 and count_Clean > 0 and ( count_Sweet + count_Clean ) == totalCount  then
		ratio_Condition = ratio_Condition + 3 * count_Clean;
		ratio_Satiety = ratio_Satiety + 3 * count_Sweet;
	end
	-- 9) 따뜻함 속성과 향이 좋은 속성이 같이 존재하는 경우
	-- 향이 좋은 속성 1개 당 의욕이 3% 증가합니다.
	-- 따뜻함 속성 1개당 포만감이 3% 감소합니다.	
	if count_Hot > 0 and count_GoodSmell > 0 and ( count_Hot + count_GoodSmell ) == totalCount then
		ratio_Condition = ratio_Condition + 3 * count_GoodSmell;
		ratio_Satiety = ratio_Satiety - 3 * count_Hot;
	end
	-- 10) 따뜻함 속성과 달콤한 속성이 같이 존재하는 경우
	-- 따듯함 속성 1개 당 의욕이 3% 증가합니다.
	-- 달콤한 속성 1개당 포만감이 3% 증가합니다.	
	if count_Hot > 0 and count_Sweet > 0 and ( count_Hot + count_Sweet ) == totalCount then
		ratio_Condition = ratio_Condition + 3 * count_Hot;
		ratio_Satiety = ratio_Satiety + 3 * count_Sweet;
	end	
	-- 11) 시원한 속성과 달콤한 속성이 같이 존재하는 경우
	-- 시원한 속성과 달콤한 속성 1개당 의욕이 3% 증가합니다.
	if count_Cool > 0 and count_Sweet > 0 and ( count_Cool + count_Sweet ) == totalCount then
		ratio_Condition = ratio_Condition + 3 * ( count_Cool + count_Sweet );
	end		
	-- 12) 담백한 속성과 향이 좋은 속성이 같이 존재하는 경우
	-- 담백한 속성과 향이 좋은 속성 1개당 포만감과 청량감이 3% 감소합니다.
	if count_Clean > 0 and count_GoodSmell > 0 and ( count_Clean + count_GoodSmell ) == totalCount then
		ratio_Satiety = ratio_Satiety - 3 * ( count_Clean + count_GoodSmell );
		ratio_Refresh = ratio_Refresh - 3 * ( count_Clean + count_GoodSmell );
	end
	-- 13) 따뜻한 속성과 향이 좋은 속성과 달콤한 속성이 같이 존재하는 경우
	-- 따뜻함 속성 1개당 포만감이 3% 감소합니다.
	-- 달콤한 속성 + 향이 좋은 속성 1개 당 의욕이 3% 증가합니다.
	if count_Hot > 0 and count_GoodSmell > 0 and count_Sweet > 0 and ( count_Hot + count_GoodSmell + count_Sweet) == totalCount then
		ratio_Condition = ratio_Condition + 3 * ( count_GoodSmell + count_Sweet );
		ratio_Satiety = ratio_Satiety - 3 * count_Hot;
	end	
	-- 14) 따뜻한 속성과 향이 좋은 속성과 담백한 속성이 같이 존재하는 경우
	-- 따듯한 속성 1개 당 의욕이 3% 증가합니다
	-- 담백한 속성과 향이 좋은 속성 1개당 포만감과 청량감이 3% 감소합니다.
	if count_Hot > 0 and count_GoodSmell > 0 and count_Clean > 0 and ( count_Hot + count_GoodSmell + count_Clean) == totalCount then
		ratio_Condition = ratio_Condition + 3 * count_Hot;
		ratio_Satiety = ratio_Satiety - 3 * ( count_GoodSmell + count_Clean );
		ratio_Refresh = ratio_Refresh - 3 * ( count_GoodSmell + count_Clean );
	end		
	-- 15) 시원한 속성과 상큼한 속성과 달콤한 속성이 같이 존재하는 경우
	-- 시원한 속성과 달콤한 속성 + 상큼한 속성 1개당 의욕이 3% 증가합니다.
	if count_Cool > 0 and count_Fresh > 0 and count_Sweet > 0 and ( count_Cool + count_Fresh + count_Sweet) == totalCount then
		ratio_Condition = ratio_Condition + 3 * ( count_Cool + count_Fresh + count_Sweet);
	end	
	result_Condition = math.max(0, math.floor(amount_Condition * ( 100 + ratio_Condition )/100));
	result_Satiety = math.max(0, math.floor(amount_Satiety * ( 100 + ratio_Satiety )/100));
	result_Refresh = math.max(0, math.floor(amount_Refresh * ( 100 + ratio_Refresh )/100));
-----------------------------------------------------------------------------	
-- 3-1. 세트 이펙트 
-----------------------------------------------------------------------------			
	-- 세트 이펙트 체크해서 넘겨줘야함.	
	local setEffectName = GetSetEffectByOrderList(curOrderList);
	if setEffectName ~= 'None' then
		local curSetRffect = foodSetList[setEffectName];
		if curSetRffect then
			setEffect = curSetRffect;
		end
	end
	
-----------------------------------------------------------------------------	
-- 4-1. 대사 타입 이펙트 
-- Drinking_Hot / Drinking_Cool / Eat_Light / Eat_Heavy
-----------------------------------------------------------------------------	
	
	-- 1) 음료로만 구성되어 있을 경우.
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
		-- 2) 주문이 4개 이하인 동시에 음료 외 ( 요리 or 곁들임 요리) 구성되어 있을 경우.
		chatType = 'Eat_Light';
	else
		chatType = 'Eat_Heavy';
	end
 	return result_Condition, result_Satiety, result_Refresh, setEffect, desc_food, chatType;
end
--------------------------------------------------------------------------
-- 추천 메뉴용 세트 리스트 
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
-- 선택 메뉴에 따른 세트
--------------------------------------------------------------------------
function GetSetEffectByOrderList(orderList)
	-- 빠른 탈출
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
-- 푸드세트 desc 만들기. CP 임.
--------------------------------------------------------------------------
function CalculatedProperty_FoodSetDesc(obj, arg)
	local idspace = GetIdspace(obj);
	local desc = obj[arg .. '_Format'];
	local foodList = GetClassList('Food');
	
	-- 1. 요리 구성 넣기.
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
	
	-- 2. 발동 조건 넣기
	local foodConditionText = FormatMessage("[colour='FFFFFF00']"..GuideMessage('FoodSetConditionMessage'), 
		{
			Status = "[colour='FFFFFFFF']"..obj.RequireType.Title.."[colour='FFFFFF00']", 
			Value = "[colour='FFFFFFFF']"..obj.RequireValue..'%'.."[colour='FFFFFF00']"
		}
	);
	desc = desc..'\n\n'..foodConditionText;
	
	-- 3. 효과 넣기
	local foodEffectTitle = "[colour='FFFFFFC8']"..GetWord('FoodSetEffect');
	local foodEffectText = FormatMessage("[colour='FF00C8FF']"..GuideMessage('FoodSetEffectMessage'), 
		{
			Buff = "[colour='FFFFFFFF']"..obj.Buff.Title.."[colour='FF00C8FF']"
		}
	);
	desc = desc..'\n\n'..foodEffectTitle..'\n'..foodEffectText;
	
	-- 4. 버프 넣기
	local foodBuffText = string.format("[colour='FFFFFFFF']%s\n%s", obj.Buff.Title, obj.Buff.Desc);
	desc = desc..'\n\n'..foodBuffText;
	
	-- 5. 경고 넣기
	desc = desc..'\n\n'.."[colour='FFF3B0A8']"..GuideMessage('FoodAlertSetEffectMessage');
		
	desc = KoreanPostpositionProcessCpp(desc);
	return desc;
end
--------------------------------------------------------------------------
-- 푸드 주문 가능
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
	-- 추천 메뉴와 일치할 때만, 추천 메뉴 할인 적용
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
	
	-- 알콜 유무
	local hasAlcohol = false;
	local foodList = GetClassList('Food');
	for _, foodName in ipairs(orderList) do
		local foodCls = foodList[foodName];
		if foodCls and foodCls.IsAlcohol then
			hasAlcohol = true;
			break;
		end
	end
	-- 미성년자 유무
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
-- 대사 출력.
function GetFoodRestActionType(curOrderList)
	local amount_Condition, amount_Satiety, amount_Refresh, setEffect, desc_food, reactionChatType = GetFoodEffectAndValue(curOrderList);
	if not reactionChatType then
		reactionChatType = 'Eat_Heavy';
	end
	return reactionChatType;
end