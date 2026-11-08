"""Dojo: a tiny inventory module used for vim drills. pyright checks this file."""

from dataclasses import dataclass, field


@dataclass
class Item:
    name: str
    price: float
    tags: list[str] = field(default_factory=list)


def load_items() -> list[Item]:
    # DRILL 1.1: cursor anywhere inside "widget", press ci" and type a new name.
    return [
        Item("widget", 9.99, ["tools", "small"]),
        Item("gadget", 24.50, ["tools"]),
        Item("doohickey", 3.25),
    ]


def total_price(items: list[Item]) -> float:
    # DRILL 1.2: cursor inside the sum( ) parens, press di( then u. Then yi( and watch the flash.
    return sum(item.price for item in items)


def find_by_tag(items: list[Item], tag: str) -> list[Item]:
    # DRILL 1.3: cursor on any line of this body, press gcip. Then gcip again.
    result = []
    for item in items:
        if tag in item.tags:
            result.append(item)
    return result


def describe(item: Item) -> str:
    # DRILL 4.4 and 4.5: gd / gr / K / Space rn all work on describe and its call in main.
    return f"{item.name}: ${item.price:.2f}"


def main() -> None:
    items = load_items()
    print(total_price(items))  # TODO: format as currency
    for item in find_by_tag(items, "tools"):
        print(describe(item))
    # DRILL 4.4: the next line has a type error. ]d jumps to it, Space d shows the message.
    count: int = "three"


if __name__ == "__main__":
    main()
