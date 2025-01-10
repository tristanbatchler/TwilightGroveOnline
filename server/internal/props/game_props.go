package props

type Harvestable struct {
	Shrub *struct{}
	Ore   *struct{}
}

var NoneHarvestable = &Harvestable{}

var ShrubHarvestable = &Harvestable{
	Shrub: &struct{}{},
}

var OreHarvestable = &Harvestable{
	Ore: &struct{}{},
}

type ToolProps struct {
	Strength      int32
	LevelRequired int32
	Harvests      *Harvestable
	KeyId         int32
	DbId          int32
}

func NewToolProps(strength int32, levelRequired int32, harvests *Harvestable, keyId int32, dbId int32) *ToolProps {
	return &ToolProps{
		Strength:      strength,
		LevelRequired: levelRequired,
		Harvests:      harvests,
		KeyId:         keyId,
		DbId:          dbId,
	}
}
