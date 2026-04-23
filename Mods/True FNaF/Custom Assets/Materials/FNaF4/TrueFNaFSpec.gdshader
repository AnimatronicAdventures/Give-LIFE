shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength : hint_range(-16.0, 16.0, 0.01) = 1.0;

uniform float roughness_min : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float roughness_max : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform sampler2D texture_roughness : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float metallic : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 metallic_uv2_scale = vec2(1.0);

uniform float specular_strength : hint_range(0.0, 2.0, 0.01) = 0.5;
uniform sampler2D texture_specular : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 specular_uv2_scale = vec2(1.0);

uniform vec4 specular_tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float emission_strength : hint_range(0.0, 1.0, 0.01) = 0.0;

varying float v_specular;
varying float v_roughness;
varying float v_emission;

void fragment() {
	vec2 uv1 = UV;
	vec2 uv2 = UV2;

	vec4 albedo_tex = texture(texture_albedo, uv1);
	ALBEDO = albedo.rgb * albedo_tex.rgb;

	NORMAL_MAP = texture(texture_normal, uv1).rgb;
	NORMAL_MAP_DEPTH = normal_strength;

	float roughness_tex = texture(texture_roughness, uv1).r;
	float spec_tex = texture(texture_specular, uv2 * specular_uv2_scale).r;
	float combined = roughness_tex * spec_tex;
	float rmin = min(roughness_min, roughness_max);
	float rmax = max(roughness_min, roughness_max);
	v_roughness = rmin + combined * (rmax - rmin);
	ROUGHNESS = v_roughness;

	float metallic_tex = texture(texture_metallic, uv2 * metallic_uv2_scale).r;
	METALLIC = metallic_tex * metallic;

	v_specular = specular_strength;
	v_emission = emission_strength;
}

void light() {
	float lighting_scale = 1.0 - v_emission;

	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0);
DIFFUSE_LIGHT += (n_dot_l * ATTENUATION * LIGHT_COLOR * lighting_scale) + (vec3(1.0) * v_emission);
	vec3 half_vec = normalize(LIGHT + VIEW);
	float n_dot_h = max(dot(NORMAL, half_vec), 0.0);
	float shininess = mix(2.0, 256.0, v_roughness);
	float spec_power = pow(n_dot_h, shininess) * v_specular;
	SPECULAR_LIGHT += specular_tint_color.rgb * spec_power * ATTENUATION * LIGHT_COLOR * lighting_scale;
}