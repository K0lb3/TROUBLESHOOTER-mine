-----------------------------------------------------------------------
-- 난이도 관련 서버 함수 
-----------------------------------------------------------------------
function CalculatedProperty_DifficultyStatus_Server(difficulty, arg)
	local result = 0;
	local scp = _G['CalculatedProperty_DifficultyStatus_Server_'..arg];
	if scp then
		result = scp(difficulty);
	end
	return result;
end
--------------------------------------------------------------------------
-- 아군에게 힐 어빌리티 사용 여부 가중치.
--------------------------------------------------------------------------
-- 3) 아군이 힐 어빌리티 지원 여부
function CalculatedProperty_DifficultyStatus_Server_RecoverRatio(difficulty)
	local adjustValue = { 
		Difficulty1 = 1.25,
		Difficulty2 = 1.25,
		Difficulty3 = 1.25,
		Difficulty4 = 1.2,
		Difficulty5 = 1.2,
		Difficulty6 = 1.2,
		Difficulty7 = 1.1,
		Difficulty8 = 1.1,
		Difficulty9 = 1.1,
		Difficulty10 = 1,
		Difficulty11 = 1,
		Difficulty12 = 1,
		Difficulty13 = 1,
		Difficulty14 = 1,
		Difficulty15 = 1
	};
	local result = adjustValue['Difficulty'..difficulty.Lv];
	if not result then
		result = 0;
	end
	return result;
end
-- 4) 적이 힐 어빌리티 지원 여부
function CalculatedProperty_DifficultyStatus_Server_EnemyRecoverRatio(difficulty)
	local adjustValue = { 
		Difficulty1 = 0,
		Difficulty2 = 0,
		Difficulty3 = 0,
		Difficulty4 = 0.5,
		Difficulty5 = 0.5,
		Difficulty6 = 0.5,
		Difficulty7 = 0.7,
		Difficulty8 = 0.7,
		Difficulty9 = 0.7,
		Difficulty10 = 0.85,
		Difficulty11 = 0.85,
		Difficulty12 = 0.85,
		Difficulty13 = 1,
		Difficulty14 = 1,
		Difficulty15 = 1
	};
	local result = adjustValue['Difficulty'..difficulty.Lv];
	if not result then
		result = 0;
	end
	return result;
end
------------------------------------------------------------------------
-- 1. AI 적 명중률 포인트 보정
------------------------------------------------------------------------
function CalculatedProperty_DifficultyStatus_Server_EnemyMaxAccuracy(difficulty)
	local adjustValue = {
		Difficulty1 = 50,
		Difficulty2 = 50,
		Difficulty3 = 50,
		Difficulty4 = 50,
		Difficulty5 = 55,
		Difficulty6 = 60,
		Difficulty7 = 65,
		Difficulty8 = 70,
		Difficulty9 = 75,
		Difficulty10 = 80,
		Difficulty11 = 90,
		Difficulty12 = 95,
		Difficulty13 = 97,
		Difficulty14 = 98,
		Difficulty15 = 100
	};
	local result = adjustValue['Difficulty'..difficulty.Lv];
	if not result then
		result = 0;
	end
	return result;
end
------------------------------------------------------------------------
-- 정예 몹 숫자 보정.
------------------------------------------------------------------------
function CalculatedProperty_DifficultyStatus_Server_EnemyGradeUpMinCount(difficulty)
	local adjustValue = { 
		Difficulty1 = -8,
		Difficulty2 = -7,
		Difficulty3 = -6,
		Difficulty4 = -5,
		Difficulty5 = -4,
		Difficulty6 = -3,
		Difficulty7 = -2,
		Difficulty8 = -1,
		Difficulty9 = 0,
		Difficulty10 = 1,
		Difficulty11 = 2,
		Difficulty12 = 3,
		Difficulty13 = 4,
		Difficulty14 = 5,
		Difficulty15 = 6
	};
	local result = adjustValue['Difficulty'..difficulty.Lv];
	if not result then
		result = 0;
	end
	return result;
end
function CalculatedProperty_DifficultyStatus_Server_EnemyGradeUpMaxCount(difficulty)
	local adjustValue = { 
		Difficulty1 = -7,
		Difficulty2 = -6,
		Difficulty3 = -5,
		Difficulty4 = -4,
		Difficulty5 = -3,
		Difficulty6 = -2,
		Difficulty7 = -1,
		Difficulty8 = 0,
		Difficulty9 = 1,
		Difficulty10 = 2,
		Difficulty11 = 3,
		Difficulty12 = 4,
		Difficulty13 = 5,
		Difficulty14 = 6,
		Difficulty15 = 7
	};
	local result = adjustValue['Difficulty'..difficulty.Lv];
	if not result then
		result = 0;
	end
	return result;
end
