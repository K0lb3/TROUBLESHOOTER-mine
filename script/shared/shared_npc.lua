function GetNPCStartQuests(self)
	local questClsList = GetClassList('Quest');
	local retQuests = {};
	for name, questCls in pairs(questClsList) do
		if questCls.ClientType == 'Npc' and
			SafeIndex(questCls, 'Client') == self.name
		then
			table.insert(retQuests, questCls.name);
		end
	end
	return retQuests;
end
function GetNPCEndQuests(self)
	local questClsList = GetClassList('Quest');
	local retQuests = {};
	for name, questCls in pairs(questClsList) do
		if SafeIndex(questCls, 'CompletionNpc') == self.name then
			table.insert(retQuests, questCls.name);
		end
	end
	return retQuests;
end
function GetNPCProgressQuests(self)
	local questClsList = GetClassList('Quest');
	local retQuests = {};
	for name, questCls in pairs(questClsList) do
		if SafeIndex(questCls, 'TargetNPC') == self.name then
			table.insert(retQuests, questCls.name);
		end
	end
	return retQuests;	
end
function GetNPCProgressQuests_Client(self)
	local questClsList = GetClassList('Quest');
	local retQuests = {};
	for name, questCls in pairs(questClsList) do
		if SafeIndex(questCls, 'Client') == self.name and 
			SafeIndex(questCls, 'Client') ~= SafeIndex(questCls, 'CompletionNpc') 
		then
			table.insert(retQuests, questCls.name);
		end
	end
	return retQuests;	
end