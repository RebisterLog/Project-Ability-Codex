return function(str1: string, str2: string): boolean
	str1, str2 = str1:lower(), str2:lower()
	return string.match(str1, str2)
end
