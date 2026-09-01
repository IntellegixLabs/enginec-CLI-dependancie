--!strict
--[[
	EngineC (root module)

	This is the public entry point for the language. Import it the normal
	Roblox way:

		local EngineC = require(ReplicatedStorage.EngineC)

	Then write EngineC *source* directly into a plain ModuleScript's Source
	property -- it does not need to be valid Luau, since EngineC.require()
	reads that Script's raw text itself and never invokes Roblox's native
	require()/Luau compiler on it. Then pull it in like this:

		EngineC.require(ReplicatedStorage.MyBlackHoles)   -- compiles + runs it

	Calling EngineC.require() twice on the same instance returns the cached
	compile result instead of recompiling/re-running -- same caching
	semantics as Roblox's own require().

	Lower-level access (for tooling, REPLs, debugging the pipeline stage by
	stage) is also exposed: EngineC.compile(sourceText), EngineC.run(sourceText),
	EngineC.Runtime, EngineC.Lexer, EngineC.Parser, etc.
]]

local Lexer = require(script.Lexer)
local Parser = require(script.Parser)
local IRBuilder = require(script.IRBuilder)
local Optimizer = require(script.Optimizer)
local CodeGen = require(script.CodeGen)
local Runtime = require(script.Runtime)
local Compiler = require(script.Compiler)

local EngineC = {}

EngineC.Lexer = Lexer
EngineC.Parser = Parser
EngineC.IRBuilder = IRBuilder
EngineC.Optimizer = Optimizer
EngineC.CodeGen = CodeGen
EngineC.Runtime = Runtime
EngineC.Compiler = Compiler

EngineC.compile = Compiler.compile
EngineC.run = Compiler.run

-- instance -> last CompileResult, so re-requiring the same source doesn't
-- recompile/re-execute it (mirrors Roblox's own require() caching)
local cache: { [Instance]: any } = {}
local cacheBySource: { [string]: any } = {} -- fallback cache when given a raw string

-- Pulls raw EngineC source text out of `source`, whatever form it comes in:
--   ModuleScript / Script / LocalScript -> .Source  (read directly, NOT required
--                                          natively -- it need not be valid Luau)
--   StringValue                          -> .Value
--   plain string                         -> used as-is
local function extractSource(source: Instance | string): string
	if type(source) == "string" then
		return source
	end
	if source:IsA("StringValue") then
		return source.Value
	end
	local ok, src = pcall(function()
		return (source :: any).Source
	end)
	if ok and type(src) == "string" then
		return src
	end
	error("EngineC.require: don't know how to read EngineC source from a " .. source.ClassName)
end

-- Compiles and executes an EngineC program, with require()-style caching.
-- Returns (compileResult, ranOk, runErr) same as EngineC.run.
function EngineC.require(source: Instance | string): (any, boolean, string?)
	if type(source) ~= "string" and cache[source] then
		local cached = cache[source]
		return cached.result, cached.ranOk, cached.runErr
	end
	if type(source) == "string" and cacheBySource[source] then
		local cached = cacheBySource[source]
		return cached.result, cached.ranOk, cached.runErr
	end

	local text = extractSource(source)
	local result, ranOk, runErr = Compiler.run(text)

	if not result.ok then
		error("EngineC compile error: " .. tostring(result.error))
	end
	if not ranOk then
		error("EngineC runtime error: " .. tostring(runErr))
	end

	-- Only cache successful results so transient errors (e.g. LoadString disabled)
	-- don't prevent retry on the next EngineC.require call
	local entry = { result = result, ranOk = ranOk, runErr = runErr }
	if type(source) == "string" then
		cacheBySource[source] = entry
	else
		cache[source] = entry
	end

	return result, ranOk, runErr
end

-- Clears the cache for one instance (or everything, if called with no args) so
-- the next EngineC.require() call recompiles/re-runs from scratch.
function EngineC.invalidate(source: (Instance | string)?)
	if source == nil then
		table.clear(cache)
		table.clear(cacheBySource)
	elseif type(source) == "string" then
		cacheBySource[source] = nil
	else
		cache[source] = nil
	end
end

return EngineC
