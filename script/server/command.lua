-- dc:AddCompanyProperty(company, 'Vill', - totalPrice);
-- dc:UpdateQuestStage(pc, args.QuestType, args.Stage) 
-- dc:UpdateNPCProperty(npc, args.PropertyType, args.PropertyValue) 
-- dc:UpdatePCProperty(pc, args.PropertyType, prev + args.PropertyValue);
-- dc:UpdateCompanyName(pc, args.Name);
-- dc:AddQuestProperty(GetCompany(pc), questType, 'TargetCount', 1);
-- dc:UpdateItemProperty(baseItem, 'Board/'..targetSlot..'/Chip', consumeItem.name);
-- dc:UpdateMasteryLv(roster, mastery.name, 0);
function OnUserCommand(company, dc, command, ...)
	LogAndPrint(command, ...);
	if GetPermissionLevel(company) < 1 then
		LogAndPrint('수행 권한이 없습니다');
		return;
	end
	local f = _G["Command_" .. command];
	if f ~= nil then
		f(company, dc, ...);
	end
end
function Command_dialog(company, dc, dialogType, npcType)
	if npcType then
		StartLobbyDialog(company, 'JumpWithNpc', { dialog_type = dialogType, npc_type = npcType });
	else
		StartLobbyDialog(company, dialogType);
	end
end
function Command_newroster(company, dc, type)
	local pcList = GetClassList('Pc');
	if pcList[type].name ~= nil then
		NewRoster(company, type);
	else
		print(string.format("PC.xml is not contained %s name",type));
	end
end
function Command_deleteroster(company, dc, rosterKey)
	local roster = GetRoster(company, rosterKey);
	if roster == nil then
		return;
	end
	dc:DeleteRoster(roster);
	dc:Commit('Command_deleteroster');
	SendChat(company, 'Notice', 'System', string.format('Delete Roster - rosterKey: %s', rosterKey));
end
function Command_newbeast(company, dc, beastType, lv, joblv)
	local beastTypeCls = GetClassList('BeastType')[beastType];
	if not beastTypeCls then
		return;
	end
	
	local rosterKey = string.format('Beast_%d', company.BeastIndex);
	dc:AddCompanyProperty(company, 'BeastIndex', 1);
	
	local rosterKey = dc:NewBeast(company, rosterKey, beastType);
	dc:Commit('Command_newbeast');
	
	local roster = GetRoster(company, rosterKey);
	if roster == nil then
		SendChat(company, 'Notice', 'System', 'New Beast Failed');
		return;
	end
	local initialMasteries = PickBeastUniqueMasteryCandidate(roster, beastTypeCls, true, beastTypeCls.EvolutionStage);
	for i, masteryName in ipairs(initialMasteries) do
		dc:UpdatePCProperty(roster, string.format('EvolutionMastery%d', i), masteryName);
	end
	if lv ~= nil then
		dc:UpdatePCProperty(roster, 'Lv', lv);
	end
	if joblv ~= nil then
		dc:UpdatePCProperty(roster, 'JobLv', joblv);
	end
	dc:Commit('Command_newbeast');
	SendChat(company, 'Notice', 'System', string.format('New Beast - rosterKey: %s', rosterKey));
end
function Command_clearbeast(company, dc)
	local rosterList = GetAllRoster(company, 'Beast');
	local rosterKeyList = table.map(rosterList, function(r) return r.RosterKey end);
	
	for _, roster in ipairs(rosterList) do
		dc:DeleteRoster(roster);
	end
	dc:UpdateCompanyProperty(company, 'BeastIndex', 0);	
	dc:Commit('Command_clearbeast');
	
	for _, rosterKey in ipairs(rosterKeyList) do
		SendChat(company, 'Notice', 'System', string.format('Clear Beast - rosterKey: %s', rosterKey));
	end
end
function Command_changebeast(company, dc, rosterName, beastType)
	local beastCls = GetClassList('BeastType')[beastType];
	if not beastCls then
		return;
	end
	local roster = GetRoster(company, rosterName);
	if roster == nil then
		SendChat(company, 'Notice', 'System', string.format('Not Exist Roster - %s', rosterName));
		return;
	end
	if roster.RosterType ~= 'Beast' then
		SendChat(company, 'Notice', 'System', string.format('Not Beast RosterType - %s', roster.RosterType));
		return;
	end
	local prevBeastType = roster.BeastType.name;	
	dc:UpdatePCProperty(roster, 'BeastType', beastCls.name);
	dc:UpdatePCProperty(roster, 'Object', string.format('Object/%s', beastCls.Monster.Object.name));
	dc:UpdatePCProperty(roster, 'Info', string.format('ObjectInfo/%s', beastCls.Monster.Info.name));
	dc:Commit('Command_changebeast');
	local newBeastType = roster.BeastType.name;
	SendChat(company, 'Notice', 'System', string.format('%s[BeastType] : %s -> %s', rosterName, prevBeastType, newBeastType));	
end
function Command_alldraky(company, dc)
	local list = {
	"Mon_Beast_Dragon_Hatchling",
"Mon_Beast_Dragon_Flame",
"Mon_Beast_Dragon_Frost",
"Mon_Beast_Dragon_Lightning",
"Mon_Beast_Dragon_Water",
"Mon_Beast_Dragon_Earth",
"Mon_Beast_Dragon_White",
"Mon_Beast_Dragon_Black",
"Mon_Beast_Dragon_Flame2",
"Mon_Beast_Dragon_Frost2",
"Mon_Beast_Dragon_Lightning2",
"Mon_Beast_Dragon_Water2",
"Mon_Beast_Dragon_Earth2",
"Mon_Beast_Dragon_White2",
"Mon_Beast_Dragon_Black2",
"Mon_Beast_Dragon_Flame3",
"Mon_Beast_Dragon_Frost3",
"Mon_Beast_Dragon_Lightning3",
"Mon_Beast_Dragon_Water3",
"Mon_Beast_Dragon_Earth3",
"Mon_Beast_Dragon_White3",
"Mon_Beast_Dragon_Black3",
"Mon_Beast_Dragon_Flame2_Ground",
"Mon_Beast_Dragon_Frost2_Ground",
"Mon_Beast_Dragon_Lightning2_Ground",
"Mon_Beast_Dragon_Water2_Ground",
"Mon_Beast_Dragon_Earth2_Ground",
"Mon_Beast_Dragon_White2_Ground",
"Mon_Beast_Dragon_Black2_Ground",
"Mon_Beast_Dragon_Flame3_Ground",
"Mon_Beast_Dragon_Frost3_Ground",
"Mon_Beast_Dragon_Lightning3_Ground",
"Mon_Beast_Dragon_Water3_Ground",
"Mon_Beast_Dragon_Earth3_Ground",
"Mon_Beast_Dragon_White3_Ground",
"Mon_Beast_Dragon_Black3_Ground",
};
	for _, beastType in ipairs(list) do
		Command_newbeast(company, dc, beastType, 50, 16);	
	end
end

function Command_newmachine(company, dc, machineType, lv)
	local machineTypeCls = GetClassList('MachineType')[machineType];
	if not machineTypeCls then
		return;
	end
	
	local rosterKey = string.format('Machine_%d', company.MachineIndex);
	dc:AddCompanyProperty(company, 'MachineIndex', 1);
	
	local rosterKey = dc:NewMachine(company, rosterKey, machineType);
	dc:Commit('Command_newmachine');
	
	local roster = GetRoster(company, rosterKey);
	if roster == nil then
		SendChat(company, 'Notice', 'System', 'New Beast Failed');
		return;
	end
	if lv ~= nil then
		dc:UpdatePCProperty(roster, 'Lv', lv);
	end
	dc:Commit('Command_newmachine');
	SendChat(company, 'Notice', 'System', string.format('New Machine - rosterKey: %s', rosterKey));
end
function Command_clearmachine(company, dc)
	local rosterList = GetAllRoster(company, 'Machine');
	local rosterKeyList = table.map(rosterList, function(r) return r.RosterKey end);
	
	for _, roster in ipairs(rosterList) do
		dc:DeleteRoster(roster);
	end
	dc:UpdateCompanyProperty(company, 'MachineIndex', 0);	
	dc:Commit('Command_clearmachine');
	
	for _, rosterKey in ipairs(rosterKeyList) do
		SendChat(company, 'Notice', 'System', string.format('Clear Machine - rosterKey: %s', rosterKey));
	end
end

function Command_mastery(company, dc, masteryName, count)
	masteryName = FindClassData('Mastery', masteryName);
	dc:AcquireMastery(company, masteryName, count and tonumber(count) or 1);
	dc:Commit('Command_mastery');
end
function Command_setmastery(company, dc, masteryName, count)
	count = count and tonumber(count) or 1;
	masteryName = FindClassData('Mastery', masteryName);
	local masterySetList = GetClassList('MasterySet');
	local setCls = masterySetList[masteryName];
	if setCls == nil then
		SendChat(company, 'Notice', 'System', string.format('no set mastery %s', masteryName));
		return;
	end
	
	for i = 1, 4 do
		local needMastery = setCls['Mastery'..i];
		if needMastery ~= 'None' then
			dc:AcquireMastery(company, needMastery, count);
		end
	end
	dc:Commit('Command_setmastery');
end
function Command_am(company, dc, count)
	local masteryCategorySet = {};
	for _, category in pairs(GetClassList('MasteryCategory')) do
		if category.EquipSlot ~= 'None' then
			masteryCategorySet[category.name] = true;
		end
	end
	for key, value in pairs (company.Mastery) do
		if masteryCategorySet[value.Category.name] and not value.FixedMastery and value.ExtractItem ~= 'None' then
			dc:AcquireMastery(company, key, count and tonumber(count) or 1, true);
		end
	end
	dc:Commit('Command_am');
end
function Command_rm(company, dc)
	for key, value in pairs (company.Mastery) do
		dc:LoseMastery(company, key, value.Amount);
	end
	dc:Commit('Command_rm');
end
function Command_tb(company, dc)
	local tbList = GetClassList('Troublebook')
	for key, value in pairs (tbList) do
		for index, stage in ipairs (value.Stage) do			
			dc:UpdateCompanyProperty(company, 'MissionCleared/'..stage.Mission, true);
		end
	end
	dc:Commit('Command_rm');
end
function Command_allroster(company, dc)
	local pcList = GetClassList('Pc');
	for key, value in pairs (pcList) do
		if key ~= nil then
			NewRoster(company, key);
		end
	end
end
function Command_resetWork(company, dc, workplace)
	local workplaceList = GetClassList('Workplace');
	if workplaceList[workplace] == nil then
		ShowMsgBox(company, 'No Workplace: '..workplace);
		return;
	end
	for key, value in pairs (company[workplace]) do
		dc:UpdateCompanyProperty(company, workplace..'/'..key..'/Target', 'None');
	end
	dc:Commit('Command_resetWork');
end
function Command_condition(company, dc, rostertype, count)
	local roster = GetRoster(company, rostertype);
	if roster == nil then
		ShowMsgBox(company, 'NoRoster:'..rostertype);
		return;
	end
	UpdateRosterConditionPoint(dc, roster, tonumber(count));
	dc:Commit('Command_condition');
end
function Command_conditionTeam(company, dc, count)
  local rosterList = GetAllRoster(company);
  for index, roster in ipairs (rosterList) do
    if roster ~= nil then
      UpdateRosterConditionPoint(dc, roster, tonumber(count));
    end
  end
  dc:Commit('Command_conditionTeam');
end
function Command_cpup(company, dc)
	local rosterList = GetAllRoster(company, 'All');
	for index, roster in ipairs(rosterList) do
		if roster.RosterType == 'Pc' then
			UpdateRosterConditionPoint(dc, roster, 1000, -roster.MaxSatiety, -roster.MaxRefresh);
			dc:UpdatePCProperty(roster, 'FoodSetEffect', 'None');
		elseif roster.RosterType == 'Beast' then
			dc:UpdatePCProperty(roster, 'CP', roster.OverChargeCP);
		else
			dc:UpdatePCProperty(roster, 'CP', roster.MaxCP);
		end
	end
	dc:Commit('Command_cpup');
end
function Command_cpdown(company, dc)
	local rosterList = GetAllRoster(company);
	for index, roster in ipairs (rosterList) do
		LogAndPrint(roster);
		if roster ~= nil then
			UpdateRosterConditionPoint(dc, roster, 0);
		end
	end
	dc:Commit('Command_cpdown');
end
function Command_cprandom(company, dc)
	local rosterList = GetAllRoster(company, 'All');
	for index, roster in ipairs(rosterList) do
		if roster.RosterType == 'Pc' then
			UpdateRosterConditionPoint(dc, roster, math.random(0, 1000));
		elseif roster.RosterType == 'Beast' then
			dc:UpdatePCProperty(roster, 'CP', math.random(0, roster.OverChargeCP));
		else
			dc:UpdatePCProperty(roster, 'CP', math.random(0, roster.MaxCP));
		end
	end
	dc:Commit('Command_cprandom');
end
function Command_ResetRefresh(company, dc)
	local rosterList = GetAllRoster(company);
	for index, roster in ipairs (rosterList) do
		if roster ~= nil then
			dc:UpdatePCProperty(roster, 'Refresh', 0);
		end
	end
	dc:Commit('Command_ResetRefresh');
end
function Command_ResetSatiety(company, dc)
	local rosterList = GetAllRoster(company);
	for index, roster in ipairs (rosterList) do
		if roster ~= nil then
			dc:UpdatePCProperty(roster, 'Satiety', 0);
		end
	end
	dc:Commit('Command_ResetSatietyp');
end
function Command_conditionState(company, dc, rostertype, conditionState)
	local roster = GetRoster(company, rostertype);
	if roster == nil then
		ShowMsgBox(company, 'Not Exist Roster - '..rostertype);
		return;
	end
	if conditionState ~= 'Rest' and conditionState ~= 'Good' then
		ShowMsgBox(company, conditionState);
		return;
	end
	if roster:GetEstimatedCP() > roster.MaxCP and conditionState == 'Rest' then
		UpdateRosterConditionPoint(dc, roster, 0);
	end
	dc:UpdatePCProperty(roster, 'ConditionState', conditionState);
	dc:Commit('Command_conditionState');
end
function Command_ResetOfficeAlbus(company, dc)
	local lobbyMenu = company.LobbyMenu;
	for key, menu in pairs (lobbyMenu) do
		if key ~= 'Option' then
			dc:UpdateCompanyProperty(company, 'LobbyMenu/'..menu.name..'/Opened', false);
		end
		if key == 'Roster' then
			dc:UpdateCompanyProperty(company, 'LobbyMenu/Roster/Tutorial', true);
		end
	end
	dc:UpdateCompanyProperty(company, 'Progress/Tutorial/GameMenuType', 'None');
	dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'Office_Albus');
	dc:UpdateCompanyProperty(company, 'Progress/Tutorial/OfficeCharPosition', 'Default');
	dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Roster', 0);
	dc:Commit('ResetOfficeAlbus');
end
function Command_ResetOfficeSilverlining(company, dc)

	local officeMenu = company.OfficeMenu;
	for key, menu in pairs (officeMenu) do
		if menu.name then
			dc:UpdateCompanyProperty(company, 'OfficeMenu/'..menu.name..'/Opened', false);
			dc:UpdateCompanyProperty(company, 'OfficeMenu/'..menu.name..'/Tutorial', true);
		end
	end
	local workshopMenu = company.WorkshopMenu;
	for key, menu in pairs (workshopMenu) do
		if menu.name then
			dc:UpdateCompanyProperty(company, 'WorkshopMenu/'..menu.name..'/Opened', false);
			dc:UpdateCompanyProperty(company, 'WorkshopMenu/'..menu.name..'/Tutorial', true);
		end
	end
	dc:UpdateCompanyProperty(company, 'OfficeMenu/Opened', false);
	dc:UpdateCompanyProperty(company, 'OfficeMenu/Tutorial', true);
	dc:UpdateCompanyProperty(company, 'BarMenu/Tutorial', false);
	dc:UpdateCompanyProperty(company, 'WorkshopMenu/Opened', false);
	dc:UpdateCompanyProperty(company, 'WorkshopMenu/Tutorial', true);
	dc:UpdateCompanyProperty(company, 'WorkshopMenu/Unlocked', false);
	dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'OfficeMoveIn');
	dc:UpdateCompanyProperty(company, 'Progress/Tutorial/OfficeCharPosition', 'AlbusStand');
	dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office', 0);
	dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Workshop', 0);
	dc:UpdateCompanyProperty(company, 'Progress/Tutorial/ActivityReport', 0);
	dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Technique', 0);
	dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Troublemaker', 0);
	dc:UpdateCompanyProperty(company, 'UnlockService/Don_CPRestore', false);
	dc:UpdateCompanyProperty(company, 'UnlockService/Don_CPRestore', false);
	dc:UpdateCompanyProperty(company, 'BarMenu/Leave/Opened', false);	
	dc:Commit('ResetOfficeSilverlining');	
end
function Command_ResetOfficeBeforeWarehouse(company, dc)
	dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office', 31);
	dc:UpdateCompanyProperty(company, 'Office', 'Office_Silverlining');
	dc:UpdateCompanyProperty(company, 'WorkshopMenu/Opened', false);
	dc:Commit('ResetOfficeBeforeWarehouse');
end
function Command_ResetOfficeBeforeMarco(company, dc)
	dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'BlueFogStreet_Win');
	dc:UpdateCompanyProperty(company, 'Progress/Character/Marco', 0);
	dc:UpdateCompanyProperty(company, 'Progress/Character/Don', 0);
	dc:Commit('ResetOfficeBeforeMarco');
end
function Command_AllMenu(company, dc)
	local lobbyMenu = company.LobbyMenu;
	for key, menu in pairs (lobbyMenu) do
		if key ~= 'Option' then
			dc:UpdateCompanyProperty(company, 'LobbyMenu/'..menu.name..'/Opened', true);
		end
		if key == 'Roster' then
			dc:UpdateCompanyProperty(company, 'LobbyMenu/Roster/Tutorial', false);
		end
	end
	dc:Commit('AllMenu');
end
function Command_addexp(company, dc, rostertype, expAmount)
	local roster = GetRoster(company, rostertype);
	if roster == nil then
		ShowMsgBox(company, 'Not Exist Roster - '..rostertype);
		return;
	end
	dc:AddExp(roster, tonumber(expAmount), 'Player');
	dc:Commit('Command_addexp');
end
function Command_setLevelUp(company, dc, rostertype, lv)
	local roster = GetRoster(company, rostertype);
	if roster == nil then
		ShowMsgBox(company, 'Not Exist Roster - '..rostertype);
		return;
	end
	if roster.Lv >= tonumber(lv) then
		ShowMsgBox(company, 'Can not level Down'..rostertype);
		return;
	end
	local expAmount = 0;
	local expList = GetClassList('Exp');
	for key, value in pairs(expList) do
		if key >= roster.Lv and key < tonumber(lv) then
			expAmount = expAmount + value.Player;
		end
	end
	dc:AddExp(roster, expAmount, 'Player');
	dc:Commit('Command_setLevelUp');
end
function FindClassData(idspace, findKey)
	if findKey == nil then
		return nil;
	end
	local clsList = GetClassList(idspace);
	if clsList[findKey] == nil then
		local found = false;
		for key, cls in pairs(clsList) do
			if cls.Title == findKey then
				findKey = key;
				found = true;
				break;
			end
		end
		if not found then
			return nil;
		end
	end
	return findKey;
end
function FindItemType(itemType)
	if itemType == nil then
		return nil;
	end
	local itemClsList = GetClassList('Item');
	if itemClsList[itemType] == nil then
		local found = false;
		for key, cls in pairs(itemClsList) do
			if cls.Title == itemType then
				itemType = key;
				found = true;
				break;
			end
		end
		if not found then
			return nil;
		end
	end
	return itemType;
end
function FindBuffType(buffType)
	if buffType == nil then
		return nil;
	end
	local itemClsList = GetClassList('Buff');
	if itemClsList[buffType] == nil then
		local found = false;
		for key, cls in pairs(itemClsList) do
			if cls.Title == buffType then
				buffType = key;
				found = true;
				break;
			end
		end
		if not found then
			return nil;
		end
	end
	return buffType;
end
function Command_giveitem(company, dc, itemType, count, option, optionType)
	local itemClsList = GetClassList('Item');
	itemType = FindItemType(itemType);
	if itemType == nil then
		return;
	end
	if count == nil then
		count = 1;
	end
	dc:GiveItem(company, itemType, tonumber(count));
	-- 옵션
	if option and option == 'Option' then
		local option = GetIdentifyItemOptions(itemClsList[itemType]);
		if optionType then
			option = GetClassList('ItemIdentify')[optionType];
		end
		-- 2. 해당 옵션을 기반으로 부여할 수치를 정한다.
		-- { Type = status.Type, Value = curValue, PickValue = pickValue, RangeValue = rangeValue}
		local identifyOptionValueList, ratio = GetIdentifyItemOptionValue(option);
		if #identifyOptionValueList <= 5 then
			-- 3. 타이틀 값 저장.
			dc:UpdateLastRefItemProperty('Option/OptionKey', option.name);
			dc:UpdateLastRefItemProperty('Option/Ratio', ratio);
			-- 4. 랜덤 스탯 저장.
			for index, status in ipairs (identifyOptionValueList) do
				dc:UpdateLastRefItemProperty(string.format('Option/Type%d', index), status.Type);
				dc:UpdateLastRefItemProperty(string.format('Option/Value%d', index), status.Value);
			end
		end
	end
	if not dc:Commit('Command_giveitem') then
		SendNotification(company, 'NotEnoughInventorySpace', 'GiveItemFail');
	else
		LogAndPrint('Good!');
	end
end
function Command_vill(company, dc, count)
	dc:AddCompanyProperty(company, 'Vill', tonumber(count));
	dc:Commit('Command_vill');
end
function Command_tp(company, dc, rostertype, count)
	local roster = GetRoster(company, rostertype);
	if roster == nil then
		ShowMsgBox(company, 'Not Exist Roster - '..rostertype);
		return;
	end
	LogAndPrint(roster.TP, count);
	dc:AddPCProperty(roster, 'BonusTP', count);
	dc:Commit('Command_tp');
end
function Command_equipmastery(company, dc, rosterType, masteryType)
	local roster = GetRoster(company, rosterType);
	if roster == nil then
		ShowMsgBox(company, 'Not Exist Roster - '..rosterType);
		return;
	end
	dc:UpdateMasteryLv(roster, masteryType, 1);
	dc:Commit('Command_equipmastery');
end
function Command_allweapon(company, dc)
	local itemList = GetClassList("Item");
	for key, value in pairs (itemList) do
		if value.Category.name == 'Weapon' then
			dc:GiveItem(company, key, 1);
		end
	end
	dc:Commit('Command_allweapon');
end
function Command_allarmor(company, dc)
	local itemList = GetClassList("Item");
	for key, value in pairs (itemList) do
		if value.Category.name == 'Accessory' or  value.Category.name == 'Armor' then
			dc:GiveItem(company, key, 1);
		end
	end
	dc:Commit('Command_allarmor');
end
function Command_rosterproperty(company, dc, rostertype)
	local roster = GetRoster(company, rostertype);
	if roster == nil then
		ShowMsgBox(company, 'Not Exist Roster - '..rostertype);
	end
	SendRosterPropertyModifier(company, roster);
end
function Command_mission(company, dc, mission)
	dc:Commit('Command_mission');
	StartMission(company, mission);
end
function Command_directmission(company, dc, mission)
	dc:Commit('Command_directmission');
	DirectMission(company, mission, {});
end
function Command_m(company, dc)
	StartMission(company, company.LastMission);
end
function Command_dropall(company, dc)
	local allitems = GetAllItems(company);
	for i, item in ipairs(allitems) do
		dc:TakeItem(item, item.Amount);
	end
	if not dc:Commit('Command_dropall') then
		LogAndPrint("it's got something wrong");
	end
end
function Command_dropitem(company, dc, itemType, count)
	itemType = FindItemType(itemType);
	if itemType == nil then
		return;
	end	
	local takeItems = table.filter(GetAllItems(company), function(item)
		return item.name == itemType;
	end);
	if #takeItems == 0 then
		return;
	end
	for i, item in ipairs(takeItems) do
		dc:TakeItem(item, count and math.min(count, item.Amount) or item.Amount);
	end
	if not dc:Commit('Command_dropitem') then
		LogAndPrint("it's got something wrong");
	end
end
function Command_addtroublesum(company, dc, questType, remainTime)
	dc:UpdateQuestStage(company, questType, 'Requested');
	dc:UpdateQuestProperty(company, questType, 'StartTime', os.time());
	dc:UpdateQuestProperty(company, questType, 'EndTime', os.time() + (remainTime or 60 * 60));
	dc:Commit('Command_addtroublesum');
end
function Command_startquest(company, dc, questType, from)
	local questClass = GetClassList('Quest')[questType];
	if questClass == nil then
		ShowMsgBox(company, 'Exist Not Quest -'..questType);
		return;
	end
	StartQuestCore(dc, company, questClass);
	if from == 'Manager' then
		SendNotification(company, 'ReloadQuestManager', questType);
	end
end
function Command_completequest(company, dc, questType, from)
	local questClass = GetClassList('Quest')[questType];
	if questClass == nil then
		ShowMsgBox(company, 'Exist Not Quest -'..questType);
		return;
	end
	local stage, progress = GetQuestState(company, questClass.name);
	CompleteQuestCore(dc, company, questClass, progress, nil, true);
	if from == 'Manager' then
		SendNotification(company, 'ReloadQuestManager', questType);
	end
end
function Command_resetquest(company, dc, questType, from)
	local questClass = GetClassList('Quest')[questType];
	if questClass == nil then
		ShowMsgBox(company, 'Exist Not Quest -'..questType);
		return;
	end
	
	RequestCancelQuest(dc, company, questClass, nil, true);
	
	if from == 'Manager' then
		SendNotification(company, 'ReloadQuestManager', questType);
	end
end
function Command_changequestproperty(company, dc, questType, propertyType, propertyValue, from)
	local questClass = GetClassList('Quest')[questType];
	LogAndPrint('Command_changequestproperty', questType, propertyType, propertyValue, from);
	if questClass == nil then
		ShowMsgBox(company, 'Exist Not Quest -'..questType);
		return;
	end
	
	dc:UpdateQuestProperty(company, questType, propertyType, propertyValue);
	dc:Commit('Command_changequestproperty');
end
function Command_go(company, dc, lobbyType)
	ChangeLocation(company, lobbyType);
end
function Command_openarea(company, dc, zoneType)
	local zoneCls = GetClassList('Zone')[zoneType];
	if zoneCls then
		dc:UpdateCompanyProperty(company, 'ZoneState/'..zoneType..'/Opened', 'true');
		dc:Commit('Command_openarea');
	end
end
function Command_t(company, dc)
	DirectMission(company, 'Tutorial_CrowBill', {});
end
function Command_d(company, dc)
	DirectMission(company, 'Demo', {});
end
function Command_emergencynotice(company, dc, msg)
	InvokeEmergencyNotice(msg);
end
function Command_contract(company, dc, officName)
	StartLobbyDialog(company, 'Initial_OfficeContract', {office_name=officName});
end
function Command_needscout(company, dc, rosterName)
	dc:UpdateCompanyProperty(company, string.format('Scout/%s/NeedScout', rosterName), 'true');
	dc:Commit('Command_needscout');
end
function Command_scout(company, dc, rosterName)
	StartLobbyDialog(company, 'Initial_SetRosterInfo_Standalone', {roster_name=rosterName});
end
function Command_officerent(company, dc)
	if company.OfficeRentVill <= 0 or company.OfficeRentDuration <= 0 then
		SendChat(company, 'Notice', 'System', string.format('Not OfficeRent Target - (OfficeRentVill : %d, OfficeRentDuration : %d)', company.OfficeRentVill, company.OfficeRentDuration));
		return;
	end
	-- OfficeRentCounter 프로퍼티가 적합한 상태가 되게 변경하고 다이얼로그를 진행한다. (적합하지 않은 상태에서 진행 시에, 이후 테스트에서 문제를 일으킬 수 있음)
	dc:UpdateCompanyProperty(company, 'OfficeRentCounter', company.OfficeRentDuration + company.OfficeRentCountDelayCont);
	dc:Commit('Command_officerent');
	StartLobbyDialog(company, 'OfficeRent_Main', {});
end
function Command_salary(company, dc, rosterName)
	local roster = GetRoster(company, rosterName);
	if roster == nil then
		SendChat(company, 'Notice', 'System', string.format('Not Exist Roster - %s', rosterName));
		return;
	end
	if roster.Salary <= 0 or roster.SalaryDuration <= 0 then
		SendChat(company, 'Notice', 'System', string.format('Not Salary Target - %s (Salary : %d, SalaryDuration : %d)', rosterName, roster.Salary, roster.SalaryDuration));
		return;
	end
	-- SalaryCounter 프로퍼티가 적합한 상태가 되게 변경하고 다이얼로그를 진행한다. (적합하지 않은 상태에서 진행 시에, 이후 테스트에서 문제를 일으킬 수 있음)
	dc:UpdatePCProperty(roster, 'SalaryCounter', roster.SalaryDuration + roster.SalaryCountDelayCont);
	dc:Commit('Command_salary');
	StartLobbyDialog(company, 'Salary_Main', {roster_name=rosterName});
end
function Command_salarynotice(company, dc, rosterName)
	local roster = GetRoster(company, rosterName);
	if roster == nil then
		SendChat(company, 'Notice', 'System', string.format('Not Exist Roster - %s', rosterName));
		return;
	end
	if roster.Salary <= 0 or roster.SalaryDuration <= 0 then
		SendChat(company, 'Notice', 'System', string.format('Not Salary Target - %s (Salary : %d, SalaryDuration : %d)', rosterName, roster.Salary, roster.SalaryDuration));
		return;
	end
	-- SalaryCounter 프로퍼티가 적합한 상태가 되게 변경하고 다이얼로그를 진행한다. (적합하지 않은 상태에서 진행 시에, 이후 테스트에서 문제를 일으킬 수 있음)
	dc:UpdatePCProperty(roster, 'SalaryCounter', roster.SalaryDuration - 1);
	dc:Commit('Command_salary');
	StartLobbyDialog(company, 'Salary_Notice', {roster_name=rosterName});
end
function Command_resetsalary(company, dc, rosterName)
	local roster = GetRoster(company, rosterName);
	if roster == nil then
		SendChat(company, 'Notice', 'System', string.format('Not Exist Roster - %s', rosterName));
		return;
	end
	dc:UpdatePCProperty(roster, 'SalaryCounter', 0);
	dc:UpdatePCProperty(roster, 'SalaryCountNormalTotal', 0);
	dc:UpdatePCProperty(roster, 'SalaryCountNormalCont', 0);
	dc:UpdatePCProperty(roster, 'SalaryCountBonusTotal', 0);
	dc:UpdatePCProperty(roster, 'SalaryCountBonusCont', 0);
	dc:UpdatePCProperty(roster, 'SalaryCountDelayTotal', 0);
	dc:UpdatePCProperty(roster, 'SalaryCountDelayCont', 0);
	dc:UpdatePCProperty(roster, 'SalaryNoticed', false);
	dc:Commit('Command_resetsalary');
end
function Command_whatsalary(company, dc, rosterName)
	local roster = GetRoster(company, rosterName);
	if roster == nil then
		SendChat(company, 'Notice', 'System', string.format('Not Exist Roster - %s', rosterName));
		return;
	end
	local propKeyList = {
		'Salary', 'SalaryDuration', 'SalaryCounter',
		'SalaryCountNormalTotal', 'SalaryCountNormalCont',
		'SalaryCountBonusTotal', 'SalaryCountBonusCont',
		'SalaryCountDelayTotal', 'SalaryCountDelayCont',
		'SalaryNoticed'
	};
	for _, propKey in ipairs(propKeyList) do
		local propValue = SafeIndex(roster, propKey);
		SendChat(company, 'Notice', 'System', string.format('%s[%s] : %s', rosterName, propKey, tostring(propValue)));	
	end
end
function Command_cp(company, dc, propKey, propVal) 
	local propKey = string.gsub(propKey, '%.', '/');
	local keyChain = table.map(string.split(propKey, '/'), function(k) if string.match(k, '^%d+$') then return tonumber(k) else return k end end);
	local prevPropValue = SafeIndex(company, unpack(keyChain));
	dc:UpdateCompanyProperty(company, propKey, propVal);
	dc:Commit('Command_cp');
	
	local propValue = SafeIndex(company, unpack(keyChain));
	SendChat(company, 'Notice', 'System', string.format('company[%s] : %s -> %s', propKey, tostring(prevPropValue), tostring(propValue)));
end
function Command_rp(company, dc, rostertype, propKey, propVal) 
	local roster = GetRoster(company, rostertype);
	if roster == nil then
		ShowMsgBox(company, 'Not Exist Roster - '..rostertype);
		return;
	end
	local propKey = string.gsub(propKey, '%.', '/');
	local keyChain = string.split(propKey, '/');
	local prevPropValue = SafeIndex(roster, unpack(keyChain));
	dc:UpdatePCProperty(roster, propKey, propVal);
	dc:Commit('Command_rp');
	
	local propValue = SafeIndex(roster, unpack(keyChain));
	SendChat(company, 'Notice', 'System', string.format('%s[%s] : %s -> %s', rostertype, propKey, tostring(prevPropValue), tostring(propValue)));
end
function Command_joblv(company, dc, rostertype, joblv, targetjob, jobexp)
	local roster = GetRoster(company, rostertype);
	if roster == nil then
		ShowMsgBox(company, 'Not Exist Roster - '..rostertype);
		return;
	end
	
	if targetjob == nil then
		targetjob = roster.Object.Job.name;
	end
	if jobexp == nil then
		jobexp = 0;
	end
	
	local targetKey, expKey;
	if roster.RosterType == 'Pc' then
		targetKey = string.format('EnableJobs/%s/Lv', targetjob);
		expKey = string.format('EnableJobs/%s/Exp', targetjob);
	elseif roster.RosterType == 'Beast' or roster.RosterType == 'Machine' then
		targetKey = 'JobLv';
		expKey = 'JobExp';
	end
	local prevJobLv = SafeIndex(roster, unpack(string.split(targetKey, '/')));
	local prevJobExp = SafeIndex(roster, unpack(string.split(expKey, '/')));
	dc:UpdatePCProperty(roster, targetKey, tonumber(joblv));
	dc:UpdatePCProperty(roster, expKey, tonumber(jobexp));
	dc:Commit('Command_joblv');
	
	SendChat(company, 'Notice', 'System', string.format('%s[%s] : %s -> %s', rostertype, targetKey, tostring(prevJobLv), tostring(joblv)));
	SendChat(company, 'Notice', 'System', string.format('%s[%s] : %s -> %s', rostertype, expKey, tostring(prevJobExp), tostring(jobexp)));
end
function Command_allreport(company, dc, currentReward)
	currentReward = currentReward or 100;
	
	dc:UpdateCompanyProperty(company, 'CurrentReward', currentReward);
	
	for i, division in ipairs(GetClassList('Zone')[company.CurrentZone].Division) do
		for j, section in ipairs(division.Section) do
			local reputation = company.Reputation[section.Type];
			dc:UpdateCompanyProperty(company, string.format('Reputation/%s/Lv', section.Type), reputation.MaxLv);
			dc:UpdateCompanyProperty(company, string.format('Reputation/%s/Opened', section.Type), true);
		end
	end
	
	for i, missionType in pairs(GetClassList('MissionType')) do
		dc:AddCompanyProperty(company, string.format('ActivityReport/Activities/%s/Clear', missionType.name), math.random(0, 3));
	end
	
	dc:Commit('Command_allreport');
end
function Command_clearreport(company, dc)
	LobbyAction_RequestActivityReward(dc, company, {});
	dc:Commit('Command_clearreport');
end
function Command_setreporttime(company, dc)
	-- 10초 뒤에 보상을 수령할 수 있는 상황으로 만들어줌
	dc:Commit('Command_setreporttime');
end
function Command_setresttime(company, dc)
	local suggestion = GetClassList('Suggestion')['ConditionRest'];
	if not suggestion or not suggestion.name then
		return;
	end
	-- 10초 뒤에 무기력 탈출 시스템을 쓸 수 있는 상황으로 만들어줌
	dc:UpdateCompanyProperty(company, suggestion.UpdateTime, os.time() - suggestion.Duration + 10);
	dc:Commit('Command_setresttime');
end
function Command_resetdivision(company, dc)
	for i, division in ipairs(GetClassList('Zone')[company.CurrentZone].Division) do
		for j, section in ipairs(division.Section) do
			dc:UpdateCompanyProperty(company, string.format('Reputation/%s/Opened', section.Type), false);
		end
	end
	dc:Commit('Command_resetdivision');
end
function Command_wp(company, dc, propKey, propVal)
	UpdateWorldProperty(propKey, propVal, string.format('Command_wp:%s', company.CompanyName));
end

function Command_systemmail(company, dc, to, title, contents, itemType, count)	
	itemType = FindItemType(itemType);
	if itemType == nil then
		count = 0;
	end
	SendSystemMail('System', to, title, contents, itemType, tonumber(count));
end
function Command_systemsystemmail(company, dc, to, systemMailKey)
	local systemMailCls = GetClassList('SystemMail')[systemMailKey];
	if systemMailCls == nil then
		return env;
	end
	SendSystemMail(systemMailKey, to, systemMailKey, systemMailKey, systemMailCls.AttachItem, systemMailCls.AttachItemCount);
end
function Command_whatcp(company, dc, propKey)
	local propKey = string.gsub(propKey, '%.', '/');
	local keyChain = table.map(string.split(propKey, '/'), function(k) if string.match(k, '%d+') then return tonumber(k) else return k end end);
	local propValue = SafeIndex(company, unpack(keyChain));
	SendChat(company, 'Notice', 'System', string.format('company[%s] : %s', propKey, tostring(propValue)));
end
function Command_whatrp(company, dc, rostertype, propKey)
	local roster = GetRoster(company, rostertype);
	if roster == nil then
		ShowMsgBox(company, 'Not Exist Roster - '..rostertype);
		return;
	end
	local propKey = string.gsub(propKey, '%.', '/');
	local keyChain = string.split(propKey, '/');
	local propValue = SafeIndex(roster, unpack(keyChain));
	SendChat(company, 'Notice', 'System', string.format('%s[%s] : %s', rostertype, propKey, tostring(propValue)));
end
function Command_beastlist(company, dc)
	local beasts = GetAllRoster(company, 'Beast')
	for _, beast in ipairs(beasts) do
		SendChat(company, 'Notice', 'System', string.format('%d: %s (%s)', _, beast.RosterKey, beast.Object.name));
	end
end
function Command_clearguidetrigger(company, dc)
	for key, guideTrigger in pairs(company.GuideTrigger) do
		if guideTrigger.Pass then
			dc:UpdateCompanyProperty(company, 'GuideTrigger/'..key..'/Pass', false);
		end
	end
	dc:Commit('Command_clearguidetrigger');
end
function Command_clearlobbyguidetrigger(company, dc)
	for key, guideTrigger in pairs(company.LobbyGuideTrigger) do
		if guideTrigger.Pass then
			dc:UpdateCompanyProperty(company, 'LobbyGuideTrigger/'..key..'/Pass', false);
		end
	end
	dc:Commit('Command_clearlobbyguidetrigger');
end
function Command_systemmailtest(company, dc, key)
	if key == 'all' then
		for key, cls in pairs(GetClassList('SystemMail')) do
			dc:GiveSystemMailOneKey(company, key);
		end
	else
		local cls = GetClassList('SystemMail')[key];
		if cls == nil then
			return;
		end
		dc:GiveSystemMailOneKey(company, key);
	end
	dc:Commit('Command_systemmailtest');
end
function Command_civilmailtest(company, dc, ageType, count)
	if count == nil then
		count = 1;
	end
	for i = 1, count do
		local civilName, mailKey, mailProb, itemType, itemCount = GetCivilRescueReward(ageType);
		if civilName then
			dc:GiveSystemMail(company, mailKey, mailKey, mailKey, itemType, itemCount, { CivilName = civilName, CivilAgeType = ageType }, nil, 'General');
		end
	end
	dc:Commit('Command_systemmailtest');
end
function Command_resettm(company, dc)
	for key, tm in pairs(company.Troublemaker) do
		if tm.Exp > 0 then
			dc:UpdateCompanyProperty(company, string.format('Troublemaker/%s/Exp', key), 0);
		end
		if tm.Reward then
			dc:UpdateCompanyProperty(company, string.format('Troublemaker/%s/Reward', key), false);
		end
		if tm.IsNew then
			dc:UpdateCompanyProperty(company, string.format('Troublemaker/%s/IsNew', key), false);
		end
	end
	dc:Commit('Command_resettm');
end
function Command_alltm(company, dc)
	for key, tm in pairs(company.Troublemaker) do
		if tm.Exp < tm.MaxExp then
			dc:UpdateCompanyProperty(company, string.format('Troublemaker/%s/Exp', key), tm.MaxExp);
		end
		if tm.Exp == 0 then
			dc:UpdateCompanyProperty(company, string.format('Troublemaker/%s/IsNew', key), true);
		end
	end
	dc:Commit('Command_alltm');
end
function Command_tmexp(company, dc, tmName, grade)
	local tm = GetWithoutError(company.Troublemaker, tmName);
	if not tm or not tm.name and tm.name == 'None' then
		return;
	end
	local needExp = nil;
	local dummyTM = { Exp = 0, MaxExp = tm.MaxExp };
	local gradeNum = tonumber(grade);
	for i = 0, tm.MaxExp do
		dummyTM.Exp = i;
		if GetTroublemakerInfoGrade(dummyTM) >= gradeNum then
			needExp = i;
			break;
		end
	end
	if not needExp then
		return;
	end
	dc:UpdateCompanyProperty(company, string.format('Troublemaker/%s/Exp', tmName), needExp);
	dc:Commit('Command_tmexp');
end
function Command_resettech(company, dc)
	local techClsList = GetClassList('Technique');
	for key, tech in pairs(company.Technique) do
		local techCls = techClsList[key];
		if tech.Opened ~= techCls.Opened then
			dc:UpdateCompanyProperty(company, string.format('Technique/%s/Opened', key), techCls.Opened);
		end
		if tech.IsNew then
			dc:UpdateCompanyProperty(company, string.format('Technique/%s/IsNew', key), false);
		end
	end
	dc:Commit('Command_resettech');
end
function Command_alltech(company, dc)
	for key, tech in pairs(company.Technique) do
		if not tech.Opened then
			dc:UpdateCompanyProperty(company, string.format('Technique/%s/Opened', key), true);
			dc:UpdateCompanyProperty(company, string.format('Technique/%s/IsNew', key), true);
		end
	end
	dc:Commit('Command_alltech');
end
function Command_tech(company, dc, techName)
	local techCls = GetClassList('Technique')[techName];
	if not techCls or not techCls.name or techCls.name == 'None' then
		return
	end
	local tech = company.Technique[techName]
	if not tech.Opened then
		dc:UpdateCompanyProperty(company, string.format('Technique/%s/Opened', techName), true);
		dc:UpdateCompanyProperty(company, string.format('Technique/%s/IsNew', techName), true);
	end
	dc:Commit('Command_tech');
end
function Command_addsteamstat(company, dc, statName, value)
	local statCls = GetClassList('SteamStat')[statName];
	if statCls and statCls.name and statCls.name ~= 'None' then
		StartLobbyDialog(company, 'Command_AddSteamStat', {stat_name=statName, value=tonumber(value)});
	end
end
function Command_updatesteamstat(company, dc, statName, value)
	local statCls = GetClassList('SteamStat')[statName];
	if statCls and statCls.name and statCls.name ~= 'None' then
		StartLobbyDialog(company, 'Command_UpdateSteamStat', {stat_name=statName, value=tonumber(value)});
	end
end
function Command_updatesteamachievement(company, dc, achievementName, achieved)
	local achievementCls = GetClassList('SteamAchievement')[achievementName];
	if achievementCls and achievementCls.name and achievementCls.name ~= 'None' then
		StartLobbyDialog(company, 'Command_UpdateSteamAchievement', {achievement_name=achievementName, achieved=StringToBool(achieved)});
		if not StringToBool(achieved) and company.CheckAchievements[achievementName] then
			dc:UpdateCompanyProperty(company, string.format('CheckAchievements/%s', achievementName), false);
			dc:Commit('Command_updatesteamachievement');
		end
	end
end
function Command_resetallsteamachievement(company, dc)
	local achievementClsList = GetClassList('SteamAchievement');
	for _, achievementCls in pairs(achievementClsList) do
		StartLobbyDialog(company, 'Command_ResetSteamAchievement', {achievement_name=achievementCls.name});
	end
	for key, checked in pairs(company.CheckAchievements) do
		if checked then
			dc:UpdateCompanyProperty(company, string.format('CheckAchievements/%s', key), false);
		end
	end
	dc:Commit('Command_resetallsteamachievement');
end
function Command_updateshop(company, dc)
	SupervisorCommand('updateshop');
end
function Command_updatefood(company, dc)
	SupervisorCommand('updatefood');
end
function Command_startsafetyfever(company, dc)
	local userZoneType = SafeIndex(GetClassList('LobbyWorldDefinition'), GetUserLocation(company), 'Zone', 'name');
	if userZoneType == nil then
		return;
	end
	SupervisorCommand('startsafetyfever', userZoneType);
end
function Command_endsafetyfever(company, dc)
	local userZoneType = SafeIndex(GetClassList('LobbyWorldDefinition'), GetUserLocation(company), 'Zone', 'name');
	if userZoneType == nil then
		return;
	end
	if not IsSingleplayMode() then
		SupervisorCommand('endsafetyfever', userZoneType);
	else
		
	end
end
function Command_gc(company, dc)
	collectgarbage();
end
function Command_alllusers(company, dc)
	local allUser = GetAllUsers();	-- user == company
	SendChat(company, 'Notice', 'System', string.format('#allUser: %d', #allUser));	
	for i, user in pairs(allUser) do
		SendChat(company, 'Notice', 'System', string.format('- i: %d, user: %s', i, user.CompanyName));	
	end
end
function Command_missionclear(company, dc, missionName)
	local mission = GetClassList('Mission')[missionName];
	if mission == nil then
		return;
	end
	-- 10 - 1. 미션 완료 프로퍼티.
	if not company.MissionCleared[mission.name] then
		dc:UpdateCompanyProperty(company, string.format('MissionCleared/%s', mission.name), true);
	end
	-- 10 - 2. 커스텀 프로퍼티.
	local envT = {
		GetStageVariable = function() LogAndPrint('GetStageVariable!!'); return 0 end,
	};
	setmetatable(envT, {__index = _G});
	local callFunc = function(func, ...)
		local envPrev = getfenv(func);
		setfenv(func, envT);
		func(...);
		setfenv(func, envPrev);
	end;
	
	local script = _G['MissionResult_Custom_' ..mission.name];
	if script then
		callFunc(script, mission, dc, company, {}, true, {}, {}, false, nil);
	end
	callFunc(MissionResult_Custom_Common, mission, dc, company, {}, true, {}, {}, false, nil);
	
	dc:Commit('Command_missionclear');
end
function Command_allms(company, dc)
	for masterySetName, opened in pairs(company.MasterySetIndex) do
		if not opened then
			dc:UpdateCompanyProperty(company, 'MasterySetIndex/'..masterySetName, true);
		end
	end
	dc:Commit('Command_allms');
end
function Command_resetms(company, dc)
	for masterySetName, opened in pairs(company.MasterySetIndex) do
		if opened then
			dc:UpdateCompanyProperty(company, 'MasterySetIndex/'..masterySetName, false);
		end
	end
	dc:Commit('Command_resetms');
end
function Command_refillcraftitem(company, dc, ratio)
	local matSet = {};
	for _, recipeCls in pairs(GetClassList('Recipe')) do
		for _, matCls in ipairs(recipeCls.RequireMaterials) do
			matSet[matCls.Item] = true;
		end
	end
	for matName, _ in pairs(matSet) do
		local itemCls = GetClassList('Item')[matName];
		if itemCls and itemCls.name and itemCls.Stackable then
			local prevItem = GetInventoryItemByType(company, matName);
			local prevCount = prevItem and prevItem.Amount or 0;
			local newCount = math.floor(itemCls.MaxStack * (ratio or 1));
			local refillCount = newCount - prevCount;
			if refillCount > 0 then
				dc:GiveItem(company, matName, refillCount);
			elseif refillCount < 0 and prevItem then
				dc:TakeItem(prevItem, -refillCount);
			end
		end
	end
	dc:Commit('Command_refillcraftitem');
end
function Command_refillupgradeitem(company, dc, ratio)
	local matSet = {};
	for _, idspace in ipairs({'ItemUpgradeType', 'ItemUpgradeStatusType'}) do
		for _, upgradeCls in pairs(GetClassList(idspace)) do
			for _, matCls in ipairs(upgradeCls.ResultMaterial) do
				matSet[matCls.Result] = true;
			end
		end
	end
	for matName, _ in pairs(matSet) do
		local itemCls = GetClassList('Item')[matName];
		if itemCls and itemCls.name and itemCls.Stackable then
			local prevItem = GetInventoryItemByType(company, matName);
			local prevCount = prevItem and prevItem.Amount or 0;
			local newCount = math.floor(itemCls.MaxStack * (ratio or 1));
			local refillCount = newCount - prevCount;
			if refillCount > 0 then
				dc:GiveItem(company, matName, refillCount);
			elseif refillCount < 0 and prevItem then
				dc:TakeItem(prevItem, -refillCount);
			end
		end
	end
	dc:Commit('Command_refillupgradeitem');
end
function Command_allrecipe(company, dc)
	local matSet = {};
	for key, recipe in pairs(company.Recipe) do
		if not recipe.Opened then
			dc:UpdateCompanyProperty(company, string.format('Recipe/%s/Opened', key), true);
			dc:UpdateCompanyProperty(company, string.format('Recipe/%s/IsNew', key), true);
		end
		if recipe.Exp < recipe.MaxExp then
			dc:UpdateCompanyProperty(company, string.format('Recipe/%s/Exp', key), recipe.MaxExp);
		end
	end
	dc:Commit('Command_allrecipe');
end
function Command_resetrecipe(company, dc)
	local matSet = {};
	for key, recipe in pairs(company.Recipe) do
		local recipeCls = GetClassList('Recipe')[key];
		if recipe.Opened ~= recipeCls.Opened then
			dc:UpdateCompanyProperty(company, string.format('Recipe/%s/Opened', key), recipeCls.Opened);
		end
		if recipe.IsNew then
			dc:UpdateCompanyProperty(company, string.format('Recipe/%s/IsNew', key), false);
		end
		if recipe.Exp > 0 then
			dc:UpdateCompanyProperty(company, string.format('Recipe/%s/Exp', key), 0);
		end
	end
	dc:Commit('Command_resetrecipe');
end
function Command_noticetest(company, dc, noticeKey)
	StartLobbyDialog(company, 'Notice_Common', { notice_type = noticeKey });
end
function Command_emotiontest(company, dc, infoKey, dialogType)
	if dialogType == nil then
		dialogType = 'Sub';
	end
	StartLobbyDialog(company, 'EmotionTest', { object_info = infoKey, dialog_type = dialogType });
end

function Command_resetrestexp(company, dc, resetVal)	
	resetVal = tonumber(resetVal or 0)
	local rosterList = GetAllRoster(company);
	for index, roster in ipairs (rosterList) do
		if roster ~= nil then
			dc:UpdatePCProperty(roster, 'RestExp', resetVal);
			dc:UpdatePCProperty(roster, 'RestJobExp', resetVal);
			dc:UpdatePCProperty(roster, 'LastMissionPlayTime', os.time());
		end
	end
	dc:Commit('Command_resetrestexp');	
end
function Command_lostshop(company, dc)
	dc:UpdateCompanyProperty(company, 'LostShop/ActiveSlot', 1);
	dc:UpdateCompanyProperty(company, 'LostShop/IsNew', true);
	dc:UpdateCompanyProperty(company, 'LostShop/ItemList/1/Item', 'Potion_Brave');
	dc:UpdateCompanyProperty(company, 'LostShop/ItemList/1/Price', 1000);
	dc:UpdateCompanyProperty(company, 'LostShop/ItemList/1/Stock', 1);
	dc:UpdateCompanyProperty(company, 'LostShop/ItemList/1/Option/OptionKey', 'None');
	dc:Commit('Command_lostshop');
end
function Command_allreputation(company, dc)
	for key, section in pairs(company.Reputation) do
		if section.Lv < section.MaxLv then
			dc:UpdateCompanyProperty(company, string.format('Reputation/%s/Lv', key), section.MaxLv);
		end
	end
	dc:Commit('Command_allreputation');
end
function Command_resetreputation(company, dc)
	for key, section in pairs(company.Reputation) do
		if section.Lv > 0 then
			dc:UpdateCompanyProperty(company, string.format('Reputation/%s/Lv', key), 0);
		end
	end
	dc:Commit('Command_resetreputation');
end
function Command_opendivision(company, dc, sectionName)
	local section = GetWithoutError(company.Reputation, sectionName);
	if not section or section.Opened then
		return;
	end
	dc:UpdateCompanyProperty(company, string.format('Reputation/%s/Opened', sectionName), true);
	dc:Commit('Command_opendivision');
end
function Command_resetdivision(company, dc)
	local office = GetClassList('Office')[company.Office];
	for key, section in pairs(company.Reputation) do
		if key ~= office.Section and section.Opened then
			dc:UpdateCompanyProperty(company, string.format('Reputation/%s/Opened', key), false);
		end
	end
	dc:Commit('Command_resetdivision');
end
function Command_addreportbonus(company, dc, bonusType, bonusCount)
	for sectionName, _ in pairs(company.ActivityReport.ReputationBonus) do
		local section = company.Reputation[sectionName];
		for i, info in ipairs(section.Bonus) do
			if info.Type == bonusType then
				dc:AddCompanyProperty(company, string.format('ActivityReport/ReputationBonus/%s/%d', sectionName, i), bonusCount);
				break;
			end
		end
	end
	dc:Commit('Command_addreportbonus');
end
function Command_report(company, dc)
	StartLobbyDialog(company, 'ActivityReport_Main', {});
end
function Command_temp1(company, dc)
	Command_rp(company, dc, 'Leton', 'EnableJobs/MartialArtist/LastLv', 0);
	Command_cp(company, dc, 'Progress/Character/Leton', 6);
end

function Command_updaterepeatquest(company, dc)
	company.RepeatQuestUpdateTime = os.time();
	UpdateRepeatQuestOneUser(dc, company, os.time() + 1);
	dc:Commit('Command_updaterepeatquest');
end

function Command_lobbyevent(company, dc, sectionName, slotIndex)
	local lobbyEventClsList = GetClassList('LobbyEvent');
	local lobbyEventCls = SafeIndex(lobbyEventClsList, sectionName, 'Images', tonumber(slotIndex));
	if not lobbyEventCls then
		SendChat(company, 'Notice', 'System', 'LobbyEvent Not Exists - sectionName: '..sectionName..', slotIndex:'..slotIndex);
		return;
	end
	local env = { _no_action = true };
	env.event_type = lobbyEventCls.Dialog;
	env.lobby_map = lobbyEventCls.Map;
	env.camera_mode = lobbyEventCls.Camera;
	env._auto_fade_in = StringToBool(lobbyEventCls.AutoFadeIn, true);
	StartLobbyDialog(company, 'LobbyEvent_Common', env);
end

function Command_questevent(company, dc, questName, dialogType)
	local env = { _no_action = true };
	env.quest_name = questName;
	env.dialog_type = dialogType;
	StartLobbyDialog(company, 'QuestEvent_Common', env);
end

function Command_goray(company, dc)
	local props = {{'Progress/Tutorial/Opening','FireflyPark'},
	{'LastLocation/LobbyType','LandOfStart'},
	{'MissionCleared/Tutorial_CrowBill','TRUE'},
	{'Progress/Tutorial/Opening','CompanyName'},
	{'MissionCleared/Tutorial_FireflyPark_Roster','TRUE'},
	{'MissionCleared/Tutorial_FireflyPark','TRUE'},
	{'LeaderID','1'},
	{'TroublesumUpdateTime','1578041430'},
	{'RepeatQuestUpdateTime','1578041430'},
	{'NeedAdjustJobLv','FALSE'},
	{'Waypoint/LandOfStart/IsNew','FALSE'},
	{'CompanyMastery','CustomerSatisfaction'},
	{'CompanyMasteries/CustomerSatisfaction/IsNew','FALSE'},
	{'Progress/Tutorial/Opening','ScoutAlbus'},
	{'LastLocation/LobbyType','Office_Albus'},
	{'Progress/Tutorial/Opening','Office_Albus'},
	{'CheckAchievements/StoryTroubleshooter','TRUE'},
	{'Waypoint/Office_Albus/IsNew','FALSE'},
	{'Progress/Tutorial/Opening','TutorialGameMenu'},
	{'Progress/Tutorial/AbilityChange','1'},
	{'Progress/Tutorial/Hunter','1'},
	{'Progress/Tutorial/Roster','12'},
	{'Progress/Tutorial/GameMenuType','Clear'},
	{'Progress/Tutorial/Opening','Silverlining'},
	{'Progress/Tutorial/Opening','OfficeContract'},
	{'LastLocation/LobbyType','LandOfStart'},
	{'ActivityReport/Unlock','TRUE'},
	{'Technique/Alacrity/Opened','TRUE'},
	{'Technique/Alacrity/IsNew','TRUE'},
	{'Technique/Supporter/Opened','TRUE'},
	{'Technique/Supporter/IsNew','TRUE'},
	{'Technique/HighSpeed/Opened','TRUE'},
	{'Technique/HighSpeed/IsNew','TRUE'},
	{'MissionCleared/Tutorial_Silverlining','TRUE'},
	{'CheckAchievements/StoryOfficeAlbus','TRUE'},
	{'SystemMailReceived/ItemSupply_Costume_Albus','TRUE'},
	{'Office','Office_Silverlining'},
	{'OfficeRentType','1'},
	{'LastLocation/LobbyType','Office'},
	{'Progress/Tutorial/Opening','OfficeMoveIn'},
	{'Progress/Tutorial/OfficeCharPosition','AlbusStand'},
	{'CheckAchievements/StoryOfficeSilverlining','TRUE'},
	{'Waypoint/Office/IsNew','FALSE'},
	{'OfficeMenu/Opened','TRUE'},
	{'OfficeMenu/TroublemakerList/Opened','TRUE'},
	{'OfficeMenu/Technique/Opened','TRUE'},
	{'OfficeMenu/Statistics/Opened','TRUE'},
	{'OfficeMenu/ActivityReport/Opened','TRUE'},
	{'Progress/Tutorial/Office','1'},
	{'Progress/Tutorial/Statistics','1'},
	{'Progress/Tutorial/BrokenMachine','1'},
	{'Progress/Tutorial/Troublemaker','1'},
	{'Progress/Tutorial/Office','2'},
	{'Progress/Tutorial/Troublemaker','2'},
	{'OfficeMenu/TroublemakerList/Tutorial','FALSE'},
	{'Progress/Tutorial/Troublemaker','3'},
	{'WorkshopMenu/Module/Tutorial','FALSE'},
	{'LobbyMenu/Beast/Opened','TRUE'},
	{'Progress/Tutorial/Hunter','2'},
	{'Progress/Tutorial/Technique','1'},
	{'Progress/Tutorial/TroubleBook','1'},
	{'Progress/Tutorial/TroubleBook','2'},
	{'OfficeMenu/TroubleBook/Tutorial','FALSE'},
	{'Progress/Tutorial/TroubleBook','3'},
	{'Progress/Tutorial/GameMenuType','GameMenu_MasteryInventory'},
	{'LobbyMenu/MasteryInventory/Opened','TRUE'},
	{'Progress/Tutorial/AbilityChange','2'},
	{'Progress/Tutorial/ActivityReport','1'},
	{'Progress/Tutorial/Office','3'},
	{'Progress/Tutorial/Statistics','2'},
	{'OfficeMenu/Statistics/Tutorial','FALSE'},
	{'Progress/Tutorial/Office','4'},
	{'Progress/Tutorial/Technique','2'},
	{'OfficeMenu/Technique/Tutorial','FALSE'},
	{'Progress/Tutorial/GameMenuType','GameMenu_Roster'},
	{'LobbyMenu/Roster/Opened','TRUE'},
	{'WorkshopMenu/Machine/Tutorial','FALSE'},
	{'WorkshopMenu/Module/Opened','TRUE'},
	{'Progress/Tutorial/ModuleCraft','1'},
	{'Progress/Tutorial/MachineCraft','2'},
	{'Progress/Tutorial/ModuleCraft','2'},
	{'Progress/Tutorial/MachineCraft','3'},
	{'OfficeMenu/Worldmap/Tutorial','FALSE'},
	{'LobbyMenu/Machine/Opened','TRUE'},
	{'Progress/Tutorial/MachineCraft','4'},
	{'Progress/Tutorial/Office','5'},
	{'Progress/Tutorial/ActivityReport','2'},
	{'OfficeMenu/ActivityReport/Tutorial','FALSE'},
	{'Progress/Tutorial/ActivityReport','3'},
	{'Progress/Tutorial/ActivityReport','4'},
	{'Progress/Tutorial/ActivityReport','5'},
	{'Progress/Tutorial/ActivityReport','6'},
	{'Progress/Tutorial/Office','6'},
	{'OfficeMenu/Tutorial','FALSE'},
	{'BarMenu/Tutorial','TRUE'},
	{'Progress/Tutorial/Office','7'},
	{'WorkshopMenu/Opened','TRUE'},
	{'BarMenu/Tutorial','FALSE'},
	{'Progress/Tutorial/Workshop','1'},
	{'Progress/Tutorial/Office','8'},
	{'WorkshopMenu/Tutorial','FALSE'},
	{'WorkshopMenu/Get/Opened','TRUE'},
	{'WorkshopMenu/Get/Tutorial','FALSE'},
	{'OfficeMenu/Worldmap/Opened','TRUE'},
	{'Progress/Tutorial/Workshop','2'},
	{'OfficeMenu/Tutorial','TRUE'},
	{'Progress/Tutorial/Office','9'},
	{'BarMenu/Tutorial','TRUE'},
	{'OfficeMenu/Tutorial','FALSE'},
	{'Progress/Tutorial/Worldmap','1'},
	{'Stats/RestAction/Drinking_Cool','1'},
	{'UnlockService/Don_CPRestore','TRUE'},
	{'WorkshopMenu/Opened','FALSE'},
	{'OfficeMenu/Tutorial','TRUE'},
	{'BarMenu/Tutorial','FALSE'},
	{'Progress/Tutorial/Office','10'},
	{'OfficeMenu/Tutorial','FALSE'},
	{'BarMenu/Tutorial','TRUE'},
	{'Progress/Tutorial/Office','11'},
	{'BarMenu/Leave/Opened','TRUE'},
	{'BarMenu/Tutorial','FALSE'},
	{'Progress/Tutorial/Office','12'},
	{'Progress/Tutorial/Opening','RamjiPlaza'},
	{'Progress/Tutorial/Opening','RamjiPlaza_Win'},
	{'MissionCleared/Tutorial_RamjiPlaza','TRUE'},
	{'Stats/RestAction/Drinking_Hot','1'},
	{'BarMenu/Leave/Opened','FALSE'},
	{'Progress/Tutorial/Worldmap','2'},
	{'Progress/Zone/EventType','Zone00'},
	{'Progress/Tutorial/Office','20'},
	{'CheckAchievements/StoryRamjiPlaza','TRUE'},
	{'Progress/Tutorial/Office','21'},
	{'Progress/Tutorial/Roster','8'},
	{'Progress/Tutorial/GameMenuType','GameMenu_MailBox'},
	{'LobbyMenu/MailBox/Opened','TRUE'},
	{'Progress/Tutorial/Roster','9'},
	{'Progress/Tutorial/Roster','10'},
	{'Progress/Tutorial/Roster','11'},
	{'Progress/Tutorial/GameMenuType','GameMenu_Inventory'},
	{'LobbyMenu/Inventory/Opened','TRUE'},
	{'Progress/Tutorial/ClassChange','1'},
	{'Progress/Tutorial/ClassChange','2'},
	{'Progress/Tutorial/GameMenuType','GameMenu_Quest'},
	{'LobbyMenu/Quest/Opened','TRUE'},
	{'Progress/Tutorial/Technique','3'},
	{'Progress/Tutorial/ModuleCraft','3'},
	{'Progress/Tutorial/GameMenuType','GameMenu_Company'},
	{'LobbyMenu/Company/Opened','TRUE'},
	{'MasterySetIndex/Bonecrusher','TRUE'},
	{'Progress/Tutorial/Opening','ScoutSion'},
	{'LastLocation/LobbyType','LandOfStart'},
	{'Technique/Consideration/Opened','TRUE'},
	{'Technique/Consideration/IsNew','TRUE'},
	{'Technique/Challenger/Opened','TRUE'},
	{'Technique/Challenger/IsNew','TRUE'},
	{'MissionCleared/Tutorial_PugoStreet','TRUE'},
	{'LastLocation/LobbyType','Office'},
	{'Progress/Tutorial/Opening','PugoStreet_Win'},
	{'CheckAchievements/StoryPugoStreet','TRUE'},
	{'SystemMailReceived/ItemSupply_Costume_Sion','TRUE'},
	{'Stats/RestAction/Sermon','1'},
	{'Progress/Zone/EventType','Zone01'},
	{'OfficeMenu/Chess/Opened','TRUE'},
	{'Progress/Tutorial/Office','30'},
	{'Progress/Tutorial/OfficeCharPosition','Default'},
	{'Progress/Tutorial/Office','31'},
	{'Progress/Character/Irene','2'},
	{'Progress/Character/Sharky','1'},
	{'MissionCleared/Tutorial_Construction_A','TRUE'},
	{'CheckAchievements/StoryConstructionA','TRUE'},
	{'Progress/Tutorial/Office','32'},
	{'Progress/Tutorial/Office','40'},
	{'Progress/Character/Heissing','1'},
	{'Progress/Character/Pierto','1'},
	{'MissionCleared/Tutorial_Road_113','TRUE'},
	{'CheckAchievements/StoryRoad113','TRUE'},
	{'Progress/Character/Irene','3'},
	{'Progress/Character/Issac','1'},
	{'Progress/Character/Anne','2'},
	{'MissionCleared/Tutorial_CrowBillAfter','TRUE'},
	{'CheckAchievements/StoryCrowBillAfter','TRUE'},
	{'Progress/Tutorial/Opening','PugoShop'},
	{'Progress/Character/Heissing','2'},
	{'Progress/Tutorial/Opening','PugoShop_Win'},
	{'MissionCleared/Tutorial_PugoShop','TRUE'},
	{'CheckAchievements/StoryPugoShop','TRUE'},
	{'OfficeMenu/TroubleBook/Opened','TRUE'},
	{'Progress/Character/Irene','5'},
	{'Progress/Character/Issac','2'},
	{'MissionCleared/Tutorial_PurpleBackStreet','TRUE'},
	{'CheckAchievements/StoryPurpleBackStreet','TRUE'},
	{'Progress/Character/Irene','6'},
	{'Progress/Tutorial/Opening','BlueFogStreet'},
	{'Progress/Character/Irene','7'},
	{'Progress/Tutorial/Opening','ScoutIrene'},
	{'LastLocation/LobbyType','LandOfStart'},
	{'MissionCleared/Tutorial_BlueFogStreet','TRUE'},
	{'LastLocation/LobbyType','Office'},
	{'Progress/Character/Irene','8'},
	{'Progress/Tutorial/Opening','BlueFogStreet_Win'},
	{'CheckAchievements/RosterIrene','TRUE'},
	{'SystemMailReceived/ItemSupply_Costume_Irene','TRUE'},
	{'Progress/Character/Irene','9'},
	{'Progress/Character/Marco','1'},
	{'Progress/Tutorial/Opening','SilverliningMarco'},
	{'MissionCleared/Tutorial_SilverliningMarco','TRUE'},
	{'Progress/Character/Marco','5'},
	{'Progress/Character/Sharky','2'},
	{'MissionCleared/Tutorial_PugoBackStreet','TRUE'},
	{'CheckAchievements/StoryPugoBackStreet','TRUE'},
	{'Progress/Character/Issac','3'},
	{'Progress/Character/Issac','4'},
	{'Progress/Tutorial/Opening','Hansando'},
	{'Progress/Character/Issac','5'},
	{'Progress/Character/Kylie','1'},
	{'MissionCleared/Tutorial_Hansando','TRUE'},
	{'CheckAchievements/StoryHansando','TRUE'},
	{'Progress/Character/Anne','3'},
	{'Progress/Tutorial/Opening','GrayCemeteryPark'},
	{'Progress/Character/Anne','4'},
	{'MissionCleared/Tutorial_GrayCemeteryPark','TRUE'},
	{'CheckAchievements/StoryGrayCemeteryPark','TRUE'},
	{'LastLocation/LobbyType','LandOfStart'},
	{'Progress/Tutorial/Opening','ScoutAnne'},
	{'LastLocation/LobbyType','Office'},
	{'Progress/Character/Anne','5'},
	{'CheckAchievements/RosterAnne','TRUE'},
	{'SystemMailReceived/ItemSupply_Costume_Anne','TRUE'},
	{'Progress/Character/Ryo','1'},
	{'MissionCleared/Tutorial_Lasa','TRUE'},
	{'CheckAchievements/StoryLasa','TRUE'},
	{'Progress/Character/Danny','1'},
	{'MissionCleared/Tutorial_Orsay','TRUE'},
	{'CheckAchievements/StoryOrsay','TRUE'},
	{'Progress/Character/Issac','6'},
	{'MissionCleared/Tutorial_LokoCabin','TRUE'},
	{'CheckAchievements/StoryLokoCabin','TRUE'},
	{'Progress/Character/Issac','7'},
	{'MissionCleared/Tutorial_SkyBlue','TRUE'},
	{'CheckAchievements/StorySkyBlue','TRUE'},
	{'Progress/Character/Ryo','2'},
	{'CompanyMasteries/HardFight/Opened','TRUE'},
	{'MissionCleared/Tutorial_PurpleStreet','TRUE'},
	{'OfficeMenu/Opened','FALSE'},
	{'WorkshopMenu/Opened','FALSE'},
	{'Progress/Character/Sion','1'},
	{'Progress/Tutorial/Office_Night','2'},
	{'LastLocation/LobbyType','Office_Night'},
	{'CheckAchievements/StoryPurpleStreet','TRUE'},
	{'Waypoint/Office_Night/IsNew','FALSE'},
	{'Progress/Character/Sion','2'},
	{'Progress/Character/Sion','3'},
	{'Progress/Character/Heissing','3'},
	{'Technique/ForthrightStatement/Opened','TRUE'},
	{'Technique/ForthrightStatement/IsNew','TRUE'},
	{'Technique/GraciousRefusal/Opened','TRUE'},
	{'Technique/GraciousRefusal/IsNew','TRUE'},
	{'Technique/Frankness/Opened','TRUE'},
	{'Technique/Frankness/IsNew','TRUE'},
	{'OfficeMenu/Opened','TRUE'},
	{'LastLocation/LobbyType','Office'},
	{'MissionCleared/Tutorial_PugoShopAfter','TRUE'},
	{'CheckAchievements/StoryPugoShopAfter','TRUE'},
	{'Progress/Character/Sion','4'},
	{'Progress/Character/Heissing','4'},
	{'MissionCleared/Tutorial_HansolStreet','TRUE'},
	{'Progress/Character/Heissing','5'},
	{'LastLocation/LobbyType','LandOfStart'},
	{'Progress/Tutorial/Opening','ScoutHeissing'},
	{'LastLocation/LobbyType','Office'},
	{'Progress/Character/Heissing','6'},
	{'Progress/Tutorial/Opening','ScoutHeissing_End'},
	{'CheckAchievements/RosterHeissing','TRUE'},
	{'SystemMailReceived/ItemSupply_Costume_Heissing','TRUE'},
	{'Progress/Character/Heissing','7'},
	{'Progress/Character/Kylie','2'},
	{'MissionCleared/Tutorial_Road_112','TRUE'},
	{'CheckAchievements/StoryRoad112','TRUE'},
	{'Progress/Character/Irene','10'},
	{'Progress/Character/Irene','11'},
	{'MissionCleared/Tutorial_MetroStreet','TRUE'},
	{'CheckAchievements/StoryMetroStreet','TRUE'},
	{'Progress/Character/Jane','1'},
	{'MissionCleared/Tutorial_StarStreet','TRUE'},
	{'CheckAchievements/StoryStarStreet','TRUE'},
	{'Progress/Character/Sion','5'},
	{'MissionCleared/Tutorial_CrescentBridge','TRUE'},
	{'CheckAchievements/StoryCrescentBridge','TRUE'},
	{'Progress/Character/Ray','3'},
	{'MissionCleared/Tutorial_GrayPortWareHouse','TRUE'},
	{'Progress/Character/Ray', '4'},
	{'MissionCleared/Tutorial_DustWind', 'TRUE'},
	{'Progress/Character/Albus', '10'},
	{'MissionCleared/Tutorial_DustWindRestArea', 'TRUE'}};
	for _, kv in ipairs(props) do
		--LogAndPrint(kv[1], kv[2]);
		dc:UpdateCompanyProperty(company, kv[1], kv[2]);
	end
	dc:Commit('Command_goray');
end

function Command_mission_reward(company, dc, missionStr, cid)
	local missionResultList = string.split(missionStr, '[, ]');
	LogAndPrint('missionResultList:', missionResultList);

	local missionList = GetClassList('Mission');
	local monsterList = GetClassList('Monster');
	local techniqueList = GetClassList('Technique');
	local itemList = GetClassList('Item');

	local missionMonSet = {};
	for _, missionName in ipairs(missionResultList) do
		local missionCls = missionList[missionName];
		for _, info in ipairs(missionCls.Enemies) do
			missionMonSet[info.Type] = true;
		end
	end
	LogAndPrint('missionMonSet:', missionMonSet);

	local rewardItemSet = {};
	local rewardTechSet = {};

	for monsterName, _ in pairs(missionMonSet) do
		local monCls = monsterList[monsterName];
		-- 영웅 이상 장비 아이템
		for _, reward in ipairs(monCls.Rewards) do
			local itemCls = itemList[reward.Item]
			if itemCls.Rank.Weight >= 5 and #itemCls.Type.EquipmentPosition > 0 and itemCls.Type.EquipmentPosition[1] ~= 'None' then
				rewardItemSet[reward.Item] = true;
			end
		end
		-- 특성 연구
		for masteryName, _ in pairs(monCls.Masteries) do
			local tech = GetWithoutError(company.Technique, masteryName);
			if tech and not tech.Opened then
				rewardTechSet[masteryName] = true;
			end
		end
	end

	local rewardItemList = {};
	local rewardTechList = {};

	for k, v in pairs(rewardItemSet) do
		table.insert(rewardItemList, k);
	end
	for k, v in pairs(rewardTechSet) do
		table.insert(rewardTechList, k);
	end

--	LogAndPrint('rewardItemList:', rewardItemList);
	LogAndPrint('rewardTechList:', rewardTechList);
	
	-- 쿼리 생성
	cid = cid or 0;
	for _, tech in ipairs(rewardTechList) do
		LogAndPrint(string.format('call set_companyInfo(%d, \'Technique/%s/Opened\', \'true\');', tonumber(cid), tech));
	end
	
	for techType, tech in pairs(company.Technique) do
		if tech.Opened then
			LogAndPrint(string.format('call add_companyInfo(%d, \'Mastery/%s/Amount\', 30, @error);', tonumber(cid), tech.name));
		end
	end
end

-- 미션용
function ApplyActionSequence(mission, actions)
	local retAction = Result_DirectingScript(function(mid, ds, args)
		--LogAndPrint('ApplyActionSequence', 'Do!');
		return unpack(actions);
	end, {});
	ApplyActions(mission, {retAction});
end
function OnUserCommandMission(company, dc, command, ...)
	LogAndPrint(command, ...);
	if GetPermissionLevel(company) < 1 then
		LogAndPrint('수행 권한이 없습니다');
		ApplyActions(GetMission(company), {Result_ActionDelimiter()});
		return;
	end
	local mission = GetMission(company);
	local f = _G["CommandMission_" .. command];
	local retActions = {};
	if f ~= nil then
		retActions = {f(mission, company, dc, ...)};
	end
	if #retActions == 0 then
		table.insert(retActions, Result_ActionDelimiter());
	end
	ApplyActionSequence(mission, retActions);
end
function CommandMission_bufftest(mission, company, dc, objKey, buffName, buffLevel)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	
	buffName = FindBuffType(buffName);
	
	local b = GetBuff(obj, buffName);
	if b == nil then
		LogAndPrint('No Buff', GetObjKey(obj), buffName);
	else
		LogAndPrint('Has Buff', GetObjKey(obj), buffName, b.Lv);
	end
end
function CommandMission_buff(mission, company, dc, objKey, buffName, buffLevel)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	
	buffName = FindBuffType(buffName);
	
	local actions = {};
	InsertBuffActions(actions, obj, obj, buffName, buffLevel and tonumber(buffLevel) or 1, nil, false);	
	
	return unpack(actions);
end
function CommandMission_buffpositive(mission, company, dc, objKey)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	local actions = {};
	for _, cls in pairs(GetClassList('Buff_Positive')) do
		InsertBuffActions(actions, obj, obj, cls.name, 1, nil, false);	
	end
	return unpack(actions);
end
function CommandMission_buffnegative(mission, company, dc, objKey)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	local actions = {};
	for _, cls in pairs(GetClassList('Buff_Negative')) do
		InsertBuffActions(actions, obj, obj, cls.name, 1, nil, false);	
	end
	return unpack(actions);
end
function CommandMission_buffteam(mission, company, dc, team, buffName, buffLevel)
	local mid = GetMissionID(mission);
	local count = GetTeamCount(mid, team);
	if count == 0 then
		return;
	end
	
	buffName = FindBuffType(buffName);
	local actions = {};
	for i = 1, count do
		local obj = GetTeamUnitByIndex(mid, team, i);
		InsertBuffActions(actions, obj, obj, buffName, buffLevel and tonumber(buffLevel) or 1);	
	end
	
	return unpack(actions);
end
function CommandMission_removebuff(mission, company, dc, objKey, buffName)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return;
	end
	
	local buff = GetBuff(obj, buffName);
	if buff == nil then
		return;
	end
	
	local actions = {};
	InsertBuffActions(actions, obj, obj, buffName, -buff.Lv, nil, false);	
	
	return unpack(actions);
end
function CommandMission_removebuffteam(mission, company, dc, team, buffName)
	local mid = GetMissionID(mission);
	local count = GetTeamCount(mid, team);
	if count == 0 then
		return;
	end
	
	buffName = FindBuffType(buffName);
	local actions = {};
	for i = 1, count do
		local obj = GetTeamUnitByIndex(mid, team, i);
		local buff = GetBuff(obj, buffName);
		if buff then
			InsertBuffActions(actions, obj, obj, buffName, -buff.Lv, nil, false);
		end
	end
	
	return unpack(actions);
end
function CommandMission_where(mission, company, dc, objKey)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return;
	end

	local actions = {};
	table.insert(actions, Result_AddFieldEffect('SmokeScreen', { GetPosition(obj) }));
	LogAndPrint(string.format('obj : %s, position : %s', GetObjKey(obj), PackTableToStringReadable(GetPosition(obj))));
	
	return unpack(actions);
end
function CommandMission_whereteam(mission, company, dc, team)
	local mid = GetMissionID(mission);
	local count = GetTeamCount(mid, team);
	if count == 0 then
		return;
	end
	
	local actions = {};
	for i = 1, count do
		local obj = GetTeamUnitByIndex(mid, team, i);
		table.insert(actions, Result_AddFieldEffect('SmokeScreen', { GetPosition(obj) }));
		LogAndPrint(string.format('i : %d, obj : %s, position : %s', i, GetObjKey(obj), PackTableToStringReadable(GetPosition(obj))));
	end
	
	return unpack(actions);
end
function CommandMission_wherepos(mission, company, dc, x, y, z)
	local actions = {};
	table.insert(actions, Result_AddFieldEffect('SmokeScreen', { {x = tonumber(x), y = tonumber(y), z = tonumber(z)} }));
	
	return unpack(actions);
end
function CommandMission_equip(mission, company, dc, objKey, itemName)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return;
	end
	
	itemName = FindItemType(itemName);
	if itemName == nil then
		return;
	end
	
	local actions = {};
	table.insert(actions, Result_EquipItem(obj, itemName));
	
	return unpack(actions);
end
function CommandMission_equipteam(mission, company, dc, team, itemName)
	local mid = GetMissionID(mission);
	local count = GetTeamCount(mid, team);
	if count == 0 then
		return;
	end
	
	itemName = FindItemType(itemName);
	if itemName == nil then
		return;
	end
	LogAndPrint('itemName');
	
	local actions = {};
	for i = 1, count do
		local obj = GetTeamUnitByIndex(mid, team, i);
		table.insert(actions, Result_EquipItem(obj, itemName));
	end
	
	return unpack(actions);
end
function CommandMission_swap(mission, company, dc, objKey1, objKey2)
	local obj1 = GetUnit(mission, objKey1);
	local obj2 = GetUnit(mission, objKey2);
	if obj1 == nil or obj2 == nil then
		return;
	end
	
	local pos1 = GetPosition(obj1);
	local pos2 = GetPosition(obj2);

	local actions = {};
	table.insert(actions, Result_SetPosition(obj1, InvalidPosition()));
	table.insert(actions, Result_SetPosition(obj2, pos1));
	table.insert(actions, Result_SetPosition(obj1, pos2));
	
	return unpack(actions);	
end
function CommandMission_turn(mission, company, dc, objKey)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return;
	end

	local minAct = 0;
	for _, unit in ipairs(GetAllUnit(mission)) do
		minAct = math.min(minAct, unit.Act);
	end
	
	local actions = {};
	table.insert(actions, Result_PropertyUpdated('Act', minAct - 1, obj));
	
	return unpack(actions);
end
function CommandMission_act(mission, company, dc, objKey, act)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return;
	end
	
	local actions = {};
	table.insert(actions, Result_PropertyUpdated('Act', tonumber(act), obj));
	
	ApplyActions(mission, actions);
end
function CommandMission_addexp(mission, company, dc, objKey, expAmount)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return;
	end

	local actions = {};
	table.insert(actions, Result_AddExp(obj, tonumber(expAmount), 0, 'CommandMission_addexp'));

	return unpack(actions);
end
function CommandMission_addexpteam(mission, company, dc, team, expAmount)
	local mid = GetMissionID(mission);
	local count = GetTeamCount(mid, team);
	if count == 0 then
		return;
	end
	
	local actions = {};
	for i = 1, count do
		local obj = GetTeamUnitByIndex(mid, team, i);
		table.insert(actions, Result_AddExp(obj, tonumber(expAmount), 0, 'CommandMission_addexp'));
	end

	return unpack(actions);
end
function CommandMission_resetcool(mission, company, dc, team)
	local mid = GetMissionID(mission);
	local count = GetTeamCount(mid, team);
	if count == 0 then
		return;
	end
	
	local actions = {};
	for i = 1, count do
		local obj = GetTeamUnitByIndex(mid, team, i);
		UpdateAbilityCoolActions(actions, obj, 0);
	end

	return unpack(actions);
end
function CheatCommandResetOne(actions, obj)
	UpdateAbilityCoolActions(actions, obj, 0);
	local abilityList = GetAllAbility(obj, false, true);
	for index, curAbility in ipairs (abilityList) do
		if curAbility.IsUseCount and curAbility.AutoUseCount then
			UpdateAbilityPropertyActions(actions, obj, curAbility.name, 'UseCount', curAbility.MaxUseCount);
		end
	end
	AddActionCost(actions, obj, obj.MaxCost);
	AddSPPropertyActions(actions, obj, obj.ESP.name, obj.MaxSP, true, nil);
end
function CommandMission_resetall(mission, company, dc, team)
	local mid = GetMissionID(mission);
	local count = GetTeamCount(mid, team);
	if count == 0 then
		return;
	end
	
	local actions = {};
	for i = 1, count do
		local obj = GetTeamUnitByIndex(mid, team, i);
		CheatCommandResetOne(actions, obj);
	end

	return unpack(actions);
end
function CommandMission_reset(mission, company, dc, objKey)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return;
	end
	local actions = {};
	CheatCommandResetOne(actions, obj);
	return unpack(actions);
end
function CommandMission_addcost(mission, company, dc, objKey, cost)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return;
	end
	local actions = {};
	AddActionCost(actions, obj, tonumber(cost));
	return unpack(actions);
end
function CommandMission_variable(mission, company, dc, variable, value)
	local f = loadstring('return ' .. value);
	return Result_UpdateStageVariable(variable, f());
end
function CommandMission_kill(mission, company, dc, objKey)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return;
	end
	CommandMission_kill_common(mission, company, dc, obj);
end
function CommandMission_killfrom(mission, company, dc, objKey, fromKey)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return;
	end
	local from = fromKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, fromKey);
	if from == nil then
		return;
	end
	CommandMission_kill_common(mission, company, dc, obj, from);
end
function CommandMission_kill_common(mission, company, dc, obj, from)
	local actions = {};
	table.insert(actions, Result_DirectingScript(function(mid, ds, args)
		if IsDead(obj) then
			ds:SetDead(GetObjKey(obj), 'Normal', 0, 0, 0, 0, 0, true);
		end
	end));
	table.insert(actions, Result_Damage(99999999, 'Normal', 'Hit', from or obj, obj, 'Cheat'));
	ApplyActionSequence(mission, actions);
end
function CommandMission_killenemyall(mission, company, dc)
	CommandMission_killenemyall_common(mission, company, dc);
end
function CommandMission_killenemyallfrom(mission, company, dc, fromKey)
	local from = fromKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, fromKey);
	if from == nil then
		return;
	end
	CommandMission_killenemyall_common(mission, company, dc, from);
end
function CommandMission_killenemyall_common(mission, company, dc, from)
	local actions = {};
	local preActions = {};
	local relationCache = {};
	local allUnits = GetAllUnit(mission);
	for _, obj in ipairs(allUnits) do
		local team = GetTeam(obj);
		local relation = relationCache[team];
		if not relation then
			relation = GetRelationByTeamName(mission, 'player', team);
			relationCache[team] = relation;
		end
		if relation == 'Enemy' and not IsInvalidPosition(GetPosition(obj)) then
			table.insert(preActions, Result_DirectingScript(function(mid, ds, args)
				if IsDead(obj) then
					ds:SetDead(GetObjKey(obj), 'Normal', 0, 0, 0, 0, 0, true);
				end
			end));
			table.insert(actions, Result_Damage(99999999, 'Normal', 'Hit', from or obj, obj, 'Cheat'));
		end
	end
	ApplyActionSequence(mission, table.append(preActions, actions));
end
function CommandMission_killteam(mission, company, dc, team)
	local mid = GetMissionID(mission);
	local count = GetTeamCount(mid, team);
	local actions = {};
	local preActions = {};
	for i = 1, count do
		local obj = GetTeamUnitByIndex(mid, team, i);
		if not IsInvalidPosition(GetPosition(obj)) then
			table.insert(preActions, Result_DirectingScript(function(mid, ds, args)
				if IsDead(obj) then
					ds:SetDead(GetObjKey(obj), 'Normal', 0, 0, 0, 0, 0, true);
				end
			end));
			table.insert(actions, Result_Damage(99999999, 'Normal', 'Hit', obj, obj, 'Cheat'));
		end
	end
	ApplyActionSequence(mission, table.append(preActions, actions));
end
function CommandMission_killteamcount(mission, company, dc, team, killcount)
	local mid = GetMissionID(mission);
	local count = math.min(GetTeamCount(mid, team), tonumber(killcount));
	local preActions = {};
	local actions = {};
	for i = 1, count do
		local obj = GetTeamUnitByIndex(mid, team, i);
		if not IsInvalidPosition(GetPosition(obj)) then
			table.insert(preActions, Result_DirectingScript(function(mid, ds, args)
				if IsDead(obj) then
					ds:SetDead(GetObjKey(obj), 'Normal', 0, 0, 0, 0, 0, true);
				end
			end));
			table.insert(actions, Result_Damage(99999999, 'Normal', 'Hit', obj, obj, 'Cheat'));
		end
	end
	ApplyActionSequence(mission, table.append(preActions, actions));
end
function CommandMission_killteamremain(mission, company, dc, team, remaincount)
	local mid = GetMissionID(mission);
	local count = math.max(0, GetTeamCount(mid, team) - tonumber(remaincount));
	local preActions = {};
	local actions = {};
	for i = 1, count do
		local obj = GetTeamUnitByIndex(mid, team, i);
		if not IsInvalidPosition(GetPosition(obj)) then
			table.insert(preActions, Result_DirectingScript(function(mid, ds, args)
				if IsDead(obj) then
					ds:SetDead(GetObjKey(obj), 'Normal', 0, 0, 0, 0, 0, true);
				end
			end));
			table.insert(actions, Result_Damage(99999999, 'Normal', 'Hit', obj, obj, 'Cheat'));
		end
	end
	ApplyActionSequence(mission, table.append(preActions, actions));
end
function CommandMission_fieldeffect(mission, company, dc, field, x, y, z)
	local actions = {};
	table.insert(actions, Result_AddFieldEffect(field, { {x = tonumber(x), y = tonumber(y), z = tonumber(z)} }));
	ApplyActions(mission, actions);
end
function CommandMission_changeteam(mission, company, dc, objKey, team)
	return Result_ChangeTeam(GetUnit(mission, objKey), team);
end
function CommandMission_spawnmonster(mission, company, dc, montype, x, y, z, team)
	local unitInitializeFunc = function(unit, arg)
		UNIT_INITIALIZER(unit, unit.Team);
		SetControllable(unit, true);
	end;
	local monKey = GenerateUnnamedObjKey(mission);
	return Result_CreateMonster(monKey, montype, {x = tonumber(x), y = tonumber(y), z = tonumber(z)}, team or 'player', unitInitializeFunc, {}, 'DoNothingAI', nil, true), Result_DirectingScript(function(mid, ds, args)
		local mon = GetUnit(mid, monKey);
		return Result_SetPosition(mon, GetPosition(mon));
	end, {});
end
function CommandMission_nowait(mission, company, dc, team)
	local mid = GetMissionID(mission);
	local count = GetTeamCount(mid, team);
	for i = 1, count do
		local obj = GetTeamUnitByIndex(mid, team, i);
		local noWait = GetInstantProperty(obj, 'NoWait');
		if noWait == true then
			SetInstantProperty(obj, 'NoWait', nil);
		else
			obj.Act = 1;
			SetInstantProperty(obj, 'NoWait', true);
		end
	end
end
function CommandMission_whatcp(mission, company, dc, propKey)
	local keyChain = table.map(string.split(propKey, '/'), function(k) if string.match(k, '%d+') then return tonumber(k) else return k end end);
	local propValue = SafeIndex(company, unpack(keyChain));
	SendChat(company, 'Notice', 'System', string.format('company[%s] : %s', propKey, tostring(propValue)));
end
function CommandMission_whatop(mission, company, dc, objKey, propKey)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return;
	end
	local propKey = string.gsub(propKey, '%.', '/');
	local keyChain = string.split(propKey, '/');
	local propValue = SafeIndex(obj, unpack(keyChain));
	SendChat(company, 'Notice', 'System', string.format('%s[%s] : %s', objKey, propKey, tostring(propValue)));
end
function CommandMission_op(mission, company, dc, objKey, propKey, propVal)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return;
	end
	local propKey = string.gsub(propKey, '%.', '/');
	local keyChain = string.split(propKey, '/');
	local prevPropValue = SafeIndex(obj, unpack(keyChain));

	local actions = {};
	table.insert(actions, Result_PropertyUpdated(propKey, propVal, obj, true, true));
	ApplyActions(mission, actions);	
	
	local propValue = SafeIndex(obj, unpack(keyChain));
	SendChat(company, 'Notice', 'System', string.format('%s[%s] : %s -> %s', objKey, propKey, tostring(prevPropValue), tostring(propValue)));	
end
function CommandMission_whatip(mission, company, dc, objKey, propKey)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return;
	end
	local propKey = string.gsub(propKey, '%.', '/');
	local keyChain = string.split(propKey, '/');
	if #keyChain == 0 then
		return;
	end
	local propValue = GetInstantProperty(obj, keyChain[1]);
	if #keyChain > 1 then
		propValue = SafeIndex(prop, unpack(keyChain, 2));
	end
	local propStr = (type(propValue) == 'table') and PackTableToStringReadable(propValue) or tostring(propValue);
	SendChat(company, 'Notice', 'System', string.format('%s[%s] : %s', objKey, propKey, propStr));
end
function CommandMission_addsp(mission, company, dc, objKey, addSP)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return;
	end
	local actions = {};
	AddSPPropertyActions(actions, obj, obj.ESP.name, tonumber(addSP), true);
	return unpack(actions)
end
function CommandMission_addspteam(mission, company, dc, team, addSP)
	local objs = {};
	if team == 'all' then
		for _, obj in ipairs(GetAllUnit(mission)) do
			table.insert(objs, obj);
		end
	else
		local mid = GetMissionID(mission);
		local count = GetTeamCount(mid, team);
		for i = 1, count do
			local obj = GetTeamUnitByIndex(mid, team, i);
			table.insert(objs, obj);
		end	
	end
	local actions = {};
	for _, obj in ipairs(objs) do
		AddSPPropertyActions(actions, obj, obj.ESP.name, tonumber(addSP), true);
	end
	return unpack(actions);
end
function CommandMission_setpos(mission, company, dc, objKey, x, y, z)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return;
	end
	LogAndPrint('CommandMission_setpos', objKey, x, y, z);
	return Result_SetPosition(obj, {x = tonumber(x), y = tonumber(y), z = tonumber(z)}, false, nil);
end
function Direct_AddSteamStat(mid, ds, args)
	ds:AddSteamStat(args.StatName, args.StatValue, args.Team);
end
function Direct_UpdateSteamStat(mid, ds, args)
	ds:UpdateSteamStat(args.StatName, args.StatValue, args.Team);
end
function Direct_UpdateSteamAchievement(mid, ds, args)
	LogAndPrint('Direct_UpdateSteamAchievement - args : ', PackTableToStringReadable(args));
	ds:UpdateSteamAchievement(args.AchievementName, args.Achieved, args.Team);
end
function Direct_ResetAllSteamAchievement(mid, ds, args)
	local achievementClsList = GetClassList('SteamAchievement');
	for _, achievementCls in pairs(achievementClsList) do
		ds:UpdateSteamAchievement(achievementCls.name, false, args.Team);
	end
end
function CommandMission_addsteamstat(mission, company, dc, statName, value)
	local actions = {};
	local statCls = GetClassList('SteamStat')[statName];
	if statCls and statCls.name and statCls.name ~= 'None' then
		table.insert(actions, Result_DirectingScript('Direct_AddSteamStat', {StatName=statName, StatValue=tonumber(value), Team=GetUserTeam(company)}));
	end
	ApplyActions(mission, actions);
end
function CommandMission_updatesteamstat(mission, company, dc, statName, value)
	local actions = {};
	local statCls = GetClassList('SteamStat')[statName];
	if statCls and statCls.name and statCls.name ~= 'None' then
		table.insert(actions, Result_DirectingScript('Direct_UpdateSteamStat', {StatName=statName, StatValue=tonumber(value), Team=GetUserTeam(company)}));
	end
	ApplyActions(mission, actions);
end
function CommandMission_updatesteamachievement(mission, company, dc, achievementName, achieved)
	local actions = {};
	local achievementCls = GetClassList('SteamAchievement')[achievementName];
	if achievementCls and achievementCls.name and achievementCls.name ~= 'None' then
		table.insert(actions, Result_DirectingScript('Direct_UpdateSteamAchievement', {AchievementName=achievementName, Achieved=StringToBool(achieved), Team=GetUserTeam(company)}));
	end
	ApplyActions(mission, actions);
end
function CommandMission_resetallsteamachievement(mission, company, dc)
	local actions = {};
	table.insert(actions, Result_DirectingScript('Direct_ResetAllSteamAchievement', {Team=GetUserTeam(company)}));
	ApplyActions(mission, actions);
end
function CommandMission_addhp(mission, company, dc, objKey, addHP)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return;
	end

	local actions = {};
	table.insert(actions, Result_Damage(-addHP, 'Normal', 'Hit', obj, obj, 'Cheat'));
	table.insert(actions, Result_ActionDelimiter());

	ApplyActions(mission, actions);
end
function CommandMission_fullresistteam(mission, company, dc, team)
	local mid = GetMissionID(mission);
	local count = GetTeamCount(mid, team);
	local actions = {};
	for i = 1, count do
		local obj = GetTeamUnitByIndex(mid, team, i);
		if not IsInvalidPosition(GetPosition(obj)) then
			for _, mastery in ipairs({'FireResistance4', 'IceResistance4', 'LightningResistance4', 'WindResistance4', 'WaterResistance4', 'EarthResistance4'}) do
				table.insert(actions, Result_UpdateMastery(obj, mastery, 1));
			end
		end
	end
	ApplyActions(mission, actions);
end
function CommandMission_mastery(mission, company, dc, objKey, mastery)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return
	end
	mastery = FindClassData('Mastery', mastery);
	ApplyActions(mission, {Result_UpdateMastery(obj, mastery, 1)});
end
function CommandMission_masteryteam(mission, company, dc, team, mastery)
	local mid = GetMissionID(mission);
	local count = GetTeamCount(mid, team);
	mastery = FindClassData('Mastery', mastery);
	local actions = {};
	for i = 1, count do
		local obj = GetTeamUnitByIndex(mid, team, i);
		if not IsInvalidPosition(GetPosition(obj)) then
			table.insert(actions, Result_UpdateMastery(obj, mastery, 1));
		end
	end
	ApplyActions(mission, actions);	
end
function CommandMission_timeelapsed(mission, company, dc, elapsedTime)
	local actions = {};
	for _, unit in ipairs(GetAllUnit(mission)) do
		table.insert(actions, Result_PropertyUpdated('Act', unit.Act + tonumber(elapsedTime), unit));	
	end
	table.insert(actions, Result_TimeElapsed(tonumber(elapsedTime), 'player'));
	ApplyActions(mission, actions);
end
function CommandMission_hate(mission, company, dc, objKey, aggroType, hateAmount)
	RaiseHateCustom(GetUnit(mission, objKey), aggroType, tonumber(hateAmount));
end
function CommandMission_damage(mission, company, dc, objKey, damage)
	local actions = {};
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return
	end
	table.insert(actions, Result_Damage(tonumber(damage), 'Normal', 'Hit', obj, obj, 'Etc'));
	ApplyActions(mission, actions);
end
function CommandMission_checkpoint(mission, company, dc)
	ReserveMissionCheckPoint(GetMissionID(mission));
	ApplyActions(mission, {Result_FireWorldEvent('CheckPointUpdated', {}, nil, true)});
end
function CommandMission_starstreetposbug(mission, company, dc)
	local objPosList = {
		{ ObjKey = 'Anne', Position = { x = 42, y = 32, z = 47 } },
		{ ObjKey = 'Irene', Position = { x = 49, y = 34, z = 0 } },
		{ ObjKey = 'Heissing', Position = { x = 41, y = 31, z = 47 } },
		{ ObjKey = 'VHPDScouter01', Position = { x = 43, y = 26, z = 18 } },
		{ ObjKey = 'VHPDScouter02', Position = { x = 52, y = 32, z = 0 } },
		{ ObjKey = 'Albus', Position = { x = 42, y = 30, z = 42 } },
		{ ObjKey = 'Sion', Position = { x = 42, y = 26, z = 18 } },
		{ ObjKey = 'Jane', Position = { x = 43, y = 28, z = 38 } },
		{ ObjKey = 'VHPD01', Position = { x = 42, y = 25, z = 8 } },
		{ ObjKey = 'VHPD02', Position = { x = 55, y = 30, z = 0 } },
		{ ObjKey = 'VHPDDefender01', Position = { x = 44, y = 26, z = 2 } },
		{ ObjKey = 'VHPDDefender02', Position = { x = 42, y = 27, z = 28 } },
	};
	
	local actions = {};
	for _, objPos in ipairs(objPosList) do
		local objKey = objPos.ObjKey;
		local pos = objPos.Position;
		local setPos = CommandMission_setpos(mission, company, dc, objKey, pos.x, pos.y, pos.z);
		if setPos then
			table.insert(actions, setPos);
		end	
	end
	return unpack(actions);
end
function CommandMission_giveability(mission, company, dc, objKey, abilityName)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return;
	end
	local ability = GetAbilityObject(obj, abilityName);
	if not ability then
		local actions = {};
		table.insert(actions, Result_GiveAbility(obj, abilityName));
		ApplyActions(mission, actions);
		ability = GetAbilityObject(obj, abilityName);
	end
	if not ability then
		return;
	end
	local newUseCount = ability.MaxUseCount;
	if ability.UseCount ~= newUseCount and ability.IsUseCount and ability.AutoUseCount then
		local actions = {};
		UpdateAbilityPropertyActions(actions, obj, ability.name, 'UseCount', newUseCount);
		ApplyActions(mission, actions);
	end
	-- AutoActiveAbility에 등록된 어빌리티도 같이 줍시다.
	for _, autoActive in ipairs(ability.AutoActiveAbility) do
		local autoActiveAbility = GetAbilityObject(obj, autoActive);
		if not autoActiveAbility then
			CommandMission_giveability(mission, company, dc, objKey, autoActive);
		end
	end
end
function CommandMission_unlockautoplay(mission, company, dc, team)
	local mid = GetMissionID(mission);
	local count = GetTeamCount(mid, team);
	local actions = {};
	for i = 1, count do
		local obj = GetTeamUnitByIndex(mid, team, i);
		table.insert(actions, Result_UpdateInstantProperty(obj, 'AutoPlayable', true));
	end
	return unpack(actions);
end
function CommandMission_addcontrol(mission, company, dc, objKey, sight)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return;
	end
	local team = GetUserTeam(company);
	local actions = {};
	table.insert(actions, Result_UpdateInstantProperty(obj, 'ControlTeam', team));
	table.insert(actions, Result_SightSharing(obj, team, StringToBool(sight, false), true));
	return unpack(actions);
end
function CommandMission_resetcontrol(mission, company, dc, objKey)
	local obj = objKey == 'this' and GetCurrentTurnplayObject(mission) or GetUnit(mission, objKey);
	if obj == nil then
		return;
	end
	local team = GetUserTeam(company);
	local actions = {};
	table.insert(actions, Result_UpdateInstantProperty(obj, 'ControlTeam', nil));
	table.insert(actions, Result_SightSharing(obj, team, false, true));
	return unpack(actions);
end
function CommandMission_direct(mission, company, dc, directType, beginHide, endShow)
	local actions = {};
	table.insert(actions, Result_DirectingScript(function(mid, ds, args)
		PlayMissionDirect(mid, ds, {}, directType, StringToBool(beginHide, true), StringToBool(endShow, true));
		ds:SceneFadeIn('', true);
	end));
	ApplyActionSequence(mission, actions);
end
function CommandMission_dialog(mission, company, dc, directType)
	local actions = {};
	table.insert(actions, Result_DirectingScript(function(mid, ds, args)
		local missionDirectInfo = GetMissionDirectInfo(mid, directType);
		if missionDirectInfo == nil then
			LogAndPrint(string.format("[DataError] [%s]'s missionDirect is nil!", directType));
			return;
		end
		PlayMissionDirect_DialogTest(mid, ds, missionDirectInfo);
	end));
	ApplyActionSequence(mission, actions);
end