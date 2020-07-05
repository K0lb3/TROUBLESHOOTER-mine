function GetOriginalTeam(obj)
	return GetInstantProperty(obj, 'OriginalTeam') or GetTeam(obj);
end