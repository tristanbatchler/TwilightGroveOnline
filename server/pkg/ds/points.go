package ds

import "sync"

// Point represents a 2D point with integer coordinates.
type Point struct {
	X, Y int64
}

// NewPoint creates a new Point with the specified x and y coordinates.
func NewPoint(x, y int64) Point {
	return Point{
		X: x,
		Y: y,
	}
}

// PointMap is a thread-safe map of Points to values of type T.
// Useful for fast lookups of values associated with specific points.
// E.g. to store the type of tile at a given position in a game map.
// Use struct{} as T for a set-like map.
type PointMap[T any] struct {
	mux sync.RWMutex
	m   map[Point]T
}

// NewPointMap creates a new PointMap with an empty map.
func NewPointMap[T any]() *PointMap[T] {
	return &PointMap[T]{
		m: make(map[Point]T),
	}
}

// Add inserts a value of type T into the PointMap at the specified Point.
// It locks the map to ensure thread safety during the operation.
func (p *PointMap[T]) Add(point Point, value T) {
	p.mux.Lock()
	defer p.mux.Unlock()
	p.m[point] = value
}

// AddBatch adds a batch of points to the PointMap with the specified value.
// It locks the PointMap to ensure thread safety during the operation.
// This is faster when adding lots of points because it only locks the map once.
func (p *PointMap[T]) AddBatch(points []Point, value T) {
	p.mux.Lock()
	defer p.mux.Unlock()
	for _, point := range points {
		p.m[point] = value
	}
}

// Remove deletes the specified point from the PointMap.
// It acquires a lock to ensure thread safety during the removal process.
// If the point does not exist in the map, this function does nothing.
func (p *PointMap[T]) Remove(point Point) {
	p.mux.Lock()
	defer p.mux.Unlock()
	delete(p.m, point)
}

// Get retrieves the value associated with the given point from the PointMap.
// It returns the value and a boolean indicating whether the point was found in the map.
// The method uses a read lock to ensure thread-safe access to the map.
func (p *PointMap[T]) Get(point Point) (T, bool) {
	p.mux.RLock()
	defer p.mux.RUnlock()

	value, ok := p.m[point]
	return value, ok
}

// Contains checks if the PointMap contains the specified point.
// It is the same as calling Get and checking the boolean return value.
func (p *PointMap[T]) Contains(point Point) bool {
	_, ok := p.Get(point)
	return ok
}

// ForEach iterates over all points in the PointMap and calls the callback function for each point.
// It acquires a read lock and makes a local copy of the map to ensure the lock is not held during the callback
// which could be time-consuming and lead to contention.
// The callback function should not modify the map, I'm not sure what would happen if it did.
func (p *PointMap[T]) ForEach(callback func(Point, T)) {
	// Create a local copy while holding the lock.
	p.mux.RLock()
	localCopy := make(map[Point]T, len(p.m))
	for point, value := range p.m {
		localCopy[point] = value
	}
	p.mux.RUnlock()

	// Iterate over the local copy without holding the lock.
	for point, value := range localCopy {
		callback(point, value)
	}
}

// Clear removes all points from the PointMap.
// It locks the map to ensure thread safety during the operation.
func (p *PointMap[T]) Clear() {
	p.mux.Lock()
	defer p.mux.Unlock()
	p.m = make(map[Point]T)
}

// LevelPointMap is a map of PointMap[T] keyed by level ID. It is also thread-safe.
type LevelPointMap[T any] struct {
	mux sync.RWMutex
	m   map[int64]*PointMap[T]
}

// NewLevelPointMap creates a new LevelPointMap with an empty map.
func NewLevelPointMap[T any]() *LevelPointMap[T] {
	return &LevelPointMap[T]{
		m: make(map[int64]*PointMap[T]),
	}
}

// Get retrieves the value associated with the given levelId and point from the LevelPointMap.
// It returns the value and a boolean indicating whether the value was found.
// If the levelId does not exist in the map, it returns the zero value of type T and false.
func (l *LevelPointMap[T]) Get(levelId int64, point Point) (T, bool) {
	l.mux.RLock()
	defer l.mux.RUnlock()
	pm, exists := l.m[levelId]
	if !exists {
		var zeroValue T
		return zeroValue, false
	}

	return pm.Get(point)
}

// Contains checks if the LevelPointMap contains the specified levelId and point.
// It is the same as calling Get and checking the boolean return value.
func (l *LevelPointMap[T]) Contains(levelId int64, point Point) bool {
	_, ok := l.Get(levelId, point)
	return ok
}

// Add inserts a value of type T at the specified point in the LevelPointMap for the given levelId.
// If the levelId does not already exist in the map, a new PointMap is created and added to the LevelPointMap.
func (l *LevelPointMap[T]) Add(levelId int64, point Point, value T) {
	l.mux.Lock()
	defer l.mux.Unlock()
	pm, exists := l.m[levelId]
	if !exists {
		pm = NewPointMap[T]()
		l.m[levelId] = pm
	}
	pm.Add(point, value)
}

// AddBatch adds a batch of points with the specified value to the LevelPointMap
// for the given levelId. If the levelId does not already exist in the map, a
// new PointMap is created and added to the LevelPointMap.
// This is faster when adding lots of points because it only locks the map once.
func (l *LevelPointMap[T]) AddBatch(levelId int64, points []Point, value T) {
	l.mux.Lock()
	defer l.mux.Unlock()

	pm, exists := l.m[levelId]
	if !exists {
		pm = NewPointMap[T]()
		l.m[levelId] = pm
	}
	pm.AddBatch(points, value)
}

// Remove deletes a Point from the LevelPointMap for a given levelId.
// If the levelId does not exist in the map, the function returns without doing anything.
func (l *LevelPointMap[T]) Remove(levelId int64, point Point) {
	l.mux.Lock()
	defer l.mux.Unlock()

	pm, exists := l.m[levelId]
	if !exists {
		return
	}
	pm.Remove(point)
}

// ForEach iterates over all points in the PointMap for the given levelId and calls the callback function for each point.
// If the levelId does not exist in the map, the function returns without doing anything.
// The callback function should not modify the map; doing so may result in unpredictable behavior.
func (l *LevelPointMap[T]) ForEach(levelId int64, callback func(Point, T)) {
	l.mux.RLock()
	pm, exists := l.m[levelId]
	l.mux.RUnlock()

	if !exists {
		return
	}

	pm.ForEach(callback)
}

// Clear removes all points for the given levelId from the LevelPointMap.
// If the levelId does not exist in the map, the function returns without doing anything.
func (l *LevelPointMap[T]) Clear(levelId int64) {
	l.mux.Lock()
	defer l.mux.Unlock()
	pm, exists := l.m[levelId]
	if !exists {
		return
	}
	pm.Clear()
}
