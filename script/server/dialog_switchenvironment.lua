function QuestSwitchValueGetter_RosterCount(cls, npc, company, env)
	return #GetAllRoster(company);
end
function QuestSwitchValueGetter_StageProgress(cls, npc, company, env)
	return GetScenarioProgressGrade(company);
end
function QuestSwitchValueGetter_RosterExist(cls, npc, company, env)
	return function(roster) 
		return table.exist(GetAllRoster(company), function(r) return r.name == roster; end);
	end
end
function QuestSwitchValueGetter_QuestComplete(cls, npc, company, env)
	return function(quest)
		return GetQuestState(company, quest) == 'Completed';
	end
end
function DialogEnvironmentValueGetter_CompanyProperty(cls, npc, company, env)
	return function(keyChain)
		return SafeIndex(company, unpack(string.split(keyChain, '/')));
	end
end