------------------------------------------------------------
-- 로비 
------------------------------------------------------------
function ShownLobbyMenu(e)
	local session = GetSession();
	local we = CEGUI.toWindowEventArgs(e);
	local chatWin = GetRootLayout('ChatWindow', false);
	UpdateLobbyInfo(we.window);
	chatWin:show();
end
function GetLobbyMenuList(company, location)
	local session = GetSession();
	local lobbyMenuList = GetClassList('LobbyMenu');
	local BuildMenuList = function(self, menuList)
		local list = {};
		for index, value in pairs (menuList) do
			local isOpened = StringToBool(value.Opened, false);
			if not IsEnableLobbyMenuOnLocation(company, location, value) then
				isOpened = false;
			end
			if isOpened then
				local item = { Menu = value.name, Order = lobbyMenuList[value.name].Priority};
				if GetWithoutError(value, 'SubMenu') then
					item.SubMenu = self(self, value.SubMenu);
				end
				table.insert(list, item);
			end
		end
		table.sort(list, function(a, b)
			return a.Order < b.Order;
		end);
		return list;
	end
	return BuildMenuList(BuildMenuList, company.LobbyMenu);
end
function IsEnableLobbyMenuOnLocation(company, location, value)
	local lobbyCls = GetClassList('LobbyWorldDefinition')[location];
	local allowLobbyMenu = GetWithoutError(lobbyCls, 'AllowLobbyMenu');
	if allowLobbyMenu and #allowLobbyMenu > 0 then
		if not table.find(allowLobbyMenu, value.name) then
			return false;
		end
	end
	local hideLobbyMenu = GetWithoutError(lobbyCls, 'HideLobbyMenu');
	if hideLobbyMenu and #hideLobbyMenu > 0 then
		if table.find(hideLobbyMenu, value.name) then
			return false;
		end
	end
	return true;
end
------------------------------------------------------------
-- 로비 정보 업데이트 함수
------------------------------------------------------------
function UpdateLobbyInfo(win)

	local location = GetCurrentLobbyType();
	local session = GetSession();
	local company = session.company_info;
	if company.LastLocation.LobbyType == 'LandOfStart' then
		win:hide();
		return;
	end	
	LogAndPrint('location ==>', location)
	-- 1. 로비 우하단 기본 메뉴 업데이트
	UpdateLobbyMenuList(company, location);
	-- 2. 실버라이닝 하단 메뉴.
	UpdateOfficeMenuList(company, location);
	
	-- 3. 로비 메뉴 업데이트
	-- 유아이 기능을 붙이지 않은 데이터 저장용 유아이.
	UpdateLobbyFrameInfo(location);
	
	OnLobbyClockVisibleUpdated(GetOption().Interface.ShowOSClock);
end
function OnLobbyClockVisibleUpdated(on)
	local lobbyMenu = GetRootLayout('LobbyMenu', false);
	lobbyMenu:getChild('Clock'):setVisible(on);
end
function OnUpdateLobbyClock(e)
	local we = CEGUI.toWindowEventArgs(e);
	if IsClient() then
		we.window:setText(GetOSClockString());
	end
end
------------------------------------------------------
-- 오피스 바 메인 메뉴 업데이트
------------------------------------------------------
function UpdateLobbyFrameInfo(location)

	local colorList = GetClassList('Color');
	
	local win = GetRootLayout('LobbyMenu', false);	
	local locationWin = win:getChild('Location');
	local officeLocation = win:getUserData('OfficeLocation');
	
	local session = GetSession();
	local company = session.company_info;
	local roster = session.rosters;
	local isSet = win:getUserData('IsSet');
	
	-- 1. 위치 정보
	local location = GetCurrentLobbyType();
	local locationKey = nil;
	if location == 'Office' then
		locationWin:show();
		locationKey = 'Silverlining';
		if officeLocation == 'Bar' then
			UpdateOfficeInfo();
		end
	elseif location == 'Office_Albus' then
		locationWin:show();
		locationKey = 'AlbusRoom';
		SetLobbyCharacterPosition();
		UpdateOfficeAlbusInfo();
	else
		locationWin:hide();
	end
	if locationKey then
		SetLocaleText(locationWin:getChild('Title'), WordText(locationKey));
	end	
end
------------------------------------------------------------
-- 오피스 화면 이동 메뉴
------------------------------------------------------------
function LobbyEventTriggerTest(events, allFailCallback)
	CreateScriptThread(function()
		local atLeastOneSucceed = false;
		local responsedCount = 0;
		for _, event in ipairs(events) do
			RequestLobbyAction('InvokeClientEvent', {EventType = event}, function(r)
				atLeastOneSucceed = atLeastOneSucceed or r.Success;
				responsedCount = responsedCount + 1;
			end);
		end
		local startTime = os.clock();
		while responsedCount < #events and os.clock() - startTime < 5 and not atLeastOneSucceed do 
			Sleep(50);
		end
		if not ui_session.is_dialog_now and not atLeastOneSucceed then
			allFailCallback();
		end
	end);
end	
function UpdateOfficeMenuList(company, location, noEventTrigger)
	local win = GetRootLayout('LobbyOfficeMenuList', false);
	if location ~= 'Office' and location ~= 'Office_Night' then
		win:hide();
		if location == 'Lobby' then
			local events = TestOfficeLocationClientEvent();
			if #events > 0 then
				if not noEventTrigger then
					for _, event in ipairs(events) do
						RequestLobbyAction('InvokeClientEvent', {EventType = event}, function(r) end);
					end
				end
			end
		end
		return;
	end
	
	local isSet = win:getUserData('IsSet');
	if isSet == nil then
		SetLocaleText(win:getChild('Bar'), WordText('Silverlining'));
		SetLocaleText(win:getChild('Office'), WordText('Office'));
		if StringToBool(company.WorkshopMenu.Unlocked) then
			SetLocaleText(win:getChild('Workshop'), WordText('Workshop'));
		else
			SetLocaleText(win:getChild('Workshop'), WordText('Workshop_Locked'));
		end
		win:getChild('Bar'):setUserData('TooltipAlign', 'Center');
		win:getChild('Office'):setUserData('TooltipAlign', 'Center');
		win:getChild('Workshop'):setUserData('TooltipAlign', 'Center');
		win:setUserData('IsSet', true);
	end
	
	local lobbyWin = GetRootLayout('LobbyMenu', false);
	local officeLocation = lobbyWin:getUserData('OfficeLocation');
	if officeLocation == nil then
		 win:getChild('Bar'):setProperty('Selected', true);
		 officeLocation = lobbyWin:getUserData('OfficeLocation');
	end
	
	-- 1. 이벤트 체크
	
	local events = TestOfficeLocationClientEvent();
	if #events > 0 and not noEventTrigger then
		LobbyEventTriggerTest(events, function()
			UpdateOfficeMenuList(company, location, true);
		end);
		win:hide();
		return;
	end
	ShowSuggestion();

	-- 2. 캐릭터 배치
	SetLobbyCharacterPosition();
	
	-- 3. 사무실 메뉴
	local officeMenu = company.OfficeMenu;
	if StringToBool(officeMenu.Opened, false) then
		win:getChild('Office'):enable();
		win:getChild('Office'):setUserData('Content',nil);
		if StringToBool(officeMenu.Tutorial, false) and officeLocation ~= 'Office' then
			win:getChild('Office'):getChild('Effect'):show();
			win:getChild('Office'):getChild('Effect'):fireEvent('StartShow', CEGUI.EventArgs());
		else
			win:getChild('Office'):getChild('Effect'):fireEvent('Stop', CEGUI.EventArgs());
			win:getChild('Office'):getChild('Effect'):hide();
		end
	else
		win:getChild('Office'):disable();
	end

	-- 4. 작업실 메뉴
	local workshopMenu = company.WorkshopMenu;
	if StringToBool(workshopMenu.Opened, false) then
		win:getChild('Workshop'):enable();
		win:getChild('Workshop'):setUserData('Content',nil);
		if StringToBool(workshopMenu.Tutorial, false) and officeLocation ~= 'Workshop' then
			win:getChild('Workshop'):getChild('Effect'):show();
			win:getChild('Workshop'):getChild('Effect'):fireEvent('StartShow', CEGUI.EventArgs());
		else
			win:getChild('Workshop'):getChild('Effect'):fireEvent('Stop', CEGUI.EventArgs());
			win:getChild('Workshop'):getChild('Effect'):hide();
		end
	else
		win:getChild('Workshop'):disable();
	end
	
	-- 5. 바 메뉴
	local barMenu = company.BarMenu;
	if StringToBool(barMenu.Opened, false) then
		win:getChild('Bar'):enable();
		win:getChild('Bar'):setUserData('Content',nil);
		if StringToBool(barMenu.Tutorial, false) and ( officeLocation == 'Office' or officeLocation == 'Workshop' ) then
			win:getChild('Bar'):getChild('Effect'):show();
			win:getChild('Bar'):getChild('Effect'):fireEvent('StartShow', CEGUI.EventArgs());
		else
			win:getChild('Bar'):getChild('Effect'):fireEvent('Stop', CEGUI.EventArgs());
			win:getChild('Bar'):getChild('Effect'):hide();
		end
	else
		win:getChild('Bar'):disable();
	end
	win:show();
end
------------------------------------------------------------
-- 로비 메뉴 버튼
------------------------------------------------------------
function ReconstructLobbyMenuList(company, location)
	local win = GetRootLayout('LobbyGameMenuList', false);
	local lobbyMenuClsList = GetClassList('LobbyMenu');
	local menuList = GetLobbyMenuList(company, location);
	local menuListWin = win:getChild('MenuList');
	local layout = SetHorizontalLayoutContainer(menuListWin);
	
	local colorList = GetClassList('Color');
	local listWidth = 1920;
	local listHeight = 1080;
	local componentWidth = 50;
	local componentHeight = 50;
	local marginScaleWidth = 1;
	local marginScaleWidthScale = marginScaleWidth/listWidth;
	for i = 1, #menuList do
		local thisMenu = menuList[i];
		local listElem = LoadLayoutCustomized('LobbyMenuButton', 
			{
				NameAndID = { name = thisMenu.Menu, id = i},
				MarginScale = { top = 0, bottom = 0, left = marginScaleWidthScale, right = marginScaleWidthScale }
			}
		);
		local lobbyMenuCls = lobbyMenuClsList[thisMenu.Menu];
		listElem:setWidth(CEGUI.UDim(componentWidth/listWidth, 0));
		listElem:setHeight(CEGUI.UDim(componentHeight/listHeight, 0));
		listElem:setProperty('NormalImage', lobbyMenuCls.Image);
		listElem:setProperty('PushedImage', lobbyMenuCls.PushedImage);
		listElem:setProperty('HoverImage', lobbyMenuCls.Image);
		listElem:setProperty('DisabledImage', lobbyMenuCls.Image);
		listElem:setUserData('MenuActionKey', thisMenu.Menu);
		listElem:setUserData('Title', lobbyMenuCls.Title);
		listElem:setUserData('TitleColor', colorList['Corn'].ARGB);
		listElem:setUserData('Content', lobbyMenuCls.Desc);
		listElem:setUserData('ContentColor', colorList['White'].ARGB);
		listElem:setUserData('KeyBinding', lobbyMenuCls.KeyBinding.name);
		
		-- 서브메뉴 구성
		if thisMenu.SubMenu then
			local subLayout = SetVerticalLayoutContainer(listElem:getChild('SubMenu'));
			for j = 1, #(thisMenu.SubMenu) do
				local thisSubMenu = thisMenu.SubMenu[j];
				local listSubElem = LoadLayoutCustomized('LobbySubMenuButton', 
					{
						NameAndID = { name = thisSubMenu.Menu, id = i},
						MarginScale = { top = 0, bottom = 0, left = 0, right = 0 }
					}
				);
				local lobbyMenuCls = lobbyMenuClsList[thisSubMenu.Menu];
				listSubElem:setWidth(CEGUI.UDim(1, 0));
				listSubElem:setHeight(CEGUI.UDim(1, 0));
				listSubElem:setProperty('NormalImage', lobbyMenuCls.Image);
				listSubElem:setProperty('PushedImage', lobbyMenuCls.PushedImage);
				listSubElem:setProperty('HoverImage', lobbyMenuCls.Image);
				listSubElem:setProperty('DisabledImage', lobbyMenuCls.Image);
				listSubElem:setUserData('MenuActionKey', thisSubMenu.Menu);
				listSubElem:setUserData('Title', lobbyMenuCls.Title);
				listSubElem:setUserData('TitleColor', colorList['Corn'].ARGB);
				listSubElem:setUserData('Content', lobbyMenuCls.Desc);
				listSubElem:setUserData('ContentColor', colorList['White'].ARGB);
				listSubElem:setUserData('KeyBinding', lobbyMenuCls.KeyBinding.name);
				subLayout:addChild(listSubElem);
			end
			NotifyLayout(subLayout);
			listElem:setUserData('SubMenu', true);
		end
		layout:addChild(listElem);
	end
	NotifyLayout(layout);
end
function UpdateLobbyMenuList(company, location)
	local win = GetRootLayout('LobbyGameMenuList', false);
	local menuList = GetLobbyMenuList(company, location);
	local menuListWin = win:getChild('MenuList');
	local isSet = win:getUserData('IsSet');	
	
	if #menuList ~= menuListWin:getChildCount() then
		isSet = nil;
	end	
	if isSet == nil then
		ReconstructLobbyMenuList(company, location);
		win:setUserData('IsSet', true);
	end
	win:show();

	-- 회사 특성 업데이트
	UpdateCompanyMasteryMenu(menuListWin);
	-- 로스터 업데이트
	UpdateRosterMenu(menuListWin);
	-- 야수 목록 업데이트
	UpdateBeastMenu(menuListWin);
	-- 기계 목록 업데이트
	UpdateMachineMenu(menuListWin);
	-- 우편함 업데이트
	UpdateMailBoxMenu(menuListWin);
	-- 퀘스트 업데이트
	UpdateQuestMenu(menuListWin);
	-- 인벤토리 업데이트
	UpdateInvnetoryMenu(menuListWin);
	-- 특성 인벤토리 업데이트
	UpdateMasteryInventoryMenu(menuListWin);
	-- 모듈 인벤토리 업데이트
	UpdateModuleInventoryMenu(menuListWin);
	-- 지역 이동 업데이트
	UpdateZoneMoveMenu(menuListWin);
	-- 친구 목록 업데이트
	UpdateFriendMenu(menuListWin);
end
------------------------------------------------------------
-- 메뉴 버튼
------------------------------------------------------------
function LobbyMenuSubListLostFocus(e)
	local we = CEGUI.toWindowEventArgs(e);
	we.window:hide();
end
function LobbyMenuSelect(e)
	if IsLayoutAnimating() then
		return;
	end	
	local we = CEGUI.toWindowEventArgs(e);
	if we.window:getUserData('SubMenu') then
		local subMenu = we.window:getChild('SubMenu');
		if subMenu:isVisible() then
			subMenu:hide();
		else
			subMenu:show();
			subMenu:activate();
		end
	else
		local menuActionKey = we.window:getUserData('MenuActionKey');
		ShowLobbyMenuSelectByMenuActionKey(menuActionKey);
	end
end
function LobbySubMenuSelect(e)
	if IsLayoutAnimating() then
		return;
	end	
	LobbyMenuSelect(e);
	local we = CEGUI.toWindowEventArgs(e);
	we.window:getParent():hide();
end
function ShowLobbyMenuSelectByMenuActionKey(menuActionKey, forceHide)
	local lastStack = ui_session.layout_stack:getLast();
	local layoutName = nil;
	if lastStack then
		layoutName = lastStack.layout;
	end
	if ui_session.disableMenuShortCut and not forceHide then
		return;
	end
	
	ui_session.disableMenuShortCut = true;

	local location = GetCurrentLobbyType();
	local showType = nil;
	if location == 'Office' then
		showType = 'Office';
		local win = GetRootLayout('LobbyMenu', false);
		local officeLocation = win:getUserData('OfficeLocation');
		if officeLocation then
			showType = officeLocation..'_Menu';
		end
	elseif location == 'Office_Albus' then
		showType = 'Office_Albus_GameMenu';
	end	
	
	-- 스택 레이아웃이 꼬인 것 같지만 강제로 닫아버리자
	if forceHide and layoutName ~= menuActionKey then
		layoutName = menuActionKey;
		-- 스택 레이아웃이 꼬였으면 ReleaseMenuShortCut이 불린다는 걸 보장받을 수 없다.
		ui_session.disableMenuShortCut = false;
	end
	
	if layoutName == 'Company' then
		HideCompany();
	elseif layoutName == 'Roster' then
		HideRosterInfo();
	elseif layoutName == 'Beast' then
		HideBeastInfo();
	elseif layoutName == 'Machine' then
		HideMachineInfo();
	elseif layoutName == 'Inventory' then
		Hide_Inventory();
	elseif layoutName == 'MasteryInventory' then
		HideMasteryInventory();
	elseif layoutName == 'ModuleInventory' then
		HideModuleInventory();
	elseif layoutName == 'ZoneMove' then
		HideZoneMove();
	elseif layoutName == 'Quest' then
		HideQuest();
	elseif layoutName == 'MailBox' then
		CloseMailBox();
	elseif layoutName == 'Option' then
		ResumeSystemMenu();
	elseif layoutName == 'Friend' then
		HideFriendList();
	elseif layoutName == 'LobbyMinimap' then
		HideLobbyMinimap();
	end
	
	if menuActionKey == layoutName then
		LobbyDefaultWindowShow(showType, true);
		return;
	end
	
	LobbyDefaultWindowShow(showType, false);

	if menuActionKey == 'Company' then
		ShowCompanyInfo();
		StackUpLayout('Company', 'NoEvent', 'NoEvent', {'this'}, ReleaseMenuShortCut);
	elseif menuActionKey == 'Roster' then
		ShowRosterInfo();
		StackUpLayout('Roster', 'NoEvent', 'NoEvent', {'this'}, ReleaseMenuShortCut);
	elseif menuActionKey == 'Beast' then
		ShowRosterInfo('Beast');
		StackUpLayout('Beast', 'NoEvent', 'NoEvent', {'this'}, ReleaseMenuShortCut);
	elseif menuActionKey == 'Machine' then
		ShowRosterInfo('Machine');
		StackUpLayout('Machine', 'NoEvent', 'NoEvent', {'this'}, ReleaseMenuShortCut);
	elseif menuActionKey == 'Inventory' then
		ShowInventory();
		StackUpLayoutOnly('Inventory', 'NoEvent', 'NoEvent', {'this'}, ReleaseMenuShortCut);
	elseif menuActionKey == 'MasteryInventory' then
		ShowMasteryInventory();
		StackUpLayoutOnly('MasteryInventory', 'NoEvent', 'NoEvent', {'this'}, ReleaseMenuShortCut);
	elseif menuActionKey == 'ModuleInventory' then
		ShowModuleInventory();
		StackUpLayoutOnly('ModuleInventory', 'NoEvent', 'NoEvent', {'this'}, ReleaseMenuShortCut);
	elseif menuActionKey == 'ZoneMove' then
		ShowZoneMove();
		StackUpLayoutOnly('ZoneMove', 'NoEvent', 'NoEvent', {'this'}, ReleaseMenuShortCut);
	elseif menuActionKey == 'Quest' then
		ShowQuestInfo();
		StackUpLayout('Quest', 'NoEvent', 'NoEvent', {'this'}, ReleaseMenuShortCut);
	elseif menuActionKey == 'MailBox' then
		OpenMailBox(); -- 자기가알아서 스택업하고있음
	elseif menuActionKey == 'Option' then
		SystemMenuLayout(); -- 자기가알아서 스택업하고있음
	elseif menuActionKey == 'Friend' then
		ShowFriendList();
		StackUpLayout('Friend', 'NoEvent', 'NoEvent', {'this'}, ReleaseMenuShortCut);
	elseif menuActionKey == 'LobbyMinimap' then
		ShowLobbyMinimap();
		StackUpLayout('LobbyMinimap', 'NoEvent', 'NoEvent', {'this'}, ReleaseMenuShortCut);
	end	
end
-------------------------------------------------------------
-- PVP 명령어 StartPvPFormation();
------------------------------------------------------------

-------------------------------------------------------------
-- 오피스 키 조작 대응
-------------------------------------------------------------
------------------------------------------------------------
-- 오피스 하단 메뉴 버튼
------------------------------------------------------------
function EscapeKeyShortCutInLobby()
	local win = GetRootLayout('LobbyMenu', false);
	local officeLocation = win:getUserData('OfficeLocation');
	if officeLocation then
		if officeLocation == 'Office' or officeLocation == 'Workshop' then
			SelectOfficeMenuButton('Bar')();
		else
			SystemMenuLayout();
		end		
	else
		SystemMenuLayout();
	end	
end
function EscapeMouseShortCutInLobby()
	if IsOfficeMode() then
		return EscapeKeyShortCutInLobby();
	else
		return false;
	end
end
function ArrowRightKeyShortCutInLobby()
	local win = GetRootLayout('LobbyMenu', false);
	local officeLocation = win:getUserData('OfficeLocation');
	if officeLocation then
		if officeLocation == 'Bar' then
			SelectOfficeMenuButton('Workshop')();
		elseif officeLocation == 'Office' then
			SelectOfficeMenuButton('Bar')();
		end		
	end
end
function ArrowLeftKeyShortCutInLobby()
	local win = GetRootLayout('LobbyMenu', false);
	local officeLocation = win:getUserData('OfficeLocation');
	if officeLocation then
		if officeLocation == 'Bar' then
			SelectOfficeMenuButton('Office')();
		elseif officeLocation == 'Workshop' then
			SelectOfficeMenuButton('Bar')();
		end		
	end
end
function KeyShortCutInLobby(key)
	return function(forceHide)
		local menuActionKeyList = {
			C = 'Company',
			R = 'Roster',
			B = 'Beast',
			N = 'Machine',
			Q = 'Quest',
			I = 'Inventory',
			P = 'MailBox',
			T = 'MasteryInventory',
			U = 'ModuleInventory',
			L = 'ZoneMove',
			M = 'LobbyMinimap',
		};
		if forceHide then
			ShowLobbyMenuSelectByMenuActionKey(menuActionKeyList[key], true);
			return;
		end
		if IsLayoutAnimating() then
			return;
		end
		if IsMissionMode() then
			return;
		end
		if IsDialogMode() then
			return;
		end
		if IsOfficeMode() and key == 'M' then
			return;
		end
		local chatWin = GetRootLayout('ChatWindow', false);
		if chatWin:isActive() and chatWin:getChild('Edit'):isActive() then
			return;
		end
		local lobbyGameMenuListWin = GetRootLayout('LobbyGameMenuList', false);
		if not lobbyGameMenuListWin:isVisible() then
			if key ~= 'R' and key ~= 'B' and key ~= 'N' then
				return;
			else
				local rosterWin = GetRootLayout('Roster', false);
				local beastWin = GetRootLayout('Beast', false);
				local machineWin = GetRootLayout('Machine', false);
				if not rosterWin:isVisible() and not beastWin:isVisible() and not machineWin:isVisible() then
					return;
				end
			end
		end
		local menuListWin = lobbyGameMenuListWin:getChild('MenuList');
		if not IsChildWindow(menuListWin, menuActionKeyList[key]) then
			return;
		end
		ShowLobbyMenuSelectByMenuActionKey(menuActionKeyList[key]);
	end
end
function KeyShortCutInLobbyMailbox(key)
	return function () MailboxSafeAction(KeyShortCutInLobby(key)); end;
end
function KeyShortCutInLobby_C(e)
	KeyShortCutInLobby('C')(true);
end
function KeyShortCutInLobby_Q(e)
	KeyShortCutInLobby('Q')(true);
end
function KeyShortCutInLobby_I(e)
	KeyShortCutInLobby('I')(true);
end
function KeyShortCutInLobby_P(e)
	KeyShortCutInLobby('P')(true);
end
function KeyShortCutInLobby_T(e)
	KeyShortCutInLobby('T')(true);
end
function KeyShortCutInLobby_U(e)
	KeyShortCutInLobby('U')(true);
end
function KeyShortCutInLobby_L(e)
	KeyShortCutInLobby('L')(true);
end
function KeyShortCutInLobby_R(e)
	KeyShortCutInLobby('R')(true);
end
function KeyShortCutInLobby_B(e)
	KeyShortCutInLobby('B')(true);
end
function KeyShortCutInLobby_N(e)
	KeyShortCutInLobby('N')(true);
end
function KeyShortCutInLobby_M(e)
	KeyShortCutInLobby('M')(true);
end
------------------------------------------------------------
-- 오피스 메뉴 버튼
------------------------------------------------------------
function OfficeMenuSelect(e)
	if IsLayoutAnimating() then
		return;
	end	
	local we = CEGUI.toWindowEventArgs(e);
	if we.window:getProperty('Selected') == 'false' then
		return;
	end
	local menuActionKey = we.window:getName();
	ShowOfficeMenuSelectByMenuActionKey(menuActionKey);
end
-------------------------------------------------------------
-- 오피스 화면 이동 메뉴 클릭 버튼
-------------------------------------------------------------
function SelectOfficeMenuButton(menuActionKey)
	return function()
		if not IsOfficeMode() or IsDialogMode() then
			return;
		end
		local win = GetRootLayout('LobbyOfficeMenuList', false);
		local toggleWin = win:getChild(menuActionKey);
		if toggleWin:isDisabled() then
			return;
		end
		local toggleButton = CEGUI.toToggleButton(toggleWin);
		toggleButton:setSelected(true);
	end
end
function ShowOfficeMenuSelectByMenuActionKey(menuActionKey, noEventTrigger)
	-- 1) 현재 오피스 위치값을 저장한다.
	local company = GetSession().company_info;
	local cameraKey = nil;
	local cameraCallback = nil;
	local lastStack = ui_session.layout_stack:getLast();
	if menuActionKey == 'Office' then
		cameraKey = menuActionKey;
		local barWin = GetRootLayout('Bar', false);
		local workShopWin = GetRootLayout('Workshop', false);
		if barWin:isVisible() then
			barWin:hide();
		end
		if workShopWin:isVisible() then
			HideWorkshopInfo();
		end
		-- 바에 독립적으로 열려있는 UI 닫아주기 --
		StackClearLayout(EmptyFunc);
		ShowOfficeInfo();
	elseif menuActionKey == 'Workshop' then
		if not StringToBool(company.WorkshopMenu.Opened, false) then
			return;
		end
		cameraKey = menuActionKey;
		local barWin = GetRootLayout('Bar', false);
		local officeWin = GetRootLayout('Office', false);
		if barWin:isVisible() then
			barWin:hide();
		end
		if officeWin:isVisible() then
			HideOfficeInfo();
		end
		-- 바에 독립적으로 열려있는 UI 닫아주기 --
		StackClearLayout(EmptyFunc);
		ShowWorkshopInfo();
	elseif menuActionKey == 'Bar' then
		cameraKey = 'Base';
		local officeWin = GetRootLayout('Office', false);
		local workShopWin = GetRootLayout('Workshop', false);
		if workShopWin:isVisible() then
			HideWorkshopInfo();
		end
		if officeWin:isVisible() then
			HideOfficeInfo();
		end
		UpdateOfficeAssets();
		StackClearLayout(EmptyFunc);
		local win = GetRootLayout('LobbyMenu', false);
		win:setUserData('OfficeLocation', menuActionKey);
		UpdateLobbyFrameInfo('Office');
	end
	-- 현재값 저장.
	local win = GetRootLayout('LobbyMenu', false);
	win:setUserData('OfficeLocation', menuActionKey);
	local events = noEventTrigger and {} or TestOfficeLocationClientEvent();
	-- 화면 이동.
	if cameraKey then
		StartLobbyCameraMode(cameraKey, function()
			if #events > 0 then
				LobbyEventTriggerTest(events, function()
					EnableLobbyLayoutKeyBinding(true);
					EnableLobbyLayoutMouseBinding(true);
					GetRootLayout('LobbyMenu', false):show();
					ShowOfficeMenuSelectByMenuActionKey(menuActionKey, true);
				end);
			end
		end, true);
		-- 화면 효과
		EnablePostEffect('Gaussian Blur', true);
		CreateScriptThread(function()
			Sleep(800);
			EnablePostEffect('Gaussian Blur', false);
		end);
		if #events > 0 then
			EnableLobbyLayoutKeyBinding(false);
			EnableLobbyLayoutMouseBinding(false);
			local officeWin = GetRootLayout('Office', false);
			local workShopWin = GetRootLayout('Workshop', false);
			if workShopWin:isVisible() then
				HideWorkshopInfo();
			end
			if officeWin:isVisible() then
				HideOfficeInfo();
			end
			StackClearLayout(EmptyFunc);
			GetRootLayout('LobbyMenu', false):hide();
			GetRootLayout('LobbyGameMenuList', false):hide();
		end
	end
	-- StartLobbyCameraMode 함수의 콜백으로 이벤트 처리를 하면 LobbyOfficeMenuList UI만 숨김
	if cameraKey and #events > 0 and not noEventTrigger then
		GetRootLayout('LobbyOfficeMenuList', false):hide();
	else
		UpdateOfficeMenuList(company, 'Office', true);
	end
	
	PlaySound('CameraMove.wav', 'Layout', 1);
end
-------------------------- 메뉴 버튼 툴팁  --------------------------
function EnterMenuButton(e)
	local colorList = GetClassList('Color');
	local we = CEGUI.toWindowEventArgs(e);
	local icon  = we.window:getChild('Icon');
	local pos = we.window:getOuterRectClipper();
	local title = we.window:getUserData('Title');
	local tooltipAlign = we.window:getUserData('TooltipAlign');
	local align = 'Center';
	if tooltipAlign then
		align = tooltipAlign;
	end
	if title then
		ShowToolTip_Line(title, colorList['WhiteYellow'].ARGB, pos, align);
	end
	if icon then
		icon:setProperty('ImageColours', colorList['Black'].ColorRect);
	end
end
function LeaveMenuButton(e)
	local we = CEGUI.toWindowEventArgs(e);
	local colorList = GetClassList('Color');
	local icon  = we.window:getChild('Icon');
	if icon then
		icon:setProperty('ImageColours', colorList['White'].ColorRect);
	end
	HideToolTip_Line();
end
-------------------------- 메뉴 버튼 툴팁  --------------------------
function EnterMenuButton_Mission(e)
	local colorList = GetClassList('Color');
	local we = CEGUI.toWindowEventArgs(e);
	local icon  = we.window:getChild('Icon');
	local pos = we.window:getOuterRectClipper();
	local title = we.window:getUserData('Title');
	local content = we.window:getUserData('Content');
	local tooltipAlign = we.window:getUserData('TooltipAlign');
	local titleColor = we.window:getUserData('TitleColor');
	local contentColor = we.window:getUserData('ContentColor');
	local tooltipWidth = we.window:getUserData('TooltipWidth');
	local bindingName = we.window:getUserData('KeyBinding');
	if tooltipAlign == nil then
		tooltipAlign = 'Center';
	end	
	if tooltipWidth == nil then
		tooltipWidth = 350;
	end
	if titleColor == nil then
		titleColor = colorList['WhiteYellow'].ARGB;
	end	
	if contentColor == nil then
		contentColor = colorList['White'].ARGB;
	end
	if title then
		if bindingName then
			local keyBinding = GetKeyBinding(bindingName);
			if keyBinding then
				for _, level in ipairs({'Primary', 'Secondary'}) do
					local keyInfo = keyBinding[level];
					if keyInfo then
						local keyText = GetKeyInfoText(keyInfo);
						title = string.format('[colour=\'%s\']%s([colour=\'FFFFFFFF\']%s[colour=\'%s\'])', titleColor, title, keyText, titleColor);
						titleColor = colorList['White'].ARGB;
						break;
					end
				end
			end
		end
		if content and content ~= '' then
			ShowToolTip_Simple(title, content, tooltipWidth, titleColor, contentColor, pos, tooltipAlign, false);
		else
			ShowToolTip_Line(title, titleColor, pos, tooltipAlign);
		end
	end
	if icon then
		icon:show();
	end
end
function LeaveMenuButton_Mission(e)
	local we = CEGUI.toWindowEventArgs(e);
	local colorList = GetClassList('Color');
	local icon = we.window:getChild('Icon');
	local content = we.window:getUserData('Content');
	if icon then
		icon:hide();
	end
	if content and content ~= '' then
		HideToolTip_Simple();
	else
		HideToolTip_Line();
	end
end
------------------------- 메뉴 버튼 툴팁  --------------------------
function EnterInstantEquipDialog(e)
	local colorList = GetClassList('Color');
	local we = CEGUI.toWindowEventArgs(e);
	local text  = we.window:getChild('Content');
	text:setProperty('NormalTextColour', colorList['WhiteYellow'].ColorRectGradation);
end
function LeaveInstantEquipDialog(e)
	local colorList = GetClassList('Color');
	local we = CEGUI.toWindowEventArgs(e);
	local text  = we.window:getChild('Content');
	text:setProperty('NormalTextColour', colorList['White'].ColorRectGradation);
end
-------------------------- 오피스 캐릭터 배치.  --------------------------
function SetLobbyCharacterPosition()
	local camPointCls = GetCurrentCameraPoint();
	if not camPointCls then
		return;
	end
	local charSlots = GetWithoutError(camPointCls, 'CharacterSlot');
	if not charSlots then
		return;
	end

	local session = GetSession();
	local company = session.company_info;
	local roster = session.rosters;
	if (camPointCls.name == 'Office' or camPointCls.name == 'Roster_Office') and company.Progress.Tutorial.OfficeCharPosition == 'AlbusStand' then
		DeployRosterOnCameraPoint(1, 'AlbusStd');
	else
		local rosterSlotIndexMap = {};
		for index, pcInfo in ipairs (roster) do
			if pcInfo.RosterType == 'Pc' then
				if GetWithoutError(charSlots, pcInfo.name) then
					DeployRosterOnCameraPoint(index, pcInfo.name);
				elseif index <= #charSlots then
					DeployRosterOnCameraPoint(index, pcInfo.OfficeSlot);
				end
			elseif (pcInfo.RosterType == 'Beast' and not pcInfo.Stored) or pcInfo.RosterType == 'Machine' then
				local menuOpened = SafeIndex(company, 'LobbyMenu', pcInfo.RosterType, 'Opened');
				if StringToBool(menuOpened, false) then
					local lobbySlot = '';
					if pcInfo.RosterType == 'Beast' then
						lobbySlot = SafeIndex(pcInfo, 'BeastType', 'LobbySlot');
					else
						lobbySlot = SafeIndex(pcInfo, 'MachineType', 'LobbySlot');
					end
					local rosterSlotIndex = rosterSlotIndexMap[lobbySlot] or 1;
					local slotName = lobbySlot..rosterSlotIndex;
					rosterSlotIndexMap[lobbySlot] = rosterSlotIndex + 1;
					if GetWithoutError(charSlots, slotName) then
						DeployRosterOnCameraPoint(index, slotName);
					end
				end
			end
		end
	end
end
---------------------------  오피스 사수 거리 가기 ------------------------------------------------
function GoLobbyClicked(e)
	local session = GetSession();
	local company = session.company_info;
	if not company.UnlockGoLobby then
		YesNoDialog(GetWord('MoveLocation'), GuideMessage('OfficeLocationMsg'), function()
			RequestMoveLocationWithFrontmessage('ShooterStreet');
		end);	
	end
end
---------------------------  사무실 돌아가기 ------------------------------------------------
function GoOfficeClicked(e)
	YesNoDialog(GetWord('MoveLocation'), GuideMessage('OfficeLocationMsg'), function()
		RequestMoveLocationWithFrontmessage('Office');
	end);
end
------------------------------------------------------------
-- 로비 디폴트 유아이 모두 켜는 함수.
------------------------------------------------------------	
function LobbyDefaultWindowShow(showType, visible)

	if not showType then
		return;
	end
	local lobbyMenuWin = GetRootLayout('LobbyMenu', false);
	local workshopWin = GetRootLayout('Workshop', false);
	local officeWin = GetRootLayout('Office', false);
	local officeWin_Albus = GetRootLayout('Office_Albus', false);
	local lobbyGameMenuWin = GetRootLayout('LobbyGameMenuList', false); 
	local lobbyOfficeMenuWin = GetRootLayout('LobbyOfficeMenuList', false);
	local officeBarWin = GetRootLayout('Bar', false);
	local suggestionWin = GetRootLayout('Suggestion', false);
	
	
	local isLobbyGameMenu = false;
	local isLobbyOfficeMenu = false;
	local isWorkshopMenu = false;
	local isOfficeMenu = false;
	local isOfficeMenu_Albus = false;
	local isLobbyMenu = false;
	local isBarMenu = false;
	local isSuggestionMenu = false;
	
	if showType == 'Lobby' then
		isLobbyMenu = true;
		isLobbyGameMenu = true;
	elseif showType == 'Office' then
		isLobbyGameMenu = true;
		isLobbyOfficeMenu = true;
		isBarMenu = true;
		isSuggestionMenu = true;
	elseif showType == 'Office_Albus' then
		isLobbyGameMenu = true;
		isOfficeMenu_Albus = true;
	elseif showType == 'Workshop' then
		isLobbyGameMenu = true;
		isLobbyOfficeMenu = true;
		isWorkshopMenu = true;
		isSuggestionMenu = true;
	elseif showType == 'Office2' then 
		isLobbyGameMenu = true;
		isLobbyOfficeMenu = true;
		isOfficeMenu = true;
		isSuggestionMenu = true;
	elseif showType == 'Office_Menu' then 
		isOfficeMenu = true;
	elseif showType == 'Workshop_Menu' then 
		isWorkshopMenu = true;
	elseif showType == 'Bar_Menu' then
		isLobbyMenu = true;
	elseif showType == 'Lobby_WorldMap' then
		isLobbyMenu = true;
		isLobbyGameMenu = true;
	elseif showType == 'Formation_Bar' then
		isLobbyMenu = true;
		isLobbyGameMenu = true;
		isLobbyOfficeMenu = true;
		isSuggestionMenu = true;
	elseif showType == 'Formation_Office' then
		isOfficeMenu = true;
		isLobbyGameMenu = true;
		isLobbyOfficeMenu = true;
		isSuggestionMenu = true;
	elseif showType == 'Formation_Workshop' then
		isWorkshopMenu = true;
		isLobbyGameMenu = true;
		isLobbyOfficeMenu = true;
		isSuggestionMenu = true;
	elseif showType == 'MailBox_Dialog' then
		isLobbyGameMenu = true;
		isSuggestionMenu = true;
	end
	
	if visible then
		if isLobbyMenu and not lobbyMenuWin:isVisible() then
			lobbyMenuWin:show();
		end
		if isLobbyGameMenu and not lobbyGameMenuWin:isVisible() then
			lobbyGameMenuWin:show();
		end
		if isLobbyOfficeMenu and not lobbyOfficeMenuWin:isVisible() then
			lobbyOfficeMenuWin:show();
		end
		if isOfficeMenu and not officeWin:isVisible() then
			officeWin:show();
		end
		if isWorkshopMenu and not workshopWin:isVisible() then
			workshopWin:show();
		end
		if isOfficeMenu_Albus and not officeWin_Albus:isVisible() then
			officeWin_Albus:show();
			officeWin_Albus:fireEvent('Stop', CEGUI.EventArgs());
			officeWin_Albus:fireEvent('StartShow', CEGUI.EventArgs());
		end
		if isBarMenu and not officeBarWin:isVisible() then
			officeBarWin:show();
		end
		if isSuggestionMenu and not suggestionWin:isVisible() then
			suggestionWin:show();
		end
	else
		if isLobbyMenu and lobbyMenuWin:isVisible() then
			lobbyMenuWin:hide();
		end
		if isLobbyGameMenu and lobbyGameMenuWin:isVisible() then
			lobbyGameMenuWin:hide();
		end
		if isLobbyOfficeMenu and lobbyOfficeMenuWin:isVisible() then
			lobbyOfficeMenuWin:hide();
		end	
		if isOfficeMenu and officeWin:isVisible() then
			officeWin:hide();
		end
		if isWorkshopMenu and workshopWin:isVisible() then
			workshopWin:hide();
		end
		if isOfficeMenu_Albus and officeWin_Albus:isVisible() then
			officeWin_Albus:hide();
		end
		if isBarMenu and officeBarWin:isVisible() then
			officeBarWin:hide();
		end
		if isSuggestionMenu and suggestionWin:isVisible() then
			suggestionWin:hide();
		end
	end
end
----------------------------------------------------------------------------------------------------------
-- 바 메뉴 관련.
----------------------------------------------------------------------------------------------
function BarChangeMode(e)
	local we = CEGUI.toWindowEventArgs(e);
	local barKey = we.window:getName();
	SetBarChangeMode(barKey, true);
end
function LobbyShortCutLock(e)
	CreateScriptThread(function()
		EnableLobbyLayoutKeyBinding(false);
	end);
end
function LobbyShortCutUnlock(e)
	EnableLobbyLayoutKeyBinding(true);
	return true;
end
function LobbyMouseBindingLock(e)
	CreateScriptThread(function()
		EnableLobbyLayoutMouseBinding(false);
	end);
	return true;
end
function LobbyMouseBindingUnlock(e)
	CreateScriptThread(function()
		EnableLobbyLayoutMouseBinding(true);
	end);
	return true;
end
function GetCurrentLobbyType()
	local location = '';
	if IsLobbyMode() then
		location = 'Lobby';
	else
		local lobbyDefinitionClass = GetLobbyDefinitionClass();
		if lobbyDefinitionClass.name == 'Office' then
			location = 'Office';
		elseif lobbyDefinitionClass.name == 'Office_Albus' then
			location = 'Office_Albus';
		elseif lobbyDefinitionClass.name == 'Office_Night' then
			location = 'Office_Night';
		end
	end
	return location;
end
------------------------------------------------------
-- 실버라이닝 바 메뉴 업데이트
------------------------------------------------------
function UpdateOfficeInfo()
	
	local colorList = GetClassList('Color');
	
	local session = GetSession();
	local company = session.company_info;
	local barMenu = company.BarMenu;
	local win = GetRootLayout('Bar', false);
	
	local leaveButton = win:getChild('Leave');
	local jukeBoxButton = win:getChild('JukeBox');

	-- 1. 초기 세팅	
	AttachWindowToScenePos(leaveButton, { x = -380, y = 300, z = -100 });
	AttachWindowToScenePos(jukeBoxButton, { x = 130, y = 285, z = -530 });
	
	local tagNormalColor = "tl:6AFFFFFF tr:6AFFFFFF bl:6AFFFFFF br:6AFFFFFF";
	local tagHighlightColor = colorList['Yellow'].ColorRect;
	local outLineColor =  colorList['Yellow'].ARGB;
	
	local animationList = {};
	
	-- 1) 나가기 버튼.
	if StringToBool(barMenu.Leave.Opened, false) then
		table.insert(animationList, { Win = jukeBoxButton, Index = 1, Distance = -60});
		leaveButton:setUserData('AssetOutline', { 'Exit' } );
		leaveButton:setUserData('AssetOutlineColor', outLineColor);
		if company.Progress.Tutorial.Office == 12 or company.Progress.Tutorial.Office == 13 then
			SetLocaleText(leaveButton:getChild('Title'), WordText('Bar_Leave'));
			leaveButton:show();
			leaveButton:getChild('Tag'):setProperty('ImageColours', tagHighlightColor);
			leaveButton:getChild('Frame'):show();
			leaveButton:getChild('Frame'):fireEvent('StartShow', CEGUI.EventArgs());			
		else			
			leaveButton:hide();
		end
	else
		leaveButton:hide();
	end	
	
	-- 2) 쥬크박스 버튼.
	if StringToBool(barMenu.JukeBox.Opened, false) then
		table.insert(animationList, { Win = jukeBoxButton, Index = 2, Distance = -60});
		jukeBoxButton:setUserData('AssetOutline', { 'JukeBox' } );
		jukeBoxButton:setUserData('AssetOutlineColor', outLineColor);
		jukeBoxButton:getChild('Tag'):setProperty('ImageColours', tagNormalColor);
		SetLocaleText(jukeBoxButton:getChild('Title'), WordText('Bar_JukeBox'));
	else
		jukeBoxButton:hide();
	end
	-- 7) 버튼 애니메이션
	if #animationList > 0 then
		table.sort(animationList, function (a, b)
		return a.Index < b.Index;
		end);
	end
	ShowLobbyMenuSelectSlotEffect(animationList);	
	win:show();
end
------------------------------------------------------
-- 오피스 알버스 메인 메뉴 업데이트
------------------------------------------------------
function UpdateOfficeAlbusInfo()

	local colorList = GetClassList('Color');

	local session = GetSession();
	local company = session.company_info;
	local lobbyMenu = company.LobbyMenu;

	local win = GetRootLayout('Office_Albus', false);
	
	local companyButton = win:getChild('Company');
	local rosterButton = win:getChild('Roster');
	local questButton = win:getChild('Quest');
	local inventoryButton = win:getChild('Inventory');
	local masteryInventoryButton = win:getChild('MasteryInventory');
	local mailButton = win:getChild('MailBox');
	local endButton = win:getChild('End');

	-- 1. 초기 세팅	
	SetLocaleText(companyButton:getChild('Title'), WordText('AlbusRoom_Company'));	
	SetLocaleText(rosterButton:getChild('Title'), WordText('AlbusRoom_Roster'));
	SetLocaleText(questButton:getChild('Title'), WordText('AlbusRoom_Quest'));
	SetLocaleText(inventoryButton:getChild('Title'), WordText('AlbusRoom_Inventory'));
	SetLocaleText(masteryInventoryButton:getChild('Title'), WordText('AlbusRoom_MasteryInventory'));
	SetLocaleText(mailButton:getChild('Title'), WordText('AlbusRoom_Mail'));
	SetLocaleText(endButton:getChild('Title'), WordText('AlbusRoom_End'));

	AttachWindowToScenePos(companyButton, { x = 225, y = 760, z = -675 });
	AttachWindowToScenePos(rosterButton, { x = 255, y = 810, z = -825 });
	AttachWindowToScenePos(questButton, { x = 375, y = 810, z = -525 });
	AttachWindowToScenePos(inventoryButton, { x = 75, y = 950, z = -900 });
	AttachWindowToScenePos(masteryInventoryButton, { x = 525, y = 900, z = -750 });
	AttachWindowToScenePos(mailButton, { x = 255, y = 810, z = -825 });
	AttachWindowToScenePos(endButton, { x = 0, y = 830, z = -525 });
	
	local test = false;
	if test then
		companyButton:show();
		rosterButton:show();
		questButton:show();
		inventoryButton:show();
		masteryInventoryButton:show();
		mailButton:show();
		return;
	end

	local animationList = {};
	local outLineColor = colorList['Yellow'].ARGB;	
	local tagNormalColor = "tl:6AFFFFFF tr:6AFFFFFF bl:6AFFFFFF br:6AFFFFFF";
	local tagHighlightColor = colorList['Yellow'].ColorRect;
	
	-- 1) 회사 메뉴
	if not StringToBool(lobbyMenu.Company.Opened, false) then
		companyButton:show();
		companyButton:setUserData('AssetOutline', { 'Box1', 'Box2','Box3', 'Box4' } );
		companyButton:setUserData('AssetOutlineColor', outLineColor);
		
		table.insert(animationList, { Win = companyButton, Index = 3, Distance = 60});
		
		companyButton:getChild('Tag'):setProperty('ImageColours', tagHighlightColor);
		companyButton:getChild('Frame'):show();
		companyButton:getChild('Frame'):fireEvent('StartShow', CEGUI.EventArgs());	
		SetNamedAssetVisible('Box1', true);
		SetNamedAssetVisible('Box2', true);
		SetNamedAssetVisible('Box3', true);
		SetNamedAssetVisible('Box4', true);
	else
		companyButton:hide();
		SetNamedAssetVisible('Box1', false);
		SetNamedAssetVisible('Box2', false);
		SetNamedAssetVisible('Box3', false);
		SetNamedAssetVisible('Box4', false);
	end
	-- 2) 사원 메뉴 메뉴
	if not StringToBool(lobbyMenu.Roster.Opened, false) and 
		StringToBool(lobbyMenu.MasteryInventory.Opened, false) and
		StringToBool(lobbyMenu.Company.Opened, false) and
		StringToBool(lobbyMenu.Quest.Opened, false) and
		StringToBool(lobbyMenu.Inventory.Opened, false)
	then
		rosterButton:show();
		rosterButton:setUserData('AssetOutline', { 'Computer01' } );
		rosterButton:setUserData('AssetOutlineColor', outLineColor);
		
		table.insert(animationList, { Win = rosterButton, Index = 3, Distance = 60});
		
		rosterButton:getChild('Tag'):setProperty('ImageColours', tagHighlightColor);
		rosterButton:getChild('Frame'):show();
		rosterButton:getChild('Frame'):fireEvent('StartShow', CEGUI.EventArgs());	
	else
		rosterButton:hide();
	end
	-- 3) 의뢰 목록 메뉴
	if not StringToBool(lobbyMenu.Quest.Opened, false) then
		questButton:show();
		questButton:setUserData('AssetOutline', { 'Desk'} );
		questButton:setUserData('AssetOutlineColor', outLineColor);
		
		table.insert(animationList, { Win = questButton, Index = 2, Distance = 60});
		
		questButton:getChild('Tag'):setProperty('ImageColours', tagHighlightColor);
		
		questButton:getChild('Frame'):show();
		questButton:getChild('Frame'):fireEvent('StartShow', CEGUI.EventArgs());	
		SetNamedAssetVisible('Desk', true);
	else
		questButton:hide();
		SetNamedAssetVisible('Desk', false);
	end
	-- 4) 인벤토리 메뉴
	if not StringToBool(lobbyMenu.Inventory.Opened, false) then
		inventoryButton:show();
		inventoryButton:setUserData('AssetOutline', { 'Objects01', 'Objects02', 'Objects03'} );
		inventoryButton:setUserData('AssetOutlineColor', outLineColor);
		
		table.insert(animationList, { Win = inventoryButton, Index = 1, Distance = 60});
		
		inventoryButton:getChild('Tag'):setProperty('ImageColours', tagHighlightColor);

		inventoryButton:getChild('Frame'):show();
		inventoryButton:getChild('Frame'):fireEvent('StartShow', CEGUI.EventArgs());	
		SetNamedAssetVisible('Objects01', true);
		SetNamedAssetVisible('Objects02', true);
		SetNamedAssetVisible('Objects03', true);
	else
		SetNamedAssetVisible('Objects01', false);
		SetNamedAssetVisible('Objects02', false);
		SetNamedAssetVisible('Objects03', false);
		inventoryButton:hide();
	end
	-- 5) 특성 목록 메뉴
	if not StringToBool(lobbyMenu.MasteryInventory.Opened, false) then
		masteryInventoryButton:show();
		masteryInventoryButton:setUserData('AssetOutline', { 'Books01', 'Books02', 'Books03'} );
		masteryInventoryButton:setUserData('AssetOutlineColor', outLineColor);
		
		table.insert(animationList, { Win = masteryInventoryButton, Index = 5, Distance = 60});
		
		masteryInventoryButton:getChild('Tag'):setProperty('ImageColours', tagHighlightColor);
	
		masteryInventoryButton:getChild('Frame'):show();
		masteryInventoryButton:getChild('Frame'):fireEvent('StartShow', CEGUI.EventArgs());
		SetNamedAssetVisible('Books01', true);
		SetNamedAssetVisible('Books02', true);
		SetNamedAssetVisible('Books03', true);
	else
		SetNamedAssetVisible('Books01', false);
		SetNamedAssetVisible('Books02', false);
		SetNamedAssetVisible('Books03', false);
		masteryInventoryButton:hide();
	end
	-- 6) 메일 메뉴
	if not StringToBool(lobbyMenu.MailBox.Opened, false) and 
		company.Progress.Tutorial.Roster == 7 and
		not StringToBool(lobbyMenu.Roster.Tutorial, false) and
		StringToBool(lobbyMenu.Company.Opened, false) and
		StringToBool(lobbyMenu.Roster.Opened, false) and
		StringToBool(lobbyMenu.Quest.Opened, false) and
		StringToBool(lobbyMenu.Inventory.Opened, false) and
		StringToBool(lobbyMenu.MasteryInventory.Opened, false)
	then
		mailButton:show();
		mailButton:setUserData('AssetOutline', { 'Computer01'} );
		mailButton:setUserData('AssetOutlineColor', outLineColor);
		
		table.insert(animationList, { Win = mailButton, Index = 5, Distance = 60});
		
		mailButton:getChild('Tag'):setProperty('ImageColours', tagHighlightColor);
		mailButton:getChild('Frame'):show();
		mailButton:getChild('Frame'):fireEvent('StartShow', CEGUI.EventArgs());	
	else
		mailButton:hide();
	end
	-- 7) 나가기 버튼.
	if company.Progress.Tutorial.Roster >= 11 and StringToBool(lobbyMenu.MailBox.Opened, false) then
		endButton:show();
		endButton:setUserData('AssetOutline', { 'Exit'} );
		endButton:setUserData('AssetOutlineColor', outLineColor);
		
		table.insert(animationList, { Win = endButton, Index = 7, Distance = 60});
		
		endButton:getChild('Tag'):setProperty('ImageColours', tagHighlightColor);
		
		endButton:getChild('Frame'):show();
		endButton:getChild('Frame'):fireEvent('StartShow', CEGUI.EventArgs());	
		SetNamedAssetVisible('Computer01', false);
		SetNamedAssetVisible('Computer02', false);
	else
		SetNamedAssetVisible('Computer01', true);
		SetNamedAssetVisible('Computer02', true);
		endButton:hide();
	end
	
	-- 8) 버튼 애니메이션
	if #animationList > 0 then
		table.sort(animationList, function (a, b)
		return a.Index < b.Index;
		end);
	end
	ShowLobbyMenuSelectSlotEffect(animationList);
	
	-- 이벤트 특성목록 + 로스터.
	if company.Progress.Tutorial.Roster == 0 and 
		StringToBool(lobbyMenu.MasteryInventory.Opened, false) and
		StringToBool(lobbyMenu.Roster.Opened, false) and
		StringToBool(lobbyMenu.Roster.Tutorial, false)
	then
		CreateScriptThread(function()
			Sleep(1000);
			RequestLobbyAction('InvokeClientEvent', {EventType='RosterTutorial1'}, function (r)end);
		end);		
	end
end
----------------------------------------------------------------------
-- 바 모드 버튼
----------------------------------------------------------------------
-- 실행 버튼
function BarChangeMode(e)
	local we = CEGUI.toWindowEventArgs(e);
	local officeKey = we.window:getName();
	SetBarChangeMode(officeKey, true);
end
function SetBarChangeMode(officeKey, isUpStack)	-- 카메라 키
	local cameraKey = nil;
	if isUpStack then
		local location = GetCurrentLobbyType();
		local session = GetSession();
		local company = session.company_info;
		if location == 'Office' then
			if company.Progress.Tutorial.Office == 12 or company.Progress.Tutorial.Office == 13 then
				RequestLobbyAction('InvokeClientEvent', {EventType='PlayRamjiPlaza'}, function (r)end);
				return;
			end
		end
		GetChatLayout():hide();
		if officeKey == 'JukeBox' then
--			cameraKey = officeKey;
			ShowJukeBox();
			StackUpLayout(officeKey, 'NoEvent', 'NoHideEvent', {'this'}, EmptyFunc);	
		end
		LobbyDefaultWindowShow('Office', false);
	else
		if officeKey == 'Bar' then
			local win = GetRootLayout('Bar', false);
			win:show();
			UpdateOfficeInfo();
			LobbyDefaultWindowShow('Office', true);
			PlaySound('Window_Out.wav', 'Layout', 1);
		end
	end
	-- 화면 이동.
	if cameraKey then
		StartLobbyCameraMode(cameraKey, EmptyFunc, true);
		-- 화면 효과
		EnablePostEffect('Gaussian Blur', true);
		CreateScriptThread(function()
			Sleep(800);
			EnablePostEffect('Gaussian Blur', false);			
		end);
	end
end
----------------------------------------------------------------------
-- 오피스 모드 버튼
----------------------------------------------------------------------
-- 실행 버튼
function OfficeAlbusChangeMode(e)
	local we = CEGUI.toWindowEventArgs(e);
	local officeKey = we.window:getName();
	SetOfficeAlbusChangeMode(officeKey, true);
end
-- 오피스 열기 닫기 함수.
function SetOfficeAlbusChangeMode(officeKey, isUpStack)
	if isUpStack then
		local key = 'GameMenu_'..officeKey;
		RequestLobbyAction('InvokeClientEvent', {EventType=key}, function (r)end);
	end
end
----------------------------------------------------------------------
-- 가이드 트리거
----------------------------------------------------------------------
function ProcessLobbyGuideTriggerEvent(company, eventType, eventArg)
	local isContinue = true;
	local guideTriggers = GetEnableLobbyGuideTrigger(company, eventType, eventArg);
	if #guideTriggers > 0 then
		isContinue = false;
		RequestLobbyAction('InvokeLobbyGuideTrigger', {EventType = eventType, EventArgs = eventArg}, function(response)end);
	end
	return isContinue;
end