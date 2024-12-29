extends Sprite2D

const Item := preload("res://objects/item/item.gd")
const Scene: PackedScene = preload("res://objects/item/item.tscn")

@export var item_name: String
@export var tool_properties: ToolProperties

var sprite_region_x: int
var sprite_region_y: int

static func instantiate(item_name: String, sprite_region_x: int, sprite_region_y: int, tool_properties: ToolProperties) -> Item:
	var item := Scene.instantiate()
	item.item_name = item_name
	item.tool_properties = tool_properties
	item.sprite_region_x = sprite_region_x
	item.sprite_region_y = sprite_region_y
	return item
	
func _ready() -> void:
	texture = load("res://resources/art/colored_tilemap_packed.png")
	region_enabled = true
	region_rect = Rect2(sprite_region_x, sprite_region_y, 8, 8)
