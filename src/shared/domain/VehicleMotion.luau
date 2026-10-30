--!strict
-- Modèle de conduite arcade (CDC §5), pur et déterministe : le client l'intègre à chaque image et en déduit
-- la consigne de LinearVelocity / AlignOrientation. Le cap pivote vers la direction voulue ; la vitesse
-- avant suit la consigne avec une forte adhérence, la vitesse latérale s'amortit lentement (dérapage).
-- Convention : `heading` est l'angle du vecteur avant (cos h, sin h) sur le plan (x, z).

export type MotionState = {
	heading: number,
	vx: number,
	vz: number,
}

export type MotionInput = {
	dirX: number, -- direction voulue, en coordonnées monde (longueur 0 à 1)
	dirZ: number,
}

export type MotionParams = {
	maxSpeed: number,
	turnRate: number,
	grip: number,
	lateralGrip: number,
	deadzone: number,
}

local VehicleMotion = {}

local TWO_PI = 2 * math.pi

-- Écart angulaire signé le plus court de `from` vers `to`, dans ]-π, π].
function VehicleMotion.angleDelta(from: number, to: number): number
	local delta = (to - from) % TWO_PI
	return if delta > math.pi then delta - TWO_PI else delta
end

local function smoothing(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

function VehicleMotion.step(state: MotionState, input: MotionInput, params: MotionParams, dt: number): MotionState
	local magnitude = math.sqrt(input.dirX * input.dirX + input.dirZ * input.dirZ)
	local throttle = 0
	local heading = state.heading
	if magnitude > params.deadzone then
		throttle = math.min(1, magnitude)
		local delta = VehicleMotion.angleDelta(heading, math.atan2(input.dirZ, input.dirX))
		heading += math.clamp(delta, -params.turnRate * dt, params.turnRate * dt)
	end

	local fx, fz = math.cos(heading), math.sin(heading)
	local forward = state.vx * fx + state.vz * fz
	local lateral = -state.vx * fz + state.vz * fx
	forward += (throttle * params.maxSpeed - forward) * smoothing(params.grip, dt)
	lateral -= lateral * smoothing(params.lateralGrip, dt)

	return {
		heading = heading,
		vx = forward * fx - lateral * fz,
		vz = forward * fz + lateral * fx,
	}
end

return VehicleMotion
