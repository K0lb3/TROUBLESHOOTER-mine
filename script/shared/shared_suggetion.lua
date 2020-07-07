-- 의견 체크
---------------------------------------------------------
function IsSuggetionEnable(company, arg)
	local result = false;
	local script = _G['GetSuggetionEnable_'..arg];
	if script then
		result = script(company, arg);
	end
	return result;
end
function GetSuggetionEnable_PugoShop(company, arg)
	local result = false;
	if company.Progress.Tutorial.Opening == 'PugoShop' or company.Progress.Tutorial.Opening == 'PugoShop_Lose' then
		result = true;
	end	
	return result;
end
function GetSuggetionEnable_SearchIrene(company, arg)
	local result = false;
	if company.Progress.Character.Irene == 6 then
		result = true;
	end	
	return result;
end
function GetSuggetionEnable_IssacRequest(company, arg)
	local result = false;
	-- 아이작 프로퍼티 .
	if company.Progress.Character.Issac == 4 then
		result = true;
	end	
	return result;
end
function GetSuggetionEnable_AlbusSuggetion(company, arg)
	local result = false;
	-- 앤 프로퍼티.
	if company.Progress.Character.Anne == 3 then
		result = true;
	end	
	return result;
end
function GetSuggetionEnable_PugoShopAfter(company, arg)
	local result = false;
	if company.Progress.Character.Sion == 2 and company.Progress.Tutorial.Office ~= 43 --[[작업대 열러옴]] then
		result = true;
	end
	return result;
end
function GetSuggetionEnable_RecruitHeissing(company, arg)
	local result = false;
	if company.Progress.Character.Heissing == 5 then
		result = true;
	end
	return result;
end
function GetSuggetionEnable_IreneRequest(company, arg)
	local result = false;
	if company.Progress.Character.Irene == 10 then
		result = true;
	end
	return result;
end
function GetSuggetionEnable_JaneRequest(company, arg)
	local result = false;
	if company.Progress.Character.Jane == 2 then
		result = true;
	end
	return result;
end
function GetSuggetionEnable_GiselleRequest(company, arg)
	local result = false;
	if company.Progress.Character.Albus == 5 then
		result = true;
	end
	return result;
end
function GetSuggetionEnable_HeissingRequest(company, arg)
	local result = false;
	if company.Progress.Character.Albus == 13 then
		result = true;
	end
	return result;
end
function GetSuggetionEnable_RecruitLeton(company, arg)
	local result = false;
	if company.Progress.Character.Leton == 4 then
		result = true;
	end
	return result;
end
function GetSuggetionEnable_IssacRequest2(company, arg)
	local result = false;
	-- 아이작.
	if company.Progress.Character.Albus == 19 then
		result = true;
	end	
	return result;
end
function GetSuggetionEnable_KylieRequest(company, arg)
	local result = false;
	-- 카일리
	if company.Progress.Character.Albus == 22 then
		result = true;
	end
	return result;
end
function GetSuggetionEnable_JaneRequest2(company, arg)
	local result = false;
	-- 카일리
	if company.Progress.Character.Albus == 24 then
		result = true;
	end
	return result;
end
----------------------------------------------------------------
function GetSuggetionEnable_ConditionRest(company, arg)
	local result = false;
	if HasConditionRest(company) then
		result = true;
	end
	return result;
end
------------------------------------------------------------
-- 의견 버튼 클릭.
------------------------------------------------------------
function Execution_Suggestion_PugoShop()
	local session = GetSession();
	local company = session.company_info;
	if company.Progress.Tutorial.Opening == 'PugoShop' or company.Progress.Tutorial.Opening == 'PugoShop_Lose' then
		RequestLobbyAction('InvokeClientEvent', {EventType='PlayPugoShop'}, function (r)end);
	end
end
function Execution_Suggestion_SearchIrene()
	local session = GetSession();
	local company = session.company_info;
	if company.Progress.Character.Irene == 6 then
		RequestLobbyAction('InvokeClientEvent', {EventType='PlayBlueFogStreet'}, function (r)end);
	end
end
function Execution_Suggestion_IssacRequest()
	local session = GetSession();
	local company = session.company_info;
	if company.Progress.Character.Issac == 4 then
		RequestLobbyAction('InvokeClientEvent', {EventType='PlayHansando'}, function (r)end);
	end
end
function Execution_Suggestion_AlbusSuggetion()
	local session = GetSession();
	local company = session.company_info;
	if company.Progress.Character.Anne == 3 then
		RequestLobbyAction('InvokeClientEvent', {EventType='PlayGrayCemeteryPark'}, function (r)end);
	end
end
function Execution_Suggestion_PugoShopAfter()
	local session = GetSession();
	local company = session.company_info;
	if company.Progress.Character.Sion == 2 then
		RequestLobbyAction('InvokeClientEvent', {EventType='PlayPugoShopAfter'}, function (r)end);
	end
end
function Execution_Suggestion_RecruitHeissing()
	local session = GetSession();
	local company = session.company_info;
	if company.Progress.Character.Heissing == 5 then
		RequestLobbyAction('InvokeClientEvent', {EventType='Office_RecruitHeissing'}, function (r)end);
	end
end
function Execution_Suggestion_IreneRequest()
	local session = GetSession();
	local company = session.company_info;
	if company.Progress.Character.Irene == 10 then
		RequestLobbyAction('InvokeClientEvent', {EventType='Office_IreneRequest'}, function (r)end);
	end
end
function Execution_Suggestion_JaneRequest()
	local session = GetSession();
	local company = session.company_info;
	if company.Progress.Character.Jane == 2 then
		RequestLobbyAction('InvokeClientEvent', {EventType='Office_JaneRequest'}, function (r)end);
	end
end
function Execution_Suggestion_GiselleRequest()
	local session = GetSession();
	local company = session.company_info;
	if company.Progress.Character.Albus == 5 then
		RequestLobbyAction('InvokeClientEvent', {EventType='Office_GiselleRequest'}, function (r)end);
	end
end
function Execution_Suggestion_HeissingRequest()
	local session = GetSession();
	local company = session.company_info;
	if company.Progress.Character.Albus == 13 then
		RequestLobbyAction('InvokeClientEvent', {EventType='Office_HeissingRequest'}, function (r)end);
	end
end
function Execution_Suggestion_RecruitLeton()
	local session = GetSession();
	local company = session.company_info;
	if company.Progress.Character.Leton == 4 then
		RequestLobbyAction('InvokeClientEvent', {EventType='Office_RecruitLeton'}, function (r)end);
	end
end
function Execution_Suggestion_HeissingRequest2()
	local session = GetSession();
	local company = session.company_info;
	if company.Progress.Character.Leton == 10 then
		RequestLobbyAction('InvokeClientEvent', {EventType='Office_HeissingRequest2'}, function (r)end);
	end
end
function Execution_Suggestion_IssacRequest2()
	local session = GetSession();
	local company = session.company_info;
	if company.Progress.Character.Albus == 19 then
		RequestLobbyAction('InvokeClientEvent', {EventType='Office_IssacRequest2'}, function (r)end);
	end
end
function Execution_Suggestion_KylieRequest()
	local session = GetSession();
	local company = session.company_info;
	if company.Progress.Character.Albus == 22 then
		RequestLobbyAction('InvokeClientEvent', {EventType='Office_KylieRequest'}, function (r)end);
	end
end
function Execution_Suggestion_JaneRequest2()
	local session = GetSession();
	local company = session.company_info;
	if company.Progress.Character.Albus == 24 then
		RequestLobbyAction('InvokeClientEvent', {EventType='Office_JaneRequest2'}, function (r)end);
	end
end
------------------------------------------------------------
function Execution_Suggestion_ConditionRest()
	local session = GetSession();
	local company = session.company_info;
	if HasConditionRest(company) then
		RequestLobbyAction('InvokeClientEvent', {EventType='ConditionRest'}, function (r)end);
	end
end
------------------------------------------------------------
-- 컨디션 체크
------------------------------------------------------------
function HasConditionRest(company)
	if IsClient() and (IsLobbyMode() or IsOfficeMode()) then
		local session = GetSession();
		local rosters = session.rosters;
		for index, roster in ipairs(rosters) do
			if roster ~= nil and roster.ConditionState == 'Rest' then
				return true;
			end
		end		
	elseif IsLobbyServer() then
		local rosterList = GetAllRoster(company);
		for index, roster in ipairs(rosterList) do
			if roster ~= nil and roster.ConditionState == 'Rest' then
				return true;
			end
		end
	end
	return false;
end