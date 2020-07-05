TextMethod = {
	Word = 1,
	GuideMessage = 2,
	SentenceString = 3,
	Dictionary = 4,
	Raw = 5,
	StringFormat = 6,
	PropertyColumn = 7,
	FormatMessage = 8,
	ClassData = 9,
	GameMessageForm = 10
};
function MakeText(method, data)
	return {Method = method, Data = data};
end
function WordText(key)
	return MakeText(TextMethod.Word, key);
end
function GuideMessageText(key, needPostPositionProcess)
	return MakeText(TextMethod.GuideMessage, {Key = key, PostPosition = needPostPositionProcess});
end
function SentenceStringText(stringKey)
	return MakeText(TextMethod.SentenceString, stringKey);
end
function DictionaryText(dicKey)
	return MakeText(TextMethod.Dictionary, dicKey);
end
function StringFormatText(...)
	return MakeText(TextMethod.StringFormat, {...});
end
function RawText(s)
	return MakeText(TextMethod.Raw, s);
end
function PropertyColumnText(cls, key)
	if not (IsClient() or IsDandyCrafter()) then
		LogAndPrint('Client에서만 지원하는 기능입니다.');
		Traceback();
		return RawText(cls[key]);
	end
	return MakeText(TextMethod.PropertyColumn, {Cls = cls, Key = key});
end
function FormatMessageText(formatText, argTextTable)
	return MakeText(TextMethod.FormatMessage, {Format=formatText, Table=argTextTable});
end
function ClassDataText(...)
	return MakeText(TextMethod.ClassData, {...});
end
function GameMessageFormText(messageForm, baseColor)
	return MakeText(TextMethod.GameMessageForm, {Form = messageForm, BaseColor = baseColor});
end
function LoadStringFormatText(data)
	local argStrings = {};
	for i = 1, #data do
		table.insert(argStrings, LoadText(data[i]));
	end
	return string.format(unpack(argStrings));
end
function LoadFormatMessageText(data)
	local formatStr = LoadText(data.Format);
	return FormatMessage(formatStr, data.Table, LoadText);
end
function LoadClassDataText(data)
	local keyChain = {};
	for i = 1, #data do
		table.insert(keyChain, data[i]);
	end
	if #keyChain <= 2 then
		return '';
	end
	local idspace = table.remove(keyChain, 1);
	return SafeIndex(GetClassList(idspace), unpack(keyChain));
end
function GameMessageBuilder(messageForm, useColor, baseColor)
	local formatClsList = GetClassList('GameSystemMessageFormat');
	local formatArgClsList = GetClassList('GameSystemMessageFormatArg');
	local formatType = messageForm.Type;
	local formatCls = formatClsList[formatType];
	local t = {};
	local failed = false;
	setmetatable(t, {__index = function(t, k)
		local formatArgCls = formatArgClsList[k];
		if formatArgCls == nil then
			failed = true;
			return nil;
		end
		
		local selectKey = messageForm[k];
		local s = formatArgCls:ToString(selectKey);
		if s == nil then
			failed = true;
			return string.format('\\[%s\\]', formatArgCls.Title);
		end
		if useColor then
			local colorGetter = GetWithoutError(formatArgCls, 'ColorGetter');
			if colorGetter then
				local color = colorGetter(formatArgCls, selectKey) or baseColor;
				s = EncloseTextWithColorKey(color, s, baseColor);
			end
		end
		return s;
	end});
	return KoreanPostpositionProcessCpp(FormatMessage(formatCls.Format, t, nil, true)), not failed;
end
function LoadGameMessageForm(data)
	return GameMessageBuilder(data.Form, true, data.BaseColor);
end
function LoadText(textData)
	if type(textData) ~= 'table' then
		return textData;
	end
	local TextExtractor = {
		[TextMethod.Word] = GetWord,
		[TextMethod.GuideMessage] = function(d) 
			local msg = GuideMessage(d.Key);
			if d.PostPosition then
				msg = KoreanPostpositionProcessCpp(msg);
			end
			return msg;
		end,
		[TextMethod.SentenceString] = GetSentenceString,
		[TextMethod.Dictionary] = function (d) return GetDictionaryText(d) or d end,
		[TextMethod.Raw] = function(d) return d; end,
		[TextMethod.StringFormat] = LoadStringFormatText,
		[TextMethod.PropertyColumn] = function(d) return d.Cls[d.Key]; end,
		[TextMethod.FormatMessage] = LoadFormatMessageText,
		[TextMethod.ClassData] = LoadClassDataText,
		[TextMethod.GameMessageForm] = LoadGameMessageForm,
	};
	return TextExtractor[textData.Method](textData.Data);
end