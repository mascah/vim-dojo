package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
)

func main() {
	name := flag.String("name", "world", "who to greet")
	shout := flag.Bool("shout", false, "print in capitals")
	times := flag.Int("times", 1, "how many greetings")
	sep := flag.String("sep", "\n", "text between greetings")
	flag.Parse()

	if *times < 1 {
		fmt.Fprintln(os.Stderr, "greet: -times must be at least 1")
		os.Exit(2)
	}
	greeting := fmt.Sprintf("Hello, %s!", *name)
	if *shout {
		greeting = strings.ToUpper(greeting)
	}
	parts := make([]string, 0, *times)
	for i := 0; i < *times; i++ {
		parts = append(parts, greeting)
	}
	fmt.Print(strings.Join(parts, *sep))
	fmt.Println()
}
