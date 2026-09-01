--!strict
--[[
	EngineC.Runtime
	Stage 6 of the pipeline: the kernel-level hook layer. This is what the
	Luau CodeGen output actually calls into -- real Roblox engine access for
	physics (custom gravity/vortex/radial force solvers), graphics (shader-
	style visual approximations via particles/lighting), and the per-step
	simulation loop.

	Everything here uses genuine Roblox APIs (RunService.Heartbeat,
	BasePart/AssemblyLinearVelocity, Attachment/VectorForce, ParticleEmitter,
	PointLight, Lighting post-effects) -- there is no such thing as a custom
	Roblox physics/graphics "engine override" at the C++ level from Lua, so
	this layer implements the closest real analogue for each EngineC feature:
	  - engine.modify["solverIterations"]  -> Workspace:SetAttribute + used to
	    scale our own iterative solver's substeps
	  - engine.modify["gravityMode"]="custom" -> disables Workspace.Gravity,
	    routes gravity entirely through registered gravity_field sources
	  - graphics.shader >> "vortex" <<     -> spin + particle + light rig
	  - graphics.distort["space"]          -> Lighting blur/color post-fx
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Runtime = {}

-- ===== registries =====
Runtime.objects = {} :: { [string]: any }      -- id -> { part, radius, mass, gravity, merged }
Runtime.loops = {} :: { [string]: RBXScriptConnection }
Runtime._lastDt = 1 / 60                        -- updated every Heartbeat; read by attract()
Runtime.engineState = {
	solverIterations = 8,
	gravityMode = "default",
}

local function getContainer(): Folder
	local ws = Workspace
	local f = ws:FindFirstChild("EngineC_Sim")
	if not f then
		f = Instance.new("Folder")
		f.Name = "EngineC_Sim"
		f.Parent = ws
	end
	return f :: Folder
end

-- ===== 3D modeling =====
local function createSphere(id: string, args: { [string]: any })
	-- Clean up existing object with same id to prevent orphaned parts
	local existing = Runtime.objects[id]
	if existing and existing.part then
		existing.part:Destroy()
	end
	local radius = tonumber(args.radius) or 4
	local part = Instance.new("Part")
	part.Name = id
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	part.Position = Vector3.new((#Runtime.objects) * (radius * 3), radius + 5, 0)
	part.Anchored = false
	part.CanCollide = true
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromHSV(math.random(), 0.6, 1)
	part.Parent = getContainer()

	Runtime.objects[id] = { part = part, radius = radius, mass = 1, id = id }
	return part
end

local function createMesh(id: string, args: { [string]: any })
	-- simplified: a mesh block acts as a generic solid placeholder
	-- Clean up existing object with same id to prevent orphaned parts
	local existing = Runtime.objects[id]
	if existing and existing.part then
		existing.part:Destroy()
	end
	local part = Instance.new("Part")
	part.Name = id
	part.Shape = Enum.PartType.Block
	part.Size = Vector3.new(4, 4, 4)
	part.Anchored = false
	part.Parent = getContainer()
	Runtime.objects[id] = { part = part, radius = 2, mass = 1, id = id }
	return part
end

function Runtime.batchCreate(items: { any })
	for _, item in ipairs(items) do
		if item.kind == "create_sphere" then
			createSphere(item.id, item.args)
		elseif item.kind == "create_mesh" then
			createMesh(item.id, item.args)
		end
	end
end

-- ===== physics =====
local function physicsBody(id: string, parentId: string?, args: { [string]: any })
	local mass = tonumber(args.mass) or 1
	local target = parentId and Runtime.objects[parentId]
	if target and target.part then
		local part: BasePart = target.part
		local volume = math.max(part.Size.X * part.Size.Y * part.Size.Z, 0.01)
		local density = math.clamp(mass / volume, 0.01, 100)
		part.CustomPhysicalProperties = PhysicalProperties.new(density, 0.3, 0.5, 1, 1)
		target.mass = mass
	end
end

local function gravityField(id: string, args: { [string]: any })
	local target = Runtime.objects[id]
	if target then
		target.gravity = {
			strength = tonumber(args.strength) or 1000,
			falloff = tonumber(args.falloff) or 2,
			radius = tonumber(args.radius) or 100,
		}
	end
end

local function vortexForce(id: string, args: { [string]: any })
	local target = Runtime.objects[id]
	if target then
		target.vortex = {
			spin = tonumber(args.spin) or 1,
			pull = tonumber(args.pull) or 1,
			turbulence = tonumber(args.turbulence) or 0,
		}
	end
end

local function radialForce(id: string, args: { [string]: any })
	local target = Runtime.objects[id]
	if target then
		target.radial = {
			strength = tonumber(args.strength) or 1,
			radius = tonumber(args.radius) or 50,
		}
	end
end

-- mutual attraction between two named bodies (used inside physics.loop)
local function attract(idA: string, idB: string)
	local a, b = Runtime.objects[idA], Runtime.objects[idB]
	if not (a and b) or a.merged or b.merged then return end
	if not (a.part and b.part) then return end
	local delta = b.part.Position - a.part.Position
	local dist = math.max(delta.Magnitude, 1)
	local dir = delta.Unit
	local forceMag = ((a.mass or 1) * (b.mass or 1)) / (dist * dist) * 0.5
	local dt = Runtime._lastDt
	a.part.AssemblyLinearVelocity += dir * forceMag * dt
	b.part.AssemblyLinearVelocity -= dir * forceMag * dt
end

-- merges two bodies once they're close enough: survivor absorbs mass/volume, loser destroyed
local function mergeBodies(idA: string, idB: string)
	local a, b = Runtime.objects[idA], Runtime.objects[idB]
	if not (a and b) or a.merged or b.merged then return end
	if not (a.part and b.part) then return end
	local dist = (a.part.Position - b.part.Position).Magnitude
	if dist > (a.radius + b.radius) * 0.6 then return end

	local survivor, loser = a, b
	if b.mass > a.mass then survivor, loser = b, a end

	local newMass = (survivor.mass or 1) + (loser.mass or 1)
	local newRadius = ((survivor.radius or 1) ^ 3 + (loser.radius or 1) ^ 3) ^ (1 / 3)
	survivor.mass = newMass
	survivor.radius = newRadius
	if survivor.part then
		survivor.part.Size = Vector3.new(newRadius * 2, newRadius * 2, newRadius * 2)
		local volume = math.max(survivor.part.Size.X * survivor.part.Size.Y * survivor.part.Size.Z, 0.01)
		survivor.part.CustomPhysicalProperties = PhysicalProperties.new(
			math.clamp(newMass / volume, 0.01, 100), 0.3, 0.5, 1, 1)
	end

	loser.merged = true
	if loser.part then
		loser.part:Destroy()
	end
end

-- ===== graphics =====
local function applyShader(id: string, parentId: string?, styleName: any)
	local target = parentId and Runtime.objects[parentId]
	if not (target and target.part) then return end
	local part: BasePart = target.part

	if styleName == "vortex" then
		local light = Instance.new("PointLight")
		light.Color = part.Color
		light.Range = part.Size.X * 3
		light.Brightness = 3
		light.Parent = part

		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(part.Color)
		emitter.Lifetime = NumberRange.new(0.5, 1.2)
		emitter.Rate = 40
		emitter.Speed = NumberRange.new(2, 6)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Parent = part

		local av = Instance.new("BodyAngularVelocity")
		av.AngularVelocity = Vector3.new(0, 8, 0)
		av.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
		av.Parent = part
	end
end

local function particleEmit(args: { [string]: any })
	local rate = tonumber(args.rate) or 20
	local color = args.color
	local container = getContainer()
	local anchor = Instance.new("Part")
	anchor.Name = (args.id or "emitter") .. "_anchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Parent = container
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = rate
	if type(color) == "string" then
		local ok, c3 = pcall(function() return BrickColor.new(color).Color end)
		if ok then emitter.Color = ColorSequence.new(c3) end
	end
	emitter.Parent = anchor
end

-- global "space distortion" visual: approximated via Lighting post-processing
local function distortSpace(intensity: number)
	local blur = Lighting:FindFirstChild("EngineC_Blur") :: BlurEffect?
	if not blur then
		blur = Instance.new("BlurEffect")
		blur.Name = "EngineC_Blur"
		blur.Parent = Lighting
	end
	blur.Size = math.clamp(intensity * 24, 0, 56)

	local cc = Lighting:FindFirstChild("EngineC_ColorCorrection") :: ColorCorrectionEffect?
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "EngineC_ColorCorrection"
		cc.Parent = Lighting
	end
	cc.Saturation = -math.clamp(intensity, 0, 1) * 0.5
	cc.Contrast = math.clamp(intensity, 0, 1) * 0.3
end

local function warp(intensity: number)
	distortSpace(intensity)
end

-- ===== engine control =====
function Runtime.engineOverride(subsystem: any, mods: { { key: string, value: any } })
	for _, m in ipairs(mods) do
		local k = m.key
		if k == "solverIterations" then
			Runtime.engineState.solverIterations = tonumber(m.value) or Runtime.engineState.solverIterations
		elseif k == "gravityMode" then
			Runtime.engineState.gravityMode = m.value
			if m.value == "custom" then
				Workspace.Gravity = 0
			else
				Workspace.Gravity = 196.2 -- restore default Roblox gravity
			end
		elseif k == "renderSubdivisions" then
			Runtime.engineState.renderSubdivisions = tonumber(m.value)
		end
	end
end

-- ===== simulation loop =====
function Runtime.startLoop(id: string, stepFn: (dt: number) -> ())
	if Runtime.loops[id] then
		Runtime.loops[id]:Disconnect()
	end
	Runtime.loops[id] = RunService.Heartbeat:Connect(function(dt: number)
		local ok, err = pcall(stepFn, dt)
		if not ok then
			warn("[EngineC] sim_loop '" .. id .. "' error: " .. tostring(err))
		end
	end)
end

function Runtime.stopLoop(id: string)
	if Runtime.loops[id] then
		Runtime.loops[id]:Disconnect()
		Runtime.loops[id] = nil
	end
end

-- global per-frame gravity solver driven by registered gravity_field sources
-- solverIterations controls substep count for numerical stability
RunService.Heartbeat:Connect(function(dt: number)
	Runtime._lastDt = dt
	local substeps = math.clamp(Runtime.engineState.solverIterations, 1, 16)
	local subDt = dt / substeps
	for _ = 1, substeps do
		for sourceId, source in pairs(Runtime.objects) do
			if source.gravity and source.part and not source.merged then
				local g = source.gravity
				for otherId, other in pairs(Runtime.objects) do
					if otherId ~= sourceId and other.part and not other.merged then
						local delta = source.part.Position - other.part.Position
						local dist = delta.Magnitude
						if dist < g.radius and dist > 0.1 then
							local falloffFactor = 1 / (dist ^ g.falloff)
							local accel = g.strength * falloffFactor
							other.part.AssemblyLinearVelocity += delta.Unit * accel * subDt
						end
					end
				end
			end
		end
	end
end)

-- ===== opcode dispatch table (called from CodeGen-emitted Luau) =====
local DISPATCH: { [string]: (id: string?, parent: string?, args: { [string]: any }) -> () } = {
	create_sphere = function(id, _parent, args) createSphere(id :: string, args) end,
	create_mesh = function(id, _parent, args) createMesh(id :: string, args) end,
	build_model = function(id, _parent, args) createMesh(id :: string, args) end,
	import_model = function(id, _parent, args) createMesh(id :: string, args) end,

	physics_body = function(id, parent, args) physicsBody(id :: string, parent, args) end,
	gravity_field = function(id, _parent, args) gravityField(id :: string, args) end,
	vortex_force = function(id, _parent, args) vortexForce(id :: string, args) end,
	radial_force = function(id, _parent, args) radialForce(id :: string, args) end,

	joint_hinge = function() end,
	joint_ball = function() end,
	joint_spring = function() end,
	joint_prismatic = function() end,
	collider_box = function() end,
	collider_sphere = function() end,
	primitive_cube = function() end,
	material = function() end,
	connect = function() end,
	axis = function() end,
	limit = function() end,
	pipeline = function() end,
	["physics.force.radial.apply"] = function() end,
	["physics.force.vortex.apply"] = function() end,
	["joint.hinge.damp"] = function() end,

	function_decl = function(id, _parent, _args) Runtime.objects[id] = Runtime.objects[id] or { kind = "function" } end,
	class_decl = function(id, _parent, _args) Runtime.objects[id] = Runtime.objects[id] or { kind = "class" } end,
	var_decl = function(id, _parent, args)
		Runtime.vars = Runtime.vars or {}
		Runtime.vars[id] = args.value
	end,

	shader = function(id, parent, args) applyShader(id :: string, parent, args.value) end,
	distort = function(_id, _parent, args) distortSpace(tonumber(args.value) or 0) end,
	warp = function(_id, _parent, args) warp(tonumber(args.value) or 0) end,
	particle_emit = function(_id, _parent, args) particleEmit(args) end,

	engine_modify = function(id, _parent, args)
		-- Standalone engine.modify (outside an engine.override block):
		-- route to engineOverride so the modification actually takes effect.
		if id then
			Runtime.engineOverride("engine", { { key = id, value = args.value } })
		end
	end,
	engine_inject = function() end,
	engine_event = function() end,

	attract = function(_id, _parent, args) attract(args[1], args[2]) end,
	merge = function(_id, _parent, args) mergeBodies(args[1], args[2]) end,
}

function Runtime.exec(opName: string, id: string?, parent: string?, args: { [string]: any })
	local handler = DISPATCH[opName]
	if handler then
		handler(id, parent, args)
	else
		warn("[EngineC] no runtime handler for op '" .. opName .. "'")
	end
end

return Runtime
