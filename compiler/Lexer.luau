--!strict
--[[
	EngineC.Lexer
	Stage 1 of the pipeline: turns raw EngineC source text into a flat token
	stream. Handles identifiers/dotted paths, strings, numbers, the
	directional-injection operators (>> <<), namespace scoping (::), brackets,
	and comments (-- to end of line, borrowed from Luau).
]]

export type Token = {
	type: string,
	value: string,
	line: number,
	column: number,
}

local Lexer = {}

local KEYWORDS = {
	["end"] = true, ["public"] = true, ["local"] = true, ["function"] = true,
	["namespace"] = true, ["pipeline"] = true, ["true"] = true, ["false"] = true,
	["int"] = true, ["float"] = true, ["bool"] = true, ["string"] = true,
	["class"] = true, ["var"] = true,
}

local function isDigit(c: string): boolean return c >= "0" and c <= "9" end
local function isAlpha(c: string): boolean
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"
end
local function isAlphaNum(c: string): boolean return isAlpha(c) or isDigit(c) end

function Lexer.tokenize(source: string): { Token }
	local tokens: { Token } = {}
	local i = 1
	local line = 1
	local lineStart = 1
	local n = #source

	local function push(t: string, v: string, startPos: number)
		table.insert(tokens, { type = t, value = v, line = line, column = startPos - lineStart + 1 })
	end

	while i <= n do
		local c = source:sub(i, i)
		local startPos = i

		local byte = string.byte(c)
		if byte == 10 then
			line += 1
			i += 1
			lineStart = i
		elseif byte == 32 or byte == 9 or byte == 13 then
			i += 1
		elseif c == "-" and source:sub(i + 1, i + 1) == "-" then
			-- line comment
			while i <= n and string.byte(source, i) ~= 10 do
				i += 1
			end
		elseif c == '"' then
			local j = i + 1
			local buf = {}
			while j <= n and source:sub(j, j) ~= '"' do
				table.insert(buf, source:sub(j, j))
				j += 1
			end
			push("STRING", table.concat(buf), startPos)
			i = j + 1
		elseif isDigit(c) or (c == "-" and isDigit(source:sub(i + 1, i + 1))) then
			local j = i
			if c == "-" then j += 1 end
			while j <= n and (isDigit(source:sub(j, j)) or source:sub(j, j) == ".") do
				j += 1
			end
			push("NUMBER", source:sub(i, j - 1), startPos)
			i = j
		elseif isAlpha(c) then
			local j = i
			while j <= n and isAlphaNum(source:sub(j, j)) do
				j += 1
			end
			local word = source:sub(i, j - 1)
			if KEYWORDS[word] then
				push(word:upper(), word, startPos)
			else
				push("IDENT", word, startPos)
			end
			i = j
		elseif c == ":" and source:sub(i + 1, i + 1) == ":" then
			push("DBLCOLON", "::", startPos)
			i += 2
		elseif c == ">" and source:sub(i + 1, i + 1) == ">" then
			push("INJECT_OPEN", ">>", startPos)
			i += 2
		elseif c == "<" and source:sub(i + 1, i + 1) == "<" then
			push("INJECT_CLOSE", "<<", startPos)
			i += 2
		elseif c == "." then push("DOT", ".", startPos); i += 1
		elseif c == "[" then push("LBRACKET", "[", startPos); i += 1
		elseif c == "]" then push("RBRACKET", "]", startPos); i += 1
		elseif c == "(" then push("LPAREN", "(", startPos); i += 1
		elseif c == ")" then push("RPAREN", ")", startPos); i += 1
		elseif c == "," then push("COMMA", ",", startPos); i += 1
		elseif c == ":" then push("COLON", ":", startPos); i += 1
		elseif c == "=" then push("EQUALS", "=", startPos); i += 1
		elseif c == "#" then push("HASH", "#", startPos); i += 1
		else
			error(("EngineC lex error: unexpected character %q at line %d"):format(c, line))
		end
	end

	push("EOF", "", i)
	return tokens
end

return Lexer
