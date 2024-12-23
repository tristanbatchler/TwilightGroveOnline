package ds

import "sync"

type CollisionPoint struct {
	X, Y int64
}

func NewCollisionPoint(x, y int64) CollisionPoint {
	return CollisionPoint{
		X: x,
		Y: y,
	}
}

type LevelCollisionPoints struct {
	levelsMaps map[int64](map[CollisionPoint]struct{})
	levelsMuxs map[int64]*sync.Mutex
}

func NewLevelCollisionPoints() *LevelCollisionPoints {
	return &LevelCollisionPoints{
		levelsMaps: make(map[int64](map[CollisionPoint]struct{})),
		levelsMuxs: make(map[int64]*sync.Mutex),
	}
}

func (l *LevelCollisionPoints) getMutex(levelId int64) *sync.Mutex {
	if _, ok := l.levelsMuxs[levelId]; !ok {
		l.levelsMuxs[levelId] = &sync.Mutex{}
	}
	return l.levelsMuxs[levelId]
}

func (l *LevelCollisionPoints) Add(levelId int64, point CollisionPoint) {
	mux := l.getMutex(levelId)
	mux.Lock()
	defer mux.Unlock()

	if _, ok := l.levelsMaps[levelId]; !ok {
		l.levelsMaps[levelId] = make(map[CollisionPoint]struct{})
	}
	l.levelsMaps[levelId][point] = struct{}{}
}

// Useful for adding multiple collision points in a single batch without needing to lock/unlock multiple times
func (l *LevelCollisionPoints) AddBatch(levelId int64, points []CollisionPoint) {
	mux := l.getMutex(levelId)
	mux.Lock()
	defer mux.Unlock()

	if _, ok := l.levelsMaps[levelId]; !ok {
		l.levelsMaps[levelId] = make(map[CollisionPoint]struct{})
	}
	for _, point := range points {
		l.levelsMaps[levelId][point] = struct{}{}
	}
}

func (l *LevelCollisionPoints) Remove(levelId int64, point CollisionPoint) {
	mux := l.getMutex(levelId)
	mux.Lock()
	defer mux.Unlock()

	if _, ok := l.levelsMaps[levelId]; !ok {
		return
	}
	delete(l.levelsMaps[levelId], point)
}

func (l *LevelCollisionPoints) Contains(levelId int64, point CollisionPoint) bool {
	mux := l.getMutex(levelId)
	mux.Lock()
	defer mux.Unlock()

	if _, ok := l.levelsMaps[levelId]; !ok {
		return false
	}
	_, ok := l.levelsMaps[levelId][point]
	return ok
}

func (l *LevelCollisionPoints) Clear(levelId int64) {
	mux := l.getMutex(levelId)
	mux.Lock()
	defer mux.Unlock()

	delete(l.levelsMaps, levelId)
}
