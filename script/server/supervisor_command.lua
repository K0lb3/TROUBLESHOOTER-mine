function OnSupervisorCommand(command, ...)
	LogAndPrint('OnSupervisorCommand', command, ...);
	local f = _G["CommandSupervisor_" .. command];
	if f ~= nil then
		f(...);
	end
end

function CommandSupervisor_updateshop()
	UpdateShopItemList();
end

function CommandSupervisor_updatefood()
	UpdateFoodRecommendList();
end

function CommandSupervisor_startsafetyfever(zoneType)
	local zoneCls = GetClassList('Zone')[zoneType];
	if zoneCls == nil then
		return;
	end
	UpdateWorldProperty(string.format('ZoneState/%s/Safty', zoneType), zoneCls.MaxSafty, 'Cheat');
end

function CommandSupervisor_endsafetyfever(zoneType)
	local zoneCls = GetClassList('Zone')[zoneType];
	if zoneCls == nil then
		return;
	end
	UpdateWorldPropertyMulti({MakeDBUpdateCommand(string.format('ZoneState/%s/Safty', zoneType), zoneCls.MaxSafty * (math.random() * 0.25 + 0.5)), MakeDBUpdateCommand(string.format('ZoneState/%s/SafetyFever', zoneType), false)}, 'SafetyFeverEnd');
end