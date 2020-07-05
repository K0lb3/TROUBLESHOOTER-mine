-- http://lua-users.org/wiki/TimeZone
-- Compute the difference in seconds between local time and UTC.
function get_timezone()
  local now = os.time()
  return os.difftime(now, os.time(os.date("!*t", now)))
end
timezone = get_timezone()

-- Return a timezone string in ISO 8601:2000 standard form (+hhmm or -hhmm)
function get_tzoffset(timezone)
  local h, m = math.modf(timezone / 3600)
  return string.format("%+.4d", 100 * h + 60 * m)
end
tzoffset = get_tzoffset(timezone);

function get_tzoffset_db(timezone)
	timezone = timezone or get_timezone();
	local h, m = math.modf(timezone / 3600)
	return string.format("%+.2d:%.2d", h, 60 * m)
end

--------------------

function GetLocalTimeFromUTCTime(t)
	if type(t) == 'table' then
		local utcTime = os.time(t);
		local localTime = utcTime + timezone;
		return os.date('*t', localTime);
	else -- type(t) == 'number'
		local utcTime = t;
		local localTime = utcTime + timezone;
		return localTime;
	end
end

function GetUTCTimeFromLocalTime(t)
	if type(t) == 'table' then
		local lt = os.time(t);
		local utcTime = lt - timezone;
		return os.date('*t', utcTime);
	else
		local lt = t;
		local utcTime = lt - timezone;
		return utcTime;
	end
end

function GetUTCTime()
	return os.time(os.date('!*t'));
end

function GetRelativeTimeFormatString(t)
	local now = os.time();
	local tValue = os.time(t);
	
	local timeDiff = math.abs(now - tValue);
	local day = 3600 * 24;
	local week = day * 7;
	
	local form = '%c';
	if timeDiff < day then
		-- 하루 안쪽임 '오전 09:25'
		form = '%p %I:%M';
	elseif timeDiff < 2 * week then
		-- 두 주 안쪽 '수 12-22'
		form = '%a %m-%d';
	else
		-- 그 외 '2016-12-26'
		form = '%Y-%m-%d';
	end
	return os.date(form, tValue);
end

function GetFullTimeFormatString(t)
	return os.date('%Y-%m-%d %p %I:%M', os.time(t));
end

function GetOSClockString(t)
	return os.date('%p %I:%M', os.time(t));
end

function TimeFromString(s, toServerTime)
	local form = {};
	table.insert(form, {key = 'year', form = '(%d%d%d%d)'});
	table.insert(form, {key = 'month', form = '(%d%d)'});
	table.insert(form, {key = 'day', form = '(%d%d)'});
	table.insert(form, {key = 'hour', form = '(%d%d)'});
	table.insert(form, {key = 'min', form = '(%d%d)'});
	table.insert(form, {key = 'sec', form = '(%d%d)'});
	
	local timeT = {year = 0, month = 0, day = 0, hour = 0, min = 0, sec = 0};
    for i = #form, 1, -1 do
		local parseFormList = {};
		for j = 1, i do
			table.insert(parseFormList, form[j].form);
		end
		local parseFormMsg = table.concat(parseFormList, '[%-/%s:,]*');
		local matches = {s:match(parseFormMsg)};
		if #matches > 0 then
			for j = 1, i do
				timeT[form[j].key] = matches[j];
			end
			break;
		end
	end
	if not toServerTime then
		return os.time(timeT);
	else
		return os.time(timeT) - os.time() + os.servertime();
	end
end

function GetLocalTimeFromServerTime(serverTime)
	if serverTime == nil then
		return nil;
	end
	if os.servertime == nil then
		return serverTime;
	else
		return serverTime - os.servertime() + os.time();
	end
end

function TimeStampToString(timeStampTable)
	
	local timeString = string.format('%04d-%02d-%02d %02d-%02d-%02d', timeStampTable.year, timeStampTable.month, timeStampTable.day, timeStampTable.hour, timeStampTable.min, timeStampTable.sec);
	local curTime = TimeFromString(timeString, false);
	local localTime = GetLocalTimeFromServerTime(curTime);
	local timeInfo = os.date('*t', localTime);
	local dayText = GetLocaleDateText(timeInfo.year, timeInfo.month, timeInfo.day);
	local timeText = GetMissionElapsedSymbolicTime(timeInfo.hour * 3600 + timeInfo.min * 60 + timeInfo.sec);
	return dayText..' '..timeText;
end