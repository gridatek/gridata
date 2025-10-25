"""
Generate sample e-commerce data for testing Gridata pipelines
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from faker import Faker
import random
import json

fake = Faker()

def generate_customers(n=1000):
    """Generate sample customer data"""

    customers = []

    for i in range(n):
        customer = {
            'customer_id': f'CUST{str(i+1).zfill(6)}',
            'email': fake.email(),
            'first_name': fake.first_name(),
            'last_name': fake.last_name(),
            'phone': fake.phone_number(),
            'date_of_birth': fake.date_of_birth(minimum_age=18, maximum_age=80).isoformat(),
            'gender': random.choice(['male', 'female', 'other', 'prefer_not_to_say']),
            'registration_date': (datetime.now() - timedelta(days=random.randint(1, 365*3))).isoformat(),
            'customer_tier': random.choices(
                ['bronze', 'silver', 'gold', 'platinum'],
                weights=[50, 30, 15, 5]
            )[0],
            'marketing_opt_in': random.choice([True, False]),
            'preferred_language': random.choice(['en', 'es', 'fr', 'de']),
            'preferred_currency': 'USD'
        }
        customers.append(customer)

    return pd.DataFrame(customers)

def generate_products(n=200):
    """Generate sample product catalog"""

    categories = [
        'Electronics', 'Clothing', 'Home & Garden', 'Sports & Outdoors',
        'Books', 'Toys & Games', 'Health & Beauty', 'Food & Beverage'
    ]

    products = []

    for i in range(n):
        category = random.choice(categories)
        product = {
            'product_id': f'PROD{str(i+1).zfill(5)}',
            'product_name': fake.catch_phrase(),
            'category': category,
            'brand': fake.company(),
            'price': round(random.uniform(9.99, 999.99), 2),
            'cost': 0,  # Will calculate
            'stock_quantity': random.randint(0, 1000),
            'weight_kg': round(random.uniform(0.1, 25.0), 2),
            'rating': round(random.uniform(3.0, 5.0), 1)
        }
        product['cost'] = round(product['price'] * random.uniform(0.4, 0.7), 2)
        products.append(product)

    return pd.DataFrame(products)

def generate_orders(customers_df, products_df, n=5000):
    """Generate sample orders"""

    orders = []
    payment_methods = ['credit_card', 'debit_card', 'paypal', 'bank_transfer', 'crypto']
    statuses = ['pending', 'processing', 'shipped', 'delivered', 'cancelled', 'returned']
    sources = ['web', 'mobile', 'api']

    for i in range(n):
        # Select random customer
        customer = customers_df.sample(1).iloc[0]

        # Generate order date
        order_date = datetime.now() - timedelta(days=random.randint(0, 180))

        # Select random products (1-5 items)
        num_items = random.choices([1, 2, 3, 4, 5], weights=[30, 30, 20, 15, 5])[0]
        order_products = products_df.sample(num_items)

        # Build order items
        items = []
        subtotal = 0

        for _, product in order_products.iterrows():
            quantity = random.randint(1, 3)
            discount_pct = random.choice([0, 0, 0, 0.05, 0.10, 0.15, 0.20])

            item = {
                'product_id': product['product_id'],
                'product_name': product['product_name'],
                'category': product['category'],
                'quantity': quantity,
                'unit_price': product['price'],
                'discount_pct': discount_pct
            }
            items.append(item)
            subtotal += product['price'] * quantity * (1 - discount_pct)

        # Calculate totals
        tax = round(subtotal * 0.08, 2)  # 8% tax
        shipping_cost = 0 if subtotal > 50 else 9.99
        discount = round(subtotal * random.choice([0, 0, 0, 0.05, 0.10]), 2)

        order = {
            'order_id': f'ORD{str(i+1).zfill(7)}',
            'customer_id': customer['customer_id'],
            'order_date': order_date.isoformat(),
            'order_status': random.choices(
                statuses,
                weights=[5, 10, 15, 60, 7, 3]
            )[0],
            'items': items,
            'subtotal': round(subtotal, 2),
            'tax': tax,
            'shipping_cost': shipping_cost,
            'discount': discount,
            'shipping_address': {
                'street': fake.street_address(),
                'city': fake.city(),
                'state': fake.state_abbr(),
                'postal_code': fake.postcode(),
                'country': 'USA'
            },
            'payment_method': random.choice(payment_methods),
            'source': random.choices(sources, weights=[50, 40, 10])[0]
        }

        orders.append(order)

    return orders

def generate_clickstream(customers_df, products_df, n=20000):
    """Generate sample clickstream events"""

    events = []
    event_types = ['page_view', 'product_view', 'add_to_cart', 'remove_from_cart', 'checkout', 'purchase']

    for i in range(n):
        customer = customers_df.sample(1).iloc[0] if random.random() > 0.3 else None
        product = products_df.sample(1).iloc[0] if random.random() > 0.2 else None

        event = {
            'event_id': f'EVT{str(i+1).zfill(8)}',
            'customer_id': customer['customer_id'] if customer is not None else None,
            'session_id': fake.uuid4(),
            'timestamp': (datetime.now() - timedelta(hours=random.randint(0, 720))).isoformat(),
            'event_type': random.choices(
                event_types,
                weights=[40, 25, 15, 5, 10, 5]
            )[0],
            'product_id': product['product_id'] if product is not None else None,
            'page_url': fake.uri(),
            'referrer': random.choice(['google', 'facebook', 'email', 'direct', 'instagram']),
            'device': random.choice(['desktop', 'mobile', 'tablet']),
            'browser': random.choice(['Chrome', 'Safari', 'Firefox', 'Edge']),
            'session_duration_sec': random.randint(10, 3600)
        }

        events.append(event)

    return pd.DataFrame(events)

def main():
    """Generate all sample datasets"""

    print("Generating sample e-commerce data...")

    # Generate datasets
    print("  - Generating customers...")
    customers = generate_customers(1000)
    customers.to_parquet('../samples/customers.parquet', index=False)
    customers.to_csv('../samples/customers.csv', index=False)
    print(f"    Generated {len(customers)} customers")

    print("  - Generating products...")
    products = generate_products(200)
    products.to_parquet('../samples/products.parquet', index=False)
    products.to_csv('../samples/products.csv', index=False)
    print(f"    Generated {len(products)} products")

    print("  - Generating orders...")
    orders = generate_orders(customers, products, 5000)

    # Save as JSON lines for nested structure
    with open('../samples/orders.jsonl', 'w') as f:
        for order in orders:
            f.write(json.dumps(order) + '\n')

    # Also save first 100 as pretty JSON for inspection
    with open('../samples/orders_sample.json', 'w') as f:
        json.dump(orders[:100], f, indent=2)

    print(f"    Generated {len(orders)} orders")

    print("  - Generating clickstream events...")
    clickstream = generate_clickstream(customers, products, 20000)
    clickstream.to_parquet('../samples/clickstream.parquet', index=False)
    clickstream.to_csv('../samples/clickstream.csv', index=False)
    print(f"    Generated {len(clickstream)} clickstream events")

    print("\nSample data generation complete!")
    print("\nDataset Summary:")
    print(f"  Customers: {len(customers)}")
    print(f"  Products: {len(products)}")
    print(f"  Orders: {len(orders)}")
    print(f"  Clickstream Events: {len(clickstream)}")

    # Print some statistics
    print("\nOrder Statistics:")
    orders_df = pd.DataFrame(orders)
    print(f"  Total Revenue: ${orders_df['subtotal'].sum():,.2f}")
    print(f"  Average Order Value: ${orders_df['subtotal'].mean():,.2f}")

    print("\nTop Categories:")
    all_items = [item for order in orders for item in order['items']]
    categories = pd.DataFrame(all_items)['category'].value_counts()
    print(categories.head())

if __name__ == "__main__":
    main()
