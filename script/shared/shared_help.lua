function ParseContentText(helpCls, baseText, keywordTarget, keywordArgs, baseColor, warningColor, highlightColor, highlightColor2)
	local ft = {};
	local helpKeywords = GetClassList(keywordTarget);
	local mode = false;
	local mode2 = false;
	setmetatable(ft, {__index = function(t, k)
		if k == 'Note' then
			local t = baseColor;
			baseColor = highlightColor;
			highlightColor = t;
			return baseColor;
		elseif k == 'Warning' then
			highlightColor = baseColor;
			baseColor = warningColor;
			return baseColor;
		elseif k == '/' then
			mode = not mode;
			return mode == true and highlightColor or baseColor;
		elseif k == '//' then
			mode2 = not mode2;
			return mode2 == true and highlightColor2 or baseColor;
		end
		local selfRedirect = GetWithoutError(helpCls, k);
		if selfRedirect then
			if helpCls.NoHighlightSelfRedirect then
				return selfRedirect;
			else
				return highlightColor .. selfRedirect .. baseColor;
			end
		end
		local cls, args = string.match(k, '(%w+)%(([^)]+)%)');
		if cls == nil then
			cls = k;
		else
			args = args and string.split(args, ',') or {};
		end
		local keywordCls = GetWithoutError(helpKeywords, cls);
		if keywordCls then
			local fullArgs = table.append(table.deepcopy(keywordArgs), args);
			return keywordCls:Title(unpack(fullArgs)) .. (keywordCls.NoTailColor and '' or baseColor);
		end
	end});
	return KoreanPostpositionProcessCpp(FormatMessage(baseColor .. baseText, ft, nil, true, true));
end


function ParseContentText_Help(helpCls, baseText, isMission)
	local baseColor = isMission and helpCls.ContentBaseColor_Mission or helpCls.ContentBaseColor;
	local highlightColor = isMission and helpCls.HighlightColor_Mission or helpCls.HighlightColor;
	local highlightColor2 = GetWithoutError(helpCls, isMission and 'HighlightColor_Mission2' or 'HighlightColor2');
	return ParseContentText(helpCls, baseText, 'HelpKeyword', {isMission}, baseColor, "[colour='FFFF5943']", highlightColor, highlightColor2)
end

function CalculatedProperty_HelpContent(self, arg)
	local result = ParseContentText_Help(self, self.Base_Content, false);
	if self.AutoScript ~= 'None' then
		local scp = _G[self.AutoScript];
		local arg = GetWithoutError(self, 'AutoScriptArg');
		if scp then
			if self.Base_Content ~= '' then
				result = result..'\n\n'..scp(self, false, arg);
			else
				result = scp(self, false, arg);
			end
		end
	end
	
	if self.Content_End ~= '' then
		result = result..'\n\n'..ParseContentText_Help(self, self.Content_End, true);
	end
	
	if #self.AttachClass > 0 then
		local helpList = GetClassList('Help');
		for _, cls in ipairs(self.AttachClass) do
			local curCls = helpList[cls];
			result = result.."\n\n[font='NotoSansBlack-18_Auto]"..curCls.Title.."\n[font='NotoSansMedium-14_Auto]"..curCls.Content;
		end
	end
	return result;
end
function CalculatedProperty_HelpContentDirect(self, arg)
	local result = ParseContentText_Help(self, self.Base_Content, false);
	if self.AutoScript ~= 'None' then
		local scp = _G[self.AutoScript];
		local arg = GetWithoutError(self, 'AutoScriptArg');
		if scp then
			if self.Base_Content ~= '' then
				result = result..'\n\n'..scp(self, true, arg);
			else
				result = scp(self, true, arg);
			end
		end
	end
	
	if self.Content_End ~= '' then
		result = result..'\n\n'..ParseContentText_Help(self, self.Content_End, true);
	end
	
	return result;
end
function CalculatedProperty_HelpTitle(self, arg)
	local colorList = GetClassList('Color');
	local baseTitle = ParseContentText_Help(self, self.Base_Title, false);
	if self.SubCategory.name and self.SubCategory.name ~= 'None' and self.SubCategory.name ~= 'Alert' then		
		local forntTitle = string.format("[colour='%s']%s:[colour='FFFFFFFF']", colorList[self.SubCategory.TitleColor].ARGB, self.SubCategory.Title);
		return forntTitle..' '..baseTitle;
	end
	return baseTitle;
end
function CalculatedProperty_HelpTitleDirect(self, arg)
	local colorList = GetClassList('Color');
	local baseTitle = ParseContentText_Help(self, self.Base_Title, false);
	if self.SubCategory.name and self.SubCategory.name ~= 'None' then
		local forntTitle = string.format("[colour='%s']%s:[colour='FFFFFFFF']", colorList[self.SubCategory.TitleColor].ARGB, self.SubCategory.Title);
		return forntTitle..' '..baseTitle;
	end
	return baseTitle;
end
------------------------------------------------------------------------------
-- 버프 계열별 정보 불러오기
------------------------------------------------------------------------------
function GetBattleFormulaContent_BuffGroup(buffgroup, buffType)
	local result = '';
	local colorList = GetClassList('Color');
	local buffGroupList = GetClassList('BuffGroup');
	local curBuffGroup = SafeIndex(buffGroupList, buffgroup);
	if curBuffGroup then
		local curbuffList = {};
		local buffTypeList = GetClassList('BuffType');
		local buffList = GetClassList('Buff');
		for key, buff in pairs (buffList) do
			if buff.IsHelpShow and buff.Group == buffgroup then
				if not buffType or buffType == buff.Type then
					table.insert(curbuffList, buff);
				end
			end			
		end
		table.sort(curbuffList, function(a, b)
			return a.Title < b.Title;
		end);
		table.sort(curbuffList, function(a, b)
			return a.GroupPriority < b.GroupPriority;
		end);		
		local imageSize = 48 * ui_session.min_screen_variation; 
		for _, buff in ipairs(curbuffList) do
			if result == '' then
				result = string.format("[colour='%s'][image-size='w:%f h:%f'][image='%s'] %s", 
					colorList[buffTypeList[buff.Type].TitleColor].ARGB, imageSize, imageSize, buff.Image, buff.Title
				)..'\n'..buff.Desc;
			else
				result = result..'\n\n'..string.format("[colour='%s'][image-size='w:%f h:%f'][image='%s'] %s", 
					colorList[buffTypeList[buff.Type].TitleColor].ARGB, imageSize, imageSize, buff.Image, buff.Title
				)..'\n'..buff.Desc;
			end
		end
	else
		result = 'Error Data';
	end
	return result;
end
------------------------------------------------------------------------------
-- 버프 with 툴팁 텍스트 불러오기
------------------------------------------------------------------------------
function GetBattleFormulaContent_BuffNameWithTooltip(buffName, isDesc)
	local result = '';
	local colorList = GetClassList('Color');
	local buffList = GetClassList('Buff');
	local buffTypeList = GetClassList('BuffType');
	local buff = SafeIndex(buffList, buffName);
	local imageSizeDefault = 48;
	if not isDesc then
		imageSizeDefault = 32;
	end
	if buff then		
		local imageSize = imageSizeDefault * ui_session.min_screen_variation;
		local buffColor = colorList[buffTypeList[buff.Type].TitleColor].ARGB;
		result = string.format("[colour='%s'][image-size='w:%f h:%f'][image='%s'] [tooltip type='buff' key='%s' color='%s']%s [tooltip-end]", 
			buffColor, imageSize, imageSize, buff.Image, buff.name, buffColor, buff.Title
		);
		
		if isDesc then
			result = result..'\n'..buff.Desc;
		end
	else
		result = 'Error Data';
	end
	return result;
end
------------------------------------------------------------------------------
-- 버프 텍스트 불러오기
------------------------------------------------------------------------------
function GetBattleFormulaContent_BuffName(buffName, isDesc)
	local result = '';
	local colorList = GetClassList('Color');
	local buffList = GetClassList('Buff');
	local buffTypeList = GetClassList('BuffType');
	local buff = SafeIndex(buffList, buffName);
	local imageSizeDefault = 40;
	if not isDesc then
		imageSizeDefault = 32;
	end
	if buff then		
		local imageSize = imageSizeDefault * ui_session.min_screen_variation;
		local buffColor = colorList[buffTypeList[buff.Type].TitleColor].ARGB;
		result = string.format("[colour='%s'][image-size='w:%f h:%f'][image='%s'] %s", 
			buffColor, imageSize, imageSize, buff.Image, buff.Title
		);
		
		if isDesc then
			result = result..'\n'..buff.Desc;
		end
	else
		result = 'Error Data';
	end
	return result;
end
------------------------------------------------------------------------------
-- 개별 버프 그룹 함수.
------------------------------------------------------------------------------
function GetBattleFormulaContent_BuffGroupRage(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Rage', 'Buff');
end
function GetBattleFormulaContent_BuffGroupBleeding(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Bleeding');
end
function GetBattleFormulaContent_BuffGroupBruise(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Bruise');
end
function GetBattleFormulaContent_BuffGroupDisease(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Disease');
end
function GetBattleFormulaContent_BuffGroupSilence(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Silence');
end
function GetBattleFormulaContent_BuffGroupFaint(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Faint');
end
function GetBattleFormulaContent_BuffGroupPoison(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Poison');
end
function GetBattleFormulaContent_BuffGroupLight(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Light');
end
function GetBattleFormulaContent_BuffGroupLuck(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Luck');
end
function GetBattleFormulaContent_BuffGroupPanic(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Panic');
end
function GetBattleFormulaContent_BuffGroupHappiness(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Happiness');
end
function GetBattleFormulaContent_BuffGroupConcentration(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Concentration', 'Buff');
end
function GetBattleFormulaContent_BuffGroupInfo(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Info', 'Buff');
end
function GetBattleFormulaContent_BuffGroupHoly(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Holy');
end
function GetBattleFormulaContent_BuffGroupSmell(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Smell', 'Buff');
end
function GetBattleFormulaContent_BuffGroupSleep(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Sleep');
end
function GetBattleFormulaContent_BuffGroupNoise(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Noise');
end
function GetBattleFormulaContent_BuffGroupFire(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Fire', 'Buff');
end
function GetBattleFormulaContent_BuffGroupIce(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Ice', 'Buff');
end
function GetBattleFormulaContent_BuffGroupWind(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Wind', 'Buff');
end
function GetBattleFormulaContent_BuffGroupLightning(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Lightning', 'Buff');
end
function GetBattleFormulaContent_BuffGroupEarth(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Earth', 'Buff');
end
function GetBattleFormulaContent_BuffGroupWater(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Water', 'Buff');
end
function GetBattleFormulaContent_BuffGroupRage2(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Rage', 'Debuff');
end
function GetBattleFormulaContent_BuffGroupConcentration2(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Concentration', 'Debuff');
end
function GetBattleFormulaContent_BuffGroupInfo2(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Info', 'Debuff');
end
function GetBattleFormulaContent_BuffGroupSmell2(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Smell', 'Debuff');
end
function GetBattleFormulaContent_BuffGroupEquipment2(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Equipment', 'Debuff');
end
function GetBattleFormulaContent_BuffGroupFire2(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Fire', 'Debuff');
end
function GetBattleFormulaContent_BuffGroupIce2(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Ice', 'Debuff');
end
function GetBattleFormulaContent_BuffGroupWind2(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Wind', 'Debuff');
end
function GetBattleFormulaContent_BuffGroupLightning2(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Lightning', 'Debuff');
end
function GetBattleFormulaContent_BuffGroupEarth2(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Earth', 'Debuff');
end
function GetBattleFormulaContent_BuffGroupWater2(self, isDirect)
	return GetBattleFormulaContent_BuffGroup('Water', 'Debuff');
end
------------------------------------------------------------------------------
-- 반응 공격/ 반격 공격 자동 완성화 툴팁.
------------------------------------------------------------------------------
function GetBattleFormulaContentByAttribute(isDirect, key)
	local result = '';
	if not isDirect then
		local colorList = GetClassList('Color');
		local buffList = GetClassList('Buff');
		local abilityList = GetClassList('Ability');
		local masteryList = GetClassList('Mastery');
		local buffTypeList = GetClassList('BuffType');
		local abilityTypeList = GetClassList('AbilityType');
		
		local imageSize = 32 * ui_session.min_screen_variation; 
		
		-- 1) 버프
		local buffTable = {};
		for _, ability in pairs (buffList) do
			table.insert(buffTable, ability);
		end
		table.sort(buffTable, function (a,b)
			return a.Title < b.Title
		end);
		local attributeOnBufftext = '';
		for _, buff in pairs (buffTable) do			
			if buff[key] then
				LogAndPrint('buff[key]', buff.Title, buff[key]);
				local curTempText =	string.format("[colour='FFFFFFFF'][image-size='w:%f h:%f'][image='%s']  [tooltip type='buff' key='%s' color='FFFFFFFF']%s[tooltip-end]", 
					imageSize, imageSize, buff.Image, buff.name, buff.Title
				);
				attributeOnBufftext = ConnentTextToText(attributeOnBufftext, '\n\n', curTempText);
			end
		end
		if attributeOnBufftext ~= '' then
			local curAttributeOnBufftext = "[colour='FFFFFF00'][font='NotoSansMedium-14_Auto']"..GetWord('Status').."\n\n[font='NotoSansMedium-12_Auto'][colour='FFFFFFFF']"..attributeOnBufftext;
			result = ConnentTextToText(result, '\n', curAttributeOnBufftext);
			result = result..'\n';
		end
		-- 어빌리티
		local abilityTable = {};
		for _, ability in pairs (abilityList) do
			table.insert(abilityTable, ability);
		end
		table.sort(abilityTable, function (a,b)
			return a.Title < b.Title
		end);		
		local attributeOnAbilitytext = '';
		for _, ability in pairs (abilityTable) do
			if ability[key] then
				LogAndPrint('ability[key]', ability.Title, ability[key]);
				local curTempAbilityText =	string.format("[colour='FFFFFFFF'][image-size='w:%f h:%f'][image='%s']  [tooltip type='ability' key='%s' color='FFFFFFFF']%s[tooltip-end]", 
					imageSize, imageSize, ability.Image, ability.name, ability.Title
				);
				attributeOnAbilitytext = ConnentTextToText(attributeOnAbilitytext, '\n\n', curTempAbilityText);
			end
		end
		if attributeOnAbilitytext ~= '' then
			local curAttributeOnAbilitytext = "[colour='FFFFFF00'][font='NotoSansMedium-14_Auto']"..GetWord('Ability').."\n\n[font='NotoSansMedium-12_Auto'][colour='FFFFFFFF']"..attributeOnAbilitytext;
			result = ConnentTextToText(result, '\n', curAttributeOnAbilitytext);
			result = result..'\n';
		end
		-- 특성
		local masteryTable = {};
		for _, mastery in pairs (masteryList) do
			table.insert(masteryTable, mastery);
		end
		table.sort(masteryTable, function (a,b)
			local aOrder = a.Type.Order or -1;
			local bOrder = b.Type.Order or -1;
			if aOrder ~= bOrder then
				return aOrder < bOrder;
			else
				return a.Title < b.Title;
			end
		end);
		
		local attributeOnMasterytext = '';
		for _, mastery in pairs (masteryTable) do
			if mastery[key] then
				LogAndPrint('mastery[key]', mastery.Title, mastery[key]);
				local curTempMasteryText =	string.format("[colour='FFFFFFFF'][image-size='w:%f h:%f'][image='%s']  [tooltip type='mastery' key='%s' color='FFFFFFFF']%s[tooltip-end]", 
					imageSize, imageSize, mastery.Type.Image, mastery.name, mastery.Title
				);
				attributeOnMasterytext =  ConnentTextToText(attributeOnMasterytext, '\n\n', curTempMasteryText);
			end
		end
		if attributeOnMasterytext ~= '' then
			local curAttributeOnMasterytext = "[colour='FFFFFF00'][font='NotoSansMedium-14_Auto']"..GetWord('Mastery').."\n\n[font='NotoSansMedium-12_Auto'][colour='FFFFFFC8']"..attributeOnMasterytext;
			result = ConnentTextToText(result, '\n', curAttributeOnMasterytext);
			result = result..'\n';
		end
	end
	return result;
end
function GetBattleFormulaContent_CounterAttack(self, isDirect)
	return GetBattleFormulaContentByAttribute(isDirect, 'CounterAttack');
end
function GetBattleFormulaContent_ReactionAttack(self, isDirect)
	return GetBattleFormulaContentByAttribute(isDirect, 'ReactionAttack');
end
----------------------------------------------------
-- 지형 효과
----------------------------------------------------
function GetBattleFormulaContent_FieldEffect(isDirect, fieldEffect)
	local result = '';
	local fieldEffectList = GetClassList('FieldEffect');
	local buffList = GetClassList('Buff');
	local tileList = GetClassList('Tile');
	local weatherList = GetClassList('MissionWeather');
	
	local curFieldEffect = fieldEffectList[fieldEffect];
	local curFieldEffectTitleText = "[colour='FFFFFF00']"..curFieldEffect.Title.."[colour='FFFFFFFF']";
	
	-- 1.1. 기본 설명하기.
	for _, aff in ipairs (curFieldEffect.BuffAffector) do
		local curBuffText = GetBattleFormulaContent_BuffNameWithTooltip(aff.ApplyBuff.name, false).."[colour='FFFFFFFF']";
		local curFieldEffectText = FormatMessage(GuideMessage('FieldEffect_BuffAffector_ApplyType_'..aff.ApplyType), 
			{FieldEffect = curFieldEffectTitleText, ApplyBuff = curBuffText}
		);
		if result == '' then
			result = curFieldEffectText
		else
			result = result..'\n'..curFieldEffectText;
		end
	end

	-- 2. 필드 이펙트 조건
	-- 2.1. 턴 대기시간
	if curFieldEffect.Base_Turn < 99999 then
		local curFieldEffectTurnWaitText = FormatMessage(GuideMessage('FieldEffect_BaseTurn_Normal'), 
			{ FieldEffect = curFieldEffectTitleText, Turn = "[colour='FFFFFF00']"..curFieldEffect.Base_Turn.."[colour='FFFFFFFF']", Wait = "[colour='FFFFFF00']"..curFieldEffect.Wait.."[colour='FFFFFFFF']"}
		);
		result = result.."\n[colour='FFFFFFFF']"..curFieldEffectTurnWaitText;
	end

	-- 2.3.1 주위 번지는 효과..
	local isInfectByTile = not table.empty(curFieldEffect.InfectRateByTile);
	local isInfectByWeather = not table.empty(curFieldEffect.InfectRateByWeather);
	local isAddTurnByTile = not table.empty(curFieldEffect.AddTurnByTile);
	local isAddTurnByWeather = not table.empty(curFieldEffect.AddTurnByWeather);
	local isDisableFieldEffect = not table.empty(curFieldEffect.DisableFieldEffect);
	
	if isInfectByTile or isInfectByWeather or isAddTurnByTile or isAddTurnByWeather then
		
		local guidekey = '';
		if isInfectByTile and isInfectByWeather and isAddTurnByTile and isAddTurnByWeather then
			guidekey = 'FieldEffect_FieldEffectTimeElapsed';
		elseif isAddTurnByTile and isAddTurnByWeather then
			guidekey = 'FieldEffect_FieldEffectTimeElapsed2';
		end
		
		local curFieldEffectTimeElapsedText = FormatMessage(GuideMessage(guidekey), 
			{ FieldEffect = curFieldEffectTitleText }
		);
		result = result.."\n[colour='FFFFFFFF']"..curFieldEffectTimeElapsedText;
		
		local headIndex = 1;
		-------------------------------------------------------
		-- 2.3.1.1. 지형에 따른 번짐
		-------------------------------------------------------		
		local temp = {};
		if isInfectByTile or isAddTurnByTile then
			local affectTileList = {};
			local fieldEffect_Affect_Tile_Title = string.format("[colour='FFFFFF00']%d. %s", headIndex, GetWord('FieldEffect_Affect_Tile'));
			headIndex = headIndex + 1;
			local content_fieldEffect_Affect_Tile = '';
			-- 번짐 확률 값 넣기.
			for key, ratio in pairs (curFieldEffect.InfectRateByTile) do
				temp[key] = { Ratio = ratio, Turn = 0 };
			end
			-- 턴 증가 넣기.
			for key, turn in pairs (curFieldEffect.AddTurnByTile) do
				if temp[key] then
					temp[key].Turn = turn;
				else
					temp[key] = { Ratio = 0, Turn = turn };
				end
			end
			-- 재배열
			for key, value in pairs (temp) do
				table.insert(affectTileList, { Tile = key, Ratio = value.Ratio, Turn = value.Turn } )
			end
			table.sort(affectTileList, function(a, b)
				if a.Ratio == b.Ratio then
					return a.Turn > b.Turn;
				end
				return a.Ratio > b.Ratio;
			end);
			
			for index, value in pairs (affectTileList) do
				local affectTileTitleText = string.format("[colour='FFF3B0A8']%s. %s[colour='FFFFFFFF']", string.char(96 + index), tileList[value.Tile].Title);
				local affectTileContentText = '';
				local affectTileTextKey = '';
				local affectTileFormatTable = {
					FieldEffect = curFieldEffectTitleText,
					Ratio = "[colour='FFFFFF00']"..math.abs(value.Ratio).."%[colour='FFFFFFFF']", 
					Turn = "[colour='FFFFFF00']"..math.abs(value.Turn).."[colour='FFFFFFFF']" 
				};
				if value.Turn > 0 and value.Ratio > 0 then
					affectTileTextKey = 'FieldEffect_FieldEffectTimeElapsed_Bonus_TurnAndRatio';
				elseif value.Turn < 0 and value.Ratio < 0 then
					affectTileTextKey = 'FieldEffect_FieldEffectTimeElapsed_Bonus_TurnAndRatio2';
				elseif value.Turn > 0 then
					affectTileTextKey = 'FieldEffect_FieldEffectTimeElapsed_Bonus_Turn';
				elseif value.Ratio > 0 then
					affectTileTextKey = 'FieldEffect_FieldEffectTimeElapsed_Bonus_Ratio';
				elseif value.Turn < 0 then
					affectTileTextKey = 'FieldEffect_FieldEffectTimeElapsed_Bonus_Turn2';
				elseif value.Ratio < 0 then
					affectTileTextKey = 'FieldEffect_FieldEffectTimeElapsed_Bonus_Ratio2';
				end	
				affectTileContentText = FormatMessage(GuideMessage(affectTileTextKey), affectTileFormatTable);			
				
				local concatenateTileText = affectTileTitleText..'\n'..affectTileContentText;
				if index == 1 then
					content_fieldEffect_Affect_Tile = concatenateTileText;
				else
					content_fieldEffect_Affect_Tile = content_fieldEffect_Affect_Tile..'\n'..concatenateTileText;
				end
			end
			result = result..'\n\n'..fieldEffect_Affect_Tile_Title;
			if content_fieldEffect_Affect_Tile ~= '' then
				result = result..'\n\n'..content_fieldEffect_Affect_Tile;
			end
		end
		-------------------------------------------------------
		-- 2.3.1.2. 날씨에 따른 번짐
		-------------------------------------------------------
		
		if isInfectByWeather or isAddTurnByWeather then
			temp = {};
			local affectWeatherList = {};
			local fieldEffect_Affect_Weather_Title = string.format("[colour='FFFFFF00']%d. %s", headIndex, GetWord('FieldEffect_Affect_Weather'));
			headIndex = headIndex + 1;
			local content_fieldEffect_Affect_Weather = '';
			-- 번짐 확률 값 넣기.
			for key, ratio in pairs (curFieldEffect.InfectRateByWeather) do
				temp[key] = { Ratio = ratio, Turn = 0 };
			end
			-- 턴 증가 넣기.
			for key, turn in pairs (curFieldEffect.AddTurnByWeather) do
				if temp[key] then
					temp[key].Turn = turn;
				else
					temp[key] = { Ratio = 0, Turn = turn };
				end
			end
			-- 재배열
			for key, value in pairs (temp) do
				table.insert(affectWeatherList, { Weather = key, Ratio = value.Ratio, Turn = value.Turn } )
			end
			table.sort(affectWeatherList, function(a, b)
				if a.Ratio == b.Ratio then
					return a.Turn > b.Turn;
				end
				return a.Ratio > b.Ratio;
			end);
		
			for index2, value in pairs (affectWeatherList) do
				local affectWeatherTitleText = string.format("[colour='FFF3B0A8']%s. %s[colour='FFFFFFFF']", string.char(96 + index2), weatherList[value.Weather].Title);
				local affectWeatherContentText = '';
				local affectWeatherTextKey = '';
				local affectWeatherFormatTable = {
					FieldEffect = curFieldEffectTitleText,
					Ratio = "[colour='FFFFFF00']"..math.abs(value.Ratio).."%[colour='FFFFFFFF']", 
					Turn = "[colour='FFFFFF00']"..math.abs(value.Turn).."[colour='FFFFFFFF']" 
				};
				if value.Turn > 0 and value.Ratio > 0 then
					affectWeatherTextKey = 'FieldEffect_FieldEffectTimeElapsed_Bonus_TurnAndRatio';
				elseif value.Turn < 0 and value.Ratio < 0 then
					affectWeatherTextKey = 'FieldEffect_FieldEffectTimeElapsed_Bonus_TurnAndRatio2';
				elseif value.Turn > 0 then
					affectWeatherTextKey = 'FieldEffect_FieldEffectTimeElapsed_Bonus_Turn';
				elseif value.Ratio > 0 then
					affectWeatherTextKey = 'FieldEffect_FieldEffectTimeElapsed_Bonus_Ratio';
				elseif value.Turn < 0 then
					affectWeatherTextKey = 'FieldEffect_FieldEffectTimeElapsed_Bonus_Turn2';
				elseif value.Ratio < 0 then
					affectWeatherTextKey = 'FieldEffect_FieldEffectTimeElapsed_Bonus_Ratio2';
				end			
				affectWeatherContentText = FormatMessage(GuideMessage(affectWeatherTextKey), affectWeatherFormatTable);			
				
				local concatenateWeatherText = affectWeatherTitleText..'\n'..affectWeatherContentText;
				if index == 1 then
					content_fieldEffect_Affect_Weather = concatenateWeatherText;
				else
					content_fieldEffect_Affect_Weather = content_fieldEffect_Affect_Weather..'\n'..concatenateWeatherText;
				end
			end
			result = result..'\n\n'..fieldEffect_Affect_Weather_Title;
			if content_fieldEffect_Affect_Weather ~= '' then
				result = result..'\n'..content_fieldEffect_Affect_Weather;
			end
		end
		
		-- 2.3.1.3. 발생 불가 지형.
		if isDisableFieldEffect then
			local fieldEffect_Affect_Land_Title = string.format("[colour='FFFFFF00']%d. %s", headIndex, GetWord('FieldEffect_Affect_Land'));
			local fieldEffect_Affect_Land_Content = '';
			for key, value in pairs (curFieldEffect.DisableFieldEffect) do
				local curTileText = tileList[key].Title;
				if fieldEffect_Affect_Land_Content == '' then
					fieldEffect_Affect_Land_Content = curTileText;
				else
					fieldEffect_Affect_Land_Content = fieldEffect_Affect_Land_Content..', '..curTileText;
				end
			end		
			result = result..'\n\n'..fieldEffect_Affect_Land_Title;
			result = result.."\n\n[colour='FFF3B0A8']"..fieldEffect_Affect_Land_Content;
		end
	end
	
	-- 3. 지형 효과 없애는 효과
	if curFieldEffect.RemoveFieldEffect ~= 'None' then
		local removeFieldEffectFormatTable = {
			FieldEffect = curFieldEffectTitleText,
			RemoveFieldEffect = "[colour='FFFFFF00']"..fieldEffectList[curFieldEffect.RemoveFieldEffect].Title.."[colour='FFFFFFFF']"
		};
		local removeFieldEffectText =  FormatMessage(GuideMessage('FieldEffect_RemoveFieldEffect'), removeFieldEffectFormatTable);
		result = result.."\n\n[colour='FFFFFFFF']"..removeFieldEffectText;
	end
	
	result = KoreanPostpositionProcessCpp(result);
	return result;
end
function GetBattleFormulaContent_FieldEffect_Short(isDirect, fieldEffect)
	local result = '';
	local fieldEffectList = GetClassList('FieldEffect');
	local buffList = GetClassList('Buff');
	local tileList = GetClassList('Tile');
	local weatherList = GetClassList('MissionWeather');
	
	local curFieldEffect = fieldEffectList[fieldEffect];
	local curFieldEffectTitleText = "[colour='FFFFFF00']"..curFieldEffect.Title.."[colour='FFFFFFFF']";
	
	-- 1.1. 기본 설명하기.
	for _, aff in ipairs (curFieldEffect.BuffAffector) do
		local curFieldEffectImage = GetBattleFormulaContent_BuffName(aff.ApplyBuff.name, false);
		local curFieldEffectText = FormatMessage(GuideMessage('FieldEffect_InfinityTile'), 
			{FieldEffectImage = curFieldEffectImage}
		);
		if result == '' then
			result = curFieldEffectText
		else
			result = result..'\n'..curFieldEffectText;
		end
		result = result..'\n\n'..GetBattleFormulaContent_BuffName(aff.ApplyBuff.name, true);
	end	
	
	result = KoreanPostpositionProcessCpp(result);
	return result;
end
function GetBattleFormulaContent_FieldEffect_Fire(self, isDirect)
	return GetBattleFormulaContent_FieldEffect(isDirect, 'Fire');
end
function GetBattleFormulaContent_FieldEffect_Spark(self, isDirect)
	return GetBattleFormulaContent_FieldEffect(isDirect, 'Spark');
end
function GetBattleFormulaContent_FieldEffect_Bush(self, isDirect)
	return GetBattleFormulaContent_FieldEffect_Short(isDirect, 'Bush');
end
function GetBattleFormulaContent_FieldEffect_Swamp(self, isDirect)
	return GetBattleFormulaContent_FieldEffect_Short(isDirect, 'Swamp');
end
function GetBattleFormulaContent_FieldEffect_Ice(self, isDirect)
	return GetBattleFormulaContent_FieldEffect_Short(isDirect, 'Ice');
end
function GetBattleFormulaContent_FieldEffect_Water(self, isDirect)
	return GetBattleFormulaContent_FieldEffect_Short(isDirect, 'Water');
end
function GetBattleFormulaContent_FieldEffect_ContaminatedWater(self, isDirect)
	return GetBattleFormulaContent_FieldEffect_Short(isDirect, 'ContaminatedWater');
end
function GetBattleFormulaContent_FieldEffect_Lava(self, isDirect)
	return GetBattleFormulaContent_FieldEffect_Short(isDirect, 'Lava');
end
function GetBattleFormulaContent_FieldEffect_PoisonGas(self, isDirect)
	return GetBattleFormulaContent_FieldEffect(isDirect, 'PoisonGas');
end
function GetBattleFormulaContent_FieldEffect_AcidGas(self, isDirect)
	return GetBattleFormulaContent_FieldEffect(isDirect, 'AcidGas');
end
function GetBattleFormulaContent_FieldEffect_PlagueMist(self, isDirect)
	return GetBattleFormulaContent_FieldEffect(isDirect, 'PlagueMist');
end
function GetBattleFormulaContent_FieldEffect_IceMist(self, isDirect)
	return GetBattleFormulaContent_FieldEffect(isDirect, 'IceMist');
end
function GetBattleFormulaContent_FieldEffect_HealMist(self, isDirect)
	return GetBattleFormulaContent_FieldEffect(isDirect, 'HealMist');
end
function GetBattleFormulaContent_FieldEffect_SmokeScreen(self, isDirect)
	return GetBattleFormulaContent_FieldEffect(isDirect, 'SmokeScreen');
end
function GetBattleFormulaContent_FieldEffect_Blackout(self, isDirect)
	return GetBattleFormulaContent_FieldEffect(isDirect, 'Blackout');
end
function GetBattleFormulaContent_FieldEffect_Web(self, isDirect)
	return GetBattleFormulaContent_FieldEffect(isDirect, 'Web');
end
----------------------------------------------------
--  Subtext 조건 자동 완성 도움말
----------------------------------------------------
function GetHelpContent_SubText(self, isDirect)
	local colorList = GetClassList('Color');
	local result = '';
	local numbering = 1;
	for index, cls in ipairs(self.SubText) do
	
		local titleExpressionType = GetWithoutError(cls, 'Type');
		local curTitleColor = GetWithoutError(cls, 'TitleColor');
		local isTitleLineBreak = StringToBool(GetWithoutError(cls, 'TitleLineBreak'), false);
		local isLineBreak = StringToBool(GetWithoutError(cls, 'LineBreak'), false);
		local titleLineBreak = isTitleLineBreak and '\n' or ( cls.Text == '' and '' or ': ');
		local titleColor = curTitleColor and colorList[curTitleColor].ARGB or colorList['White'].ARGB;
		local titleExpression = '';
			
		-- 넘버링
		local numberingAdditionalLineBreak = '';
		if titleExpressionType == 'Numbering' then
			titleExpression = numbering..'. ';
			numbering = numbering + 1;
			numberingAdditionalLineBreak = "\n[font='NotoSansMedium-4']\n[font='NotoSansMedium-14_Auto']";
		elseif titleExpressionType == 'AlphabetNumbering' then
			titleExpression = string.char(64 + numbering)..'. ';
			numbering = numbering + 1;
			numberingAdditionalLineBreak = "\n[font='NotoSansMedium-4']\n[font='NotoSansMedium-14_Auto']";
		else
			numberingAdditionalLineBreak = "\n"
		end
		
		local sentenceLineBreak = isLineBreak and '\n\n' or numberingAdditionalLineBreak;
		
		local curTitle = titleExpression..cls.Title;
		curTitle = ParseContentText(self, curTitle, 'HelpKeyword', {false}, string.format("[colour='%s']", titleColor), "[colour='FFFF5943']", "[colour='FFFFFFFF']", "[colour='FFFFFFFF']");
		local curContent = ParseContentText(self, cls.Text, 'HelpKeyword', {false}, "[colour='FFFFFFFF']", "[colour='FFFF5943']", "[colour='FFFFFFFF']", "[colour='FFFFFFFF']");
		
		local curSentence = curTitle..titleLineBreak..curContent;
		if index == 1 then
			result = curSentence..sentenceLineBreak;			
		else
			result = result..curSentence..sentenceLineBreak;		
		end
	end
	return result;
end
----------------------------------------------------
--  연쇄효과 조건 자동 완성 도움말
----------------------------------------------------
function GetHelpContent_ChainEffect(self, isDirect)
	local result = '';
	local chainEventList = GetClassList('ChainEvent');
	local curChainEvent = chainEventList[self.name];	
	if curChainEvent.ApplyBuff.name then
		local chainApplyBuffText = '';
		chainApplyBuffText =  FormatMessage(GuideMessage('ChainEvent_ApplyBuff'),
			{ 
				ChainEvent = "[colour='FFFFFF00']"..curChainEvent.Title, 
				ApplyBuff = GetBattleFormulaContent_BuffName(curChainEvent.ApplyBuff.name, false).."[colour='FFFFFF00']"
			}
		);
		result = chainApplyBuffText;
		result = result..'\n\n'..GetBattleFormulaContent_BuffName(curChainEvent.ApplyBuff.name, true);
	end
	result = KoreanPostpositionProcessCpp(result);
	return result;
end
----------------------------------------------------
--  자원 게이지 추가.
----------------------------------------------------
function GetHelpContent_Resource(isDirect, resource)
	local result = '';
	local costTypeList = GetClassList('CostType');
	local colorList = GetClassList('Color');
	local curCostType = costTypeList[resource];
	local title = string.format("[colour='%s']%s[colour='FFFFFFFF']", colorList['Yellow'].ARGB, curCostType.Title);
	result = FormatMessage(curCostType.Desc_Format, { Cost = title });
	return result;
end
function GetHelpContent_Resource_Vigor(self, isDirect)
	return GetHelpContent_Resource(isDirect, 'Vigor');
end
function GetHelpContent_Resource_Rage(self, isDirect)
	return GetHelpContent_Resource(isDirect, 'Rage');
end
function GetHelpContent_Resource_Fuel(self, isDirect)
	return GetHelpContent_Resource(isDirect, 'Fuel');
end
----------------------------------------------------
--  특성 추가.
----------------------------------------------------
function GetHelpContent_MasteryAdd(isDirect, masteryName)
	local result = '';
	local masteryList = GetClassList('Mastery');
	local colorList = GetClassList('Color');
	local curMastery = masteryList[masteryName];
	local title = string.format("[colour='%s']%s[colour='FFFFFFFF']", colorList[curMastery.Category.Color].ARGB, curMastery.Title);
	result = title..'\n'..curMastery.Desc;
	return result;
end
function GetHelpContent_MasteryAdd_Berserker(self, isDirect)
	return GetHelpContent_MasteryAdd(isDirect, 'Berserker');
end
----------------------------------------------------
--  버프 추가.
----------------------------------------------------
function GetHelpContent_BuffAdd(isDirect, buffName)
	local result = '';
	result = GetBattleFormulaContent_BuffName(buffName, true);
	return result;
end
function GetHelpContent_BuffAdd_FireShield(self, isDirect)
	return GetHelpContent_BuffAdd(isDirect, 'FireShield');
end
function GetHelpContent_BuffAdd_SmokeScreen(self, isDirect)
	return GetHelpContent_BuffAdd(isDirect, 'SmokeScreen');
end
function GetHelpContent_BuffAdd_Stealth(self, isDirect)
	return GetHelpContent_BuffAdd(isDirect, 'Stealth');
end
function GetHelpContent_BuffAdd_Blackout(self, isDirect)
	return GetHelpContent_BuffAdd(isDirect, 'Blackout');
end
function GetHelpContent_BuffAdd_Vitality(self, isDirect)
	return GetHelpContent_BuffAdd(isDirect, 'Vitality');
end
function GetHelpContent_BuffAdd_Fatigue(self, isDirect)
	return GetHelpContent_BuffAdd(isDirect, 'Fatigue');
end
function GetHelpContent_BuffAdd_Civil_Confusion(self, isDirect)
	return GetHelpContent_BuffAdd(isDirect, 'Civil_Confusion');
end
function GetHelpContent_BuffAdd_InjuredRescue(self, isDirect)
	return GetHelpContent_BuffAdd(isDirect, 'InjuredRescue');
end
function GetHelpContent_BuffAdd_Civil_Stabilized(self, isDirect)
	return GetHelpContent_BuffAdd(isDirect, 'Civil_Stabilized');
end
function GetHelpContent_BuffAdd_Civil_Child_Rescue(self, isDirect)
	return GetHelpContent_BuffAdd(isDirect, 'Civil_Child_Rescue');
end
function GetHelpContent_BuffAdd_Civil_Unrest(self, isDirect)
	return GetHelpContent_BuffAdd(isDirect, 'Civil_Unrest');
end
-----------------------------------------------------------------------------------
-- 적 경계 상태 자동 완성.
-----------------------------------------------------------------------------------
function GetHelpContent_EnemyState(self, isDirect, alertType)
	local result = '';
	local buffList = GetClassList('Buff');

	local grade = {
		Stand = 1, Patrol = 2, Detecting = 3
	};
	local curAlertName = {
		Stand = "[colour='FFFFFF00']"..buffList['Stand'].Title.."[colour='FFFFFFFF']",
		Patrol = "[colour='FFFF5943']"..buffList['Patrol'].Title.."[colour='FFFFFFFF']",
		Detecting = "[colour='FFDB00D3']"..buffList['Detecting'].Title.."[colour='FFFFFFFF']"
	}
	local curGrade = grade[alertType];
	-- 1. 기본 설명하기.
	local frontMessage = FormatMessage("[colour='FFFFE959']"..GuideMessage('EnemyAlertState_GradeDesc'), 
		{	Grade = "[colour='FFFFFFFF']"..curGrade.."[colour='FFFFE959']" }
	);

	local imageSize = 24 * ui_session.min_screen_variation; 
	local hilightMessage = FormatMessage("[colour='FFFFFFFF']"..GuideMessage('EnemyAlertState_Highlight'), 
		{	
			AlertState = curAlertName[alertType],
			AlertStateImage = string.format("[image-size='w:%f h:%f'][image='TaharezLook/SightAlert%d']", imageSize, imageSize, curGrade)
		}
	);
	-- 2. 전투 돌입 메시지
	local battleStartText = '';
	if curGrade < 3 then
		battleStartText = "[colour='FFFFFFFF']"..	GuideMessage('EnemyAlertState_EnemyDetect');
	else
		battleStartText = "[colour='FFFFFFFF']"..	GuideMessage('EnemyAlertState_EnemyDetect2');
	end
	
	-- 3. 하이라이트
	local imageSize = 24 * ui_session.min_screen_variation; 
	local hilightMessage = FormatMessage("[colour='FFFFFFFF']"..GuideMessage('EnemyAlertState_Highlight'), 
		{	
			AlertState = curAlertName[alertType],
			AlertStateImage = string.format("[image-size='w:%f h:%f'][image='TaharezLook/SightAlert%d']", imageSize, imageSize, curGrade)
		}
	);
	result = frontMessage..'\n'..battleStartText..'\n\n'..hilightMessage..'\n\n'..GetBattleFormulaContent_BuffName(alertType, true);
	
	if isDirect then
		result = result..'\n\n'..ParseContentText_Help(self, self.Content_Mission, true);
	end
	
	return result;
end
function GetHelpContent_EnemyState_Stand(self, isDirect)
	return GetHelpContent_EnemyState(self, isDirect, 'Stand');
end
function GetHelpContent_EnemyState_Patrol(self, isDirect)
	return GetHelpContent_EnemyState(self, isDirect, 'Patrol');
end
function GetHelpContent_EnemyState_Detecting(self, isDirect)
	return GetHelpContent_EnemyState(self, isDirect, 'Detecting');
end
-----------------------------------------------------------------------------------
-- 온도 설명
-----------------------------------------------------------------------------------
function GetHelpContent_Temperature(isDirect, missionTemperature)
	local result = '';
	local missionTemperatureList = GetClassList('MissionTemperature');
	local list = {};
	for key, cls in pairs (missionTemperatureList) do
		table.insert(list, cls);
	end
	table.sort(list, function(a, b)
		return a.Order < b.Order;
	end);
	local imageSize =  48 * ui_session.min_screen_variation;
	for index, cls2 in ipairs (list) do
		local title = string.format("[vert-alignment='centre'][colour='FFFFFFFF'][image-size='w:%f h:%f'][image='%s'] %s [colour='FFFFFFFF']", imageSize, imageSize, cls2.Image, cls2.Title);
		local content = cls2.Desc;
		if result == '' then
			result = title..'\n'..content;
		else
			result = result..'\n\n'..title..'\n'..content;
		end
	end
	return result;
end
-----------------------------------------------------------------------------------
-- 시간 설명
-----------------------------------------------------------------------------------
function GetHelpContent_MissionTime(isDirect, missionTime)
	local result = '';
	local missionTimeList = GetClassList('MissionTime');
	local list = {};
	for key, cls in pairs (missionTimeList) do
		table.insert(list, cls);
	end
	table.sort(list, function(a, b)
		return a.Order < b.Order;
	end);
	local imageSize =  48 * ui_session.min_screen_variation;
	for index, cls2 in ipairs (list) do
		local title = string.format("[colour='FFFFFFFF'][image-size='w:%f h:%f'][image='%s'] %s [colour='FFFFFFFF']", imageSize, imageSize, cls2.Image, cls2.Title);
		local content = cls2.Desc;
		if result == '' then
			result = title..'\n'..content;
		else
			result = result..'\n\n'..title..'\n'..content;
		end
	end
	return result;
end
-----------------------------------------------------------------------------------
-- 날씨 설명
-----------------------------------------------------------------------------------
function GetHelpContent_Weather(isDirect, weather)
	local result = '';
	local weatherList = GetClassList('MissionWeather');
	local list = {};
	for key, cls in pairs (weatherList) do
		table.insert(list, cls);
	end
	table.sort(list, function(a, b)
		return a.Order < b.Order;
	end);
	local imageSize =  48 * ui_session.min_screen_variation;
	for index, cls2 in ipairs (list) do
		local title = string.format("[colour='FFFFFFFF'][image-size='w:%f h:%f'][image='%s'] %s [colour='FFFFFFFF']", imageSize, imageSize, cls2.Image, cls2.Title);
		local content = cls2.Desc;
		if result == '' then
			result = title..'\n'..content;
		else
			result = result..'\n\n'..title..'\n'..content;
		end
	end
	return result;
end
-----------------------------------------------------------------------------------
-- 유닛 상태 설명
-----------------------------------------------------------------------------------
function GetHelpContent_UnitState(isDirect, unitState)
	local result = '';
	local pcStateList = GetClassList('PcState');
	
	local temp = {};
	for key, pcState in pairs (pcStateList) do
		if pcState.Type == unitState then
			table.insert(temp, pcState);
		end
	end
	table.sort(temp, function(a, b)
		return a.Order < b.Order;
	end);
	
	for index, state in ipairs (temp) do
		local curPcState = state;
		
		local curRange = '';
		local percent = '';
		if unitState == 'Condition' or unitState == 'Loyalty' then
			percent = '%';
		end
		if state.Min == 0 and state.Max == 0 then
			curRange = '0'..percent;
		elseif state.Max == 100 then
			curRange = state.Min..percent..' ~';
		else
			curRange = state.Min..percent..' ~ '..state.Max..percent;
		end
		local curTitle = "[colour='FFFFFF00']"..curPcState.Title.."([colour='FFFFFFFF']"..curRange.."[colour='FFFFFF00'])[colour='FFFFFFFF']";
		local frontMessage = FormatMessage(curPcState.Desc, { BuffTitle = GetBattleFormulaContent_BuffName(curPcState.Buff, false)});
		if result == '' then
			result = curTitle..'\n'..frontMessage;
		else
			result = result..'\n\n'..curTitle..'\n'..frontMessage;
		end
		
		if curPcState.Buff ~= 'None' then
			result = result..'\n\n'..GetBattleFormulaContent_BuffName(curPcState.Buff, true);
		end
	end	
	return result;
end
function GetHelpContent_UnitState_Condition(self, isDirect)
	return GetHelpContent_UnitState(isDirect, 'Condition');
end
function GetHelpContent_UnitState_Loyalty(self, isDirect)
	return GetHelpContent_UnitState(isDirect, 'Loyalty');
end
function GetHelpContent_UnitState_Duration(self, isDirect)
	return GetHelpContent_UnitState(isDirect, 'Duration');
end
-----------------------------------------------------------------------------------
-- 국가 설명.
-----------------------------------------------------------------------------------
function GetHelpContent_Nation(isDirect, nation)
	local result = '';
	local sectorList = GetClassList('Sector');
	local curSector = sectorList[nation];
	result = curSector.Desc;
	return result;
end
function GetHelpContent_Nation_Ater(self, isDirect)
	return GetHelpContent_Nation(isDirect, 'Ater');
end
function GetHelpContent_Nation_Caras(self, isDirect)
	return GetHelpContent_Nation(isDirect, 'Caras');
end
function GetHelpContent_Nation_EastAlliance(self, isDirect)
	return GetHelpContent_Nation(isDirect, 'EastAlliance');
end
function GetHelpContent_Nation_FortressOfTribulation(self, isDirect)
	return GetHelpContent_Nation(isDirect, 'FortressOfTribulation');
end
function GetHelpContent_Nation_Valhalla(self, isDirect)
	return GetHelpContent_Nation(isDirect, 'Valhalla');
end
function GetHelpContent_Nation_Aelly(self, isDirect)
	return GetHelpContent_Nation(isDirect, 'Aelly');
end
-----------------------------------------------------------------------------------
-- 등급 자동 완성.
-----------------------------------------------------------------------------------
function GetHelpContent_UnitRank(isDirect, rank)
	local result = '';
	local colorList = GetClassList('Color');
	local masteryList = GetClassList('Mastery');
	local monsterGradeList = GetClassList('MonsterGrade');
	local curGrade = monsterGradeList[rank];
	
	local imageSize = 24 * ui_session.min_screen_variation; 
	local curImage = string.format("[image-size='w:%f h:%f'][image='%s']", imageSize,imageSize, curGrade.Image);
	
	-- 1. 기본 설명하기.
	local frontMessage = FormatMessage(GuideMessage('UnitRankDesc'), {	RankImage = curImage });
	-- 2. 능력 설명하기.
	local descMessage = curGrade.Desc;
	-- 3. 특성 설명하기
	local masteryTitle = "[colour='FFFFFFFF']"..curImage..'  '..string.format("[colour='%s']", colorList[curGrade.Color].ARGB)..masteryList[rank].Title;
	local masteryMessage = masteryList[rank].Desc;
	
	result = frontMessage..'\n\n'..descMessage..'\n\n'..masteryTitle..'\n'..masteryMessage;	
	return result;
end
function GetHelpContent_UnitRank_Elite(self, isDirect)
	return GetHelpContent_UnitRank(isDirect, 'Elite');
end
function GetHelpContent_UnitRank_Epic(self, isDirect)
	return GetHelpContent_UnitRank(isDirect, 'Epic');
end
function GetHelpContent_UnitRank_Legend(self, isDirect)
	return GetHelpContent_UnitRank(isDirect, 'Legend');
end
-----------------------------------------------------------------------------------
-- 위임 기능 도움말
-----------------------------------------------------------------------------------
function GetHelpContent_BattleEntrust(isDirect, button)
	local result = '';
	local colorList = GetClassList('Color');
	local aiControlList = GetClassList('AIControl');
	
	-- 1. 기본 설명하기.
	local tList = {};
	for key, cls in pairs (aiControlList) do
		table.insert(tList, cls);
	end
	table.sort(tList, function(a, b)
		return a.Order < b.Order;
	end);
	local imageSize = 24 * ui_session.min_screen_variation;
	for _, control in ipairs (tList) do

		local addText = string.format("[image-size='w:%f h:%f'][image='%s'][colour='FFFFAA00'] %s ( [colour='FFFFFFFF']%s[colour='FFFFAA00'] ): [colour='FFFFFFFF'] %s", 
			imageSize, imageSize, control.Image, control.Title, GetKeyBindingText(control.KeyBinding.name), control.Desc
		);
		if result == '' then
			result = '- '..addText;
		else
			result = result..'\n'..'- '..addText;
		end	
		
	end
	return result;	
end
-----------------------------------------------------------------------------------
-- 배틀 메뉴 메시지.
-----------------------------------------------------------------------------------
function GetHelpContent_BattleMenu(isDirect, button)
	local result = '';
	local colorList = GetClassList('Color');
	local battleMenuList = GetClassList('BattleMenu');
	local curBattleMenu = battleMenuList[button];

	
	-- 1. 기본 설명하기.
	local imageSize = 24 * ui_session.min_screen_variation; 
	local frontMessage = FormatMessage(GuideMessage('HelpMessage_BattleMenu_Base'), 
		{	
			Button = string.format("[image-size='w:%f h:%f'][image='%s']  [colour='FFFFFF00']%s[colour='FFFFFFFF']", imageSize, imageSize, curBattleMenu.Image, curBattleMenu.Title ),
			Key = ' '..GetKeyBindingKeyIamge(curBattleMenu.KeyBinding.name, imageSize)..' '
		}
	);
	result = frontMessage..'\n\n'..curBattleMenu.Desc;
	return result;	
end
function GetHelpContent_BattleMenu_TurnEnd(self, isDirect)
	return GetHelpContent_BattleMenu(isDirect, 'TurnEnd');
end
function GetHelpContent_BattleMenu_BattleMinimap(self, isDirect)
	return GetHelpContent_BattleMenu(isDirect, 'BattleMinimap');
end
function GetHelpContent_BattleMenu_TacticView(self, isDirect)
	return GetHelpContent_BattleMenu(isDirect, 'TacticView');
end
function GetHelpContent_BattleMenu_BattleInfoMode(self, isDirect)
	return GetHelpContent_BattleMenu(isDirect, 'BattleInfoMode');
end
function GetHelpContent_BattleMenu_BattleDetailInfo(self, isDirect)
	return GetHelpContent_BattleMenu(isDirect, 'BattleDetailInfo');
end
function GetHelpContent_BattleMenu_CameraSetting(self, isDirect)
	return GetHelpContent_BattleMenu(isDirect, 'CameraSetting');
end
function GetHelpContent_BattleMenu_DialogWindow(self, isDirect)
	return GetHelpContent_BattleMenu(isDirect, 'DialogWindow');
end
-----------------------------------------------------------------------------------
-- 야수 진화 특성
-----------------------------------------------------------------------------------
function GetHelpContent_EvolutionMastery(self, isDirect, arg)
	local result = '';
	local clsList = GetClassList('BeastEvolutionMastery');
	local cls = clsList[arg];
	if not cls then
		return result;
	end
	result = GuideMessage('BeastEvolutionMastery_Base');
	
	local addMsgType = nil;	
	if cls.Changeable then
		if cls.name == 'Training' then
			addMsgType = 'BeastEvolutionMastery_Change_Training';
		else
			addMsgType = 'BeastEvolutionMastery_Change_NotTraining';
		end
	else
		addMsgType = 'BeastEvolutionMastery_NoChange';
	end
	result = result..'\n\n'..FormatMessage(GuideMessage(addMsgType), { Type = cls.Title, Menu = GetWord('BasicMastery_Menu3'), Training = clsList['Training'].Title });
	return result;
end
-----------------------------------------------------------------------------------
-- 미션과 도움말이 다른 메시지.
-----------------------------------------------------------------------------------
function GetHelpContent_Common(self, isDirect)
	local result = '';
	if isDirect then
		result = ParseContentText_Help(self, self.Content_Mission, true);
	end
	return result;
end

function HelpKeywordTitle_Text(cls, isMission)
	return string.format("[colour='%s']%s", isMission and cls.Color_Mission or cls.Color, cls.Base_Title);
end
function HelpKeywordTitle_Image(cls, isMission)
	return string.format("[colour='%s'][image-size='w:%s h:%s'][image='%s']", isMission and cls.Color_Mission or cls.Color, cls.Width, cls.Height, cls.Image);
end
function HelpKeywordTitle_KeyBind(cls, isMission)
	return string.format("[colour='%s']%s", isMission and cls.Color_Mission or cls.Color, GetKeyBindingText(cls.KeyBind));
end
function HelpKeywordTitle_KeyBindImage(cls, isMission)
	return string.format("[colour='%s']%s", isMission and cls.Color_Mission or cls.Color, GetKeyBindingKeyIamge(cls.KeyBind, cls.Height));
end
function HelpKeywordTitle_SecondMoveRatio(cls, isMission)
	return string.format("[colour='%s']%d%%", isMission and cls.Color_Mission or cls.Color, GetClassList('Object').PC_Albus.Base_SecondaryMoveRatio * 100);
end
function HelpKeywordTitle_OverKillRatio(cls, isMission)
	return string.format('%d%%', math.floor(GetSystemConstant('OverKillRatio') * 100));
end
function HelpKeywordTitle_OvKill_Exp(cls, isMission)
	return math.floor(GetSystemConstant('OverKillReward_Exp')) .. '%';
end
function HelpKeywordTitle_OvKill_ItemGrade(cls, isMission)
	return GetClassList('ItemRank')[GetSystemConstant('OverKillReward_ItemGrade')].Title;
end
function HelpKeywordTitle_OvKill_Troublemaker(cls, isMission)
	return GetSystemConstant('OverKillReward_Troublemaker');
end
function HelpKeywordTitle_PfKill_Exp(cls, isMission)
	return math.floor(GetSystemConstant('PerfectKillReward_Exp')) .. '%';
end
function HelpKeywordTitle_PfKill_ItemGrade(cls, isMission)
	return GetClassList('ItemRank')[GetSystemConstant('PerfectKillReward_ItemGrade')].Title;
end
function HelpKeywordTitle_PfKill_Troublemaker(cls, isMission)
	return GetSystemConstant('PerfectKillReward_Troublemaker');
end
function HelpKeywordTitle_SystemConstant(cls, isMission)
	return string.format("[colour='%s']%s", isMission and cls.Color_Mission or cls.Color, GetSystemConstant(cls.Key));
end
function HelpKeywordTitle_DataRedirector(cls, isMission)
	return string.format("[colour='%s']%s", isMission and cls.Color_Mission or cls.Color, SafeIndex(GetClassList(cls.Idspace), unpack(string.split(cls.DataKey, '/'))));
end
function HelpKeywordTitle_Status(cls, isMission)
	local statusCls = GetClassList('Status')[cls.Status];
	local key = 'Title_HPChangeFunctionArg';
	if GetWithoutError(cls, 'Short') == 'true' then
		key = 'Title';
	end
	return string.format("[colour='%s']%s", isMission and cls.Color_Mission or cls.Color, SafeIndex(statusCls, key));
end
function HelpKeywordTitle_Word(cls, isMission)
	return string.format("[colour='%s']%s", isMission and cls.Color_Mission or cls.Color, SafeIndex(GetClassList('WordCollection'), cls.Word, 'Text'));
end
function HelpKeywordTitle_ChainEffect(cls, isMission)
	return string.format("[colour='%s']%s", isMission and cls.Color_Mission or cls.Color, SafeIndex(GetClassList('ChainEvent'), cls.ChainType, 'Title'));
end
function HelpKeywordTitle_Ability(cls, isMission)
	local abilityCls = GetClassList('Ability')[cls.Ability];
	return string.format("[colour='FFFFFFFF'][image-size='w:$ImgSize$ h:$ImgSize$'][image='%s'] [colour='%s']%s", abilityCls.Image, isMission and cls.Color_Mission or cls.Color, abilityCls.Title);
end
function HelpKeywordTitle_Buff(cls, isMission)
	local buffCls = GetClassList('Buff')[cls.Buff];
	local buffTypeCls = GetClassList('BuffType')[buffCls.Type];	
	return GetColorTagByKey(buffTypeCls.TitleColor)..string.format("[image-size='w:$ImgSize$ h:$ImgSize$'][image='%s'] [colour='%s']%s", buffCls.Image, isMission and cls.Color_Mission or cls.Color, buffCls.Title);
end
function HelpKeywordTitle_Item(cls, isMission)
	local itemCls = GetClassList('Item')[cls.Item];
	return string.format("[colour='FFFFFFFF'][image-size='w:$ImgSize$ h:$ImgSize$'][image='%s'] [colour='%s']%s", itemCls.Type.Image, isMission and cls.Color_Mission or cls.Color, itemCls.Title);
end
function HelpKeywordTitle_FieldEffect(cls, isMission)
	local fieldEffectCls = GetClassList('FieldEffect')[cls.FieldEffect];
	return string.format("[colour='%s']%s", isMission and cls.Color_Mission or cls.Color, fieldEffectCls.Title);
end
function HelpKeywordTitle_MonsterGrade(cls, isMission)
	local monGradeCls = GetClassList('MonsterGrade')[cls.Grade];
	return string.format("[colour='%s']%s", isMission and cls.Color_Mission or cls.Color, monGradeCls.Title);
end
function HelpKeywordTitle_Job(cls, isMission)
	local jobCls = GetClassList('Job')[cls.Job];
	return string.format("[colour='%s']%s", isMission and cls.Color_Mission or cls.Color, jobCls.Title);
end
function HelpKeywordTitle_Mastery(cls, isMission)
	local masteryCls = GetClassList('Mastery')[cls.Mastery];
	return string.format("[colour='FFFFFFFF'][image-size='w:$ImgSize$ h:$ImgSize$'][image='%s'][colour='%s']%s", masteryCls.Type.Image, isMission and cls.Color_Mission or cls.Color, masteryCls.Title);
end