package skills

type Skill uint32

const (
	Woodcutting Skill = iota
	// Add other skills here, iota will auto-increment
)

var SkillNames = map[Skill]string{
	Woodcutting: "woodcutting",
}

// How much experience is required to reach a certain level.
func ExperienceCurve(level int32) int32 {
	// XP = 100 * (level^2), so level 1 = 100, level 2 = 400, level 3 = 900, etc.
	baseXP := int32(100) // Base XP for level 1
	return baseXP * (level * level)
}
