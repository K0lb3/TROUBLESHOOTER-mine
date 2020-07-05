function GetObjectMoveAni(self, pathLength, forceMode)
	-- 로비 예외 처리
	if _G['IsLobbyMode'] and IsLobbyMode() then
		return 'Run', self.Shape.RunSpeed;
	end
	
	local mode;
	if forceMode and string.len(forceMode) > 0 then
		mode = forceMode;
	elseif GetBuff(self, 'Stand') then
		mode = 'Walk';
	else
		LogAndPrint('self.Shape.MoveAni :', self.Shape.MoveAni)
		mode = self.Shape.MoveAni;
	end
	
	local speed = self.Shape[mode .. 'Speed'];
	if HasBuff(self, 'Giant') then
		speed = speed * 1.25;
	elseif HasBuff(self, 'Giant_SideEffect') then
		speed = speed * 0.75;
	end
	
	return mode, speed;
end

function Get_StandingAnimation(self)
	if IsLobby() then
		return self.LobbyStd;
	else
		return 'Astd';	
	end
end

function Get_StandingIdleProb(self)
	if IsLobby() then
		return 1 / 10;
	else
		return 1 / 40;
	end
end

function Get_StandingIdleDelay(self)
	if IsLobby() then
		return 0;
	else
		return math.random(180, 300);
	end
end