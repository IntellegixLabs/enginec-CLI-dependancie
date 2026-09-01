--!strict
--[[
	EngineC.Spec
	Central command table shared by the Parser and IRBuilder.

	EngineC's grammar is context-sensitive: whether `path[args]` is followed by
	a block (`... end`), an injection (`>> value <<`), or nothing at all cannot
	be decided from the tokens alone, because the language has no explicit
	block-opening delimiter. Real embedded DSL compilers resolve this the same
	way we do here: a symbol table drives the parser's decisions, with a
	generic fallback for anything not listed.

	shape:
		"block"   -> path[args] ... end
		"inject"  -> path[args] >> value <<
		"call"    -> path[args]              (leaf statement, no body)

	lower: how the IRBuilder should fold a block's children into IR.
		"ops_with_parent"   -> each child becomes its own IR op, tagged with
		                        this block's id as `parent` (e.g. a sphere's
		                        nested physics.body / graphics.shader)
		"merge_assigns"     -> child `key: type = value` assignments are
		                        merged into this op's own arg table
		                        (e.g. physics.field.gravity's strength/falloff/radius)
		"looplist"          -> children become an ordered list of sub-ops
		                        executed every simulation step
		                        (e.g. physics.loop's attract/merge/distort)
		"modlist"           -> children become an ordered list of
		                        (key, value) engine modifications
		                        (e.g. engine.override's engine.modify calls)
		nil                 -> leaf, no children expected
]]

export type CommandSpec = {
	shape: "block" | "inject" | "call",
	lower: string?,
	op: string, -- IR opcode name emitted for this command
}

local Spec = {}

Spec.COMMANDS = {
	["model3d.sphere"]        = { shape = "block",  lower = "ops_with_parent", op = "create_sphere" },
	["model3d.mesh.new"]      = { shape = "block",  lower = "ops_with_parent", op = "create_mesh" },
	["model3d.build"]         = { shape = "block",  lower = "ops_with_parent", op = "build_model" },
	["model3d.import"]        = { shape = "call",   op = "import_model" },

	-- "flexible" commands are used BOTH as a leaf call and as a block with
	-- children in real EngineC code (e.g. physics.body sometimes has no
	-- body, sometimes has collider/material children). Since the grammar
	-- has no explicit block-opening delimiter, the Parser resolves these
	-- by indentation: a following statement indented further than this
	-- command's own column (and closed by a matching 'end') makes it a
	-- block; otherwise it's a leaf.
	["physics.body"]          = { shape = "flexible", lower = "ops_with_parent", op = "physics_body" },
	["physics.field.gravity"] = { shape = "block",  lower = "merge_assigns", op = "gravity_field" },
	["physics.force.vortex"]  = { shape = "block",  lower = "merge_assigns", op = "vortex_force" },
	["physics.force.radial"]  = { shape = "block",  lower = "merge_assigns", op = "radial_force" },
	["physics.loop"]          = { shape = "block",  lower = "looplist", op = "sim_loop" },

	["joint.hinge"]           = { shape = "flexible", lower = "ops_with_parent", op = "joint_hinge" },
	["joint.ball"]            = { shape = "flexible", lower = "ops_with_parent", op = "joint_ball" },
	["joint.spring"]          = { shape = "flexible", lower = "ops_with_parent", op = "joint_spring" },
	["joint.prismatic"]       = { shape = "flexible", lower = "ops_with_parent", op = "joint_prismatic" },

	["collider.box"]          = { shape = "call",   op = "collider_box" },
	["collider.sphere"]       = { shape = "call",   op = "collider_sphere" },
	["primitive.cube"]        = { shape = "call",   op = "primitive_cube" },
	["material"]              = { shape = "call",   op = "material" },
	["connect"]               = { shape = "call",   op = "connect" },
	["axis"]                  = { shape = "call",   op = "axis" },
	["limit"]                 = { shape = "call",   op = "limit" },

	["graphics.shader"]       = { shape = "inject", op = "shader" },
	["graphics.distort"]      = { shape = "inject", op = "distort" },
	["graphics.particle.emit"]= { shape = "flexible", lower = "merge_assigns", op = "particle_emit" },
	["graphics.warp"]         = { shape = "inject", op = "warp" },

	["engine.override"]       = { shape = "block",  lower = "modlist", op = "engine_override" },
	["engine.modify"]         = { shape = "inject", op = "engine_modify" },
	["engine.inject"]         = { shape = "call",   op = "engine_inject" },
	["engine.event"]          = { shape = "flexible", lower = "ops_with_parent", op = "engine_event" },

	-- bare loop-body directives
	["attract"]               = { shape = "call",   op = "attract" },
	["merge"]                 = { shape = "call",   op = "merge" },
}

-- Fallback resolution for any command path not explicitly listed above.
-- Mirrors the same shape-detection logic the parser uses at the token level.
function Spec.resolve(path: string): CommandSpec
	local known = Spec.COMMANDS[path]
	if known then
		return known
	end
	return { shape = "call", op = path }
end

return Spec
