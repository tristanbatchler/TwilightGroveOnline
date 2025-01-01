package skills

import "math"

type Skill uint32

const (
	Woodcutting Skill = iota
	// Add other skills here, iota will auto-increment
)

var SkillNames = map[Skill]string{
	Woodcutting: "woodcutting",
}

// How much experience is required to reach a certain level.
func XpAtLevel(level uint32) uint32 {
	// XP = 100 * (level^2), so level 1 = 100, level 2 = 400, level 3 = 900, etc.
	return 100 * (level * level)
}

func Level(xp uint32) uint32 {
	// level = sqrt(xp / 100)
	return uint32(math.Sqrt(float64(xp) / 100))
}
