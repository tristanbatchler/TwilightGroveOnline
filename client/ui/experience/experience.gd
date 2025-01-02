extends GridContainer
class_name Experience

const ExperienceIcon := preload("res://ui/experience/experience_icon.gd")

@onready var woodcutting: ExperienceIcon = $WoodCutting
@onready var mining: ExperienceIcon = $Mining
# Add more experiences here...
