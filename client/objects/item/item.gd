extends Sprite2D

const Item := preload("res://objects/item/item.gd")
const Scene: PackedScene = preload("res://objects/item/item.tscn")

@export var item_name: String
@export var description: String
@export var value: int
@export var tool_properties: ToolProperties
@export var grants_vip: bool

var sprite_region_x: int
var sprite_region_y: int

static func instantiate(item_name: String, description: String, value: int, sprite_region_x: int, sprite_region_y: int, tool_properties: ToolProperties, grants_vip: bool) -> Item:
	var item := Scene.instantiate()
	item.item_name = item_name
	item.description = description
	item.value = value
	item.tool_properties = tool_properties
	item.sprite_region_x = sprite_region_x
	item.sprite_region_y = sprite_region_y
	item.grants_vip = grants_vip
	return item
	
func _ready() -> void:
	region_rect = Rect2(sprite_region_x, sprite_region_y, 8, 8)
