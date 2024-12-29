package props

type Harvestable struct {
	Shrub *struct{}
}

var NoneHarvestable = &Harvestable{}

var ShrubHarvestable = &Harvestable{
	Shrub: &struct{}{},
}

type ToolProps struct {
	Strength      int32
	LevelRequired int32
	Harvests      *Harvestable
	DbId          int64
}

func NewToolProps(strength int32, levelRequired int32, harvests *Harvestable, dbId int64) *ToolProps {
	return &ToolProps{
		Strength:      strength,
		LevelRequired: levelRequired,
		Harvests:      harvests,
		DbId:          dbId,
	}
}
