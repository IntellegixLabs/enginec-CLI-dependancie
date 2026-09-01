--!strict
--[[
	EngineC.IRBuilder
	Stage 3 of the pipeline: lowers the AST into a flat intermediate
	representation (a list of typed ops). How a block's children fold into IR
	is driven by the `lower` field on that block's Spec entry -- see
	EngineC.Spec for the four lowering strategies.
]]

local Spec = require(script.Parent.Spec)
local Parser = require(script.Parent.Parser)

type Node = Parser.Node

export type IROp = {
	op: string,
	id: string?,
	parent: string?,
	args: { [string]: any },
	sub: { IROp }?,     -- for sim_loop: ordered sub-ops run per step
	mods: { { key: string, value: any } }?, -- for engine_override
	line: number,
}

local IRBuilder = {}

local function evalExpr(e): any
	return e.value
end

local function argsToTable(argNodes): { [string]: any }
	local t: { [string]: any } = {}
	for idx, a in ipairs(argNodes) do
		if a.key then
			t[a.key] = evalExpr(a.value)
		else
			-- positional arg (e.g. attract["bh1","bh2"]) -> stored as array part
			t[idx] = evalExpr(a.value)
		end
	end
	return t
end

local function idOf(args: { [string]: any }): string?
	local v = args.id
	if type(v) == "string" then
		return v
	end
	return nil
end

local buildNode

local function buildOp(node: Node, parentId: string?): IROp
	local args = argsToTable(node.args)
	local op: IROp = {
		op = node.op,
		id = idOf(args),
		parent = parentId,
		args = args,
		line = node.line,
	}

	if node.kind == "Inject" then
		op.args.value = evalExpr(node.value)
	end

	if node.kind == "VarDecl" then
		op.args.value = evalExpr(node.value)
		op.args.typ = node.typ
		op.id = node.path  -- var declarations have no id arg; use the variable name
	end

	if (node.kind == "Block" or node.kind == "Function" or node.kind == "Class") and node.body then
		local spec = Spec.resolve(node.path)
		local lower = spec.lower

		if lower == "merge_assigns" then
			-- fold child `key: type = value` assigns straight into this op's args
			for _, child in ipairs(node.body) do
				if child.kind == "Assign" then
					op.args[child.path] = evalExpr(child.value)
				else
					-- non-assign child inside a merge_assigns block still lowers normally,
					-- parented to this block's id, kept alongside via `sub`
					op.sub = op.sub or {}
					table.insert(op.sub, buildOp(child, op.id))
				end
			end
		elseif lower == "looplist" then
			op.sub = {}
			for _, child in ipairs(node.body) do
				table.insert(op.sub, buildOp(child, op.id))
			end
		elseif lower == "modlist" then
			op.mods = {}
			for _, child in ipairs(node.body) do
				if child.kind == "Inject" then
					local childArgs = argsToTable(child.args)
					-- the setting name is either a positional bare-typed string
					-- (engine.modify["solverIterations": int]) or falls back to
					-- the command path itself (engine.modify["gravityMode"])
					local key = childArgs[1]
					if type(key) ~= "string" then
						key = child.path
					end
					table.insert(op.mods, { key = key, value = evalExpr(child.value) })
				end
			end
		else
			-- "ops_with_parent" (default): children become sibling ops tagged
			-- with this block's id as their parent. Handled by caller via
			-- buildNode's flattening pass below.
			op.args._hasChildren = true
		end
	end

	return op
end

-- Walks the AST, producing a flat list of IR ops. Blocks using the default
-- "ops_with_parent" lowering strategy emit their own op *and* recursively
-- flatten their children (parented) into the same list.
local function flatten(nodes: { Node }, parentId: string?, out: { IROp })
	for _, node in ipairs(nodes) do
		local spec = Spec.resolve(node.path)
		local op = buildOp(node, parentId)
		op.args._hasChildren = nil
		table.insert(out, op)

		if node.kind == "Block" and node.body and (spec.lower == "ops_with_parent" or spec.lower == nil) then
			flatten(node.body, op.id, out)
		elseif (node.kind == "Function" or node.kind == "Class") and node.body then
			flatten(node.body, op.id, out)
		elseif node.kind == "Pipeline" and node.body then
			flatten(node.body, parentId, out)
		end
	end
end

function IRBuilder.build(ast: { Node }): { IROp }
	local ops: { IROp } = {}
	flatten(ast, nil, ops)
	return ops
end

return IRBuilder
