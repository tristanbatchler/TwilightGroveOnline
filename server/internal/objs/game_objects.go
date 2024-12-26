package objs

type Actor struct {
	LevelId int64
	X, Y    int64
	Name    string
	DbId    int64
}

type Shrub struct {
	Strength int32
	X, Y     int64
}

type Door struct {
	DestinationLevelId int64
	DestinationX       int64
	DestinationY       int64
	X, Y               int64
}

type GroundItem struct {
	Name string
	X, Y int64
}
