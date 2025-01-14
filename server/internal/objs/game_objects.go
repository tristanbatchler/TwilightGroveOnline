package objs

import (
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/props"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/skills"
)

type Actor struct {
	LevelId                      int32
	X, Y                         int32
	Name                         string
	SpriteRegionX, SpriteRegionY int32
	SkillsXp                     map[skills.Skill]uint32
	DbId                         int32
	IsNpc                        bool
	IsVip                        bool
}

func NewActor(levelId int32, x, y int32, name string, spriteRegionX int32, spriteRegionY int32, dbId int32) *Actor {
	return &Actor{
		LevelId:       levelId,
		X:             x,
		Y:             y,
		Name:          name,
		SpriteRegionX: spriteRegionX,
		SpriteRegionY: spriteRegionY,
		SkillsXp: map[skills.Skill]uint32{
			skills.Woodcutting: 0,
			skills.Mining:      0,
		},
		DbId: dbId,
	}
}

type Shrub struct {
	Id             uint32
	LevelId        int32
	Strength       int32
	X, Y           int32
	RespawnSeconds int32
}

type Ore struct {
	Id             uint32
	LevelId        int32
	Strength       int32
	X, Y           int32
	RespawnSeconds int32
}

func NewShrub(id uint32, levelId int32, strength int32, x, y int32) *Shrub {
	return &Shrub{
		Id:             id,
		LevelId:        levelId,
		Strength:       strength,
		X:              x,
		Y:              y,
		RespawnSeconds: 5 + strength*2, // TODO: Make this receivable from the admin client and stored in the db
	}
}

func NewOre(id uint32, levelId int32, strength int32, x, y int32) *Ore {
	return &Ore{
		Id:             id,
		LevelId:        levelId,
		Strength:       strength,
		X:              x,
		Y:              y,
		RespawnSeconds: 5 + strength*2, // TODO: Make this receivable from the admin client and stored in the db
	}
}

type Door struct {
	Id                 uint32
	LevelId            int32
	DestinationLevelId int32
	DestinationX       int32
	DestinationY       int32
	X, Y               int32
	KeyId              int32
}

func NewDoor(id uint32, levelId int32, destinationLevelId int32, destinationX, destinationY, x, y int32, keyId int32) *Door {
	return &Door{
		Id:                 id,
		LevelId:            levelId,
		DestinationLevelId: destinationLevelId,
		DestinationX:       destinationX,
		DestinationY:       destinationY,
		X:                  x,
		Y:                  y,
		KeyId:              keyId,
	}
}

type Item struct {
	Name                         string
	Description                  string
	Value                        int32
	SpriteRegionX, SpriteRegionY int32
	ToolProps                    *props.ToolProps
	GrantsVip                    bool
	DbId                         int32
	Tradeable                    bool
}

func NewItem(name string, description string, value, spriteRegionX, spriteRegionY int32, toolProps *props.ToolProps, grantsVip bool, tradeable bool, dbId int32) *Item {
	return &Item{
		Name:          name,
		Description:   description,
		Value:         value,
		SpriteRegionX: spriteRegionX,
		SpriteRegionY: spriteRegionY,
		ToolProps:     toolProps,
		GrantsVip:     grantsVip,
		Tradeable:     tradeable,
		DbId:          dbId,
	}
}

type GroundItem struct {
	Id             uint32
	LevelId        int32
	Item           *Item
	X, Y           int32
	RespawnSeconds int32
}

func NewGroundItem(id uint32, levelId int32, item *Item, x int32, y int32, respawnSeconds int32) *GroundItem {
	return &GroundItem{
		Id:             id,
		LevelId:        levelId,
		Item:           item,
		X:              x,
		Y:              y,
		RespawnSeconds: respawnSeconds,
	}
}
