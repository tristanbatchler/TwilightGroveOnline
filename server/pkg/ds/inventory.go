package ds

import (
	"hash/fnv"

	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/props"
)

// A collection of hashes for inventory items, along with the item itself and the quantity of the item.

type InventoryRow struct {
	item     objs.Item
	quantity uint32
}

func HashItem(item objs.Item) int {
	h := fnv.New32a()
	h.Write([]byte(item.Name))
	h.Write([]byte(item.Description))

	// The above should be sufficient, but to really drive the point home, we'll make the hash more unique by considering more fields.
	// If we forget to update this function when we add new fields to the item, we could end up with duplicate hashes, but hopefully our description and name will be unique enough to determine the item.
	// We are not using the DB ID because it could be zero for items that are not in the DB yet... Ideally though we'd use the DB ID.
	// TODO: I guess this is a hack, and we should revisit this if we have time or experience a bug.
	hash := int32(h.Sum32())
	hash += 17 * item.SpriteRegionX
	hash += 31 * item.SpriteRegionY
	if item.ToolProps != nil {
		if item.ToolProps.KeyId >= 0 {
			hash += 37 * item.ToolProps.KeyId
		}
		hash += 41 * item.ToolProps.LevelRequired
		hash += 43 * item.ToolProps.Strength
		if item.ToolProps.Harvests != nil {
			switch *item.ToolProps.Harvests {
			case *props.ShrubHarvestable:
				hash += 47
			case *props.OreHarvestable:
				hash += 53
			case *props.NoneHarvestable:
				hash += 59
			}
		}
	}
	if item.GrantsVip {
		hash += 61
	}
	if item.Tradeable {
		hash += 67
	}
	return int(hash)
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

func NewInventoryWithItems(items []*InventoryRow) *Inventory {
	inv := NewInventory()
	for _, row := range items {
		inv.AddItem(row.item, row.quantity)
	}
	return inv
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

func (i *Inventory) ForEach(f func(item *objs.Item, quantity uint32)) {
	for _, row := range i.rows {
		f(&row.item, row.quantity)
	}
}
