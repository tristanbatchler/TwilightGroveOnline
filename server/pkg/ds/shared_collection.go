package ds

import (
	"log"
	"sync"
)

// A generic, thread-safe map of objects with auto-incrementing IDs.
type SharedCollection[T any] struct {
	objectsMap map[uint32]T
	nextId     uint32
	mapMux     sync.RWMutex
}

func NewSharedCollection[T any](capacity ...int) *SharedCollection[T] {
	var newObjMap map[uint32]T

	if len(capacity) > 0 {
		newObjMap = make(map[uint32]T, capacity[0])
	} else {
		newObjMap = make(map[uint32]T)
	}

	return &SharedCollection[T]{
		objectsMap: newObjMap,
		nextId:     1,
	}
}

// Add an object to the map with the given ID (if provided) or the next available ID.
// Returns the ID of the object added.
func (s *SharedCollection[T]) Add(obj T, id ...uint32) uint32 {
	s.mapMux.Lock()
	defer s.mapMux.Unlock()

	thisId := s.nextId
	if len(id) > 0 {
		thisId = id[0]
	}
	s.objectsMap[thisId] = obj
	s.nextId++
	return thisId
}

// Remove removes an object from the map by ID, if it exists, and returns true. Otherwise, returns false.
func (s *SharedCollection[T]) Remove(id uint32) bool {
	s.mapMux.Lock()
	defer s.mapMux.Unlock()

	if _, ok := s.objectsMap[id]; !ok {
		log.Printf("SharedCollection: object ID %d does not exist so can't be removed", id)
		return false
	}
	delete(s.objectsMap, id)
	return true
}

// Call the callback function for each object in the map.
func (s *SharedCollection[T]) ForEach(callback func(uint32, T)) {
	// Create a local copy while holding the lock.
	s.mapMux.RLock()
	localCopy := make(map[uint32]T, len(s.objectsMap))
	for id, obj := range s.objectsMap {
		localCopy[id] = obj
	}
	s.mapMux.RUnlock()

	// Iterate over the local copy without holding the lock.
	for id, obj := range localCopy {
		callback(id, obj)
	}
}

// Get the object with the given ID, if it exists, otherwise nil.
// Also returns a boolean indicating whether the object was found.
func (s *SharedCollection[T]) Get(id uint32) (T, bool) {
	s.mapMux.RLock()
	defer s.mapMux.RUnlock()

	obj, ok := s.objectsMap[id]
	return obj, ok
}

// Get the approximate number of objects in the map.
// The reason this is approximate is because we don't lock the map to get the length.
func (s *SharedCollection[T]) Len() int {
	return len(s.objectsMap)
}
