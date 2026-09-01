--!strict
--[[
	EngineC.Compiler
	Orchestrates the full pipeline: Lexer -> Parser -> IRBuilder -> Optimizer
	-> CodeGen -> Runtime. This is the public entry point for EngineC source.
]]

local Lexer = require(script.Parent.Lexer)
local Parser = require(script.Parent.Parser)
local IRBuilder = require(script.Parent.IRBuilder)
local Optimizer = require(script.Parent.Optimizer)
local CodeGen = require(script.Parent.CodeGen)

local Compiler = {}

export type CompileResult = {
	ok: boolean,
	tokens: { any }?,
	ast: { any }?,
	ir: { any }?,
	optimizedIr: { any }?,
	luau: string?,
	error: string?,
}

-- Runs stages 1-5, returns every intermediate artifact for inspection/debugging.
function Compiler.compile(source: string): CompileResult
	local ok, result = pcall(function()
		local tokens = Lexer.tokenize(source)
		local ast = Parser.parse(tokens)
		local ir = IRBuilder.build(ast)
		local optimizedIr = Optimizer.optimize(ir)
		local luau = CodeGen.generate(optimizedIr)
		return {
			tokens = tokens,
			ast = ast,
			ir = ir,
			optimizedIr = optimizedIr,
			luau = luau,
		}
	end)

	if not ok then
		return { ok = false, error = tostring(result) }
	end

	return {
		ok = true,
		tokens = result.tokens,
		ast = result.ast,
		ir = result.ir,
		optimizedIr = result.optimizedIr,
		luau = result.luau,
	}
end

-- Compiles and immediately executes the generated Luau (stage 6: runtime layer
-- picks it up from there). Returns the compile result plus execution status.
function Compiler.run(source: string): (CompileResult, boolean, string?)
	local result = Compiler.compile(source)
	if not result.ok then
		return result, false, result.error
	end

	-- loadstring requires ServerScriptService.LoadStringEnabled on the server
	local sss = game:GetService("ServerScriptService")
	local wasEnabled = sss.LoadStringEnabled
	sss.LoadStringEnabled = true

	local chunk, loadErr = loadstring(result.luau :: string, "EngineC_Generated")

	if not wasEnabled then
		sss.LoadStringEnabled = false
	end

	if not chunk then
		return result, false, "Luau load error: " .. tostring(loadErr)
	end

	local ok, fnOrErr = pcall(chunk)
	if not ok then
		return result, false, "Luau load-phase error: " .. tostring(fnOrErr)
	end

	local execOk, execErr = pcall(fnOrErr :: () -> ())
	if not execOk then
		return result, false, "Runtime execution error: " .. tostring(execErr)
	end

	return result, true, nil
end

-- ===== deploy: one ServerScriptService file per top-level declaration =====
--
-- Every top-level `public ... # ... end` (Function), `class ... end` (Class),
-- and `var ... = ...` (VarDecl) compiles to its OWN Script instance under
-- ServerScriptService.ApplicationSupport, named `<name>_<kind>` (e.g.
-- "bootstrap_function", "flare_gun_function", "PlayerState_class",
-- "maxSpeed_var"). Each Script requires EngineC.Runtime itself and runs
-- immediately once parented -- that's what makes it "compiled", as opposed
-- to Compiler.run's single in-memory loadstring.
local KIND_SUFFIX = { Function = "function", Class = "class", VarDecl = "var" }

local function lastSegment(path: string): string
	return path:match("([^%.]+)$") or path
end

local function getAppSupportFolder(): Folder
	local ServerScriptService = game:GetService("ServerScriptService")
	local folder = ServerScriptService:FindFirstChild("ApplicationSupport")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ApplicationSupport"
		folder.Parent = ServerScriptService
	end
	return folder :: Folder
end

export type DeployedFile = { name: string, ok: boolean, error: string? }

-- Compiles `source` and writes one Script per top-level declaration into
-- ServerScriptService.ApplicationSupport. Returns the list of files written
-- (each already parented and, since it's a real Script, already running).
function Compiler.deploy(source: string): { DeployedFile }
	local okTok, tokensOrErr = pcall(Lexer.tokenize, source)
	if not okTok then
		return { { name = "<lex error>", ok = false, error = tostring(tokensOrErr) } }
	end
	local okAst, astOrErr = pcall(Parser.parse, tokensOrErr)
	if not okAst then
		return { { name = "<parse error>", ok = false, error = tostring(astOrErr) } }
	end

	local ast = astOrErr :: { any }
	local folder = getAppSupportFolder()
	local results: { DeployedFile } = {}

	-- loadstring fallback requires LoadStringEnabled when Source is not writable
	local sss = game:GetService("ServerScriptService")
	local wasEnabled = sss.LoadStringEnabled
	sss.LoadStringEnabled = true

	for i, node in ipairs(ast) do
		local suffix = KIND_SUFFIX[node.kind] or "script"
		local baseName = lastSegment(node.path) .. "_" .. suffix
		local fileName = baseName

		-- Remove existing script with same name to avoid duplicates on re-deploy
		local existing = folder:FindFirstChild(fileName)
		if existing then
			existing:Destroy()
		end

		local ok, err = pcall(function()
			local ir = IRBuilder.build({ node })
			local optimized = Optimizer.optimize(ir)
			local luau = CodeGen.generateScript(optimized, baseName)

			local scr = Instance.new("Script")
			scr.Name = fileName
			scr.Parent = folder

			-- Try to set Source (works in Studio edit mode, fails at runtime)
			local srcOk = pcall(function()
				(scr :: any).Source = luau
			end)

			if not srcOk then
				-- Runtime: Source not writable, execute directly via loadstring
				scr:Destroy()
				local chunk = loadstring(luau)
				assert(chunk, "Failed to load generated Luau for " .. fileName)
				chunk()
			end
		end)

		table.insert(results, { name = fileName, ok = ok, error = if ok then nil else tostring(err) })
	end

	if not wasEnabled then
		sss.LoadStringEnabled = false
	end

	return results
end

return Compiler
