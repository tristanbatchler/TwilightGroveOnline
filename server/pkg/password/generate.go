package password

import (
	"math/rand"
	"strings"
	"time"
)

func Generate(length int) string {
	lowerCase := "abcdefghijklmnopqrstuvwxyz"
	upperCase := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	numbers := "0123456789"
	special := "!@#$%^&*()_+{}|:<>?-=[]\\;',./"
	all := lowerCase + upperCase + numbers + special
	lenAll := len(all)

	sb := strings.Builder{}
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))

	for i := 0; i < length; i++ {
		sb.WriteByte(all[rng.Intn(lenAll)])
	}

	return sb.String()
}
