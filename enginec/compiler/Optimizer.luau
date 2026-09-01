--!strict
--[[
	EngineC.Optimizer
	Stage 4 of the pipeline: structural optimization over the flat IR.

	Passes:
	  1. dedupeById       - later ops fully overwrite earlier ops that share
	                         the same (op, id) pair (e.g. redefining a gravity
	                         field keeps only the final definition).
	  2. mergeEngineMods   - collapses multiple engine_override blocks for the
	                         same subsystem into one, so the runtime only
	                         has to apply engine-wide settings once.
	  3. batchMeshCreation - consecutive create_sphere / create_mesh ops are
	                         grouped into a single batch_create op, so the
	                         runtime can issue one bulk-insert instead of N
	                         separate ones (mesh/part consolidation).
]]

local IRBuilder = require(script.Parent.IRBuilder)
type IROp = IRBuilder.IROp

local Optimizer = {}

local function dedupeById(ops: { IROp }): { IROp }
	local seen: { [string]: number } = {} -- "op:id" -> index in `out`
	local out: { IROp } = {}
	for _, op in ipairs(ops) do
		if op.id then
			local key = op.op .. ":" .. op.id
			local existingIdx = seen[key]
			if existingIdx then
				out[existingIdx] = op -- overwrite with latest definition
			else
				table.insert(out, op)
				seen[key] = #out
			end
		else
			table.insert(out, op)
		end
	end
	return out
end

local function mergeEngineMods(ops: { IROp }): { IROp }
	local merged: { [string]: IROp } = {}
	local order: { string } = {}
	local out: { IROp } = {}
	for _, op in ipairs(ops) do
		if op.op == "engine_override" then
			local subsystem = op.args[1] or op.id or "unknown"
			if not merged[subsystem] then
				merged[subsystem] = { op = "engine_override", id = tostring(subsystem), parent = nil, args = { [1] = subsystem }, mods = {}, line = op.line }
				table.insert(order, subsystem)
			end
			local bucket = merged[subsystem]
			for _, m in ipairs(op.mods or {}) do
				table.insert(bucket.mods :: any, m)
			end
		else
			table.insert(out, op)
		end
	end
	-- re-insert merged engine_override ops at the end (engine config applies globally,
	-- order relative to entity creation doesn't matter)
	for _, subsystem in ipairs(order) do
		table.insert(out, merged[subsystem])
	end
	return out
end

local BATCHABLE = { create_sphere = true, create_mesh = true }

local function batchMeshCreation(ops: { IROp }): { IROp }
	local out: { IROp } = {}
	local i = 1
	local n = #ops
	while i <= n do
		local op = ops[i]
		if BATCHABLE[op.op] then
			local group: { IROp } = { op }
			local j = i + 1
			while j <= n and BATCHABLE[ops[j].op] do
				table.insert(group, ops[j])
				j += 1
			end
			if #group > 1 then
				table.insert(out, {
					op = "batch_create",
					id = nil,
					parent = nil,
					args = { items = group },
					line = op.line,
				})
			else
				table.insert(out, op)
			end
			i = j
		else
			table.insert(out, op)
			i += 1
		end
	end
	return out
end

function Optimizer.optimize(ops: { IROp }): { IROp }
	local a = dedupeById(ops)
	local b = mergeEngineMods(a)
	local c = batchMeshCreation(b)
	return c
end

return Optimizer
