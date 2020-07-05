function ClassFormatStringParser_ClassColumn(cls, key)
	local idspace = cls.Idspace;
	local column = cls.Column;
	return GetClassList(idspace)[key][column];
end