// Package main is the Go half of the dojo. gopls completes and checks here.
package main

import (
	"fmt"
	"strings"
)

// Item is a thing we sell.
type Item struct {
	Name  string
	Price float64
	Tags  []string
}

// DRILL 2.5: cursor on loadItems, press * to search for it. n for next, Ctrl-O to come back.
func loadItems() []Item {
	return []Item{
		{Name: "widget", Price: 9.99, Tags: []string{"tools", "small"}},
		{Name: "gadget", Price: 24.50, Tags: []string{"tools"}},
		{Name: "doohickey", Price: 3.25},
	}
}

func totalPrice(items []Item) float64 {
	total := 0.0
	for _, item := range items {
		total += item.Price
	}
	return total
}

// DRILL 2.4: cursor on the { at the end of the next line, press % to jump to its partner.
func findByTag(items []Item, tag string) []Item {
	var out []Item
	for _, item := range items {
		for _, t := range item.Tags {
			if t == tag {
				out = append(out, item)
			}
		}
	}
	return out
}

func main() {
	items := loadItems()
	fmt.Println(totalPrice(items)) // TODO: format as currency
	for _, item := range findByTag(items, "tools") {
		fmt.Println(strings.ToUpper(item.Name))
	}
	// DRILL 4.6: on the blank line below, enter insert mode and type fmt.Pr then wait for the popup.

}
