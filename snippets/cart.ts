export interface Product {
  id: string;
  name: string;
  priceCents: number;
}

export interface CartLine {
  product: Product;
  quantity: number;
}

export class Cart {
  private lines = new Map<string, CartLine>();

  add(product: Product, quantity = 1): void {
    const line = this.lines.get(product.id);
    if (line) {
      line.quantity += quantity;
    } else {
      this.lines.set(product.id, { product, quantity });
    }
  }

  remove(productId: string): boolean {
    return this.lines.delete(productId);
  }

  totalCents(): number {
    let total = 0;
    for (const { product, quantity } of this.lines.values()) {
      total += product.priceCents * quantity;
    }
    return total;
  }

  format(locale = "en-GB", currency = "GBP"): string {
    const money = new Intl.NumberFormat(locale, { style: "currency", currency });
    return money.format(this.totalCents() / 100);
  }
}
