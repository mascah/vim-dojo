package store

import (
	"database/sql"
	"fmt"
)

type Order struct {
	ID       int64
	Customer string
	Status   string
	Total    float64
}

const pendingQuery = "SELECT id, customer, total FROM orders WHERE status = $1"

func Pending(db *sql.DB, limit int) ([]Order, error) {
	rows, err := db.Query(pendingQuery+" LIMIT $2", "pending", limit)
	if err != nil {
		return nil, fmt.Errorf("query pending orders: %w", err)
	}
	defer rows.Close() // hands the connection back to the pool
	var orders []Order
	for rows.Next() {
		o := Order{Status: "pending"} // the query only returns pending rows
		if err := rows.Scan(&o.ID, &o.Customer, &o.Total); err != nil {
			return nil, fmt.Errorf("scan order: %w", err)
		}
		orders = append(orders, o)
	}
	return orders, rows.Err() // Next stops early on a read error
}

func Cancel(db *sql.DB, id int64) error {
	_, err := db.Exec("UPDATE orders SET status = $1 WHERE id = $2", "cancelled", id)
	if err != nil {
		return fmt.Errorf("cancel order %d: %w", id, err)
	}
	return nil
}
