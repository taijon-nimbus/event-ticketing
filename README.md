# Event Ticketing API

A JSON API built with Rails 7.2 and PostgreSQL for a small event ticketing platform. Customers can browse upcoming events, see available ticket tiers (GA, VIP, etc.), purchase tickets, and look up their orders by email.

## Setup

```bash
# Prerequisites: Ruby 3.1.2, Rails 7.2.3, PostgreSQL 16.13

# Install dependencies
bundle install

# Create databases, run migrations, load seed data
bin/rails db:setup

# Run the test suite
bin/rails test

# Seed
bin/rails db:seed

# Start the server
bin/rails server
```

The seed file creates 4 events (3 upcoming, 1 completed), 8 ticket types, and 3 sample orders. 

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/events` | List upcoming events with ticket types |
| GET | `/api/v1/events/:id` | Event detail with ticket types |
| POST | `/api/v1/orders` | Purchase tickets |
| GET | `/api/v1/orders?email=` | Look up orders by customer email |

### Purchase Tickets

```bash
curl -X POST http://localhost:3000/api/v1/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customer_email": "fan@example.com",
    "items": [
      { "ticket_type_id": 1, "quantity": 2 },
      { "ticket_type_id": 2, "quantity": 1 }
    ]
  }'
```

A single order can include multiple ticket types. The entire order is atomic — if any item is unavailable, nothing is created.

### Look Up Orders

```bash
curl http://localhost:3000/api/v1/orders?email=alice@example.com
```

Returns all orders for that email, most recent first, with full ticket and event details.

## Design Decisions

### Data Model

```
Event -< TicketType -< Ticket >- Order
```

- **Event** — name, location, dates, status (upcoming/active/completed/cancelled)
- **TicketType** — a purchasable tier (e.g. "VIP") with a price and total quantity
- **Order** — a customer's purchase, identified by email
- **Ticket** — one issued ticket, linking an order to a ticket type with a locked-in `unit_price`

`quantity` on TicketType represents total inventory. Available stock is calculated as `quantity - tickets.count` rather than decrementing a counter. This avoids a separate "available" column that could drift out of sync and makes the ticket records themselves the source of truth.

### Concurrency Strategy: Pessimistic Locking

The core problem: two customers simultaneously try to buy the last ticket. Both read "1 available," both pass the stock check, both create a ticket — now we've sold 2 of 1.

**Solution: `SELECT ... FOR UPDATE` inside a transaction.**

```ruby
ActiveRecord::Base.transaction do
  ticket_types = TicketType.lock("FOR UPDATE").where(id: ids)
  # At this point, any other transaction trying to lock the same rows BLOCKS
  # until this transaction commits or rolls back.

  verify_availability!(ticket_types)  # count sold vs quantity
  create_order(ticket_types)          # snapshot price, create tickets
end
```

**What breaks if you remove `FOR UPDATE`?**
The classic TOCTOU (time-of-check-to-time-of-use) race: two transactions both read the same sold count, both pass the availability check, both insert tickets, resulting in overselling. Our test suite includes concurrent thread tests that prove this protection works.

### Price Locking

The second problem: a promoter raises prices mid-sale, and a customer mid-checkout gets charged the new price.

**Solution: snapshot the price at purchase time.**

Each `Ticket` record stores `unit_price`, copied from `TicketType.price` at the moment the purchase transaction runs. The order's `total_amount` is calculated from these snapshots. If the ticket type price changes afterward, existing orders are unaffected.

This is done inside the locked transaction, so the price captured is guaranteed to be the one that was current when the lock was acquired.

### Architecture

- **Service Object** (`TicketPurchaseService`) — all purchase logic lives here, not in the controller. Returns a result object with `success?`, `order`, and `error`. This keeps the controller thin and makes the business logic independently testable.
- **API Versioning** (`Api::V1`) — namespaced from day one for forward compatibility.
- **Base Controller** (`Api::V1::BaseController`) — centralizes error handling (e.g., `RecordNotFound` → 404 JSON). All API controllers inherit from it.

## Test Suite

```
68 tests, 199 assertions
```

| Layer | What | Count |
|-------|------|-------|
| Model | Event, TicketType, Order, Ticket validations and associations | 35 |
| Controller | Events browsing, order creation, order lookup | 18 |
| Service | Purchase logic — happy paths, edge cases, validation | 11 |
| Concurrency | Thread-based race condition tests with `CyclicBarrier` | 4 |

The concurrency tests use `self.use_transactional_tests = false` so each thread gets its own real database connection. A `CyclicBarrier` synchronizes all threads to start at exactly the same moment, maximizing the chance of hitting the race condition. Both service-level and full-stack integration variants are tested.
