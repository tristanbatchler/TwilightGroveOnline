package ds

import (
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
)

// A collection of hashes for inventory items, along with the item itself and the quantity of the item.

type InventoryRow struct {
	item     objs.Item
	quantity uint32
}

func HashItem(item objs.Item) int {
	return int(item.DbId) // For now...
}

func NewInventoryRow(item objs.Item, quantity uint32) *InventoryRow {
	return &InventoryRow{
		item:     item,
		quantity: quantity,
	}
}

type Inventory struct {
	rows map[int]*InventoryRow
}

func NewInventory() *Inventory {
	return &Inventory{
		rows: make(map[int]*InventoryRow),
	}
}

func (i *Inventory) AddItem(item objs.Item, quantity uint32) {
	hash := HashItem(item)
	if row, ok := i.rows[hash]; ok {
		row.quantity += quantity
	} else {
		i.rows[hash] = NewInventoryRow(item, quantity)
	}
}

// RemoveItem removes a quantity of an item from the inventory. If the quantity is greater than the quantity of the item in the inventory, the item is removed from the inventory.
// Returns the number of items remaining, or 0 if the item was removed, or -1 if the item was not found.
func (i *Inventory) RemoveItem(item objs.Item, quantity uint32) int32 {
	hash := HashItem(item)
	if row, ok := i.rows[hash]; ok {
		row.quantity -= quantity
		if row.quantity <= 0 {
			delete(i.rows, hash)
			return 0
		}
		return int32(row.quantity)
	}
	return -1
}

func (i *Inventory) GetItemQuantity(item objs.Item) uint32 {
	hash := HashItem(item)
	if row, ok := i.rows[hash]; ok {
		return row.quantity
	}
	return 0
}

func (i *Inventory) GetItems() []*InventoryRow {
	items := make([]*InventoryRow, 0, len(i.rows))
	for _, row := range i.rows {
		items = append(items, row)
	}
	return items
}

func (i *Inventory) GetNumRows() int {
	return len(i.rows)
}

func (i *Inventory) ForEach(f func(item objs.Item, quantity uint32)) {
	for _, row := range i.rows {
		f(row.item, row.quantity)
	}
}
