function ParseScript(self, company, env, script)
	local envT = {
		npc = self,
		company = company,
		env = env,
		math = math,
		string = string,
	};
	setmetatable(envT, {__index = _G});
	--LogAndPrint('ParseScript', script, env);
	local ret = table.deepcopy(script);
	for k, v in pairs(script) do
		if type(v) == 'table' then
			ret[k] = ParseScript(self, company, env, v);
		elseif string.find(tostring(k), '^C_') then
			local calcFunc = loadstring('return ' .. tostring(v));
			setfenv(calcFunc, envT);
			local nKey = string.sub(k, 3);
			local nVal = calcFunc();
			ret[nKey] = nVal;
		end
	end
	return ret;
end
function ProgressDialog(ds, self, company, dialog, prevEnv)
	local dialogCls = GetClassList('Dialog')[dialog];
		if dialogCls == nil then
		local logMsg = "Can't Find Dialog Type "..dialog;
		LogAndPrint(logMsg);
		return prevEnv;
	end
	return ProgressDialogCls(ds, self, company, dialogCls, prevEnv);
end
function ProgressDialogCls(ds, self, company, dialogCls, prevEnv)
	if dialogCls == nil then
		LogAndPrint('ProgressDialogCls', 'dialogCls is nil');
		return prevEnv;
	end
	local scripts = dialogCls.Scripts;
	if scripts == nil or #scripts == 0 then
		return;
	end
	if prevEnv == nil then
		prevEnv = {};
	end
	local env = table.deepcopy(prevEnv);
	env._last_dialog = prevEnv._cur_dialog;
	env._cur_dialog = dialogCls;
	for i, script in ipairs(scripts) do
		local parsedScript = ParseScript(self, company, env, ClassToTable(script));
		env = PlayDialogScript(ds, self, company, env, parsedScript);
		if SafeIndex(env, '_terminated') then
			break;
		end
	end
	env._last_dialog = prevEnv._last_dialog;
	env._cur_dialog = prevEnv._cur_dialog;
	return env;
end
g_noActionScriptType = {
	Dialog = true,
	BattleDialog = true,
	Selection = true,
	BattleSelection = true,
	Switch = true,
	SwitchExpr = true,
	Loop = true,
	Jump = true,
	Finish = true,
	Env = true,
	SceneFade = true,
	CloseDialog = true,
	ChangeCameraNPC = true,
	ChangeCameraMode = true,
	ChangeLobbyMap = true,
	SetNamedAssetVisible = true,
	SetNamedAssetVisibleAll = true,
	Sleep = true,
	GetRoster = true,
	ShowBackgroundImage = true,
	HideBackgroundImage = true,
	ShowFrontmessage = true,
	ShowFrontmessageFormat = true,
	TitleMessage = true,
	PlaySound = true,
	PlayBGM = true,
	StopBGM = true,
	PlayLoopSound = true,
	StopLoopSound = true,
	ShowCredit = true,
};
function PlayDialogScript(ds, self, company, env, parsedScript)
	local scriptType = parsedScript.Type;
	if scriptType == nil then
		LogAndPrint(string.format("[DataError] [%s] Dialog Type not exist!", SafeIndex(env, '_cur_dialog', 'name') or 'No Dialog'), parsedScript);
		return env;
	end
	local f = _G["PlayDialogScript_" .. scriptType];
	if f == nil then
		LogAndPrint("Dialog play function is not exist (" .. scriptType ..")");
		return env;
	end
	if env._no_action and not g_noActionScriptType[scriptType] then
		return env;
	end	
	return f(ds, self, company, env, parsedScript);
end
---------------------------------------------------------------------
-- 대화창 함수
---------------------------------------------------------------------
function PlayDialogScript_Dialog(ds, self, company, env, parsedScript)
	local dialogArgs = table.deepcopy(parsedScript);
	dialogArgs.Type = dialogArgs.DialogType;
	dialogArgs.DialogType = nil;
	dialogArgs.Mode = (not env._dialogFadeIn) and 'Start' or 'Continue';
	env._dialogFadeIn = true;
	
	-- 클라에 보내는 값.
	if self then
		dialogArgs.Friendship = company.Npc[self.name].Friendship;
		dialogArgs.FriendshipPoint = company.Npc[self.name].FriendshipPoint;
		dialogArgs.NPC = self.name;
		dialogArgs.DlgName = self.Info.Title;
		dialogArgs.JobName = self.Info.JobName;
		dialogArgs.FamilyName = self.Info.FamilyName;
		dialogArgs.TypingSound = self.Info.DialogTypingSound;
		dialogArgs.SpeakerInfo = dialogArgs.SpeakerInfo or self.Info.name;
		dialogArgs.SpeakerEmotion = dialogArgs.SpeakerEmotion or 'Normal';
		dialogArgs.Type = dialogArgs.Type or 'Sub';
		dialogArgs.Slot = dialogArgs.Slot or 'Center';
		dialogArgs.Effect = dialogArgs.Effect or 'Appear';
	else
		dialogArgs.Friendship = nil;
		dialogArgs.FriendshipPoint = 0;
		dialogArgs.DlgName = '';
		dialogArgs.JobName = '';
		dialogArgs.FamilyName = '';
	end
	
	local needClose = StringToBool(dialogArgs.Close, false);
	local needCallback = StringToBool(dialogArgs.Sync, false) or needClose;
	if dialogArgs.Message then
		ds:Dialog('BattleDialog', dialogArgs, needCallback);
	else
		for i, message in ipairs(parsedScript) do
			local newArgs = table.deepcopy(dialogArgs);
			newArgs.Message = message;
			if message.Emotion then
				newArgs.SpeakerEmotion = message.Emotion;
			end
			ds:Dialog('BattleDialog', newArgs, (i == #parsedScript) and needCallback);
			dialogArgs.Mode = 'Continue';
		end
	end
	if needClose then
		ds:CloseDialog('BattleDialog');
	end
	return env;
end
function PlayDialogScript_BattleDialog(ds, self, company, env, parsedScript)
	local dialogArgs = table.deepcopy(parsedScript);
	dialogArgs.Type = dialogArgs.DialogType;
	dialogArgs.DialogType = nil;
	ds:Dialog('BattleDialog', dialogArgs, StringToBool(dialogArgs.Sync, false) or StringToBool(dialogArgs.Close, false));
	
	if dialogArgs.Close == 'true' then
		ds:CloseDialog('BattleDialog');
	end
	return env;
end
function PlayDialogScript_Selection(ds, self, company, env, parsedScript)
	local dialogArgs = table.deepcopy(parsedScript);
	dialogArgs.Type = dialogArgs.DialogType;
	dialogArgs.DialogType = nil;
	dialogArgs.Mode = (not env._dialogFadeIn) and 'Start' or 'Continue';
	env._dialogFadeIn = true;
	
	-- 클라에 보내는 값.
	dialogArgs.Target = nil;
	if self then
		dialogArgs.Friendship = company.Npc[self.name].Friendship;
		dialogArgs.FriendshipPoint = company.Npc[self.name].FriendshipPoint;
		dialogArgs.NPC = self.name;
		dialogArgs.DlgName = self.Info.Title;
		dialogArgs.JobName = self.Info.JobName;
		dialogArgs.FamilyName = self.Info.FamilyName;
		dialogArgs.TypingSound = self.Info.DialogTypingSound;
		dialogArgs.SpeakerInfo = dialogArgs.SpeakerInfo or self.Info.name;
		dialogArgs.SpeakerEmotion = dialogArgs.SpeakerEmotion or 'Normal';
		dialogArgs.Type = dialogArgs.Type or 'Sub';
		dialogArgs.Slot = dialogArgs.Slot or 'Center';
		dialogArgs.Effect = dialogArgs.Effect or 'Appear';
	else
		dialogArgs.Friendship = nil;
		dialogArgs.FriendshipPoint = 0;
		dialogArgs.DlgName = '';
		dialogArgs.JobName = '';
		dialogArgs.FamilyName = '';
	end
	
	dialogArgs.Message = dialogArgs.Message or dialogArgs.Content;
	dialogArgs.Content = nil;
	dialogArgs.SelectType = dialogArgs.SelectType or 'List';
	
	local target_values = {};
	for i, choice in ipairs(parsedScript) do
		table.insert(target_values, choice.Value);
	end
	local id, sel = ds:Dialog('BattleSelDialog', dialogArgs, true);
	env[parsedScript.Target] = target_values[sel];
	env._last_selection = sel;
	if dialogArgs.Close then
		ds:CloseDialog('BattleSelDialog');
	end
	return env;
end
function PlayDialogScript_BattleSelection(ds, self, company, env, parsedScript)
	local dialogArgs = table.deepcopy(parsedScript);
	dialogArgs.Type = dialogArgs.DialogType;
	dialogArgs.DialogType = nil;
	FilterBattleSelection(dialogArgs, self, company, env);
	
	local target_values = {};
	for i, choice in ipairs(dialogArgs) do
		table.insert(target_values, choice.Value);
	end
	
	local id, sel = ds:Dialog('BattleSelDialog', dialogArgs, true);
	env[parsedScript.Target] = target_values[sel];
	env._last_selection = sel;
	
	if dialogArgs.Close then
		ds:CloseDialog('BattleSelDialog');
	end
	return env;
end
function FilterBattleSelection(dialogArgs, self, company, env)
	local envT = {
		npc = self,
		company = company,
		env = env,
		math = math,
		string = string,
	};
	setmetatable(envT, {__index = _G});
	
	local filterList = {};
	for i = 1, #dialogArgs do
		local selection = dialogArgs[i];
		local isValid = true;
		if selection.Condition then
			local calcFunc = loadstring('return ' .. tostring(selection.Condition));
			setfenv(calcFunc, envT);
			isValid = calcFunc();
		end
		if isValid then
			table.insert(filterList, selection);
		end
	end
	
	for i = 1, #dialogArgs do
		if i <= #filterList then
			dialogArgs[i] = filterList[i];
		else
			dialogArgs[i] = nil;
		end
	end
end
function PlayDialogScript_Action(ds, self, company, env, parsedScript)
	local dc = ds:GetDatabaseCommiter();
	ProcessDialogAction_New(dc, self, company, parsedScript, ds);
	local commit = StringToBool(parsedScript.Commit, true);
	local forceCommitCommand = {
		NewRoster = true,
	};
	if commit or forceCommitCommand[parsedScript.Command] then
		env._last_action_success = dc:Commit('DialogAction:'..env._cur_dialog.name);
		env._last_db_action_success = env._last_action_success;
	end
	return env;
end
function PlayDialogScript_Switch(ds, self, company, env, parsedScript)
	for i, case in ipairs(parsedScript) do
		if tostring(case.Case) == tostring(parsedScript.TestTarget) then
			local env_ = table.deepcopy(env);
			for j, script in ipairs(case) do
				local pscript = ParseScript(self, company, env_, script);
				env_ = PlayDialogScript(ds, self, company, env_, pscript);
			end
			return env_;
		end
	end
	return env;
end
function PlayDialogScript_SwitchExpr(ds, self, company, env, parsedScript)
	local fenv = {};
	local envClsList = GetClassList('DialogEnvironment');
	setmetatable(fenv, {__index = function(t, k)
		local envCls = envClsList[k];
		if envCls == nil then
			return _G[k];
		end
		t[k] = envCls:ValueGetter(self, company, env);
		return t[k];
	end});
	local multiAccept = StringToBool(parsedScript.MultiAccept, false);
	for i, case in ipairs(parsedScript) do
		local caseExpr = loadstring('return ' .. case.Case);
		setfenv(caseExpr, fenv);
		local succ, ret = pcall(caseExpr);
		if succ and ret then
			local env_ = table.deepcopy(env);
			for j, script in ipairs(case) do
				local pscript = ParseScript(self, company, env_, script);
				env_ = PlayDialogScript(ds, self, company, env_, pscript);
			end
			if not multiAccept then
				return env_;
			else
				env = env_;
			end
		elseif not succ then
			LogAndPrint('PlayDialogScript_SwitchExpr', 'Case Evaluate Failed', ret);
		end
	end
	return env;
end
function PlayDialogScript_Loop(ds, self, company, env, parsedScript)
	local env_ = table.deepcopy(env);
	for i = 1, parsedScript.LoopCount do
		for j, script in ipairs(parsedScript) do
			local pscript = ParseScript(self, company, env_, script);
			env_ = PlayDialogScript(ds, self, company, env_, pscript);
		end
	end
	return env_;
end
function PlayDialogScript_Jump(ds, self, company, env, parsedScript)
	local jumpto = parsedScript.JumpTo;
	local jtType = type(jumpto);
	local callFunc = function(...) return env; end
	if (jtType == 'string') then
		callFunc = ProgressDialog;
	elseif (jtType == 'userdata') then
		callFunc = ProgressDialogCls;
	end
	local npcName = parsedScript.Npc;
	if npcName then
		local npc = GetNPC(company, npcName);
		if npc then
			self = npc;
		end
	end	
	return callFunc(ds, self, company, jumpto, env);
end
function PlayDialogScript_QuestJump(ds, self, company, env, parsedScript)
	local jumpto = parsedScript.JumpTo;
	local quest = parsedScript.Quest;
	if quest == nil then
		quest = env.QuestType;
	end
	if quest == nil then
		return env;
	end
	local npcName = parsedScript.Npc;
	if npcName then
		local npc = GetNPC(company, npcName);
		if npc then
			self = npc;
		end
	end
	local dialog = GetQuestDialog(quest, jumpto);
	if dialog then
		local prevQuestType = env.QuestType;
		env.QuestType = quest;
		env = ProgressDialogCls(ds, self, company, dialog, env);
		env.QuestType = prevQuestType;
		return env;
	else
		return env;
	end
end
function PlayDialogScript_Finish(ds, self, company, env, parsedScript)
	LogAndPrint('PlayDialogScript_Finish!!!!');
	ds:CloseDialog('NormalDialog');
	return env;
end
function PlayDialogScript_DirectMission(ds, self, company, env, parsedScript)
	lineup = {};
	if parsedScript.Lineup then
		lineup = string.split(parsedScript.Lineup, '[, ]');
	end
	local rosterSet = Linq.new(GetAllRoster(company))
		:select(function(r) return r.name end)
		:toSet();
	lineup = table.filter(lineup, function(l) return rosterSet[l] end);
	local dc = ds:GetDatabaseCommiter();
	dc:Commit('DialogAction:'..env._cur_dialog.name);
	local directMissionInfo = {Grade = parsedScript.Grade, Site = parsedScript.Site, RewardRatio = parsedScript.RewardRatio, Lv = parsedScript.Lv, Group = parsedScript.Group};
	if DirectMission(company, parsedScript.Mission, lineup, {DirectMissionInfo = directMissionInfo}) then
		ds:ReadyToMove();
		env._last_action_success = true;
		env._terminated = true;
	else
		env._last_action_success = false;
	end
	return env;
end
function PlayDialogScript_ChangeLocation(ds, self, company, env, parsedScript)
	if not env._last_db_action_success then
		env._last_action_success = false;
		return env;
	end
	local lobbyCls = GetClassList('LobbyWorldDefinition')[parsedScript.Lobby];
	if lobbyCls == nil or lobbyCls.name == nil or lobbyCls.name == 'None' then
		env._last_action_success = false;
		return env;
	end
	ds:SyncWithClient();
	ChangeLocation(company, parsedScript.Lobby);
	ds:ReadyToMove();
	env._last_action_success = true;
	env._terminated = true;
	return env;
end
function PlayDialogScript_KickCompany(ds, self, company, env, parsedScript)
	KickCompany(company, parsedScript.Reason);
	env._terminated = true;
	return env;
end
function PlayDialogScript_Leave(ds, self, company, env, parsedScript)
	env._terminated = true;
	return env;
end
function PlayDialogScript_Env(ds, self, company, env, parsedScript)
	env[parsedScript.Key] = parsedScript.Value;
	return env;
end
function PlayDialogScript_Script(ds, self, company, env, parsedScript)
	local func = _G[parsedScript.Script];
	if func ~= nil then
		local retValue = func(ds, self, company, env, parsedScript);
		if parsedScript.Return then
			env[parsedScript.Return] = retValue;
		end
	end
	return env;
end
function PlayDialogScript_SceneFade(ds, self, company, env, parsedScript)
	local fadeType =  parsedScript.FadeType;
	if fadeType == 'In' then
		ds:SceneFadeIn(parsedScript.Image, StringToBool(parsedScript.Direct, false));
	elseif fadeType == 'Out' then
		ds:SceneFadeOut(parsedScript.Image, StringToBool(parsedScript.Direct, false));
	end
	env['_last_fade_type'] = fadeType;
	return env;
end
function PlayDialogScript_CloseDialog(ds, self, company, env, parsedScript)
	ds:CloseDialog(parsedScript.DialogType);
	return env;
end
function PlayDialogScript_ChangeCameraNPC(ds, self, company, env, parsedScript)
	ds:ChangeCameraNPC(parsedScript.TargetType, false, false, parsedScript.MoveTime, parsedScript.CameraAnimSlope or 3, StringToBool(parsedScript.NoWait, false));
	return env;
end
function PlayDialogScript_ChangeCameraMode(ds, self, company, env, parsedScript)
	ds:StartLobbyCameraMode(parsedScript.CameraMode, StringToBool(parsedScript.Direct, false));
	return env;
end
function PlayDialogScript_ChangeLobbyMap(ds, self, company, env, parsedScript)
	ds:ChangeLobbyMap(parsedScript.LobbyDef);
	return env;
end
function PlayDialogScript_Sleep(ds, self, company, env, parsedScript)
	ds:Sleep(parsedScript.Time);
	return env;
end
function PlayDialogScript_SetNamedAssetVisible(ds, self, company, env, parsedScript)
	ds:SetNamedAssetVisible(parsedScript.Key, StringToBool(parsedScript.Visible, true));
	return env;
end
function PlayDialogScript_SetNamedAssetVisibleAll(ds, self, company, env, parsedScript)
	ds:SetNamedAssetVisibleAll(StringToBool(parsedScript.Visible, true));
	return env;
end
function ReserveChangeLocationCore(dc, company, lobby)
	local needUpdates = {{ "LastLocation/LobbyType", lobby },
						 { "LastLocation/Pos/X", -1 },
						 { "LastLocation/Pos/Y", -1 },
						 { "LastLocation/Pos/Z", -1 }};
	for _, updateTarget in ipairs(needUpdates) do
		dc:UpdateCompanyProperty(company, updateTarget[1], updateTarget[2]);
	end
end
function PlayDialogScript_ReserveChangeLocation(ds, self, company, env, parsedScript)
	local dc = ds:GetDatabaseCommiter();
	ReserveChangeLocationCore(dc, company, parsedScript.Lobby);
	return env;
end
function PlayDialogScript_UpdateSteamAchievement(ds, self, company, env, parsedScript)
	local achievement = parsedScript.Achievement;
	local achievementCls = GetClassList('SteamAchievement')[achievement];
	if achievementCls and achievementCls.name ~= 'None' then
		ds:UpdateSteamAchievement(achievement, StringToBool(parsedScript.Achieved, false));
	end
	return env;
end
function PlayDialogScript_UpdateSteamStat(ds, self, company, env, parsedScript)
	local stat = parsedScript.Stat;
	local statCls = GetClassList('SteamStat')[stat];
	if statCls and statCls.name ~= 'None' then
		ds:UpdateSteamStat(stat, tonumber(parsedScript.Value));
	end
	return env;
end
function PlayDialogScript_AddSteamStat(ds, self, company, env, parsedScript)
	local stat = parsedScript.Stat;
	local statCls = GetClassList('SteamStat')[stat];
	if statCls and statCls.name ~= 'None' then
		ds:AddSteamStat(stat, tonumber(parsedScript.Value));
	end
	return env;
end
function PlayDialogScript_SystemChat(ds, self, company, env, parsedScript)
	local chatArgs = table.deepcopy(parsedScript);
	ds:AddMissionChat(parsedScript.Category, parsedScript.Message, chatArgs);
	return env;
end
------------------------------------------------ 
-- 다이아로그 상점 Shop
------------------------------------------------ 
function BuildLostShopItemData(company, friendship, lostShopData)
	-- Npc 할인율
	local friendshipList = GetClassList('Friendship');
	local curFriendship = friendshipList[friendship];
	local discountRatio = GetNpcDiscountRatio(curFriendship, company.Reputation);
	
	local itemSlotList = {};
	local baseOptionCls = GetClassList('ItemOption').Normal;
	for i, item in ipairs(lostShopData.ItemList) do
		if i > lostShopData.ActiveSlot then
			break;
		end
		(function()
			if item.Item == 'None' or item.Stock <= 0 then
				return;
			end
			-- ItemInfo 구성
			local itemInfo = {Item = item.Item, GoodsType = 'Item'};
			local option = item.Option;
			if option.OptionKey ~= 'None' then
				local props = {};
				for key, value in pairs(option) do
					if value ~= baseOptionCls[key] then
						props['Option/'..key] = value;
					end
				end
				itemInfo.Props = props;
			end
			local shopItem = GetClassList('Item')[item.Item];
			itemInfo.Price = math.floor(item.Price * (1 - discountRatio)) * 2;
			itemInfo.Stock = item.Stock;
			itemInfo.DBIndex = i;
			
			table.insert(itemSlotList, itemInfo);
		end)();
	end
	return itemSlotList;
end
function BuildValkyrieShopItemData(company, friendship, shopCls)
	-- Npc 할인율
	local friendshipList = GetClassList('Friendship');
	local curFriendship = friendshipList[friendship];
	local rosters = GetAllRoster(company, 'Pc');

	local itemList = {};
	for i, item in ipairs(shopCls.ValkyrieShop) do 
	(function()
		if item.Friendship and item.Friendship ~= 'None' then
			local itemFriendship = friendshipList[item.Friendship];
			if itemFriendship.Rank > curFriendship.Rank then
				return;
			end
		end
		if item.Checker then
			local checker = _G[item.Checker];
			if item.GoodsType == 'Recipe' then
				local recipe = GetClassList('Recipe')[item.Recipe];
				if not checker(company, rosters, recipe) then
					return;
				end
			else
				local shopItem = GetClassList('Item')[item.Item];
				if not checker(company, rosters, shopItem) then
					return;
				end
			end
		end
		if item.Quest then
			local questCls = GetClassList('Quest')[item.Quest];
			if questCls == nil then
				return;
			end
			local curState, progress = GetQuestState(company, item.Quest);
			if curState ~= 'Completed' then
				return;
			end
		end
	
		-- ItemInfo 구성
		local itemInfo = nil;
		if item.GoodsType == 'Recipe' then
--			if company.Recipe[item.Recipe].Opened then
--				return;	 -- 이미 열린 레시피는 구매할 수 없음.
--			end
			itemInfo = {Recipe = item.Recipe, GoodsType = 'Recipe', Price = item.Price, Opened = company.Recipe[item.Recipe].Opened};
		else
			itemInfo = {Item = item.Item, GoodsType = 'Item', Price = item.Price};
			if item.Option then
				local props = {};
				for key, value in pairs(option) do
					if value ~= 0 and value ~= 'None' then
						props['Option/'..key] = value;
					end
				end
				itemInfo.Props = props;
			end
		end
		table.insert(itemList, itemInfo);
	end)();
	end
	
	return itemList;
end
function CheckShopItemEnableEquip(company, rosters, shopItem)
	for _, roster in ipairs(rosters) do
		if IsEnableEquipItem_EnableEquipCompare(roster.Object, shopItem) then
			return true;
		end
	end
	return false;
end
function BuildShopItemData(company, friendship, shopCls)
	-- Npc 할인율
	local friendshipList = GetClassList('Friendship');
	local curFriendship = friendshipList[friendship];
	local discountRatio = GetNpcDiscountRatio(curFriendship, company.Reputation);
	local rosters = GetAllRoster(company, 'Pc');

	local shopData = GetWorldProperty().ShopOption[shopCls.name];
	local itemSlotList = {};
	local itemNoneSlotList = {};
	-- Slot값은 1~9999사이여야함..
	local minSlot = 9999;
	local maxSlot = 1;
	for i, item in ipairs(shopCls.ItemList) do 
	(function()
		if item.Friendship and item.Friendship ~= 'None' then
			local itemFriendship = friendshipList[item.Friendship];
			if itemFriendship.Rank > curFriendship.Rank then
				return;
			end
		end
		if item.Checker then
			local checker = _G[item.Checker];
			if item.GoodsType == 'Recipe' then
				local recipe = GetClassList('Recipe')[item.Recipe];
				if not checker(company, rosters, recipe) then
					return;
				end
			else
				local shopItem = GetClassList('Item')[item.Item];
				if not checker(company, rosters, shopItem) then
					return;
				end
			end
		end
	
		-- ItemInfo 구성
		local itemInfo = nil;
		if item.GoodsType == 'Recipe' then
			if company.Recipe[item.Recipe].Opened then
				return;	 -- 이미 열린 레시피는 구매할 수 없음.
			end
			itemInfo = {Recipe = item.Recipe, GoodsType = 'Recipe', Price = item.Price};
		else
			itemInfo = {Item = item.Item, GoodsType = 'Item'};
			local option = nil;
			if StringToBool(item.RandomOption, false) then
				option = shopData.ItemList[i].Option;
			elseif item.Option then
				option = item.Option;
			end
			if option then
				local props = {};
				for key, value in pairs(option) do
					if value ~= 0 and value ~= 'None' then
						props['Option/'..key] = value;
					end
				end
				itemInfo.Props = props;
			end
			local shopItem = GetClassList('Item')[item.Item];
			local sellPrice = ItemCalculateSellPrice(shopItem, option);
			local shopPrice = item.Price;
			if item.RandomPriceScript ~= 'None' then
				shopPrice = shopData.ItemList[i].Price;
			end
			local price = 0;
			if option then
				price = math.max(
					shopPrice, 
					math.min(sellPrice * ( 3 + 0.5 * math.floor(shopItem.RequireLv/5)), sellPrice + shopPrice)
				);
			else
				price = shopPrice;
			end
			-- 우호도 할인 적용
			itemInfo.Price = math.max(sellPrice, math.floor(price * (1 - discountRatio)));
		end
		
		-- Slot정보에 따라 배분
		if item.Slot == nil or item.Rate == nil then
			table.insert(itemNoneSlotList, itemInfo);
		else
			minSlot = math.min(item.Slot, minSlot);
			maxSlot = math.max(item.Slot, maxSlot);
			itemInfo.Rate = shopData.ItemList[i].Rate;
			if itemSlotList[item.Slot] == nil then
				itemSlotList[item.Slot] = itemInfo;
			elseif itemSlotList[item.Slot].Rate > itemInfo.Rate then
				itemSlotList[item.Slot] = itemInfo;
			end
		end
	end)();
	end
	
	-- Shop List 구축
	local itemData = {};
	for i = minSlot, maxSlot do
	(function()
		if itemSlotList[i] == nil then
			return;
		end
		local minRateOne = itemSlotList[i];
		minRateOne.Rate = nil;
		table.insert(itemData, minRateOne);
	end)();
	end
	table.append(itemData, itemNoneSlotList);
	return itemData;
end
function PlayDialogScript_Shop(ds, self, company, env, parsedScript)
	local shopType = parsedScript.Value;
	local shopCls = GetClassList('Shop')[shopType];
	if shopCls == nil then
		print('No Shop Class Exit ' .. shopType);
		return env;
	end
	
	local args = table.deepcopy(parsedScript);
	args.NPC = self.name;
	args.DlgName = self.Info.Title;
	args.JobName = self.Info.JobName;
	args.FamilyName = self.Info.FamilyName;
	args.ReBuy = false;
	args.ShopType = shopType;

	SetCompanyInstantProperty(company, 'ShopOpened', true);
	SetCompanyInstantProperty(company, 'ShopHost', self);
	ds:Dialog('Shop', args, true);	
	SetCompanyInstantProperty(company, 'ShopOpened', nil);
	SetCompanyInstantProperty(company, 'ShopHost', nil);
	return env;
end
------------------------------------------------ 
-- 다이아로그 FoodShop
------------------------------------------------ 
function BuildFoodMenuData(company, friendship, foodShopCls)
	-- Npc 할인율
	local friendshipList = GetClassList('Friendship');
	local curFriendship = friendshipList[friendship];
	local discountRatio = GetNpcDiscountRatio(curFriendship, company.Reputation);
	local rosters = GetAllRoster(company, 'Pc');

	local recommendData = GetWorldProperty().FoodRecommend[foodShopCls.name];
	local recommendSet = {};
	for _, menuName in ipairs(recommendData) do
		if menuName ~= 'None' then
			recommendSet[menuName] = true;
		end
	end
	
	local menuSlotList = {};
	local menuNoneSlotList = {};
	-- Slot값은 1~9999사이여야함..
	local minSlot = 9999;
	local maxSlot = 1;
	for i, menu in ipairs(foodShopCls.MenuList) do 
	(function()
		if menu.Friendship and menu.Friendship ~= 'None' then
			local menuFriendship = friendshipList[menu.Friendship];
			if menuFriendship.Rank > curFriendship.Rank then
				return;
			end
		end
		if menu.Checker and menu.Checker ~= 'None' then
			local checker = _G[menu.Checker];
			local foodCls = GetClassList('Food')[menu.Food];
			if checker and not checker(company, rosters, foodCls) then
				return;
			end
		end
	
		-- MenuInfo 구성
		local menuInfo = {Food = menu.Food};
		if recommendSet[menu.Food] then
			menuInfo.Recommend = true;
		end		
		local foodCls = GetClassList('Food')[menu.Food];
		local shopPrice = foodCls.Vill;
		-- 우호도 할인 적용
		menuInfo.Price = math.max(1, math.floor(shopPrice * (1 - discountRatio)));
		
		-- Slot정보에 따라 배분
		if menu.Slot == nil then
			table.insert(menuNoneSlotList, menuInfo);
		else
			minSlot = math.min(menu.Slot, minSlot);
			maxSlot = math.max(menu.Slot, maxSlot);
			menuSlotList[menu.Slot] = menuInfo;
		end
	end)();
	end
	
	-- Shop List 구축
	local menuData = {};
	for i = minSlot, maxSlot do
	(function()
		if menuSlotList[i] == nil then
			return;
		end
		local minRateOne = menuSlotList[i];
		minRateOne.Rate = nil;
		table.insert(menuData, minRateOne);
	end)();
	end
	table.append(menuData, menuNoneSlotList);
	return menuData;
end
function PlayDialogScript_FoodShop(ds, self, company, env, parsedScript)
	local foodShopType = parsedScript.Value;
	local foodShopCls = GetClassList('FoodShop')[foodShopType];
	if foodShopCls == nil then
		print('No Shop Class Exit ' .. foodShopType);
		return env;
	end
	
	local args = table.deepcopy(parsedScript);
	args.NPC = self.name;
	args.DlgName = self.Info.Title;
	args.JobName = self.Info.JobName;
	args.FamilyName = self.Info.FamilyName;
	args.ReBuy = false;
	args.ShopType = foodShopType;

	SetCompanyInstantProperty(company, 'ShopHost', self);
	ds:Dialog('FoodShop', args, true);	
	SetCompanyInstantProperty(company, 'ShopHost', nil);
	return env;
end
------------------------------------------------ 
-- 다이아로그 Troublesum
------------------------------------------------ 
function PlayDialogScript_Troublesum(ds, self, company, env, parsedScript)
	local troublesumType = parsedScript.Value;
	local dialogArgs = table.deepcopy(parsedScript);
	dialogArgs.Mode = dialogArgs.Mode;
	
	-- 클라에 보내는 값.
	dialogArgs.TroublesumType = troublesumType;
	dialogArgs.Friendship = company.Npc[self.name].Friendship;
	dialogArgs.FriendshipPoint = company.Npc[self.name].FriendshipPoint;
	dialogArgs.DlgName = self.Info.Title;
	dialogArgs.JobName = self.Info.JobName;
	dialogArgs.FamilyName = self.Info.FamilyName;
	while true do		
		local id, callback, result = ds:Dialog('Troublesum', dialogArgs, true);
		if callback == 0 then
			return env;
		end		
	end	
	return env;	
end
------------------------------------------------ 
-- 다이아로그 TroublesumReward
------------------------------------------------ 
function PlayDialogScript_TroublesumReward(ds, self, company, env, parsedScript)
	local troublesumType = parsedScript.Value;
	local dialogArgs = table.deepcopy(parsedScript);
	dialogArgs.Mode = dialogArgs.Mode;
	
	-- 클라에 보내는 값.
	dialogArgs.TroublesumType = troublesumType;
	dialogArgs.Friendship = company.Npc[self.name].Friendship;
	dialogArgs.FriendshipPoint = company.Npc[self.name].FriendshipPoint;
	dialogArgs.DlgName = self.Info.Title;
	dialogArgs.JobName = self.Info.JobName;
	dialogArgs.FamilyName = self.Info.FamilyName;
	while true do		
		local id, callback, result = ds:Dialog('TroublesumReward', dialogArgs, true);
		if callback == 0 then
			return env;
		end		
	end	
	return env;	
end
------------------------------------------------ 
-- 다이아로그 Waypoint
------------------------------------------------ 
function PlayDialogScript_Waypoint(ds, self, company, env, parsedScript)
	local waypointType = parsedScript.Value;
	local dialogArgs = table.deepcopy(parsedScript);
	dialogArgs.Mode = dialogArgs.Mode;
	
	-- 클라에 보내는 값.
	dialogArgs.WaypointType = waypointType;
	dialogArgs.Friendship = company.Npc[self.name].Friendship;
	dialogArgs.FriendshipPoint = company.Npc[self.name].FriendshipPoint;
	dialogArgs.DlgName = self.Info.Title;
	dialogArgs.JobName = self.Info.JobName;
	dialogArgs.FamilyName = self.Info.FamilyName;
	while true do		
		local id, callback, result = ds:Dialog('Waypoint', dialogArgs, true);
		if callback == 0 then
			return env;
		end		
	end	
	return env;	
end
------------------------------------------------ 
-- 다이아로그 AllowDivision
------------------------------------------------ 
function PlayDialogScript_AllowDivision(ds, self, company, env, parsedScript)
	LogAndPrint('PlayDialogScript_AllowDivision', company.CompanyName);
	local allowDivisionType = parsedScript.Value;
	local dialogArgs = table.deepcopy(parsedScript);
	dialogArgs.Mode = dialogArgs.Mode;
	
	-- 클라에 보내는 값.
	dialogArgs.AllowDivision = allowDivisionType;
	dialogArgs.Friendship = company.Npc[self.name].Friendship;
	dialogArgs.FriendshipPoint = company.Npc[self.name].FriendshipPoint;
	dialogArgs.DlgName = self.Info.Title;
	dialogArgs.JobName = self.Info.JobName;
	dialogArgs.FamilyName = self.Info.FamilyName;
	while true do		
		local id, callback, result = ds:Dialog('AllowDivision', dialogArgs, true);
		if callback == 0 then
			return env;
		end		
	end	
	return env;	
end
------------------------------------------------ 
-- 다이아로그 RosterSelector
------------------------------------------------ 
function PlayDialogScript_RosterSelector(ds, self, company, env, parsedScript)
	local dialogArgs = table.deepcopy(parsedScript);
	local id, ok, result = ds:Dialog('RosterSelector', dialogArgs, true);
	env._last_action_success = ok == 1;
	if env._last_action_success then
		env[parsedScript.Target] = result.RosterName;
		env._cur_roster = GetRoster(company, result.RosterName);
	end
	return env;	
end
function PlayDialogScript_GetRoster(ds, self, company, env, parsedScript)
	local roster = GetRoster(company, parsedScript.RosterName);
	env._last_action_success = (roster ~= nil);
	env[parsedScript.RosterTarget] = roster;
	return env;	
end
------------------------------------------------ 
-- 다이아로그 입력창
------------------------------------------------ 
function PlayDialogScript_InputDialog(ds, self, company, env, parsedScript)
	local args = table.deepcopy(parsedScript);
	local id, ok, result = ds:Dialog('UserInput', args, true);
	env._last_action_success = ok == 1;
	if env._last_action_success then
		env[parsedScript.Target] = result.InputString;
	end
	return env;
end
------------------------------------------------ 
-- 다이아로그 회사명 입력창
------------------------------------------------ 
function PlayDialogScript_CompanyName(ds, self, company, env, parsedScript)
	--LogAndPrint('PlayDialogScript_CompanyName', company.CompanyName);
	local args = table.deepcopy(parsedScript);
	local id, ok, result = ds:Dialog('CompanyName', args, true);
	env._last_action_success = ok == 1;
	if env._last_action_success then
		env[parsedScript.NameTarget] = result.InputString;
		env[parsedScript.MasteryTarget] = result.Mastery;
	end
	return env;
end
function PlayDialogScript_CloseCompanyName(ds, self, company, env, parsedScript)
	ds:CloseDialog('CompanyName');
	return env;
end
function PlayDialogScript_MessageBox(ds, self, company, env, parsedScript)
	local args = table.deepcopy(parsedScript);
	local id, ok = ds:Dialog('MessageBox', args, true);
	return env;
end
------------------------------------------------ 
-- 다이아로그 캐릭터 영입창
------------------------------------------------ 
function PlayDialogScript_ScoutRoster(ds, self, company, env, parsedScript)
	--LogAndPrint('PlayDialogScript_ScoutRoster', company.CompanyName);
	local args = table.deepcopy(parsedScript);
	local id, ok, result = ds:Dialog('ScoutRoster', args);
	env._last_action_success = ok == 1;
	if env._last_action_success then
		env[parsedScript.MasteryTarget] = result.Mastery;
		env[parsedScript.SalaryTarget] = result.SalaryIndex;
		local pcList = GetClassList('Pc');
		local pc = pcList[env.roster_name];
		if pc and pc.name then
			env.roster_title = pc.Info.Title;
		end
	end
	return env;
end
------------------------------------------------ 
-- 다이아로그 사무실 계약서
------------------------------------------------ 
function PlayDialogScript_OfficeContract(ds, self, company, env, parsedScript)
	local args = table.deepcopy(parsedScript);
	local id, sel = ds:Dialog('OfficeContract', args);
	env._last_action_success = sel > 0;
	if env._last_action_success then
		env[parsedScript.Target] = sel;
	end
	return env;
end
------------------------------------------------
function PlayDialogScript_SystemMail(ds, self, company, env, parsedScript)
	local systemMailCls = GetClassList('SystemMail')[parsedScript.MailKey];
	if systemMailCls == nil then
		return env;
	end
	local dc = ds:GetDatabaseCommiter();
	dc:GiveSystemMailOneKey(company, parsedScript.MailKey);
	if not StringToBool(parsedScript.NoCommit, false) then
		env._last_action_success = dc:Commit('DialogAction:'..env._cur_dialog.name);
	end
	return env;
end
function PlayDialogScript_CivilMail(ds, self, company, env, parsedScript)
	local ageType = parsedScript.AgeType;
	if ageType == nil then
		ageType = table.randompick({'Boy', 'Girl', 'Man', 'Man_Complain', 'OldMan', 'Woman', 'Woman_Complain'});
	end
	local civilName, mailKey, mailProb, itemType, itemCount = GetCivilRescueReward(ageType);
	if parsedScript.MailKey then
		mailKey = parsedScript.MailKey;
	end
	
	local systemMailCls = GetClassList('SystemMail')[mailKey];
	if systemMailCls == nil then
		return env;
	end
	if parsedScript.MailKey then
		itemType = systemMailCls.AttachItem;
		itemCount = systemMailCls.AttachItemCount;
	end
	local dc = ds:GetDatabaseCommiter();
	dc:GiveSystemMail(company, mailKey, mailKey, mailKey, itemType, itemCount, { CivilName = civilName, CivilAgeType = ageType }, nil, systemMailCls.Category.name);
	if not StringToBool(parsedScript.NoCommit, false) then
		env._last_action_success = dc:Commit('DialogAction:'..env._cur_dialog.name);
	end
	return env;
end
------------------------------------------------
-- 아이템 강화
------------------------------------------------
function PlayDialogScript_ItemUpgrade(ds, self, company, env, parsedScript)
	company.Temporary.NpcDialogMode = true;
	UpdateUserActionState(company, 'Talking', 'Craft');
	local id, callback = ds:Dialog('ItemUpgrade', {});
	UpdateUserActionState(company, 'Talking', nil);
	company.Temporary.NpcDialogMode = false;
	return env;
end
------------------------------------------------
-- 아이템 감정
------------------------------------------------
function PlayDialogScript_ItemIdentify(ds, self, company, env, parsedScript)
	company.Temporary.NpcDialogMode = true;
	SetCompanyInstantProperty(company, 'ShopHost', self);
	local id, callback = ds:Dialog('ItemIdentify', {Npc = SafeIndex(self, 'name')});
	SetCompanyInstantProperty(company, 'ShopHost', nil);
	company.Temporary.NpcDialogMode = false;
	return env;
end
------------------------------------------------
-- 야수 관리인
------------------------------------------------
function PlayDialogScript_BeastManager(ds, self, company, env, parsedScript)
	local dialogArgs = table.deepcopy(parsedScript);
	dialogArgs.Friendship = company.Npc[self.name].Friendship;
	dialogArgs.FriendshipPoint = company.Npc[self.name].FriendshipPoint;
	dialogArgs.DlgName = self.Info.Title;
	dialogArgs.JobName = self.Info.JobName;
	dialogArgs.FamilyName = self.Info.FamilyName;
	local lobbyCls = GetClassList('LobbyWorldDefinition')[GetUserLocation(company)];
	local msgList, curMsgList = GetLobbyIdleMessage(company, self.name, lobbyCls, 'NpcVisitMessage');
	if curMsgList and #curMsgList > 0 and RandomTest(50) then
		dialogArgs.VisitMessage = table.randompick(curMsgList).Text;
	else
		dialogArgs.VisitMessage = table.randompick(msgList).Text;
	end
	
	company.Temporary.NpcDialogMode = true;
	SetCompanyInstantProperty(company, 'ShopHost', self);
	local id, callback = ds:Dialog('BeastManager', dialogArgs);
	SetCompanyInstantProperty(company, 'ShopHost', nil);
	company.Temporary.NpcDialogMode = false;
	return env;
end
function PlayDialogScript_WarehouseManager(ds, self, company, env, parsedScript)
	company.Temporary.NpcDialogMode = true;
	UpdateUserActionState(company, 'Talking', 'Craft');
	local id, callback = ds:Dialog('WarehouseManager', {});
	UpdateUserActionState(company, 'Talking', nil);
	company.Temporary.NpcDialogMode = false;
	return env;
end
------------------------------------------------
function PlayDialogScript_ShowBackgroundImage(ds, self, company, env, parsedScript)
	ds:ShowBackgroundImage({Image = parsedScript.BackgroundImage, Type = parsedScript.DialogType, Effect = parsedScript.DialogEffect, Slow = StringToBool(parsedScript.Slow, false)});
	return env;
end
function PlayDialogScript_HideBackgroundImage(ds, self, company, env, parsedScript)
	ds:HideBackgroundImage({Slow = StringToBool(parsedScript.Slow, false)});
	return env;
end
function PlayDialogScript_ShowFrontmessage(ds, self, company, env, parsedScript)
	ds:ShowFrontmessageWithText(DictionaryText(parsedScript.Message), parsedScript.MessageColor);
	return env;
end
function PlayDialogScript_ShowFrontmessageFormat(ds, self, company, env, parsedScript)
	ds:ShowFrontmessageWithText(GameMessageFormText(RebaseClassTableToXmlTable(parsedScript.GameMessageForm), parsedScript.MessageColor), parsedScript.MessageColor);
	return env;
end
function PlayDialogScript_TitleMessage(ds, self, company, env, parsedScript)
	ds:UpdateTitleMessageWithText(DictionaryText(parsedScript.Title), parsedScript.TitleColor, DictionaryText(parsedScript.Message), parsedScript.MessageColor, parsedScript.Image);
	return env;
end
function PlayDialogScript_PlaySound(ds, self, company, env, parsedScript)
	ds:PlaySound(parsedScript.SoundName, parsedScript.SoundGroup, tonumber(parsedScript.Volume) or 1, parsedScript.NoWait == 'On');
	return env;
end
function PlayDialogScript_PlayBGM(ds, self, company, env, parsedScript)
	local bgmCls = GetClassList('Bgm')[parsedScript.BGMName];
	if not bgmCls or not bgmCls.name then
		LogAndPrint('PlayDialogScript_PlayBGM - not exist bgm name: ', parsedScript.BGMName);
		return env;
	end
	ds:PlayCustomBGM(bgmCls.File, tonumber(parsedScript.FadeTime) or 3, tonumber(parsedScript.Volume) or 1);
	return env;
end
function PlayDialogScript_StopBGM(ds, self, company, env, parsedScript)
	ds:StopCustomBGM(StringToBool(parsedScript.Direct, false), tonumber(parsedScript.FadeTime) or 3);
	return env;
end
function PlayDialogScript_PlayLoopSound(ds, self, company, env, parsedScript)
	ds:PlayLoopSound(parsedScript.Name, parsedScript.SoundName, parsedScript.SoundGroup, tonumber(parsedScript.Volume) or 1, parsedScript.NoWait == 'On');
	return env;
end
function PlayDialogScript_StopLoopSound(ds, self, company, env, parsedScript)
	ds:StopLoopSound(parsedScript.Name);
	return env;
end
function PlayDialogScript_ShowCredit(ds, self, company, env, parsedScript)
	ds:ShowCredit({CreditType = parsedScript.CreditType or 'None', Slow = StringToBool(parsedScript.Slow, false)});
	return env;
end
------------------------------------------------ 
function GetPropertyRecursive(obj, propType)
	for str in propType:gmatch('[^/]+') do
		obj = obj[str];
		if obj == nil then
			return nil;
		end
	end
	return obj;
end
local ActionTable =
{
	NoAction = function(...) end,
	UpdateQuestStage = 	function(dc, npc, company, args)
		local showMessage = args.ShowMessage and StringToBool(args.ShowMessage) or false;
		dc:UpdateQuestStage(company, args.QuestType, args.Stage, showMessage) 
	end,
	UpdateNPCProperty = function(dc, npc, company, args) 
		dc:UpdateNPCProperty(npc, args.PropertyType, args.PropertyValue) 
	end,
	AddNPCProperty = function(dc, npc, company, args)
		dc:AddNPCProperty(npc, args.PropertyType, args.PropertyValue);
	end,
	AddCompanyProperty = function(dc, npc, company, args)
		dc:AddCompanyProperty(company, args.PropertyType, args.PropertyValue, args.MinValue);
	end,
	UpdateCompanyProperty = function(dc, npc, company, args)
		dc:UpdateCompanyProperty(company, args.PropertyType, args.PropertyValue);
	end,
	UpdateCompanyName = function(dc, npc, company, args)
		dc:UpdateCompanyName(company, args.Name);
	end,
	UpdateFriendship = function(dc, npc, company, args)
		UpdateFriendship(dc, company, args.FriendshipType, args.FriendshipName, args.FriendshipPoint);
	end,
	NewRoster = function(dc, npc, company, args)
		dc:NewRoster(company, args.RosterName);
	end,
	AddRosterProperty = function(dc, npc, company, args)
		local roster = GetRoster(company, args.RosterName);
		dc:AddPCProperty(roster, args.PropertyType, args.PropertyValue);
	end,
	UpdateRosterProperty = function(dc, npc, company, args)
		local roster = GetRoster(company, args.RosterName);
		dc:UpdatePCProperty(roster, args.PropertyType, args.PropertyValue);
	end,	
	UpdateMasteryLv = function(dc, npc, company, args)
		local roster = GetRoster(company, args.RosterName);
		dc:UpdateMasteryLv(roster, args.MasteryName, tonumber(args.MasteryLv));
	end,
	AcquireMastery = function(dc, npc, company, args)
		dc:AcquireMastery(company, args.MasteryName, tonumber(args.MasteryCount), not StringToBool(args.ShowMessage, true));
	end,
	RefillMastery = function(dc, npc, company, args)
		local curCount = SafeIndex(company.Mastery, args.MasteryName, 'Amount') or 0;
		local refillCount = tonumber(args.MasteryCount) - curCount;
		if refillCount > 0 then
			dc:AcquireMastery(company, args.MasteryName, refillCount);
		end
	end,
	GiveItem = function(dc, npc, company, args, ds)
		local showMessage = StringToBool(args.ShowMessage, false);
		local alternative = StringToBool(args.Alternative, false);
		if ds and showMessage and alternative then
			-- ds가 있으면 타이밍을 맞춰서 수동으로 연출하고, DB 처리 후의 자동 연출을 숨김
			ds:PlayLobbyPopupEffect('GetItem', args.ItemName);
			showMessage = false;
		end
		dc:GiveItem(company, args.ItemName, tonumber(args.ItemCount), alternative, "", {}, showMessage);
	end,
	RefillItem = function(dc, npc, company, args)
		local showMessage = args.ShowMessage and StringToBool(args.ShowMessage) or false;
		local prevItem = GetInventoryItemByType(company, args.ItemName);
		local prevCount = prevItem and prevItem.Amount or 0;
		local refillCount = tonumber(args.ItemCount) - prevCount;
		if refillCount > 0 then
			dc:GiveItem(company, args.ItemName, refillCount, false, "", {}, showMessage);
		end
	end,
	-- 만들기는 했는데 기존의 사용여부를 고려하지 못해서 쓰기 애매한듯..
	EquipNewItem = function(dc, npc, company, args)
		local roster = GetRoster(company, args.RosterName);
		local itemCls = GetClassList('Item')[args.ItemType];
		local equipPos = GetAutoEquipmentPosition(roster.Object, itemCls);
		if equipPos ~= nil then
			dc:EquipNewItem(roster, args.ItemType, equipPos);
		end
	end,
	UpdateConditionPoint = function(dc, npc, company, args)
		local roster = GetRoster(company, args.RosterName);
		UpdateRosterConditionPoint(dc, roster, args.Value);
	end,
	AddConditionPoint = function(dc, npc, company, args)
		local roster = GetRoster(company, args.RosterName);
		AddRosterConditionPoint(dc, roster, args.Value);
	end,
	__index = function(at, key) return function(dc, npc, company, args) print('Unhandled Action : '..tostring(key)..' args:'..PackTableToString(args)); print(debug.traceback()); end end -- 없는 액션을 호출함..
}
setmetatable(ActionTable, ActionTable)

function ProcessDialogAction(dc, npc, company, args)
	ActionTable[args.Action](dc, npc, company, args);
end

function ProcessDialogAction_New(dc, npc, company, args, ds)
	ActionTable[args.Command](dc, npc, company, args, ds);
end
-----------------------------------------------------------------------------------------------
-- 퀘스트 대화 시작 함수
-----------------------------------------------------------------------------------------------
function QuestDialogStart(ldm, npc, company, questType, baseEnv)
	local questCls = GetClassList("Quest")[questType];
	if questCls == nil then
		return baseEnv;
	end

	local dialog = GetQuestDialog(questCls.name, 'Start');
	if dialog == nil then
		return;
	end
	baseEnv._Mode = 'QuestStart';
	baseEnv.QuestType = questType;
	baseEnv.QuestCls = questCls;
	local retEnv = ProgressDialogCls(ldm, npc, company, dialog, baseEnv);
	if retEnv.Closed then	-- 수락안함
		return retEnv;
	end
	
	-- 퀘스트가 MaxRequestCount 이상이면 수락해도 진행하지 말자
	local allQuests = GetAllQuests(company)
	local progressQuestCount = 0;
	for i, questInfo in ipairs(allQuests) do
		local questStage = questInfo.Stage; -- could be nil
		if questStage == 'InProgress' then
			progressQuestCount = progressQuestCount + 1;
		end
	end
	local uselessQuestion = progressQuestCount >= company.MaxQuestCount;

	ldm:Dialog('QuestSuggest', {QuestType = questType}, false);
	local id = nil;
	local sel = nil;
	repeat
		id, sel = ldm:Dialog('QuestSuggestBack', {Mode = 'Suggest', QuestType = questType}, true);
		if sel == 1 and uselessQuestion then
			ldm:ShowFrontmessageWithText(GuideMessageText('NoMoreQuestIsAvailable'));
			ldm:Sleep(0.75);
		end
	until not (sel == 1 and uselessQuestion);
	ldm:CloseDialog('QuestSuggest');
	local closed = sel ~= 1;

	if closed then
		return retEnv;
	end
	
	local dc = ldm:GetDatabaseCommiter();
	RequestStartQuest(dc, company, questCls, nil, true);
	
	dialog = GetQuestDialog(questCls.name, 'StartContinue');
	if dialog == nil then
		return retEnv;
	end
	retEnv._Mode = 'QuestStartContinue';
	retEnv = ProgressDialogCls(ldm, npc, company, dialog, retEnv);
	
	return retEnv;
end
-----------------------------------------------------------------------------------------------
-- 퀘스트 대화 종료 함수
-----------------------------------------------------------------------------------------------
function QuestDialogClear(ldm, npc, company, questType, baseEnv)
	local questCls = GetClassList("Quest")[questType];
	if questCls == nil then
		return baseEnv;
	end
	
	local dialog = GetQuestDialog(questCls.name, 'End');
	if dialog == nil then
		return baseEnv;
	end
	
	if dialog then
		baseEnv._Mode='QuestClear';
		baseEnv._dialogFadeIn = true;
		baseEnv.QuestType = questType;
		local retEnv = ProgressDialogCls(ldm, npc, company, dialog, baseEnv);
		if retEnv.Closed then	-- 완료안함
			return retEnv;
		end
		baseEnv = retEnv;
	end
		
	local hideCancel = nil;
	local directQuest = questCls.DirectContinue;
	if directQuest and directQuest ~= 'None' and TestQuestStart(company, npc, directQuest, questCls) then
		hideCancel = true;
	end
	
	ldm:Dialog('QuestSuggest', {QuestType = questType}, false);
	local id, sel = ldm:Dialog('QuestSuggestBack', {Mode = 'Complete', QuestType = questType, HideCancel = hideCancel}, true);
	if sel ~= 1 then
		ldm:CloseDialog('QuestSuggest');
		return baseEnv;
	end
	
	local rewards = GetWithoutError(questCls, 'Reward');
	local disabledIndex = {};
	for i, reward in ipairs(rewards) do
		local disable = false;
		if reward.Type == 'Recipe' then
			local recipe = company.Recipe[reward.Value];
			if recipe.Exp >= recipe.MaxExp then
				disable = true;
			end
			-- 레시피 언락
			if reward.Amount == 1 and recipe.Opened then
				disable = true;
			end
		elseif reward.Type == 'RandomRecipe' then
			local candidates = Linq.new(company.Recipe)
				:select(function(rd) return rd[2] end)
				:where(function(r) return r.Opened and r.Exp < r.MaxExp and #(r.UnLockRecipe) > 0 end);
			if reward.Value ~= 'All' then
				candidates:where(function(r) return r.Category == reward.Value end);
			end
			candidates = candidates:toList();
			if #candidates == 0 then
				disable = true;
			end
		elseif reward.Type == 'Troublemaker' then
			local tm = company.Troublemaker[reward.Value];
			if tm.Exp >= tm.MaxExp then
				disable = true;
			end
		elseif reward.Type == 'RandomTroublemaker' then
			local candidates = Linq.new(company.Troublemaker)
				:select(function(tmd) return tmd[2] end)
				:where(function(tmInfo) return tmInfo.Exp > 0 and tmInfo.Exp < tmInfo.MaxExp end);
			if reward.Value ~= 'All' then
				candidates:where(function(tmInfo) return tmInfo.Category.name == reward.Value end);
			end
			candidates = candidates:toList();
			if #candidates == 0 then
				disable = true;
			end
		end
		if disable then
			table.insert(disabledIndex, i);
		end
	end
	local rewardIndex = nil;
	if #rewards > #disabledIndex then
		local disabledSet = Set.new(disabledIndex);
		local id, sel = ldm:Dialog('QuestSuggestBack', {Mode = 'Reward', QuestType = questType, DisabledReward = disabledSet, HideCancel = hideCancel}, false);
		if disabledSet[sel] then
			sel = Linq.new(xrange(#rewards)):firstIf(function(i) return not disabledSet[i] end);		-- 안 disabled된 처음꺼
		end
		if sel <= #rewards then
			rewardIndex = sel;
		else
			ldm:CloseDialog('QuestSuggest');
			return baseEnv;
		end
	end

	ldm:CloseDialog('QuestSuggest');
	
	local dc = ldm:GetDatabaseCommiter();
	
	local success, rewardInfo = RequestCompleteQuest(dc, company, questCls, rewardIndex);
	if not success then
		return baseEnv;
	end
	
	local directQuest = questCls.DirectContinue;
	if directQuest and directQuest ~= 'None' and TestQuestStart(company, npc, directQuest) then
		baseEnv = QuestDialogStart(ldm, npc, company, directQuest, baseEnv);
	end
	return baseEnv;
end
-----------------------------------------------------------------------------------------------
-- 퀘스트 대화 선별 함수
-----------------------------------------------------------------------------------------------
function GetQuestDialog(questName, dialogType, noError)
	local questDialog = GetClassList("DialogQuest");
	local dialogList = questDialog[questName];
	if dialogList == nil and not noError then
		LogAndPrint(questName..' :: requestName not exist on DialogQuest.xml. Check questName and DialogQuest name');
		return nil;
	end
	local dialog = dialogList.Process[dialogType];
	if dialog == nil and not noError then
		LogAndPrint(questName..' :: DialogQuest - questName have not '..dialogType);
		return nil;
	end
	return dialog;
end
function QuestDialogProgress(ldm, npc, company, questType, baseEnv)
	local questCls = GetClassList('Quest')[questType];
	local success, retEnv = questCls.Type.ProgressHost(ldm, npc, company, questType, baseEnv);
	if not success then
		return retEnv;
	end
	if TestQuestClear(company, npc, questType) and questCls.CompletionNpc == npc.name then	-- 프로그래스를 처리한 대상과 완료대상이 같다면 바로 완료처리로 이어주자
		retEnv = QuestDialogClear(ldm, npc, company, questType, retEnv);
	end
	return retEnv;
end
function DeliveryItemDialogHost(ldm, npc, company, questType, env)
	local questCls = GetClassList('Quest')[questType];
	if questCls == nil then
		return false, env;
	end
	local item = questCls.Target;
	local curCount = LobbyInventoryItemCounter(company)(item);
	local dialog = nil;
	if curCount < questCls.TargetCount then		-- 아직 만족되지 않음
		dialog = GetQuestDialog(questCls.name, 'Reject');
		env._Mode = 'QuestProgress';
		env = ProgressDialogCls(ldm, npc, company, dialog, env);
		return false, env;
	else
		dialog = GetQuestDialog(questCls.name, 'Accept');
		env._Mode = 'QuestProgress';
		local retEnv = ProgressDialogCls(ldm, npc, company, dialog, env);
		if retEnv.Closed then	-- 진행하다가 닫아버리는 경우(?)
			return false, retEnv;
		end
		env = retEnv;
	end
	local itemCls = GetClassList('Item')[item];
	local itemGiveMessage = {GuideMessage = 'ItemGived', item=itemCls.Title, count=questCls.TargetCount};
	ldm:Dialog('NormalDialog', {DlgName=npc.Info.Title, Message=itemGiveMessage});
	ldm:CloseDialog('NormalDialog');
	local dc = ldm:GetDatabaseCommiter();
	dc:TakeItem(GetInventoryItemByType(company, item), questCls.TargetCount);
	dc:AddQuestProperty(company, questType, 'TargetCount', 1);
	dc:Commit('DeliveryDialog:'..questType);
	return true, env;
end
function ProgressDialogNormalProgress(ldm, npc, company, questType, env)
	local questCls = GetClassList('Quest')[questType];
	if questCls == nil then
		return false;
	end
	local modeKey = 'QuestProgress';
	local dialogKey = 'Progress';
	if npc.name == questCls.Client and npc.name ~= questCls.TargetNPC then
		modeKey = 'QuestProgress_Client';
		dialogKey = 'Progress_Client';
	end
	env._Mode = modeKey;
	env.QuestType = questType;
	local retEnv = ProgressDialogCls(ldm, npc, company, GetQuestDialog(questCls.name, dialogKey), env);
	return not retEnv.Closed, retEnv;
end
--- 커스텀 다이얼로그 스크립트들
function ProgressUnlockWorkshop(ds, self, company, env, parsedScript)
	if company.Vill < company.UnlockPrice.Workshop then
		return false;
	end
	
	local dc = ds:GetDatabaseCommiter();
	dc:AddCompanyProperty(company, 'Vill', -20000);
	dc:UpdateCompanyProperty(company, 'WorkshopMenu/Opened', true);
	dc:UpdateCompanyProperty(company, 'WorkshopMenu/Unlocked', true);
	return dc:Commit();
end
function ProgressRestoreCP(ds, self, company, env, parsedScript)
	local roster = GetRoster(company, parsedScript.RosterName);
	if roster == nil then
		return false;
	end
	if company.Vill < parsedScript.Price then
		return false;
	end
	
	local dc = ds:GetDatabaseCommiter();
	dc:AddCompanyProperty(company, 'Vill', -parsedScript.Price);
	
	if parsedScript.Mode == 'Update' then
		UpdateRosterConditionPoint(dc, roster, parsedScript.Value);
	else -- parsedScript.Mode == 'Add'
		AddRosterConditionPoint(dc, roster, parsedScript.Value);
	end
	return dc:Commit();
end
function ProgressRestoreCPNoVill(ds, self, company, env, parsedScript)
	local roster = GetRoster(company, parsedScript.RosterName);
	if roster == nil then
		return false;
	end
	local dc = ds:GetDatabaseCommiter();
	local prevCP = roster:GetEstimatedCP();
	if parsedScript.Mode == 'Update' then
		UpdateRosterConditionPoint(dc, roster, parsedScript.Value);
	else -- parsedScript.Mode == 'Add'
		AddRosterConditionPoint(dc, roster, parsedScript.Value);
	end
	if not dc:Commit('DialogAction:'..env._cur_dialog.name) then
		return false;
	end
	local fillData = {};
	table.insert(fillData, {Name = roster.name, StartValue = prevCP, EndValue = roster:GetEstimatedCP()});
	ds:ShowConditionEffect(fillData);
	return true;
end

function ProgressRestAction(ds, self, company, env, parsedScript)
	
	local restActionList = GetClassList('RestAction');

	local rosters = GetAllRoster(company);
	if parsedScript.RosterName ~= nil then
		rosters = table.filter(rosters, function(roster) return roster.name == parsedScript.RosterName; end);
	end
	local dc = ds:GetDatabaseCommiter();
	
	
	local restAction = restActionList[parsedScript.RestActionType];
	if not restAction then
		LogAndPrint(string.format('DataError - RestAction %s not exist Rest.xml - idspace RestAction', parsedScript.RestActionType));
		return false;
	end
	
	local fee = 0;
	-- 1. RestAction 일때 검증 체크.
	local isEnable, fee, reason = IsEnableRestAction(company, rosters, restAction, parsedScript.Roster);
	if not isEnable then
		return false;
	end
	
	-- 2. 로스터 CP 회복.
	local prevCP = {};
	local categoryList = {};
	for i, roster in ipairs(rosters) do
		local addCP, addCount, category = GetResultRestAction(restAction, roster);
		local addValue = {Refresh = 0, Satiety = 0};
		addValue[restAction.Type] = addCount;
		prevCP[roster.name] = roster:GetEstimatedCP();
		AddRosterConditionPoint(dc, roster, addCP, addValue.Satiety, addValue.Refresh);
		-- 각 행동 카운트 증가
		if addCount ~= 0 then
			dc:AddPCProperty(roster, restAction.Type, addCount);
		end
		table.insert(categoryList, category);
	end
	
	-- 3. 비용 지불.
	if fee ~= 0 then
		dc:AddCompanyProperty(company, 'Vill', -1 * fee);
	end
	
	-- 4. 회사 통계
	dc:AddCompanyProperty(company, 'Stats/RestAction/'..restAction.name, 1);
	
	if not dc:Commit('DialogAction:'..env._cur_dialog.name) then
		return false;
	end
	local fillData = {};
	for i, roster in ipairs(rosters) do
		local category = categoryList[i];
		table.insert(fillData, {Name = roster.name, StartValue = prevCP[roster.name], EndValue = roster:GetEstimatedCP(), Category = category, RestAction = restAction.name});
	end
	ds:ShowConditionEffect(fillData);
end
function PostSuggestionConditonRest(ds, self, company, env, parsedScript)
	local rosters = GetAllRoster(company);
	local dc = ds:GetDatabaseCommiter();
	
	for i, roster in ipairs(rosters) do
		dc:AddPCProperty(roster, 'SalaryCounter', 1);
	end
	dc:AddCompanyProperty(company, 'OfficeRentCounter', 1);
	dc:Commit('DialogAction:'..env._cur_dialog.name);
	
	-- 월급 후처리
	LobbyEnterPost(ds, company, 'Office');
end

function Dialog_Office_Silverlining_Resetter(ds, self, company, env, parsedScript)
	local roster = GetRoster(company, 'Albus');
	if roster == nil then
		return false;
	end
	
	local dc = ds:GetDatabaseCommiter();
	for i, resetInfo in ipairs({{ItemType='Potion_HP', InvCount = 9},
								{ItemType='Grenade_FlashBang', InvCount = 4}}) do
		local itemCls = GetClassList('Item')[resetInfo.ItemType];
		
		-- 장비
		local equipPos = GetAutoEquipmentPosition(roster.Object, itemCls);
		if equipPos ~= nil then
			local prevItem = GetWithoutError(roster.Object, equipPos);
			if SafeIndex(prevItem, 'name') ~= itemCls.name then
				if prevItem.name ~= nil then
					dc:UnequipItem(roster, equipPos);
				end
				dc:EquipNewItem(roster, itemCls.name, equipPos);
			end
		end
		
		-- 인벤토리
		local invItem = GetInventoryItemByType(company, resetInfo.ItemType);
		local curCount = invItem and invItem.Amount or 0;
		if curCount < resetInfo.InvCount then
			dc:GiveItem(company, resetInfo.ItemType, resetInfo.InvCount - curCount);
		elseif curCount > resetInfo.InvCount then
			dc:TakeItem(invItem, curCount - resetInfo.InvCount);
		end
	end
	dc:Commit();
end

function ProgressNoticeAction(ds, self, company, env, parsedScript)
	local noticeCls = GetClassList('Notice')[parsedScript.NoticeType];
	if not noticeCls or not noticeCls.name then
		return false;
	end
	
	ds:Dialog('UpdateNotice', {NoticeType = noticeCls.name}, true);
	
	local dc = ds:GetDatabaseCommiter();
	dc:UpdateCompanyProperty(company, string.format('NoticeVersions/%s', noticeCls.name), noticeCls.Version);
	return dc:Commit('ProgressNoticeAction');
end

function ProgressEmotionTest(ds, self, company, env, parsedScript)
	local objectInfoCls = GetClassList('ObjectInfo')[parsedScript.ObjectInfo];
	if not objectInfoCls or not objectInfoCls.name then
		return false;
	end
	local dialogType = parsedScript.DialogType;
	
	local infoList = {};
	for key, info in pairs(objectInfoCls.Emotions) do
		table.insert(infoList, { Key = key, Info = info });
	end
	
	for i = 1, #infoList do
		local key = infoList[i].Key;
		local info = infoList[i].Info;
		local dialogArgs = {
			SpeakerInfo = objectInfoCls.name,
			SpeakerEmotion = key,
			Mode = (i == 1 and 'Start' or 'Continue'),
			Message = key,
			Type = dialogType,
			Slot = 'Center',
			Effect = 'Appear',
		};
		ds:Dialog('BattleDialog', dialogArgs, i == #infoList);
	end
end

function ProgressPlayDialogFunc(ds, self, company, env, parsedScript)
	local func = nil;
	if type(parsedScript.Func) == 'function' then
		func = parsedScript.Func;
	elseif type(parsedScript.Func) == 'string' then
		func =  _G[parsedScript.Func];
	end
	if func ~= nil then
		func(ds, company, parsedScript.Args);
	end
	return env;
end

-- 활동 보고서
function ProgressActivityReport(ds, self, company, env, parsedScript)
	local dc = ds:GetDatabaseCommiter();
	
	local dialogArgs = { 
		Vill = {},
		Item = {},
		Etc = {}
	};

	local reputationSectorTypeList = GetClassList('ReputationSectorType');
	local recipeList = GetClassList('Recipe');
	
	-- I. 지원금 관련.
	-- 1. 기본 보상
	local vill = 0;
	vill = math.floor(vill + company.Grade.BaseReward);
	table.insert(dialogArgs.Vill, { Type = 'BaseReward', Value = company.Grade.BaseReward });	
	-- 2. 미션 누적 보상
	vill = vill + company.CurrentReward;
	table.insert(dialogArgs.Vill, { Type = 'MissionClearReward', Value = company.CurrentReward });
	-- 3. 평판 기본보상
	local villReputation = 0;
	for i, division in ipairs(GetClassList('Zone')[company.CurrentZone].Division) do
		for j, section in ipairs(division.Section) do
			local reputation = company.Reputation[section.Type];
			if reputation.Opened and reputation.Lv > 0 then
				local rewardLv = reputation.RewardLv;
				local addVill = reputation.Reward[rewardLv].Vill;
				if addVill > 0 then
					villReputation = villReputation + addVill;
				end
			end
		end
	end
	vill = vill + villReputation;
	table.insert(dialogArgs.Vill, { Type = 'AreaBonus', Value = villReputation });
	-- 4. 북부 지구 보너스
	local northAreaBonus, northAreaCount = GetDivisionTypeBonusValue(company.Reputation, 'Area_North');
	if northAreaBonus > 0 then
		local northAreaBonusVill = math.floor(villReputation * northAreaBonus / 100);
		if northAreaBonusVill > 0 then
			vill = vill + northAreaBonusVill;
			table.insert(dialogArgs.Vill, { Type = 'Area_North', Grade = northAreaCount, Value = northAreaBonusVill });
		end
	end
	-- 5. 넉넉한 후원
	local villEnoughSupport = 0;	
	for _, info in ipairs(company.ActivityReport.History) do
		if info.Section ~= 'None' and info.EnoughSupport > 0 then
			villEnoughSupport = villEnoughSupport + info.EnoughSupport;
		end
	end
	if villEnoughSupport > 0 then
		table.insert(dialogArgs.Vill, { Type = 'EnoughSupport', Value = villEnoughSupport });
		vill = vill + villEnoughSupport;
	end
	-- 5. 보상 지급
	dialogArgs.TotalVill = vill
	dc:AddCompanyProperty(company, 'Vill', vill);
	
	-- II. 아이템 관련.
	-- 1. 산업 지구 보상.
	local industryBonus, industryCount = GetSectionTypeBonusValue(company.Reputation, 'Industry');
	if industryBonus > 0 then
		local rewardItemList = PickIndustryBonusItem(company, industryBonus);
		for _, rewardItem in ipairs(rewardItemList) do
			dc:GiveItem(company, rewardItem, 1, true, '_INV_FULL_ACTIVITY_REPORT_');
			table.insert(dialogArgs.Item, { Type = 'Industry', Grade = industryCount, Value = rewardItem, Amount = 1 });
		end
	end
	-- 2. 특수 지구 훈련서.
	local specialBonus, specialCount = GetSectionTypeBonusValue(company.Reputation, 'Special');
	if specialBonus > 0 then
		local rewardItem = 'Statement_Mastery';	
		dc:GiveItem(company, rewardItem, specialBonus, true, '_INV_FULL_ACTIVITY_REPORT_');
		table.insert(dialogArgs.Item, { Type = 'Special', Grade = specialCount, Value = rewardItem, Amount = specialBonus });
	end
	
	local ForeachAllowDivisionBonus = function(company, bonusType, doFunc)
		local bonusCls = GetClassList('ReputationPolicy')[bonusType];
		if not bonusCls then
			return;
		end
		for sectionName, bonusCount in pairs(company.ActivityReport.ReputationBonus) do
			local section = company.Reputation[sectionName];
			for i, info in ipairs(section.Bonus) do
				if info.Type == bonusType and bonusCount[i] > 0 then
					for j = 1, bonusCount[i] do
						local ret = doFunc(bonusCls, section);
						-- 중단 처리
						if ret == false then
							return;
						end
					end
				end
			end
		end
	end;
	
	-- 3. 정책으로인한 지원류. (물품지원, 암거래, 기타 등등)
	-- 물품 지원: XXX
	local supportItemFuncList = {};
	local AddSupportItemFuncList = function(bonusType, fixCountKey, doFunc)
		table.insert(supportItemFuncList, { BonusType = bonusType, FixCountKey = fixCountKey, DoFunc = doFunc });
	end;
	
	-- 3-1) 물품 지원: 회복약
	AddSupportItemFuncList('SupportItem_Potion', nil, function(bonusCls, bonusSection)
		local rewardItem = PickSupportItemPotion();
		if rewardItem then
			local itemCount = bonusCls.ApplyAmount;
			dc:GiveItem(company, rewardItem, itemCount, true, '_INV_FULL_ACTIVITY_REPORT_');
			table.insert(dialogArgs.Item, { Type = bonusSection.name, SubType = bonusCls.name, Value = rewardItem, Amount = itemCount });
		end
	end);
	-- 3-2) 물품 지원: 희귀 장비(무기, 방어구, 악세서리)
	local supportEquipmentList = {
		{ BonusType = 'SupportItem_RareEquipment', Category = { 'Weapon', 'Armor', 'Accessory' } },
		{ BonusType = 'SupportItem_RareWeapon', Category = { 'Weapon' } },
		{ BonusType = 'SupportItem_RareArmor', Category = { 'Armor' } },
		{ BonusType = 'SupportItem_RareAccessory', Category = { 'Accessory' } },
	};
	for _, info in ipairs(supportEquipmentList) do
		AddSupportItemFuncList(info.BonusType, 'SupportItem_RareEquipment', function(bonusCls, bonusSection, fixCountKey)
			local rewardItem, nextFixCount = PickSupportItemRareEquipment(company, info.Category, fixCountKey);
			if rewardItem then
				local itemCount = bonusCls.ApplyAmount;
				dc:GiveItem(company, rewardItem, itemCount, true, '_INV_FULL_ACTIVITY_REPORT_');
				table.insert(dialogArgs.Item, { Type = bonusSection.name, SubType = bonusCls.name, Value = rewardItem, Amount = itemCount });
			end
			local curFixCount = GetWithoutError(company.ActivityReport.RewardCounter, fixCountKey);
			if curFixCount and curFixCount ~= nextFixCount then
				dc:UpdateCompanyProperty(company, string.format('ActivityReport/RewardCounter/%s', fixCountKey), nextFixCount);
				-- 다음 아이템 선택 시에 반영되도록 임시로 프로퍼티를 바로 변경함
				company.ActivityReport.RewardCounter[fixCountKey] = nextFixCount;
			end
		end);
	end
	-- 3-3) 물품 지원: 희귀 소재
	AddSupportItemFuncList('SupportItem_RareMaterial', 'SupportItem_RareEquipment', function(bonusCls, bonusSection, fixCountKey)
		local rewardItem, nextFixCount = PickSupportItemRareMaterial(company, fixCountKey);
		if rewardItem then
			local itemCount = bonusCls.ApplyAmount;
			dc:GiveItem(company, rewardItem, itemCount, true, '_INV_FULL_ACTIVITY_REPORT_');
			table.insert(dialogArgs.Item, { Type = bonusSection.name, SubType = bonusCls.name, Value = rewardItem, Amount = itemCount });
		end
		local curFixCount = GetWithoutError(company.ActivityReport.RewardCounter, fixCountKey);
		if curFixCount and curFixCount ~= nextFixCount then
			dc:UpdateCompanyProperty(company, string.format('ActivityReport/RewardCounter/%s', fixCountKey), nextFixCount);
			-- 다음 아이템 선택 시에 반영되도록 임시로 프로퍼티를 바로 변경함
			company.ActivityReport.RewardCounter[fixCountKey] = nextFixCount;
		end
	end);
	-- 3-4) 물품 지원: 에너지 추출기
	AddSupportItemFuncList('SupportItem_Extractor', nil, function(bonusCls, bonusSection, fixCountKey)
		local rewardItem = PickSupportItemExtractor();
		if rewardItem then
			local itemCount = bonusCls.ApplyAmount;
			dc:GiveItem(company, rewardItem, itemCount, true, '_INV_FULL_ACTIVITY_REPORT_');
			table.insert(dialogArgs.Item, { Type = bonusSection.name, SubType = bonusCls.name, Value = rewardItem, Amount = itemCount });
		end
	end);
	-- 3-5) 물품 지원: 순도 높은 이능석
	AddSupportItemFuncList('SupportItem_Psistone', 'SupportItem_Psistone', function(bonusCls, bonusSection, fixCountKey)
		local rewardItem, nextFixCount = PickSupportItemPsistone(company, fixCountKey);
		if rewardItem then
			local itemCount = bonusCls.ApplyAmount;
			dc:GiveItem(company, rewardItem, itemCount, true, '_INV_FULL_ACTIVITY_REPORT_');
			table.insert(dialogArgs.Item, { Type = bonusSection.name, SubType = bonusCls.name, Value = rewardItem, Amount = itemCount });
		end
		local curFixCount = GetWithoutError(company.ActivityReport.RewardCounter, fixCountKey);
		if curFixCount and curFixCount ~= nextFixCount then
			dc:UpdateCompanyProperty(company, string.format('ActivityReport/RewardCounter/%s', fixCountKey), nextFixCount);
			-- 다음 아이템 선택 시에 반영되도록 임시로 프로퍼티를 바로 변경함
			company.ActivityReport.RewardCounter[fixCountKey] = nextFixCount;
		end
	end);
	for _, info in ipairs(supportItemFuncList) do
		ForeachAllowDivisionBonus(company, info.BonusType, function(bonusCls, bonusSection)
			info.DoFunc(bonusCls, bonusSection, info.FixCountKey);
		end)
	end
	-- 3-6) 암거래 적발
	ForeachAllowDivisionBonus(company, 'BlackMarket', function(bonusCls, bonusSection)
		-- 물품 지원: XXX 타입 중에서 1가지가 랜덤으로 적용됨 (아이템 개수는 BlackMarket에 적용된 대로)
		local info = supportItemFuncList[math.random(1, #supportItemFuncList)];
		info.DoFunc(bonusCls, bonusSection, 'BlackMarket');
	end);
	-- 3-7) 현장 수습
	for _, info in ipairs(company.ActivityReport.History) do
		if info.Section ~= 'None' and info.FieldControlSection ~= 'None' then
			local rewardItem = PickFieldControlEquipment(company, info.FieldControlMission);
			if rewardItem then
				dc:GiveItem(company, rewardItem, 1, true, '_INV_FULL_ACTIVITY_REPORT_');
				table.insert(dialogArgs.Item, { Type = info.FieldControlSection, SubType = 'FieldControl', Value = rewardItem, Amount = 1 });
			end
		end
	end	
	
	-- III. 기타 관련
	-- 1. 기술 협약
	ForeachAllowDivisionBonus(company, 'TechnicalAgreements', function(bonusCls, bonusSection)
		local picker = RandomPicker.new();
		for key, recipe in pairs(company.Recipe) do
			if recipe.Opened and recipe.Exp < recipe.MaxExp and #recipe.UnLockRecipe > 0 then
				picker:addChoice(1, recipe);
			end
		end
		local recipe = picker:pick();
		if recipe == nil then
			return false;
		end
		local maxExp = recipe.MaxExp;
		local nextExp = math.min(recipe.Exp + bonusCls.ApplyAmount * 100, maxExp);
		local addExp = nextExp - recipe.Exp;
		local unlockRecipe = {};
		local dbKey = string.format('Recipe/%s/Exp', recipe.name);
		if nextExp >= maxExp then
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
		else
			dc:AddCompanyProperty(company, dbKey, addExp);
		end
		-- 타입에 지역 명, 서브 타입에 정책명. Value에 제작 가능한 아이템 레시피 클래스 네임. Amount 에 올라간 숙련도 값.
		table.insert(dialogArgs.Etc, { Type = bonusSection.name, SubType = 'TechnicalAgreements', Value = recipe.name, Amount = bonusCls.ApplyAmount, UnlockRecipe = unlockRecipe });
		-- 다음 레시피 선택 시에 반영되도록 임시로 프로퍼티를 바로 변경함
		recipe.Exp = nextExp;
	end);
	-- 2. 정보상.
	ForeachAllowDivisionBonus(company, 'InformationMerchant', function(bonusCls, bonusSection)
		local picker = RandomPicker.new();
		for key, tmInfo in pairs(company.Troublemaker) do
			if tmInfo.Exp > 0 and tmInfo.Exp < tmInfo.MaxExp then
				picker:addChoice(1, tmInfo);
			end
		end
		local tmInfo = picker:pick();
		if tmInfo == nil then
			return false;
		end
		local nextExp = math.min(tmInfo.Exp + bonusCls.ApplyAmount, tmInfo.MaxExp);
		local addExp = nextExp - tmInfo.Exp;
		-- 타입에 지역 명, 서브 타입에 정책명. Value에 트러블메이커 이름. Amount 에 올라간 정보값.
		table.insert(dialogArgs.Etc, { Type = bonusSection.name, SubType = 'InformationMerchant', Value = tmInfo.name, Amount = bonusCls.ApplyAmount });
		dc:AddCompanyProperty(company, string.format('Troublemaker/%s/Exp', tmInfo.name), addExp);
		-- 다음 레시피 선택 시에 반영되도록 임시로 프로퍼티를 바로 변경함
		tmInfo.Exp = nextExp;
	end);
	
	-- 5. 보상 시간 갱신
	dc:UpdateCompanyProperty(company, 'ActivityReportCounter', 0);
	
	-- 6. 초기화
	ResetActivityReport(dc, company);

	if not dc:Commit('DialogAction:'..env._cur_dialog.name) then
		return false;
	end
	
	-- 싱글 플레이 치안도 증감
	if IsSingleplayMode() then
		if company.ZoneState[company.CurrentZone].SafetyFever then
			local repuSum = Linq.new(GetClassList('Zone')[company.CurrentZone].Division)
				:selectMany(function(dv) return dv.Section; end)
				:sum(function(section) return company.Reputation[section.Type].Lv; end);
			dc:UpdateCompanyProperty(company, string.format('ZoneState/%s/Safty', company.CurrentZone), repuSum);
			dc:UpdateCompanyProperty(company, string.format('ZoneState/%s/SafetyFever', company.CurrentZone), false);
			
			SendSystemNotice(company, 'SafetyFeverEnd', {ZoneName = company.CurrentZone});
		else			
			local addSafety = company.Singleplay.SafetyStack * (1 + 40 * company.Singleplay.ScenarioClearCount / 100);
			dc:AddCompanyProperty(company, string.format('ZoneState/%s/Safty', company.CurrentZone), addSafety, 0, company.ZoneState[company.CurrentZone].MaxSafty);
			
			local currentSafety = company.ZoneState[company.CurrentZone].Safty;
			if currentSafety + addSafety >= company.ZoneState[company.CurrentZone].MaxSafty then
				dc:UpdateCompanyProperty(company, string.format('ZoneState/%s/SafetyFever', company.CurrentZone), true);
				SendSystemNotice(company, 'SafetyFeverStart_Single', {ZoneName=company.CurrentZone, LeftMissionCount = company.ActivityReportDuration - company.ActivityReportCounter});
			end
		end
		
		-- 싱글플레이 치안도 관련
		dc:UpdateCompanyProperty(company, 'Singleplay/SafetyStack', 0);
		dc:UpdateCompanyProperty(company, 'Singleplay/ScenarioClearCount', 0);
		dc:Commit('DialogAction:'..env._cur_dialog.name);
	end
	
	ds:Dialog('ActivityReport', dialogArgs, true);
end
local g_industryCandidateSet = nil;
function PickIndustryBonusItem(company, pickCount)
	local rankInfoSet = {
		Rare = { Prob = 80 },
		Epic = { Prob = 20, Next = 'Rare' },
	};
	
	local categorySet = { Weapon = true, Armor = true, Accessory = true };

	if g_industryCandidateSet == nil then
		local candidateSet = {};
		local pcList = GetClassList('Pc');
		for rank, _ in pairs(rankInfoSet) do
			candidateSet[rank] = {};
			for _, pcCls in pairs(pcList) do
				candidateSet[rank][pcCls.name] = {};
			end
		end
		local equipPosList = GetClassList('ItemEquipmentPosition');
		local itemList = GetClassList('Item');
		for _, pcCls in pairs(pcList) do
			-- 캐릭터가 착용 가능한 아이템 Type들을 뽑음
			local equipTypeSet = {};
			for equipPos, _ in pairs(equipPosList) do
				local equipTypeList = GetWithoutError(pcCls.Object, 'EnableEquip'..equipPos);
				if equipTypeList then
					for _, equipType in ipairs(equipTypeList) do
						equipTypeSet[equipType] = true;
					end
				end
			end
			for key, item in pairs(itemList) do
				if rankInfoSet[item.Rank.name] and equipTypeSet[item.Type.name] and categorySet[item.Category.name] then
					local candidateList = SafeIndex(candidateSet, item.Rank.name, pcCls.name);
					if candidateList ~= nil then
						table.insert(candidateList, key);
					end
				end
			end
		end
		g_industryCandidateSet = candidateSet;
	end
		
	-- 현재 회사가 획득 가능한 아이템 셋
	local itemFilter = {};
	for _, recipe in pairs(company.Recipe) do
		if recipe.Opened then
			itemFilter[recipe.name] = true;
		end
	end
	local monsterList = GetClassList('Monster');
	for _, tmInfo in pairs(company.Troublemaker) do
		if tmInfo.Exp > 0 then
			local monCls = monsterList[tmInfo.name];
			for _, reward in ipairs(monCls.Rewards) do
				itemFilter[reward.Item] = true;
			end
		end
	end
	
	local roster = GetAllRoster(company);
	local maxRequireLv = 0;
	for _, pcInfo in ipairs(roster) do
		local requireLv = math.floor(pcInfo.Lv / 5) * 5;
		maxRequireLv = math.max(maxRequireLv, requireLv);
	end
	
	local pickItemList = {};
	
	for i = 1, pickCount do
		local pickRank = nil;
		local pickItem = nil;
		for fixRequireLv = 0, maxRequireLv, 5 do
			local rankPicker = RandomPicker.new();
			for rank, info in pairs(rankInfoSet) do
				rankPicker:addChoice(info.Prob, rank);
			end
			pickRank = rankPicker:pick();		
			while pickRank ~= nil do
				local candidateList = {};
				-- 로스터 멤버 당
				for _, pcInfo in ipairs(roster) do
					local candidateListByRoster = SafeIndex(g_industryCandidateSet, pickRank, pcInfo.name);
					-- 회사가 획득 가능한 것만
					candidateListByRoster = table.filter(candidateListByRoster, function(itemName)
						return itemFilter[itemName];
					end);
					-- RequireLv이 맞는 것만
					local testRequireLv = math.floor(pcInfo.Lv / 5) * 5;
					testRequireLv = math.max(testRequireLv - fixRequireLv, 0);
					local itemList = GetClassList('Item');
					candidateListByRoster = table.filter(candidateListByRoster, function(itemName)
						local itemCls = itemList[itemName];
						return itemCls.RequireLv == testRequireLv;
					end);
					table.append(candidateList, candidateListByRoster);
				end
				if #candidateList > 0 then
					pickItem = candidateList[math.random(1, #candidateList)];
					break;
				end
				pickRank = rankInfoSet[pickRank].Next;
			end
			if pickItem ~= nil then
				break;
			end
		end
		if pickItem ~= nil then
			table.insert(pickItemList, pickItem);
		end
	end
	return pickItemList;
end
local g_potionPicker = nil;
function PickSupportItemPotion()
	if g_potionPicker == nil then
		local picker = RandomPicker.new();
		local rareGrade = GetClassList('ItemRank')['Rare'];		
		for key, item in pairs(GetClassList('Item')) do
			if item.Type.name == 'Potion' and item.Rank.Weight >= rareGrade.Weight then
				picker:addChoice(1, key);
			end
		end
		g_potionPicker = picker;
	end
	return g_potionPicker:pick();
end
local g_extractorPicker = nil;
function PickSupportItemExtractor()
	if g_extractorPicker == nil then
		local picker = RandomPicker.new();
		local rareGrade = GetClassList('ItemRank')['Rare'];		
		for key, item in pairs(GetClassList('Item')) do
			if item.Type.name == 'Extractor' and item.Rank.Weight >= rareGrade.Weight then
				picker:addChoice(1, key);
			end
		end
		g_extractorPicker = picker;
	end
	return g_extractorPicker:pick();
end
local g_psiStonePickerSet = nil;
function PickSupportItemPsistone(company, fixCountKey)
	local rankInfoSet = {
		Rare = { Prob = 70, Fix = -7 },
		Epic = { Prob = 20, Fix = 5, Next = 'Rare' },
		Legend = { Prob = 10, Fix = 2, Next = 'Epic' },
	};

	if g_psiStonePickerSet == nil then
		local pickerSet = {};
		for rank, _ in pairs(rankInfoSet) do
			pickerSet[rank] = RandomPicker.new();
		end
		for key, item in pairs(GetClassList('Item')) do
			if item.Type.name == 'PsionicStone' and rankInfoSet[item.Rank.name] then
				local picker = pickerSet[item.Rank.name];
				picker:addChoice(1, key);
			end
		end
		g_psiStonePickerSet = pickerSet;
	end
	
	local fixCount = GetWithoutError(company.ActivityReport.RewardCounter, fixCountKey) or 0;
	
	local rankPicker = RandomPicker.new();
	for rank, info in pairs(rankInfoSet) do
		local prob = math.max(info.Prob + fixCount * info.Fix, 0);
		rankPicker:addChoice(prob, rank);
	end
	local pickRank = rankPicker:pick();
	local pickItem = nil;
	
	while pickRank ~= nil do
		local itemPicker = g_psiStonePickerSet[pickRank];
		if itemPicker and itemPicker:size() > 0 then
			pickItem = itemPicker:pick();
			break;
		end
		pickRank = rankInfoSet[pickRank].Next;
	end
	
	if pickRank == 'Rare' then
		fixCount = fixCount + 1;
	else
		fixCount = 0;
	end
	return pickItem, fixCount;
end
local g_rareEquipmentCandidateSet = nil;
function PickSupportItemRareEquipment(company, categoryList, fixCountKey)
	local rankInfoSet = {
		Rare = { Prob = 70, Fix = -7 },
		Epic = { Prob = 20, Fix = 5, Next = 'Rare' },
		Legend = { Prob = 10, Fix = 2, Next = 'Epic' },
	};

	if g_rareEquipmentCandidateSet == nil then
		local candidateSet = {};
		local pcList = GetClassList('Pc');
		for rank, _ in pairs(rankInfoSet) do
			candidateSet[rank] = {};
			for _, pcCls in pairs(pcList) do
				candidateSet[rank][pcCls.name] = { Weapon = {}, Armor = {}, Accessory = {} };
			end
		end
		local equipPosList = GetClassList('ItemEquipmentPosition');
		local itemList = GetClassList('Item');
		for _, pcCls in pairs(pcList) do
			-- 캐릭터가 착용 가능한 아이템 Type들을 뽑음
			local equipTypeSet = {};
			for equipPos, _ in pairs(equipPosList) do
				local equipTypeList = GetWithoutError(pcCls.Object, 'EnableEquip'..equipPos);
				if equipTypeList then
					for _, equipType in ipairs(equipTypeList) do
						equipTypeSet[equipType] = true;
					end
				end
			end
			for key, item in pairs(itemList) do
				if rankInfoSet[item.Rank.name] and equipTypeSet[item.Type.name] then
					local candidateList = SafeIndex(candidateSet, item.Rank.name, pcCls.name, item.Category.name);
					if candidateList ~= nil then
						table.insert(candidateList, key);
					end
				end
			end
		end
		g_rareEquipmentCandidateSet = candidateSet;
	end
		
	-- 현재 회사가 획득 가능한 아이템 셋
	local itemFilter = {};
	for _, recipe in pairs(company.Recipe) do
		if recipe.Opened then
			itemFilter[recipe.name] = true;
		end
	end
	local monsterList = GetClassList('Monster');
	for _, tmInfo in pairs(company.Troublemaker) do
		if tmInfo.Exp > 0 then
			local monCls = monsterList[tmInfo.name];
			for _, reward in ipairs(monCls.Rewards) do
				itemFilter[reward.Item] = true;
			end
		end
	end
	
	local roster = GetAllRoster(company);
	local maxRequireLv = 0;
	for _, pcInfo in ipairs(roster) do
		local requireLv = math.floor(pcInfo.Lv / 5) * 5;
		maxRequireLv = math.max(maxRequireLv, requireLv);
	end
	
	local fixCount = GetWithoutError(company.ActivityReport.RewardCounter, fixCountKey) or 0;
	
	local pickRank = nil;
	local pickItem = nil;
	
	for fixRequireLv = 0, maxRequireLv, 5 do
		local rankPicker = RandomPicker.new();
		for rank, info in pairs(rankInfoSet) do
			local prob = math.max(info.Prob + fixCount * info.Fix, 0);
			rankPicker:addChoice(prob, rank);
		end
		pickRank = rankPicker:pick();		
		while pickRank ~= nil do
			local candidateList = {};
			-- 로스터 멤버 당
			for _, pcInfo in ipairs(roster) do
				local candidateListByRoster = {};
				-- 인자로 받은 카테고리만
				for _, category in ipairs(categoryList) do
					local candidateListByCategory = SafeIndex(g_rareEquipmentCandidateSet, pickRank, pcInfo.name, category);
					if candidateListByCategory then
						table.append(candidateListByRoster, candidateListByCategory);
					end
				end
				-- 회사가 획득 가능한 것만
				candidateListByRoster = table.filter(candidateListByRoster, function(itemName)
					return itemFilter[itemName];
				end);
				-- RequireLv이 맞는 것만
				local testRequireLv = math.floor(pcInfo.Lv / 5) * 5;
				testRequireLv = math.max(testRequireLv - fixRequireLv, 0);
				local itemList = GetClassList('Item');
				candidateListByRoster = table.filter(candidateListByRoster, function(itemName)
					local itemCls = itemList[itemName];
					return itemCls.RequireLv == testRequireLv;
				end);
				table.append(candidateList, candidateListByRoster);
			end
			if #candidateList > 0 then
				pickItem = candidateList[math.random(1, #candidateList)];
				break;
			end
			pickRank = rankInfoSet[pickRank].Next;
		end
		if pickItem ~= nil then
			break;
		end
	end
	
	if pickRank == 'Rare' then
		fixCount = fixCount + 1;
	else
		fixCount = 0;
	end
	return pickItem, fixCount;
end
local g_rareMaterialCandidateSet = nil;
function PickSupportItemRareMaterial(company, fixCountKey)
	local rankInfoSet = {
		Rare = { Prob = 70, Fix = -7 },
		Epic = { Prob = 20, Fix = 5, Next = 'Rare' },
		Legend = { Prob = 10, Fix = 2, Next = 'Epic' },
	};

	if g_rareMaterialCandidateSet == nil then
		local candidateSet = {};
		for rank, _ in pairs(rankInfoSet) do
			candidateSet[rank] = {};
		end
		for key, item in pairs(GetClassList('Item')) do
			if item.Category.name == 'Material' and rankInfoSet[item.Rank.name] then
				local candidateList = candidateSet[item.Rank.name];
				table.insert(candidateList, key);
			end
		end
		g_rareMaterialCandidateSet = candidateSet;
	end
	
	-- 현재 회사가 획득 가능한 아이템 셋
	local itemFilter = {};
	for _, recipe in pairs(company.Recipe) do
		if recipe.Opened then
			for _, material in ipairs(recipe.RequireMaterials) do
				itemFilter[material.Item] = true;
			end
		end
	end
	local monsterList = GetClassList('Monster');
	for _, tmInfo in pairs(company.Troublemaker) do
		if tmInfo.Exp > 0 then
			local monCls = monsterList[tmInfo.name];
			for _, reward in ipairs(monCls.Rewards) do
				itemFilter[reward.Item] = true;
			end
		end
	end
	
	local fixCount = GetWithoutError(company.ActivityReport.RewardCounter, fixCountKey) or 0;
	
	local rankPicker = RandomPicker.new();
	for rank, info in pairs(rankInfoSet) do
		local prob = math.max(info.Prob + fixCount * info.Fix, 0);
		rankPicker:addChoice(prob, rank);
	end
	local pickRank = rankPicker:pick();
	local pickItem = nil;
		
	while pickRank ~= nil do
		local candidateList = g_rareMaterialCandidateSet[pickRank];
		candidateList = table.filter(candidateList, function(itemName)
			return itemFilter[itemName];
		end);
		if #candidateList > 0 then
			pickItem = candidateList[math.random(1, #candidateList)];
			break;
		end
		pickRank = rankInfoSet[pickRank].Next;
	end
	
	if pickRank == 'Rare' then
		fixCount = fixCount + 1;
	else
		fixCount = 0;
	end
	return pickItem, fixCount;
end
local g_fieldControlCandidateSet = nil;
function PickFieldControlEquipment(company, missionName, roster)
	local rankInfoSet = {
		Rare = { Prob = 70 },
		Epic = { Prob = 20, Next = 'Rare' },
		Legend = { Prob = 10, Next = 'Epic' },
	};
	
	local categorySet = { Weapon = true, Armor = true, Accessory = true };

	if g_fieldControlCandidateSet == nil then
		local candidateSet = {};
		local pcList = GetClassList('Pc');
		for rank, _ in pairs(rankInfoSet) do
			candidateSet[rank] = {};
			for _, pcCls in pairs(pcList) do
				candidateSet[rank][pcCls.name] = {};
			end
		end
		local equipPosList = GetClassList('ItemEquipmentPosition');
		local itemList = GetClassList('Item');
		for _, pcCls in pairs(pcList) do
			-- 캐릭터가 착용 가능한 아이템 Type들을 뽑음
			local equipTypeSet = {};
			for equipPos, _ in pairs(equipPosList) do
				local equipTypeList = GetWithoutError(pcCls.Object, 'EnableEquip'..equipPos);
				if equipTypeList then
					for _, equipType in ipairs(equipTypeList) do
						equipTypeSet[equipType] = true;
					end
				end
			end
			for key, item in pairs(itemList) do
				if rankInfoSet[item.Rank.name] and equipTypeSet[item.Type.name] and categorySet[item.Category.name] then
					local candidateList = SafeIndex(candidateSet, item.Rank.name, pcCls.name);
					if candidateList ~= nil then
						table.insert(candidateList, key);
					end
				end
			end
		end
		g_fieldControlCandidateSet = candidateSet;
	end
		
	-- 현재 회사가 획득 가능한 아이템 셋
	local itemFilter = {};
	local missionMonSet = {};
	local missionCls = GetClassList('Mission')[missionName];
	for _, info in ipairs(missionCls.Enemies) do
		missionMonSet[info.Type] = true;
	end
	local monsterList = GetClassList('Monster');
	for _, tmInfo in pairs(company.Troublemaker) do
		if tmInfo.Exp > 0 and missionMonSet[tmInfo.name] then
			local monCls = monsterList[tmInfo.name];
			for _, reward in ipairs(monCls.Rewards) do
				itemFilter[reward.Item] = true;
			end
		end
	end
	
	if IsLobbyServer() then
		roster = GetAllRoster(company);
	end
	local maxRequireLv = 0;
	for _, pcInfo in ipairs(roster) do
		local requireLv = math.floor(pcInfo.Lv / 5) * 5;
		maxRequireLv = math.max(maxRequireLv, requireLv);
	end
	
	local pickRank = nil;
	local pickItem = nil;
	
	for fixRequireLv = 0, maxRequireLv, 5 do
		local rankPicker = RandomPicker.new();
		for rank, info in pairs(rankInfoSet) do
			rankPicker:addChoice(info.Prob, rank);
		end
		pickRank = rankPicker:pick();		
		while pickRank ~= nil do
			local candidateList = {};
			-- 로스터 멤버 당
			for _, pcInfo in ipairs(roster) do
				local candidateListByRoster = SafeIndex(g_fieldControlCandidateSet, pickRank, pcInfo.name);
				-- 회사가 획득 가능한 것만
				candidateListByRoster = table.filter(candidateListByRoster, function(itemName)
					return itemFilter[itemName];
				end);
				-- RequireLv이 맞는 것만
				local testRequireLv = math.floor(pcInfo.Lv / 5) * 5;
				testRequireLv = math.max(testRequireLv - fixRequireLv, 0);
				local itemList = GetClassList('Item');
				candidateListByRoster = table.filter(candidateListByRoster, function(itemName)
					local itemCls = itemList[itemName];
					return itemCls.RequireLv == testRequireLv;
				end);
				table.append(candidateList, candidateListByRoster);
			end
			if #candidateList > 0 then
				pickItem = candidateList[math.random(1, #candidateList)];
				break;
			end
			pickRank = rankInfoSet[pickRank].Next;
		end
		if pickItem ~= nil then
			break;
		end
	end
	
	return pickItem;
end
-- 로스타 타입 개수
function ProgressRosterTypeCount(ds, self, company, env, parsedScript)
	local roster = GetAllRoster(company, parsedScript.RosterType);
	return #roster;
end