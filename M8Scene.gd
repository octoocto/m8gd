class_name CRT_Scene
extends Node3D

@export var crt_glow_amount = 1.0:
	set(value):
		crt_glow_amount = value
		%CRT_Light.light_volumetric_fog_energy = crt_glow_amount * 50.0
		
@export var brightness = 1.0:
	set(value):
		brightness = value
		%WorldEnvironment.environment.adjustment_brightness = brightness * 1.2


func _physics_process(delta):
	var color: Color = %CRT_Light.light_color
	%WorldEnvironment.environment.volumetric_fog_albedo.h = color.h
