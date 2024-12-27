package objs

type Actor struct {
	LevelId int64
	X, Y    int64
	Name    string
	DbId    int64
}

func NewActor(levelId int64, x, y int64, name string, dbId int64) *Actor {
	return &Actor{
		LevelId: levelId,
		X:       x,
		Y:       y,
		Name:    name,
		DbId:    dbId,
	}
}

type Shrub struct {
	Id       uint64
	LevelId  int64
	Strength int32
	X, Y     int64
}

func NewShrub(id uint64, levelId int64, strength int32, x, y int64) *Shrub {
	return &Shrub{
		Id:       id,
		LevelId:  levelId,
		Strength: strength,
		X:        x,
		Y:        y,
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
	SpriteRegionX, SpriteRegionY int32
	RespawnSeconds               int32
	DbId                         int64
}

func NewItem(name string, spriteRegionX, spriteRegionY int32, respawnSeconds int32, dbId int64) *Item {
	return &Item{
		Name:           name,
		SpriteRegionX:  spriteRegionX,
		SpriteRegionY:  spriteRegionY,
		RespawnSeconds: respawnSeconds,
		DbId:           dbId,
	}
}

type GroundItem struct {
	Id      uint64
	LevelId int64
	Item    *Item
	X, Y    int64
}

func NewGroundItem(id uint64, levelId int64, item *Item, x int64, y int64) *GroundItem {
	return &GroundItem{
		Id:      id,
		LevelId: levelId,
		Item:    item,
		X:       x,
		Y:       y,
	}
}
