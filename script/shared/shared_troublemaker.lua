----------------------------------------------------
-- 보상 받는 조건 체크 함수.
----------------------------------------------------
function TroublemakerRewardTest(company, monName)
	local isEnable = true;
	local rewardItem = nil;
	local reason = {};
	local unlockTechList = {};

	local tm = company.Troublemaker[monName];	
	if tm == nil then
		isEnable = false;
		table.insert(reason, 'CompanyTroublemakerNotExist');		
		return isEnable, rewardItem, reason, unlockTechList;
	end
	
	rewardItem = tm.BonusItem;
	
	-- 레벨 체크.
	local infoGrade = GetTroublemakerInfoGrade(tm);
	if infoGrade < 7 then
		isEnable = false;
		table.insert(reason, 'NotMaxEXP');
	end	
	
	
	
	local monsterList = GetClassList('Monster');
	local masteryList = GetClassList('Mastery');
	local techniqueList = GetClassList('Technique');
	
	local monCls = monsterList[monName];
	if monCls and monCls.name and (tm.Category.name ~= 'Machine' or IsModuleMenuOpened(company)) then
		table.foreach(ClassToTable(monCls.Masteries), function(masteryName, masteryLv)
			local masteryCls = masteryList[masteryName];
			if not masteryCls or not masteryCls.name then
				return;
			end
			if masteryLv <= 0 then
				return;
			end
			local category = masteryCls.Category;
			if category.EquipSlot == 'None' then
				return;
			end		
			local techniqueCls = techniqueList[masteryName];
			if not techniqueCls or not techniqueCls.name then
				return;
			end
			if company.Technique[masteryName].Opened then
				return;
			end
			table.insert(unlockTechList, masteryName);			
		end);
	end
	
	local unlockRecipeList = nil;
	if tm.Category.name == 'Machine' and IsCraftMachineTabOpened(company) then
		unlockRecipeList = {};
		local itemClsList = GetClassList('Item');
		for _, equipmentData in pairs(monCls.Equipments) do
			local equipCls = itemClsList[equipmentData.Item];
			local recipe = GetWithoutError(company.Recipe, equipCls.name);
			local opened = SafeIndex(recipe, 'Opened')
			if equipCls.Type.IsEquipableMachineParts and opened == false then
				table.insert(unlockRecipeList, equipCls.name);
			end
		end
	end
		
	return isEnable, rewardItem, reason, unlockTechList, unlockRecipeList;
end
function IsModuleMenuOpened(company)
	return StringToBool(company.WorkshopMenu.Module.Opened, false);
end
function IsCraftMachineTabOpened(company)
	return StringToBool(company.WorkshopMenu.Machine.Opened, false) and not StringToBool(company.WorkshopMenu.Machine.Tutorial, true);
end
----------------------------------------------------
-- 경험치 랭크 구하는 공식.
-----------------------------------------------------
function GetTroublemakerInfoGrade(tm)
	local infoGrade = 0;
	local expRatio = tm.Exp/tm.MaxExp * 100;
	-- 정보 공개 등급 설정
	if expRatio == 0 then
		infoGrade = 0;
	elseif expRatio < 5  then
		infoGrade = 1;
	elseif expRatio < 15  then
		infoGrade = 2;
	elseif expRatio < 30  then
		infoGrade = 3;
	elseif expRatio < 50  then
		infoGrade = 4;	
	elseif expRatio < 75  then
		infoGrade = 5;
	elseif expRatio < 100  then
		infoGrade = 6;
	else
		infoGrade = 7;
	end
	return infoGrade;
end
----------------------------------------------------
-- 현재 랭크 최대값 구하는 공식.
-----------------------------------------------------
function GetMaxInfoTroublemakerByInfoGrade(tm, infoGrade)
	local result = 0;
	if infoGrade == 1 then
		result = tm.MaxExp * 0.05;
	elseif infoGrade == 2 then
		result = tm.MaxExp * 0.15;
	elseif infoGrade == 3 then
		result = tm.MaxExp * 0.3;
	elseif infoGrade == 4  then
		result = tm.MaxExp * 0.5;		
	elseif infoGrade == 5 then
		result = tm.MaxExp * 0.8;
	elseif infoGrade == 6  then
		result = tm.MaxExp;
	else
		result = tm.MaxExp;
	end
	return result;
end
----------------------------------------------------
-- 경험치 랭크 구하는 공식 by missiontarget
----------------------------------------------------
function GetTroublemakerInfoGradeByMissionTarget(target)
	local infoGrade = 0;
	local company = GetCompany(target);
	if not company then
		return infoGrade;
	end
	local tm = company.Troublemaker[target.name];
	if not tm then
		return infoGrade;
	end
	infoGrade = GetTroublemakerInfoGrade(tm);
	return infoGrade;
end

function CP_MasterySet_HavingTroublemakers(masterySet, arg)
	local masteries = Linq.new({'Mastery1', 'Mastery2', 'Mastery3', 'Mastery4'})
		:select(function(key) return masterySet[key]; end)
		:where(function(mastery) return mastery ~= 'None' end)
		:toList();
	local troublemakerList = GetClassList('Troublemaker');
	local monsterList = GetClassList('Monster');
	local retTroublemakers = {};
	for key, _ in pairs(troublemakerList) do
		local monCls = monsterList[key];
		if (function()
			if monCls == nil then
				return false;
			end
			for _, mastery in ipairs(masteries) do
				local lv = GetWithoutError(monCls.Masteries, mastery);
				if lv == nil then
					return false;
				end
			end
			return true;
		end)() then
			table.insert(retTroublemakers, key);
		end
	end
	return retTroublemakers;
end
----------------------------------------------------
-- 트러블메이커 몬스터 타입
----------------------------------------------------
function FindBaseMonsterType(monster, monType)
	-- 자동 승급이면 정보가 있음
	local baseMonType = GetInstantProperty(monster, 'BaseMonsterType');
	if baseMonType then
		return baseMonType;
	end
	if not monType then
		monType = GetInstantProperty(monster, 'MonsterType');
	end
	-- 자동 승급으로 BaseMonsterType이 세팅된 게 아니면, 몬스터 테이블을 다 살펴봐야...
	local monsterList = GetClassList('Monster');
	for _, monCls in pairs(monsterList) do
		if monCls.GradeUp == monType then
			return monCls.name;
		end
	end
	-- 여기까지 왔으면 승급 몬스터가 아니라는 거지...
	return monType;
end
if not g_baseMonsterCache then
	g_baseMonsterCache = {};
end
function FindBaseMonsterTypeWithCache(monster)
	-- 일단 캐쉬를 찾아본다.
	local monType = GetInstantProperty(monster, 'MonsterType');
	if not monType then
		return nil;
	end	
	local baseMonType = g_baseMonsterCache[monType];
	if not baseMonType then
		baseMonType = FindBaseMonsterType(monster, monType);
		g_baseMonsterCache[monType] = baseMonType;
	end
	return baseMonType;
end