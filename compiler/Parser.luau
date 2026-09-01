--!strict
--[[
	EngineC.Parser
	Stage 2 of the pipeline: recursive-descent parser that turns the Lexer's
	token stream into an AST.

	Statement shape (block / injection / bare call) is resolved via
	EngineC.Spec's command table for most commands. A few commands are
	"flexible" (used both as a leaf and as a block with children in real
	EngineC code, e.g. physics.body) -- those are resolved by indentation,
	since the grammar has no explicit block-opening delimiter: a following
	statement indented further than the flexible command's own column (and
	eventually closed by a matching 'end') makes it a block.

	Top-level declaration forms (each becomes its own deployed file --
	see EngineC.Compiler):
		public <ns.path> <name>[args] # ... end     -> Node.kind = "Function"
		class <name>[args] ... end                   -> Node.kind = "Class"
		var <name> (':' TYPE)? '=' expr               -> Node.kind = "VarDecl"
]]

local Spec = require(script.Parent.Spec)
local Lexer = require(script.Parent.Lexer)

type Token = Lexer.Token

export type Expr = { kind: string, value: any }

export type ArgNode = {
	key: string?,
	typ: string?,
	value: Expr,
}

export type Node = {
	kind: string,       -- "Block" | "Inject" | "Call" | "Assign" | "Function" | "Class" | "VarDecl"
	path: string,
	op: string,
	args: { ArgNode },
	body: { Node }?,
	value: Expr?,
	typ: string?,
	line: number,
}

local Parser = {}

local function newParserState(tokens: { Token })
	local pos = 1
	local function peek(offset: number?): Token
		return tokens[pos + (offset or 0)]
	end
	local function advance(): Token
		local t = tokens[pos]
		pos += 1
		return t
	end
	local function expect(ttype: string): Token
		local t = tokens[pos]
		if t.type ~= ttype then
			error(("EngineC parse error: expected %s but got %s (%q) at line %d")
				:format(ttype, t.type, t.value, t.line))
		end
		pos += 1
		return t
	end
	return { peek = peek, advance = advance, expect = expect }
end

-- Some Lexer keywords (namespace, pipeline, etc.) also occur as ordinary
-- path segments in real EngineC code (e.g. `namespace.Physics::core::static`
-- uses "namespace" as a plain identifier, not as a distinct construct we
-- implement). Path parsing accepts either a true IDENT or one of these.
local PATH_WORD_KEYWORDS = { NAMESPACE = true, LOCAL = true, FUNCTION = true }

local function expectPathWord(s): Token
	local t = s.peek()
	if t.type == "IDENT" or PATH_WORD_KEYWORDS[t.type] then
		return s.advance()
	end
	error(("EngineC parse error: expected identifier but got %s (%q) at line %d")
		:format(t.type, t.value, t.line))
end

-- Consumes a dotted and/or ::-scoped path, e.g. `model3d.sphere`,
-- `namespace.Physics::core::static`. Both separators are accepted anywhere
-- in the chain since EngineC uses '.' for member access and '::' for
-- explicit namespace scoping.
local function parsePath(s): string
	local first = expectPathWord(s)
	local parts = { first.value }
	while s.peek().type == "DOT" or s.peek().type == "DBLCOLON" do
		local sep = s.advance().type == "DOT" and "." or "::"
		local nxt = expectPathWord(s)
		table.insert(parts, sep .. nxt.value)
	end
	return table.concat(parts, "")
end

local function parseType(s): string
	local t = s.advance()
	return t.value
end

local function parseExpr(s): Expr
	local t = s.peek()
	if t.type == "STRING" then
		s.advance()
		return { kind = "string", value = t.value }
	elseif t.type == "NUMBER" then
		s.advance()
		return { kind = "number", value = tonumber(t.value) }
	elseif t.type == "TRUE" then
		s.advance()
		return { kind = "bool", value = true }
	elseif t.type == "FALSE" then
		s.advance()
		return { kind = "bool", value = false }
	elseif t.type == "IDENT" then
		local p = parsePath(s)
		return { kind = "ident", value = p }
	else
		error(("EngineC parse error: unexpected token %s in expression at line %d"):format(t.type, t.line))
	end
end

-- arg := (IDENT (':' TYPE)? '=' expr)   -- e.g. id="bh1", mass: float=5000
--      | expr ':' TYPE                  -- e.g. "solverIterations": int  (bare typed value)
--      | expr                           -- e.g. "space", "bh1", or a positional tuple component
local function parseArg(s): ArgNode
	if s.peek().type == "IDENT" and (s.peek(1).type == "EQUALS" or s.peek(1).type == "COLON") then
		local key = s.advance().value
		local typ: string? = nil
		if s.peek().type == "COLON" then
			s.advance()
			typ = parseType(s)
		end
		s.expect("EQUALS")
		local value = parseExpr(s)
		return { key = key, typ = typ, value = value }
	else
		local value = parseExpr(s)
		local typ: string? = nil
		if s.peek().type == "COLON" then
			s.advance()
			typ = parseType(s)
		end
		return { key = nil, typ = typ, value = value }
	end
end

local function parseArgList(s): { ArgNode }
	s.expect("LBRACKET")
	local args: { ArgNode } = {}
	if s.peek().type ~= "RBRACKET" then
		table.insert(args, parseArg(s))
		while s.peek().type == "COMMA" do
			s.advance()
			table.insert(args, parseArg(s))
		end
	end
	s.expect("RBRACKET")
	return args
end

local parseStatement, parseStatementList

function parseStatementList(s): { Node }
	local nodes: { Node } = {}
	while true do
		local t = s.peek()
		if t.type == "END" or t.type == "EOF" then
			break
		end
		table.insert(nodes, parseStatement(s))
	end
	return nodes
end

-- public <ns.path> <name>[args]? '#' body 'end'
local function parsePublic(s, line: number): Node
	s.expect("PUBLIC")
	local nsPath = parsePath(s)
	local name = s.expect("IDENT").value
	local args: { ArgNode } = {}
	if s.peek().type == "LBRACKET" then
		args = parseArgList(s)
	end
	s.expect("HASH")
	local body = parseStatementList(s)
	s.expect("END")
	return { kind = "Function", path = nsPath .. "." .. name, op = "function_decl", args = args, body = body, line = line }
end

-- class <name>[args]? body 'end'
local function parseClass(s, line: number): Node
	s.expect("CLASS")
	local name = s.expect("IDENT").value
	local args: { ArgNode } = {}
	if s.peek().type == "LBRACKET" then
		args = parseArgList(s)
	end
	local body = parseStatementList(s)
	s.expect("END")
	return { kind = "Class", path = name, op = "class_decl", args = args, body = body, line = line }
end

-- var <name> (':' TYPE)? '=' expr
local function parseVar(s, line: number): Node
	s.expect("VAR")
	local name = s.expect("IDENT").value
	local typ: string? = nil
	if s.peek().type == "COLON" then
		s.advance()
		typ = parseType(s)
	end
	s.expect("EQUALS")
	local value = parseExpr(s)
	return { kind = "VarDecl", path = name, op = "var_decl", args = {}, value = value, typ = typ, line = line }
end

-- pipeline[ <statement list> 'end' ]   -- note: 'end' closes the body,
-- THEN ']' closes the pipeline itself, per the language spec.
local function parsePipeline(s, line: number): Node
	s.expect("PIPELINE")
	s.expect("LBRACKET")
	local body = parseStatementList(s)
	s.expect("END")
	s.expect("RBRACKET")
	return { kind = "Pipeline", path = "pipeline", op = "pipeline", args = {}, body = body, line = line }
end

-- statement := 'public' ...                                    -- Function decl
--            | 'class' ...                                     -- Class decl
--            | 'var' ...                                       -- Var decl
--            | path (':' TYPE)? '=' expr                       -- Assign
--            | path arglist? '>>' expr '<<'                    -- Inject
--            | path arglist? <indented body> 'end'             -- Block (or flexible-as-block)
--            | path arglist?                                   -- Call (or flexible-as-leaf)
function parseStatement(s): Node
	local line = s.peek().line

	if s.peek().type == "PUBLIC" then
		return parsePublic(s, line)
	elseif s.peek().type == "CLASS" then
		return parseClass(s, line)
	elseif s.peek().type == "VAR" then
		return parseVar(s, line)
	elseif s.peek().type == "PIPELINE" then
		return parsePipeline(s, line)
	end

	local startColumn = s.peek().column
	local path = parsePath(s)

	-- bare assignment form, e.g. `strength: float = 9000`
	if s.peek().type == "COLON" or s.peek().type == "EQUALS" then
		local typ: string? = nil
		if s.peek().type == "COLON" then
			s.advance()
			typ = parseType(s)
		end
		s.expect("EQUALS")
		local value = parseExpr(s)
		return { kind = "Assign", path = path, op = path, args = {}, value = value, typ = typ, line = line }
	end

	local args: { ArgNode } = {}
	if s.peek().type == "LBRACKET" then
		args = parseArgList(s)
	end

	local spec = Spec.resolve(path)
	local shape = spec.shape

	if s.peek().type == "INJECT_OPEN" then
		shape = "inject"
	end

	if shape == "inject" then
		s.expect("INJECT_OPEN")
		local value = parseExpr(s)
		s.expect("INJECT_CLOSE")
		return { kind = "Inject", path = path, op = spec.op, args = args, value = value, line = line }
	elseif shape == "block" then
		local body = parseStatementList(s)
		s.expect("END")
		return { kind = "Block", path = path, op = spec.op, args = args, body = body, line = line }
	elseif shape == "flexible" then
		local nxt = s.peek()
		if nxt.type ~= "END" and nxt.type ~= "EOF" and nxt.line > line and nxt.column > startColumn then
			local body = parseStatementList(s)
			s.expect("END")
			return { kind = "Block", path = path, op = spec.op, args = args, body = body, line = line }
		else
			return { kind = "Call", path = path, op = spec.op, args = args, line = line }
		end
	else
		return { kind = "Call", path = path, op = spec.op, args = args, line = line }
	end
end

function Parser.parse(tokens: { Token }): { Node }
	local s = newParserState(tokens)
	local nodes = parseStatementList(s)
	s.expect("EOF")
	return nodes
end

return Parser
