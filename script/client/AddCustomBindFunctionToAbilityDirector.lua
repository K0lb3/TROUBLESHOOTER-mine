----------------------------------------------------------------------------
------------------------------- Bind function ------------------------------
----------------------------------------------------------------------------
------------------------------- CoverState ------------------------------
function UpdateCoverStateIcon(args)
	local obj = GetObjectByKey(args.objKey);
	if obj == nil then	return;	end
	local win = GetAttachingWindow(obj, 'Status');
	if win == nil then	return; end
	local coverWin = win:getChild('Cover');
	coverWin:fireEvent('StartShow', CEGUI.EventArgs());
end
function HideCoverStateIcon(args)
	local obj = GetObjectByKey(args.objKey);
	if obj == nil then	return;	end
	local win = GetAttachingWindow(obj, 'Status');
	if win == nil then	return; end
	local coverWin = win:getChild('Cover');
	coverWin:fireEvent('Hide', CEGUI.EventArgs());
end
function UpdateStatusName(args)
	local obj = GetObjectByKey(args.objKey);
	if obj == nil then	return;	end
	local win = GetAttachingWindow(obj, 'Status');
	if win == nil then	return; end
	local nameWin = win:getChild('Name');
	if args.visible then	
		nameWin:show();
		nameWin:fireEvent('StartShow', CEGUI.EventArgs());	
		for i = 1, 3 do
			local curState = win:getChild('State'..i);
			curState:fireEvent('StartShow', CEGUI.EventArgs());	
		end	
	else
		nameWin:hide();
	end
end
------------------------------- Object TopIcon ------------------------------
function UpdateTopIcon(args)

	local obj = GetObjectByKey(args.objKey);
	if obj == nil then	return;	end
	local win = GetAttachingWindow(obj, 'Sign');
	
	if win == nil then	return; end	

	local icon = win:getChild('Icon');
	local img = '';
	local imgColor = 'tl:FF00FFFF tr:FF00FFFF bl:FF00FFFF br:FF00FFFF';
	
	if args.IconState == 'OverWatch' then
		img = 'Icons/Icon_Alert';
		if GetTeam(obj) == 'enemy' then
			imgColor = 'tl:FFFF5500 tr:FFFF5500 bl:FFFF5500 br:FFFF5500';
		end
	end
	icon:setProperty('Image', img);
	icon:setProperty('ImageColours', imgColor);

	win:show();
	icon:fireEvent('StartShow', CEGUI.EventArgs());	
end
function HideTopIcon(args)

	local obj = GetObjectByKey(args.objKey);
	if obj == nil then	return;	end
	local win = GetAttachingWindow(obj, 'Sign');
	
	if win == nil then	return; end	

	local icon = win:getChild('Icon');
	win:hide();
	icon:fireEvent('Stop', CEGUI.EventArgs());	
end
------------------------------- GameState ------------------------------
function UpdateTurnFlow(turnState)
	-- turnState = {'NPCTurn' , 'UserTurn'}
	
	local turnMarkWin = GetRootLayout('BattleTurnMark', false);
	if turnMarkWin == nil then
		return;
	end

	if turnMarkWin:isVisible() and turnState == 'NPCTurn' then	
		-- 이미 열려있는 상태
		return;
	end
	
	function StopAndFireEvent(win, eventType)
		win:fireEvent('Stop', CEGUI.EventArgs());
		if eventType == 'StartShow' and not IsUserInterfaceVisible() then
			win:hide();
			win:setUserData('__ToggleInterfaceTarget', true);
			return;
		end
		win:fireEvent(eventType, CEGUI.EventArgs());
	end
		
	if turnState == 'NPCTurn' then
		local haveEverPlayed  = turnMarkWin:getUserData('HaveEverPlayed');
		if haveEverPlayed == nil then	-- 적어도 유저가 한번은 턴 돌아온 다음에 켜자
			return;
		end
		PlaySound('EnemyTurn.wav', 'System');
		for i = 1, turnMarkWin:getChild('SideGauge'):getChildCount() do
			StopAndFireEvent(turnMarkWin:getChild('SideGauge'):getChild(i), 'StartShow')
		end
		StopAndFireEvent(turnMarkWin, 'StartShow');
		StopAndFireEvent(turnMarkWin:getChild('Mark'), 'StartShow');
	else
		-- 턴 스타트 사운드는 여기서 하는것보다 소스단에서 캐릭터를 액티베이트 시키는 그 시점에 하는게 더 맞는듯..
		-- PlaySound('TurnStart.wav', 'System');
		
		-- 적턴 게이지 비저블.
		for i = 1, turnMarkWin:getChild('SideGauge'):getChildCount() do
			StopAndFireEvent(turnMarkWin, 'Hide');
			turnMarkWin:getChild('SideGauge'):getChild(i):fireEvent('Stop', CEGUI.EventArgs());
		end
		turnMarkWin:setUserData('HaveEverPlayed', true);
	end
end
------------------------------------------------------------------------------
------------------------------- Mission Direct Objective ----------------------------
------------------------------------------------------------------------------
function _UpdateTitleMessage(title, titleColor, content, contentColor, img)
	local win = GetRootLayout('MissionTitleMessage', false);
	if win == nil then
		return;
	end
	if img == nil then
		img = '';
	end
	if titleColor == nil then
		titleColor = 'White';
	end
	if contentColor == nil then
		contentColor = 'White';
	end
	
	local animationKey = 'StartShow';
	local colorList = GetClassList('Color');
	
	if title == '' or title == nil then
		animationKey = 'Hide';
	else
		win:getChild('Title'):setText(title);
		win:getChild('Title'):setProperty('NormalTextColour', colorList[titleColor].ColorRectGradation);
		win:getChild('Content'):setText(content);
		win:getChild('Content'):setProperty('NormalTextColour', colorList[titleColor].ColorRectGradation);
		win:getChild('Image'):setProperty('Image', img);
		
		-- 글자수 길이가 길면 폰트를 작게 해서 더들어가게 한다. NotoSansBlack-40 보다 작은 폰트는 안씀;
		local contentFont = { 'NotoSansBlack-50', 'NotoSansBlack-40' };
		local contentTextWin = win:getChild('Content');
		for index, font in ipairs (contentFont) do
			contentTextWin:setProperty('Font', font);
			local width, height = GetTextSize(contentTextWin, false);
			if width <= contentTextWin:getPixelSize().width then
				break;
			end
		end
		
		win:show();
	end
	win:getChild('Title'):fireEvent(animationKey, CEGUI.EventArgs());
	win:getChild('Content'):fireEvent(animationKey, CEGUI.EventArgs());
	win:getChild('Image'):fireEvent(animationKey, CEGUI.EventArgs());	
	if not IsUserInterfaceVisible() then
		win:setUserData('__ToggleInterfaceTarget', true);
		win:hide();
	end
end
function UpdateTitleMessage(args)
	local title = GetSentenceString(args.title);
	local titleColor = args.titleColor;
	local content = GetSentenceString(args.content);
	local contentColor = args.contentColor;
	local img = args.image;
	_UpdateTitleMessage(title, titleColor, content, contentColor, img);
end
function UpdateTitleMessageWithText(args)
	local title = LoadText(args.title);
	local titleColor = args.titleColor;
	local content = LoadText(args.content);
	local contentColor = args.contentColor;
	local img = args.image;
	_UpdateTitleMessage(title, titleColor, content, contentColor, img);
end
function Hide_TitleMessage_Animation(e)
	local ae = tolua.cast(e,"const CEGUI::AnimationEventArgs");
	local aniName = ae.instance:getDefinition():getName();
	if aniName == 'Hide_BattleTitleMessage_Content' then
		local win = GetRootLayout('MissionTitleMessage', false);
		if win then
			win:hide();
		end
	end
end
------------------------------------------------------------------------------
------------------------------- AlertScreenEffect ----------------------------
------------------------------------------------------------------------------
function AlertScreenEffect(args)
	local obj = GetObjectByKey(args.objKey, true);
	if obj == nil or not IsObjectInSight(obj) then
		return;
	end
	local win = GetRootLayout('Alert', false);
	if win == nil then
		return;
	end
	local isSet = win:getUserData('IsSet');
	if isSet == nil then
		win:setProperty('Image', 'Effect_TV_White');
		win:setUserData('IsSet', true)
	end
	PlaySound('AlertSiren.ogg', 'Effect', 1.0);
	StartBattleBGM();
	win:fireEvent('StartShow', CEGUI.EventArgs());
end
------------------------------- InteractionMessage ------------------------------
function UpdateInteractionFrontMessage(args)
	local content = nil;
	
	local interaction = args.interaction;
	local interactionType = args.interactionType;
	local interactionSubType = args.interactionSubType;	

	if GetOption().Gameplay.SimpleGetItem then
		if interaction == 'ItemAcqired' then
			local newItem = nil;
			if type(interactionSubType) == 'table' then
				newItem = CreateDummyProperty('Item', interactionType);
				for propType, propValue in pairs(interactionSubType) do
					SetAutoType(newItem, propType, propValue);
				end
			else
				newItem = GetClassList('Item')[interactionType];
			end
			-- 정작 InteractionMessage UI를 사용하지 않지만, 클라 옵션에 따른 서버 연출 분기가 마땅치가 않아서 여기서 처리함.
			local itemTitle = GetStringFontColorChangeTagWithColorKey(newItem.Rank.Color, newItem.Title, 'Corn');
			content = string.format(GuideMessage('ItemEffect_GiveItem'), itemTitle);
		elseif interaction == 'EmptyChest' then
			content = GuideMessage('NothingAcquired');
		end
	end
	if GetOption().Gameplay.SimpleInteraction then
		if interaction == 'InformationAcquired' then
			content = GuideMessage('InformationAcquired');
		elseif interaction == 'ContentsBroken' then
			content = GuideMessage('DamagedItem');
		elseif interaction == 'HackingSuccess' then
			local objInfoCls = GetClassList('ObjectInfo')[interactionType];	
			content = objInfoCls.Title..' '..GuideMessage('HackingSuccess');
		elseif interaction == 'HackingFailed' then
			content = GuideMessage('HackingFailed');
		elseif interaction == 'Hacked' then
			local objInfoCls = GetClassList('ObjectInfo')[interactionType];	
			content = objInfoCls.Title..' '..GuideMessage('HackingSuccess');
		elseif interaction == 'Rescue' then
			local objInfoCls = GetClassList('ObjectInfo')[interactionType];	
			content = GuideMessage('Rescue');		
		elseif interaction == 'RescueFailed' then
			local objInfoCls = GetClassList('ObjectInfo')[interactionType];	
			content = GuideMessage('RescueFailed');
		elseif interaction == 'Release' then
			local objInfoCls = GetClassList('ObjectInfo')[interactionType];	
			content = objInfoCls.Title..' '..GuideMessage('Rescue2');
		elseif interaction == 'MemberJoin' then
			local objInfoCls = GetClassList('ObjectInfo')[interactionType];	
			content = objInfoCls.Title..' '..GuideMessage('MemberJoin');
		elseif interaction == 'AssistMap' then
			content = GuideMessage('AssistMapEnabled');
		elseif interaction == 'RestoreConnection' then
			content = GuideMessage('Guide_RestoreConnection');
		end
	end
	if not content then
		return false;
	end
	ShowFrontmessage(GetStringFontColorChangeTagWithColorKey('Corn', content, 'White'));
	return true;
end
function UpdateInteractionMessage(args)
	-- 프론트 메시지 연출을 하게 되었으면, InteractionMessage 연출은 생략한다.
	if UpdateInteractionFrontMessage(args) then
		return;
	end

	local win = GetRootLayout('InteractionMessage', false);
	if win == nil then	return; end
	if not win:isVisible() then
		win:show();
	end
	
	local colorList = GetClassList('Color');
	
	local title = '';
	local content = '';
	
	local colorList = GetClassList('Color');
	local interaction = args.interaction;
	local interactionType = args.interactionType;
	local interactionSubType = args.interactionSubType;

	-- 초기값 세팅
	
	local lineWin = win:getChild('Line');
	local titleWin = win:getChild('Title');
	local contentWin = win:getChild('Content');
	local contentWinSize = contentWin:getPixelSize();
	
	-- 각 인터렉션에 따라 다르게 표현한다.
	if interaction == 'ItemAcqired' then
		local newItem = nil;
		if type(interactionSubType) == 'table' then
			newItem = CreateDummyProperty('Item', interactionType);
			for propType, propValue in pairs(interactionSubType) do
				SetAutoType(newItem, propType, propValue);
			end
		else
			newItem = GetClassList('Item')[interactionType];
		end
		title = 'ITEM ACQUIRED!';
		content = GetStringFontImageTag(contentWinSize.height, contentWinSize.height, newItem.Type.Image)..' '..GetStringFontColorChangeTag(colorList[newItem.Rank.Color].ARGB, newItem.Title, colorList['White'].ARGB )..' '..GuideMessage('ItemAcquired');
	elseif interaction == 'EmptyChest' then
		title = 'NOTHING ACQUIRED!';
		content = GuideMessage('NothingAcquired');
	elseif interaction == 'InformationAcquired' then
		title = 'INFORMATION ACQUIRED!';
		content = GuideMessage('InformationAcquired');
	elseif interaction == 'ContentsBroken' then
		title = 'DAMAGED ITEM!';
		content = GuideMessage('DamagedItem');
	elseif interaction == 'HackingSuccess' then
		title = 'HACKING SUCCESS!';
		local objInfoCls = GetClassList('ObjectInfo')[interactionType];	
		content = objInfoCls.Title..' '..GuideMessage('HackingSuccess');
	elseif interaction == 'HackingFailed' then
		title = 'HACKING FAILED!';
		content = GuideMessage('HackingFailed');
	elseif interaction == 'Hacked' then
		title = 'HACKING SUCCESS!';
		local objInfoCls = GetClassList('ObjectInfo')[interactionType];	
		content = objInfoCls.Title..' '..GuideMessage('HackingSuccess');
	elseif interaction == 'Rescue' then
		title = 'RESCUE SUCCESS!';
		local objInfoCls = GetClassList('ObjectInfo')[interactionType];	
		content = GuideMessage('Rescue');		
	elseif interaction == 'RescueFailed' then
		title = 'RESCUE FAILED!';
		local objInfoCls = GetClassList('ObjectInfo')[interactionType];	
		content = GuideMessage('RescueFailed');
	elseif interaction == 'Release' then
		title = 'RESCUE SUCCESS!';
		local objInfoCls = GetClassList('ObjectInfo')[interactionType];	
		content = objInfoCls.Title..' '..GuideMessage('Rescue2');
	elseif interaction == 'MemberJoin' then
		title = 'MEMBER JOINED!';
		local objInfoCls = GetClassList('ObjectInfo')[interactionType];	
		content = objInfoCls.Title..' '..GuideMessage('MemberJoin');
	elseif interaction == 'AssistMap' then
		title = 'INFORMATION ACQUIRED!';
		content = GuideMessage('AssistMapEnabled');
	elseif interaction == 'RestoreConnection' then
		title = 'RESTORE CONNECTION!';
		content = GuideMessage('Guide_RestoreConnection');
	end
	titleWin:setText(title);
	contentWin:setText(content);
	
	win:fireEvent('Stop', CEGUI.EventArgs());
	lineWin:fireEvent('Stop', CEGUI.EventArgs());
	titleWin:fireEvent('Stop', CEGUI.EventArgs());
	contentWin:fireEvent('Stop', CEGUI.EventArgs());

	win:fireEvent('StartShow', CEGUI.EventArgs());
	lineWin:fireEvent('StartShow', CEGUI.EventArgs());
	titleWin:fireEvent('StartShow', CEGUI.EventArgs());
	contentWin:fireEvent('StartShow', CEGUI.EventArgs());
end
------------------------------- BattleEvent ------------------------------
function UpdateBattleEvent(args)
	local event = nil;
	if not args.eventArgs then
		event = args.eventType;
	else
		event = args.eventArgs;
		event.Type = args.eventType;
	end

	local abilityEventClsList = GetClassList('AbilityDirectingEvent');
	local eventCls = abilityEventClsList[args.eventType];
	
	if (eventCls.AliveOnly or SafeIndex(args, 'eventArgs', 'AliveOnly')) and GetFSMState(GetObjectByKey(args.objKey)) == 'Dead'	then
		return;
	end
	
	local msgArg = {};
	msgArg.objKey = args.objKey;
	msgArg.Color = eventCls:ColorSelector(event);
	msgArg.message = FormatMessage(eventCls.Message, eventCls:FormatTableMaker(event));
	
	UpdateBattleMessage(msgArg);
end
------------------------------- BattleMessage ------------------------------
local battleMessageEnabled = true;
function UpdateBattleMessageText(args)
	args.message = LoadText(args.text);
	UpdateBattleMessage(args);
end
function UpdateBattleMessage(args)
	if not battleMessageEnabled then
		return;
	end
	local obj = GetObjectByKey(args.objKey, true);
	if obj == nil or not IsObjectInSight(obj) or not IsObjectVisible(obj) then	return;	end
	local win = GetAttachingWindow(obj, 'BattleMessage');
	SetAttachingWindowVisible(obj, 'BattleMessage', true);
	if win == nil then	return; end
	if not win:isVisible() then
		win:show();
	end
	
	if not IsUserInterfaceVisible() then
		win:setUserData('__ToggleInterfaceTarget', true);	--- system dependent...
		win:hide();
	end
		
	local colorList = GetClassList('Color');
	local bgColor = colorList['White'].ColorRect;
	local text = args.message;
	
	-- 초기값 세팅
	if args.Color ~= nil then
		bgColor = colorList[args.Color].ColorRect;
	end
	ShowBattleMessage(win, bgColor, text);
end
function EnableBattleMessage(args)
	battleMessageEnabled = args.enable;
end
function ShowBattleMessage(win, bgColor, text)
	local realText = ' '..text..' ';
	
	for i = 1, win:getChildCount() do
		local curMessage = win:getChild(i);
		if curMessage:isVisible() then 
			local textParent = curMessage:getChild('Text');
			local textWin = textParent:getChild('Text');
			if textWin:getText() == realText then
				return;
			end
		end
	end
	
	local message = nil;
	for i = 2, win:getChildCount() do
		local prevMessage = win:getChild(i - 1);
		local curMessage = win:getChild(i);
		
		if prevMessage:isVisible() and not curMessage:isVisible() then
			message = curMessage;
		end
	end
	if message == nil then
		message = win:getChild(1);
	end
	message:show();
	
	-- 배경색 결정.
	local tag = message:getChild('Tag');
	tag:setProperty('ImageColours', bgColor);
	
	local ps = message:getPixelSize();
	
	-- 텍스트 컬러, 내용 결정.
	local textParent = message:getChild('Text');
	local textWin = textParent:getChild('Text');
	ConvertSizeAsAbsolute(textWin);
	
	textWin:setText(realText);
	
	--- 텍스트 길이 정하기 ---	
	local width, height = GetTextSize(textWin, false);
	if width < ps.width * 0.7 then
		width = ps.width * 0.7;
	end
	textParent:setWidth(CEGUI.UDim(0, width));
	ConvertSizeAsRelative(textParent)
	
	textWin:setWidth(CEGUI.UDim(1, 0));
	textWin:setHeight(CEGUI.UDim(1, 0));

	message:fireEvent('Stop', CEGUI.EventArgs());
	message:fireEvent('StartShow', CEGUI.EventArgs());
end
function InitializeSkipPoint()
	g_enabled_skip_point = false;
end
function SkipPointOn(args)
	if not IsMissionMode() then
		return;
	end
	-- 기존에 이미 실행 중인 스킵 포인트가 있으면 꺼줌
	if g_enabled_skip_point then
		SkipPointOff();
	end
	g_enabled_skip_point = true;
	
	SetDirectingSkipEnabled(true);
end
function SkipPointOff()
	if not IsMissionMode() then
		return;
	end
	-- 실행 중인 스킵 포인트가 없으면 무시
	if not g_enabled_skip_point then
		return;
	end
	g_enabled_skip_point = false;
	
	SetDirectingSkipEnabled(false);
end
function OnSkipEnableChanged(isEnabled)
	LogAndPrint(string.format('=== OnSkipEnableChanged(%s) ===', (isEnabled and "true" or "false")));
	
	if IsMissionMode() then
		local session = GetSession();
		local mission = session.current_mission;
		if mission and mission.name == 'Tutorial_CrowBill' then
			isEnabled = false;
		end
	end
	
	local win = GetRootLayout('BattleDirectSkipMark', false);
	local isSet = win:getUserData('IsSet');
	if isSet == nil then
		SetTitleAdjustLength(win:getChild('Text'), GetWord('SkipDirect'), 'NotoSansMedium-14_Auto');
		win:setUserData('IsSet', true);
	end
	win:setUserData('Enabled', isEnabled);
	win:fireEvent('Stop', CEGUI.EventArgs());
	if isEnabled then
		win:fireEvent('StartShow', CEGUI.EventArgs());		
	else
		win:fireEvent('Hide', CEGUI.EventArgs());
	end	
end
------------------------------------------------------------------
--- MissionDirect - 미션 시작시 유아이 닫아주고 열어주는 부분
------------------------------------------------------------------
local missionDirectStack = 0;
local prevAcceleration;
local prevZoomLevel;
local prevPitch;
local prevHideUI;
function ResetMissionDirect()
	missionDirectStack = 0;
	prevAcceleration = nil;
	prevZoomLevel = nil;
	prevPitch = nil;
	prevHideUI = nil;
end
function StartMissionDirect(args)
	IncreaseCameraControlLock();
	if missionDirectStack == 0 then
		prevZoomLevel = UpdateMissionZoomLevel(GetSystemConstant('CAM_ZOOM_LEVEL_DEFAULT'));
		prevPitch = UpdateMissionCameraPitch(0);
		EnableAddingBuffEffect(false, true);
		InsertBuffEffectHideFlagAll('MissionDirect', true);
	end
	missionDirectStack = missionDirectStack + 1;
	-- 이미 스킵 모드 중이면 그대로
	if not IsDirectingSkipEnabled() then
		SetDirectingSkipEnabled(true);
	end
	if args.HideUI then
		BattleUIControl({visible = false});
		prevHideUI = true;
	end
	EnableFSMInteraction(false);
	prevAcceleration = GetAccelerationLevel();
	EnableAcceleration(-1);
end
function EndMissionDirect(args)
	missionDirectStack = missionDirectStack - 1;
	DecreaseCameraControlLock();
	if missionDirectStack == 0 then
		UpdateMissionZoomLevel(prevZoomLevel);
		UpdateMissionCameraPitch(prevPitch);
		EnableAddingBuffEffect(true, true);
		PopOutBuffEffectAll(true);
		RemoveBuffEffectHideFlagAll('MissionDirect', true);
	end
	-- 이미 스킵 모드 중이면 그대로
	if not IsDirectingSkipEnabled() then
		SetDirectingSkipEnabled(false);
	end
	if args.ShowUI then
		BattleUIControl({visible = true});
		prevHideUI = nil;
	end
	EnableFSMInteraction(true);
	EnableAcceleration(prevAcceleration);
end
function BattleUIControl(args)
	if IsDandyCrafter() then
		return;
	end
	local testWindows = {GetRootLayout('BattleMain', false)
						, GetRootLayout('PlayerInfo', false)
						, GetRootLayout('BattleTurnMark', false)
						, GetRootLayout('ChatWindow_Mission', false)};
	local restore = StringToBool(args.restore, false);
	local visible = StringToBool(args.visible, true);
	local previous = StringToBool(args.previous, false);
	for i, win in ipairs(testWindows) do
		if win then
			(function ()	-- break 용
				if restore then
					-- 이전 컨트롤 상태로 복구합니다.
					if win:getUserData('HideByControl') then
						win:fireEvent('Stop', CEGUI.EventArgs());
						win:fireEvent('Hide', CEGUI.EventArgs());
						if win:getName() ~= 'PlayerInfo' then
							win:hide();	-- PlayerInfo는 AntiBlink타입 애니를 이용하므로 여기서 hide치면 오히려 깜빡임 현상이 발생한다.
						end
					end
					return;
				end
				if visible then
					-- 미션 디렉트가 UI를 숨기고 있는 상태면 다시 켜지 않는다.
					if previous and prevHideUI then
						return;
					end
					if win:getUserData('HideByControl') then
						win:fireEvent('Stop', CEGUI.EventArgs());
						win:fireEvent('StartShow', CEGUI.EventArgs());
						win:setUserData('HideByControl', nil);
					end
				else
					if win:isVisible() then
						win:fireEvent('Stop', CEGUI.EventArgs());
						win:fireEvent('Hide', CEGUI.EventArgs());
						win:setUserData('HideByControl', true);
					end
				end
			end)();
		end
	end
end
function MissionDashBoardVisible(args)
	local win = GetRootLayout('BattleMain', false);
	local dashboardTypes = {'MissionBoardCounterSingle', 'MissionBoardCounterDouble', 'MissionBoardCounterTriple', 'MissionBoardTimeLimit'};
	if args.visible then
		win:show();
		win:getChild('MissionObjectiveMainPanel'):fireEvent('Stop', CEGUI.EventArgs());
		win:getChild('MissionObjectiveMainPanel'):fireEvent('StartShow', CEGUI.EventArgs());
		for _, boardType in ipairs(dashboardTypes) do
			local board = win:getChild(boardType);
			if board:getUserData('Visible') then
				board:fireEvent('Stop', CEGUI.EventArgs());
				board:fireEvent('StartShow', CEGUI.EventArgs());
			else
				board:fireEvent('Stop', CEGUI.EventArgs());
				board:setProperty('Alpha', 1);
			end
		end
	else
		win:getChild('MissionObjectiveMainPanel'):fireEvent('Stop', CEGUI.EventArgs());
		win:getChild('MissionObjectiveMainPanel'):setProperty('Alpha', 0);
		for _, boardType in ipairs(dashboardTypes) do
			local board = win:getChild(boardType);
			board:fireEvent('Stop', CEGUI.EventArgs());
			board:setProperty('Alpha', 0);
		end
	end
	SetMarkerVisible(args.visible);
end
function MissionSubInterfaceVisible(args)
	MissionDashBoardVisible(args);
	BattleUIControl(args);
	local visible = args.visible;
	SetInteractionGuideVisible(visible);
end
function SetNamedAssetVisibleDirect(args)
	SetNamedAssetVisible(args.key, args.visible);
end
function SetNamedAssetVisibleAllDirect(args)
	SetNamedAssetVisibleAll(args.visible);
end
function SetLayerAssetVisibleDirect(args)
	SetLayerAssetVisible(args.key, args.visible);
end
function StartLobbyCameraModeDirect(args)
	local ended = false;
	StartLobbyCameraMode(args.cameraMode, function()
		ended = true;
	end, false, false, args.direct, true);
	while not ended do
		Sleep(10);
	end
end
function ChangeLobbyMapDirect(args)
	ChangeLobbyMap(args.lobbyDefName);
	while not IsAsyncLoadQueueEmpty() do
		Sleep(10);
	end
end
------------------------------------------------------------------
--- 오브젝트 스테이터스 게이지 닫아주는거
------------------------------------------------------------------
function HideBattleStatus(args)

	local obj = GetObjectByKey(args.objKey);
	if obj == nil then return; end
	local win = GetAttachingWindow(obj, 'Status');
	if win == nil then	return; end	
	if win:isVisible() then
		win:fireEvent('Stop', CEGUI.EventArgs());
		win:fireEvent('Hide', CEGUI.EventArgs());
	end	
end
function ShowBattleStatus(args)
	local obj = GetObjectByKey(args.objKey, true);
	if obj == nil then return; end
	local win = GetAttachingWindow(obj, 'Status');
	if win == nil then	return; end	
	if win:isVisible() then
		win:fireEvent('Stop', CEGUI.EventArgs());
		win:fireEvent('StartShow', CEGUI.EventArgs());
	else
		win:setAlpha(1.0);
	end	
end
------------------------------------------------------------------
-- 튜토리얼 및 각종 시스템 메세지.
------------------------------------------------------------------
function UpdateBattleSystemMessage(args)

	local win = GetRootLayout('BattleSystemMessage', false);
	if win == nil then	return; end	
	
	local title = GetSentenceString(args.title);
	local text = GetSentenceString(args.text);
	local mark = args.mark;
	local visible = true;
	if title == nil  then
		title = '';
	end	
	if text == nil or text == '' then
		visible = false;
	end
	if mark == nil then
		mark = '';
	end
	if text ~= nil then
		local formatTable = {};
		FillImgSizeToFormatTable(formatTable);
		text = FormatMessage(text, formatTable);
	end
	
	local listContent = win:getChild('List');
	local frameWin = win:getChild('Frame'); 
	local layout = CEGUI.toVerticalLayoutContainer(listContent);
	local titleWin = listContent:getChild('Title');	
	if visible then
		-- 제목 넣기.
		SetTitleAdjustLength(titleWin:getChild('Text'), title, 'NotoSansBlack-18_Auto');
		
		local contentWin = listContent:getChild('Content');
		local contentTextWin = contentWin:getChild('Text');
		contentTextWin:setText(text);
		local width, height = GetTextSize(contentTextWin, true);
		local textHeight = height + 10 * ui_session.min_screen_variation;
		local contentHeight = textHeight + 20 * ui_session.min_screen_variation;
		contentTextWin:setHeight(CEGUI.UDim(0, textHeight));
		contentWin:setHeight(CEGUI.UDim(0, contentHeight));
		NotifyLayout(layout);		
		titleWin:getChild('Right'):fireEvent('StartShow', CEGUI.EventArgs());
		titleWin:getChild('Left'):fireEvent('StartShow', CEGUI.EventArgs());
		if IsUserInterfaceVisible() then
			win:fireEvent('StartShow', CEGUI.EventArgs());
		else
			win:fireEvent('Hide', CEGUI.EventArgs());	-- 초기 상태로 되돌리기 위해..
			win:fireEvent('Stop', CEGUI.EventArgs());	-- 초기 상태로 되돌리기 위해..
			win:hide();
			win:setUserData('__ToggleInterfaceTarget', true);
		end
		frameWin:setProperty('Area', listContent:getProperty('Area'));
	else
		titleWin:getChild('Right'):fireEvent('Stop', CEGUI.EventArgs());
		titleWin:getChild('Left'):fireEvent('Stop', CEGUI.EventArgs());
		win:fireEvent('Hide', CEGUI.EventArgs());
	end	
end
function UpdateBattleSystemMessage_KeyWord(args)
	UpdateBattleSystemMessage({ title = GetWord(args.title), text = GuideMessage(args.text), mark = args.mark });
end
function UpdateBattleSystemMessage_Help(args)
	if not args.help or args.help == '' or args.help == 'None' then
		UpdateBattleSystemMessage({ title = '', text = '', mark = args.mark });
		return;
	end
	local helpCls = GetClassList('Help')[args.help];
	if not helpCls or not helpCls.name then
		UpdateBattleSystemMessage({ title = '', text = '', mark = args.mark });
		return;
	end
	UpdateBattleSystemMessage({ title = helpCls.TitleDirect, text = helpCls.ContentDirect, mark = args.mark });
end
-----------------------------------------------------------
-- 미션에서 챗 함수
------------------------------------------------------------
function AddMissionChat(args)
	if IsDandyCrafter() then
		return;
	end
	if not args.Type or not args.Message or not args.Args then
		return;
	end

	local chatArgs = table.deepcopy(args.Args);
	
	if GetSession().permission_level < 1 then
		-- 대상 오브젝트가 존재하는 경우, 플레이어 시야에 따른 필터링을 한다.
		local objKey = chatArgs.ObjectKey;
		if objKey then
			local obj = GetObjectByKey(objKey, true);
			if not obj then
				return;
			end
			if not IsObjectInSight(obj, true) then
				return;
			end
		end
		
		-- 대상 팀이 존재하는 경우, 플레이어 팀이 아니면 필터링을 한다.
		local team = chatArgs.Team;
		if team then
			if team ~= GetPlayerTeamName() then
				return;
			end	
		end
	end
	
	local objKey = chatArgs.ObjectKey;
	if objKey then
		local obj = GetObjectByKey(objKey, true);
		if not obj then
			return;
		end
		chatArgs.ObjectName = obj.Info.name;
		chatArgs.ObjectRelation = GetRelationWithPlayer(obj);
	end
	
	local targetKey = chatArgs.TargetKey;
	if targetKey then
		local target = GetObjectByKey(targetKey, true);
		if not target then
			return;
		end
		chatArgs.TargetName = target.Info.name;
		chatArgs.TargetRelation = GetRelationWithPlayer(target);
	end	
	
	AddChat(args.Type, args.Message, chatArgs);
end
function AddChatDS(args)
	AddChat(args.Type, LoadText(args.Message), chatArgs);
end
function AddRelationMissionChat(args)
	if not args.Type or not args.Message or not args.Args then
		return;
	end

	local relation = nil;	
	
	local objKey = args.Args.ObjectKey;
	local team = args.Args.Team;
	if not objKey and not team then
		return;
	end
	
	if team then
		relation = GetRelationWithPlayer(team);
	else
		local obj = GetObjectByKey(objKey, true);
		if not obj then
			return;
		end
		relation = GetRelationWithPlayer(obj);
	end

	local relationKey = nil;
	if relation == 'Team' then
		relationKey = 'Player';
	elseif relation == 'Enemy' then
		relationKey = 'Enemy';
	else
		relationKey = 'Other';
	end	
	
	AddMissionChat({ Type = relationKey..args.Type, Message = args.Message, Args = args.Args });
end

function ShowAlertLine(args)
	LogAndPrint(args.FromKey, args.ToKey);
	local fromObj = GetObjectByKey(args.FromKey);
	local toObj = GetObjectByKey(args.ToKey);
	local fromPos = GetModelPosition(fromObj);
	local toPos = GetModelPosition(toObj);
	local particleName = args.ParticleName;
	if particleName == nil then
		particleName = 'Particles/Dandylion/Selection_Alert';
	end
	
	local line = GetLinePathThroughPositions(fromPos, toPos, true);
	for i, pos in ipairs(line) do
		if IsEnterablePosition(pos) then
			PlayParticle(pos, particleName, 2);
		end
	end
end
function ShowBuffEffect(args)
	local target = GetObjectByKey(args.objKey);
	PopOutBuffEffect(target, args.buffName);
end
function HideBuffEffect(args)
	local target = GetObjectByKey(args.objKey);
	RemoveBuffEffect(target, args.buffName);
end
function HideObjectMarkerByDirecting(args)
	local target = GetObjectByKey(args.objKey);
	HideObjectMarker(target);
end

function EnableAssistMap(args)
	local team = args.Team;
	if team ~= GetPlayerTeamName() then
		return;
	end
	ui_session.enable_assist_map = args.Enabled;
end
------------------------------------------------------------------------------
------------------------------- Credit 연출 -----------------------------------
------------------------------------------------------------------------------
function ShowCredit(args)
	local win = GetRootLayout('Credit', false);
	args.Slow = true;
	
	local session = GetSession();
	local company = session.company_info;
	local formatTable = { CompanyName = company.CompanyName };
	
	local ToNormalText = function(text)
		return FormatMessage(text, formatTable);
	end
	local ToIndentText = function(text)
		return FormatMessage(text and (text) or '', formatTable);
	end
	
	local creditCls = GetWithoutError(GetClassList('Credit'), args.CreditType);
	local animationKey = 'StartShow';
	local colorList = GetClassList('Color');
	local jobColor = colorList['CreditJob'].ARGB;
	local nameColor = colorList['White'].ARGB;
	if not creditCls then
		if not args.Slow then
			animationKey = 'Hide';
		else
			animationKey = 'Hide2';
		end	
	else
		if not args.Slow then
			animationKey = 'StartShow';
		else
			animationKey = 'StartShow2';
		end
		local componentWidth = 1300 * ui_session.min_screen_variation;
		local componentHeight = 45 * ui_session.min_screen_variation;
		
		local listContent = win:getChild('List/Content');
		ResizeLayoutContainer(listContent, #creditCls.List, function(i)
			local listElem = LoadLayout('CreditComponent');
			listElem:setWidth(CEGUI.UDim(0, componentWidth));
			listElem:setHeight(CEGUI.UDim(0, componentHeight));
			return listElem;
		end, function(i, listElem)
			local textCls = creditCls.List[i];
			
			local textLeft = listElem:getChild('Left');
			local textRight = listElem:getChild('Right');
			local textCenter = listElem:getChild('Center');
			textLeft:setText('');
			textRight:setText('');
			textCenter:setText('');
			
			if textCls.Type == 'Job' then
				if textCls.Align == 'Center' then
					textCenter:setText(ToNormalText(textCls.Text));
					textCenter:setProperty('NormalTextColour', jobColor);
				else
					textLeft:setText(ToNormalText(textCls.Text));
					textLeft:setProperty('NormalTextColour', jobColor);
				end
			elseif textCls.Type == 'Name' then
				if textCls.Align == 'Center' then
					textCenter:setText(ToNormalText(textCls.Text or textCls.Text2));
					textCenter:setProperty('NormalTextColour', nameColor);
				else
					textRight:setText(ToIndentText(textCls.Text or textCls.Text2));
					textRight:setProperty('NormalTextColour', nameColor);
				end
			elseif textCls.Type == 'JobName' then
				textLeft:setText(ToNormalText(textCls.Text));
				textLeft:setProperty('NormalTextColour', jobColor);
				textRight:setText(ToIndentText(textCls.Text2));
				textRight:setProperty('NormalTextColour', nameColor);
			elseif textCls.Type == 'Name2' then
				textLeft:setText(ToIndentText(textCls.Text));
				textLeft:setProperty('NormalTextColour', nameColor);
				textRight:setText(ToIndentText(textCls.Text2));
				textRight:setProperty('NormalTextColour', nameColor);
			end
			
			local margin = (textCls.Margin or 25) * ui_session.min_screen_variation;
			SetMarginWindow(listElem, 0, margin, 0, 0);
		end);
		local height = listContent:getPixelSize().height;
		win:getChild('List'):setHeight(CEGUI.UDim(0, height));
		win:show();
	end
	win:fireEvent('Stop', CEGUI.EventArgs());
	win:fireEvent(animationKey, CEGUI.EventArgs());
end
------------------------------------------------------------------------------
------------------------------- VoiceText 연출 --------------------------------
------------------------------------------------------------------------------
function UpdateCharacterVoiceText(args)
	if not IsClient() then
		return;
	end
	if not GetOption().Gameplay.ShowCharacterVoiceText then
		return;
	end
	local win = GetRootLayout('CharacterVoiceText', false);
	if not win:isVisible() then
		win:show();
	end
	if not IsUserInterfaceVisible() then
		win:setUserData('__ToggleInterfaceTarget', true);	--- system dependent...
		win:hide();
	end
	local text = args.message;
	if type(text) == 'table' then
		text = LoadText(text);
	end
	ShowCharacterVoiceText(win, text);
	local noTagText = string.gsub(text, '%[[^%]]+%]', '');
	AddMissionChat({ Type = 'TalkNPC', Message = noTagText, Args = { ObjectKey = args.objKey } });
end
function ShowCharacterVoiceText(win, text)
	local voiceCount = win:getUserData('VoiceCount') or 0;
	voiceCount = voiceCount + 1;
	win:setUserData('VoiceCount', voiceCount);
	
	local realText = ' '..text..' ';
	
	local listWin = win:getChild('Content/List');
	for i = 1, listWin:getChildCount() do
		local curMessage = listWin:getChild(i);
		if curMessage:isVisible() then 
			if curMessage:getText() == realText then
				return;
			end
		end
	end
	
	local message = nil;
	for i = 2, listWin:getChildCount() do
		local prevMessage = listWin:getChild(i - 1);
		local curMessage = listWin:getChild(i);
		
		if prevMessage:isVisible() and not curMessage:isVisible() then
			message = curMessage;
		end
	end
	if message == nil then
		message = listWin:getChild(1);
	end
	message:show();
	SetTitleAdjustLength(message, realText, 'NotoSansMedium-18_Auto', true);

	message:fireEvent('Stop', CEGUI.EventArgs());
	message:fireEvent('StartShow', CEGUI.EventArgs());
	message:setUserData('VoiceCount', voiceCount);	
end
function CharacterVoiceTextAnimationEnded(e)
	local ae = tolua.cast(e, 'const CEGUI::AnimationEventArgs');
	local message = GetAnimationOwner(ae.instance);
	local win = GetTopMostParent(message);
	-- 마지막 요청된 보이스의 애니메이션이 끝났으면 닫는다.
	if message:getUserData('VoiceCount') == win:getUserData('VoiceCount') then
		win:hide();
	end
end