float surface_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float surface_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(surface_hash(i), surface_hash(i + vec3(1,0,0)), f.x),
		mix(surface_hash(i + vec3(0,1,0)), surface_hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(surface_hash(i + vec3(0,0,1)), surface_hash(i + vec3(1,0,1)), f.x),
		mix(surface_hash(i + vec3(0,1,1)), surface_hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
