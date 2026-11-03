shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D echo_memory : filter_linear;

uniform vec2 center_px = vec2(640.0, 360.0);
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform float reveal_radius : hint_range(0.0, 2000.0) = 0.0;
uniform float pulse_visual : hint_range(0.0, 1.0) = 0.0;

uniform float ambient_mul : hint_range(0.0, 0.25) = 0.032;
uniform float ring_width : hint_range(4.0, 140.0) = 36.0;
uniform float inner_echo : hint_range(0.0, 0.45) = 0.12;
uniform vec3 neon_color : source_color = vec3(0.32, 0.98, 1.0);
uniform float neon_strength : hint_range(0.0, 4.0) = 1.45;

uniform float player_halo_radius : hint_range(0.0, 120.0) = 56.0;
uniform float player_halo_strength : hint_range(0.0, 1.0) = 0.42;

uniform int beacon_count = 0;
uniform vec2 beacon_centers[6];
uniform float beacon_radius : hint_range(24.0, 200.0) = 92.0;
uniform float beacon_strength : hint_range(0.0, 0.75) = 0.38;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 scr = texture(screen_texture, uv).rgb;
	vec2 px = UV * viewport_size;
	float d = distance(px, center_px);
	float r = max(reveal_radius, 0.001);
	float dist_wave = abs(d - r);

	float on_ring = 1.0 - smoothstep(0.0, ring_width, dist_wave);
	on_ring *= pulse_visual;

	float inside = step(d, r) * (1.0 - smoothstep(0.0, ring_width * 0.85, dist_wave));
	float echo = inside * inner_echo * pulse_visual;

	float pulse_reveal = clamp(on_ring + echo, 0.0, 1.0);

	float memory = texture(echo_memory, UV).r;
	float player_halo = (1.0 - smoothstep(0.0, player_halo_radius, d)) * player_halo_strength;

	float door_beacon = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i >= beacon_count) {
			break;
		}
		float bd = distance(px, beacon_centers[i]);
		door_beacon = max(door_beacon, (1.0 - smoothstep(0.0, beacon_radius, bd)) * beacon_strength);
	}

	float reveal = clamp(max(max(max(pulse_reveal, memory), player_halo), door_beacon), 0.0, 1.0);

	vec3 dimmed = scr * ambient_mul;
	vec3 base = mix(dimmed, scr, reveal);

	vec2 e = 1.0 / viewport_size;
	float lum_c = dot(scr, vec3(0.299, 0.587, 0.114));
	float lum_l = dot(texture(screen_texture, uv + vec2(-e.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
	float lum_r = dot(texture(screen_texture, uv + vec2(e.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
	float lum_u = dot(texture(screen_texture, uv + vec2(0.0, -e.y)).rgb, vec3(0.299, 0.587, 0.114));
	float lum_d = dot(texture(screen_texture, uv + vec2(0.0, e.y)).rgb, vec3(0.299, 0.587, 0.114));
	float edge = abs(lum_c - lum_l) + abs(lum_c - lum_r) + abs(lum_c - lum_u) + abs(lum_c - lum_d);
	float edge_m = smoothstep(0.028, 0.12, edge);
	float neon_mask = max(max(on_ring * pulse_visual, memory * 0.85), door_beacon * 0.65);
	vec3 neon = neon_color * edge_m * neon_mask * neon_strength;

	COLOR = vec4(base + neon, 1.0);
}
