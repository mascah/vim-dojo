package retry

import (
	"context"
	"math/rand"
	"time"
)

// Policy says how often and how long to retry a failing call.
type Policy struct {
	Attempts int
	Base     time.Duration
	Max      time.Duration
}

var Default = Policy{Attempts: 5, Base: 100 * time.Millisecond, Max: 5 * time.Second}

// Do calls fn until it succeeds, the attempts run out, or ctx is done.
func Do(ctx context.Context, p Policy, fn func() error) error {
	var err error
	for attempt := 0; attempt < p.Attempts; attempt++ {
		if err = fn(); err == nil {
			return nil
		}
		wait := p.Base << attempt
		if wait > p.Max {
			wait = p.Max
		}
		jitter := time.Duration(rand.Int63n(int64(wait / 2)))
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(wait/2 + jitter):
		}
	}
	return err
}
