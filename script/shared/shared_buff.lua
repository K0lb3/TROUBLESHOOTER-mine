-- 버프 최대 스택
function FunctionProperty_BuffGetMaxStack(buff, owner)
	local result = buff.Base_MaxStack;
	return math.max(1, result);
end
function BuffImmunityTest(buff, victim)

	-- 사망자 테스트
	if IsDead(victim) then
		return true, 'Hidden';
	end
	
	-- 종족 면제 테스트
	for i, race in ipairs(buff.ImmuneRace) do
		if victim.Race.name == race then
			return true, 'ImmuneRace';
		end
	end
	if victim.Race.name == 'Object' and buff.Type ~= 'State' then
		-- 오브젝트 타입은 스테이트가 아닌 모든 버프에 면역
		if victim.name ~= 'Utility_TrapInstance' or buff.name ~= 'ExposurePosition' then
			return true, 'Hidden';
		end
	end
	-- 면역아님
	if buff.NeutralizeBuff ~= 'None' then
		local neutralizeBuff = GetBuff(victim, buff.NeutralizeBuff);
		if neutralizeBuff then
			return true, 'NeutralizeBuff';
		end
	end
	local masteryTable = GetMastery(victim);
	if buff.Type == 'Debuff' then
		-- 버프 속성에 따른 면역아님
		if victim.ImmuneDebuff_Mental > 0 and buff.SubType == 'Mental' then
			return true, 'MentalImmune';
		end
		if victim.ImmuneDebuff_Physical > 0 and buff.SubType == 'Physical' then
			return true, 'PhysicalImmune';
		end
		-- 버프 계열에 따른 면역
		if buff.Group ~= 'None' then
			for _, mastery in pairs(masteryTable) do
				if mastery.ImmuneDebuff_BuffGroup then
					if buff.Group == mastery.BuffGroup.name or buff.Group == mastery.SubBuffGroup.name then
						return true, 'Mastery_'..mastery.name;
					end
				end
			end
		end
	end
	-- 개별 버프 특수화
	if buff.name == 'Web' then
		-- 줄타기
		if GetMasteryMastered(masteryTable, 'Wiredancer') then
			return true, 'Hidden';
		end
	elseif buff.name == 'Conceal_For_Aura' then
		if not victim.Coverable then
			return true, 'Hidden';
		end
	elseif buff.name == 'Blackout' then
		-- 야간 투시경
		if GetMasteryMastered(masteryTable, 'Goggle_NightVision') then
			return true, 'Mastery_Goggle_NightVision';
		end
		-- 발광
		if HasBuff(victim, 'Illumination') then
			return true, 'Mastery_Illumination';
		end
	end	
	-- 고결한 자아 특수화
	if buff.name == 'Confusion' or (buff.Type == 'Debuff' and buff.SubType == 'Mental') then
		if GetMasteryMastered(masteryTable, 'Draky') then
			local beastTypeCls = GetBeastTypeClassFromObject(victim);
			if not beastTypeCls or beastTypeCls.EvolutionType.name ~= 'EggStart' or beastTypeCls.EvolutionStage > 1 then
				return true, 'Mastery_Draky';
			end
		end
	end
	if buff.name == 'Confusion' then
		if GetMasteryMastered(masteryTable, 'PerfectSpirit') then
			return true, 'Mastery_PerfectSpirit';
		end
	end
	return false;
end

function BuffEffectivenessTest(buff, victim)
	if BuffImmunityTest(buff, victim) then
		return "None";
	end
	return buff.Type;		-- 'Debuff' 가 리턴되어야 나쁜효과로 간주해서 이동범위 로직에 영향을 줌
end

-- 타입에 따른 분기를 위한 더미 함수
function FunctionProperty_BuffHPChangeFunction(self, owner)
	local funcName = string.format('FunctionProperty_BuffHPChangeFunction%s', self.HPChangeFunctionType);
	return _G[funcName](self, owner);
end
-- 고정 데미지 계산 함수
function FunctionProperty_BuffHPChangeFunctionFixed(self, owner)
	return self.HPChangeValue;
end
-- Owner 능력치 비례 데미지 계산 함수
function FunctionProperty_BuffHPChangeFunctionOwner(buff, owner)
	return (buff.HPChangeValue / 100) * owner[buff.HPChangeFunctionArg];
end
-- 버프 Lv당 데미지 계산 함수
function FunctionProperty_BuffHPChangeFunctionLv(buff, owner)
	return buff.HPChangeValue * buff.Lv;
end
-- 오브젝트에 걸린 버프 인스턴스인지 확인하는 함수
function IsBuffInstance(buff)
	return IsObject(buff) and not GetWithoutError(buff, 'parent');
end
-- 레벨에 따른 버프 해제확률
function GetBuffGetSelfDischargeRate(ownerLv)
	return 100 + ( ownerLv - 1 ) * 15;
end
function GetBuffVisualLife(owner, buff)
	local fakeLife = (not owner.TurnState.TurnEnded and buff.UseForwardTurnTest) and -1 or 0;
	return buff.Life + fakeLife;
end
-- 버프 라이프 받아오기.
function SetBuffLife(target, win, buff)
	if not buff then
		return;
	end
	if buff.Type == 'HUD' then
		return;
	end
	
	local coloList = GetClassList('Color');
	
	-- 1. Frame 설정.
	local buff_FrameImage = '';
	if buff.IsTurnShow and buff.Turn < 99999 and buff.Turn > 1 then
		buff_FrameImage = string.format('BuffFrame/Turn%d_Frame', math.min(9, buff.Turn));
	end	
	win:getChild('TurnFrame'):setProperty('Image', buff_FrameImage);
	
	-- 2. 턴 표시.
	local buff_TurnImage = '';
	local turnColor = 'White';
	if buff.IsTurnShow and buff.Turn < 99999 and buff.Turn > 1 then
		if buff.Life > 0 then
			buff_TurnImage = string.format('BuffFrame/Turn%d_%d', math.min(9, buff.Turn), math.min(9, GetBuffVisualLife(target, buff)));
			if buff.Type == 'Buff' then
				turnColor = 'WhiteBlue';
			elseif buff.Type == 'Debuff' then
				turnColor = 'YellowOrange';
			else
				turnColor = 'Cream';
			end
			if buff.Life == 1 then
				win:getChild('TurnFrame'):getChild('Turn'):fireEvent('StartShow', CEGUI.EventArgs());
			else
				win:getChild('TurnFrame'):getChild('Turn'):fireEvent('Stop', CEGUI.EventArgs());
				win:getChild('TurnFrame'):getChild('Turn'):setProperty('Alpha', 1);
			end
		end
	end
	win:getChild('TurnFrame'):getChild('Turn'):setProperty('ImageColours', coloList[turnColor].ColorRect);
	win:getChild('TurnFrame'):getChild('Turn'):setProperty('Image', buff_TurnImage);
end


function CalculatedProperty_BuffGroupBuffList(cls, arg)
	return Linq.new(GetClassList('Buff'))
		:where(function(data) return data[2].Group == cls.name end)
		:select(function(data) return data[1] end)
		:toList();
end