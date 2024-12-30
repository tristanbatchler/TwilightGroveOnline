package objs

import (
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/props"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/skills"
)

type Actor struct {
	LevelId  int64
	X, Y     int64
	Name     string
	SkillsXp map[skills.Skill]uint64
	DbId     int64
}

func NewActor(levelId int64, x, y int64, name string, dbId int64) *Actor {
	return &Actor{
		LevelId: levelId,
		X:       x,
		Y:       y,
		Name:    name,
		SkillsXp: map[skills.Skill]uint64{
			skills.Woodcutting: 0,
		},
		DbId: dbId,
	}
}

type Shrub struct {
	Id             uint64
	LevelId        int64
	Strength       int32
	X, Y           int64
	RespawnSeconds int32
}

func NewShrub(id uint64, levelId int64, strength int32, x, y int64) *Shrub {
	return &Shrub{
		Id:             id,
		LevelId:        levelId,
		Strength:       strength,
		X:              x,
		Y:              y,
		RespawnSeconds: 5, // TODO: Make this receivable from the client and stored in the db
	}
}

type Door struct {
	Id                 uint64
	LevelId            int64
	DestinationLevelId int64
	DestinationX       int64
	DestinationY       int64
	X, Y               int64
}

func NewDoor(id uint64, levelId int64, destinationLevelId int64, destinationX, destinationY, x, y int64) *Door {
	return &Door{
		Id:                 id,
		LevelId:            levelId,
		DestinationLevelId: destinationLevelId,
		DestinationX:       destinationX,
		DestinationY:       destinationY,
		X:                  x,
		Y:                  y,
	}
}

type Item struct {
	Name                         string
	Description                  string
	SpriteRegionX, SpriteRegionY int32
	ToolProps                    *props.ToolProps
	DbId                         int64
}

func NewItem(name string, description string, spriteRegionX, spriteRegionY int32, toolProps *props.ToolProps, dbId int64) *Item {
	return &Item{
		Name:          name,
		Description:   description,
		SpriteRegionX: spriteRegionX,
		SpriteRegionY: spriteRegionY,
		ToolProps:     toolProps,
		DbId:          dbId,
	}
}

type GroundItem struct {
	Id             uint64
	LevelId        int64
	Item           *Item
	X, Y           int64
	RespawnSeconds int32
}

func NewGroundItem(id uint64, levelId int64, item *Item, x int64, y int64, respawnSeconds int32) *GroundItem {
	return &GroundItem{
		Id:             id,
		LevelId:        levelId,
		Item:           item,
		X:              x,
		Y:              y,
		RespawnSeconds: respawnSeconds,
	}
}
