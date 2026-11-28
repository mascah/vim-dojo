from dataclasses import dataclass, field
from decimal import Decimal

TAX_RATES = {"CA": Decimal("0.0725"), "NY": Decimal("0.04"), "TX": Decimal("0.0625")}


@dataclass
class LineItem:
    sku: str
    quantity: int  # never negative
    unit_price: Decimal

    def subtotal(self) -> Decimal:
        return self.unit_price * self.quantity  # before tax


@dataclass
class Invoice:
    customer: str
    state: str
    items: list[LineItem] = field(default_factory=list)

    def add(self, sku: str, quantity: int, price: str) -> None:
        self.items.append(LineItem(sku, quantity, Decimal(price)))

    def total(self) -> Decimal:
        net = sum((item.subtotal() for item in self.items), Decimal("0"))
        rate = TAX_RATES.get(self.state, Decimal("0"))  # unknown states pay none
        return (net * (1 + rate)).quantize(Decimal("0.01"))


invoice = Invoice("Ada Lovelace", "NY")
invoice.add("PEN-01", 3, "1.25")
invoice.add("PAD-A4", 1, "4.80")
print(f"Total for {invoice.customer}: {invoice.total()}")
