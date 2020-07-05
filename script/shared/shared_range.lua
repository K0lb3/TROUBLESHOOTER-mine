function Get_MovePath(self, posList)
	return GetMovePath(self, posList, self.MoveDist * (1 + self.SecondaryMoveRatio), self.MoveDist);
end
function Get_MovePathSecondary(self, posList)
	local md = self.MoveDist * self.SecondaryMoveRatio;
	return GetMovePath(self, posList, md, md);
end
function Get_ObjectiveArea(self, posList)
	local area = GetInstantProperty(self, 'Area');
	if not area then
		return {};
	end
	
	local posList = GetPositionListInArea(area.From, area.To);
	local validPosFunc = function(p)
		if IsMissionServer() then
			return GetValidPosition(GetMission(self), p, true);
		else
			return GetValidPosition(p, true);
		end
	end;
	
	return table.map(posList, validPosFunc);
end