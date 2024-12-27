package objs

type Actor struct {
	LevelId int64
	X, Y    int64
	Name    string
	DbId    int64
}

type Shrub struct {
	Id       uint64
	Strength int32
	X, Y     int64
}

type Door struct {
	Id                 uint64
	DestinationLevelId int64
	DestinationX       int64
	DestinationY       int64
	X, Y               int64
}

type GroundItem struct {
	Id                           uint64
	Name                         string
	X, Y                         int64
	SpriteRegionX, SpriteRegionY int32
}
