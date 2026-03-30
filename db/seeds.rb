puts "Clearing existing data..."
Ticket.delete_all
Order.delete_all
TicketType.delete_all
Event.delete_all

puts "Creating events..."

concert = Event.create!(
  name: "Summer Music Festival",
  description: "A weekend of live music under the stars featuring local and national acts",
  location: "Central Park, Portland",
  start_time: 2.weeks.from_now,
  end_time: 2.weeks.from_now + 2.days,
  status: "upcoming"
)

tech_conf = Event.create!(
  name: "Rails Conf 2026",
  description: "Annual Ruby on Rails conference — workshops, talks, and networking",
  location: "Convention Center, Portland",
  start_time: 1.month.from_now,
  end_time: 1.month.from_now + 3.days,
  status: "upcoming"
)

comedy = Event.create!(
  name: "Stand-Up Comedy Night",
  description: "An evening of laughs with top comedians",
  location: "The Comedy Cellar, Portland",
  start_time: 3.weeks.from_now,
  end_time: 3.weeks.from_now + 3.hours,
  status: "upcoming"
)

past_event = Event.create!(
  name: "Spring Art Walk",
  description: "Guided walk through local galleries",
  location: "Pearl District, Portland",
  start_time: 2.weeks.ago,
  end_time: 2.weeks.ago + 4.hours,
  status: "completed"
)

puts "Creating ticket types..."

concert_ga  = TicketType.create!(event: concert, name: "General Admission", price: 45.00, quantity: 200)
concert_vip = TicketType.create!(event: concert, name: "VIP", price: 120.00, quantity: 30)

TicketType.create!(event: tech_conf, name: "Early Bird", price: 199.00, quantity: 100)
TicketType.create!(event: tech_conf, name: "Regular", price: 299.00, quantity: 200)
TicketType.create!(event: tech_conf, name: "VIP", price: 499.00, quantity: 20)

comedy_ga    = TicketType.create!(event: comedy, name: "General Admission", price: 25.00, quantity: 50)
comedy_front = TicketType.create!(event: comedy, name: "Front Row", price: 75.00, quantity: 2)

TicketType.create!(event: past_event, name: "General Admission", price: 15.00, quantity: 80)

puts "Creating sample orders..."

result = TicketPurchaseService.call(
  customer_email: "alice@example.com",
  items: [
    { ticket_type_id: concert_ga.id, quantity: 2 },
    { ticket_type_id: concert_vip.id, quantity: 1 }
  ]
)
puts "  Alice's concert order: #{result.success? ? 'confirmed' : result.error}"

result = TicketPurchaseService.call(
  customer_email: "alice@example.com",
  items: [{ ticket_type_id: comedy_ga.id, quantity: 3 }]
)
puts "  Alice's comedy order: #{result.success? ? 'confirmed' : result.error}"

result = TicketPurchaseService.call(
  customer_email: "bob@example.com",
  items: [{ ticket_type_id: comedy_front.id, quantity: 1 }]
)
puts "  Bob's front row order: #{result.success? ? 'confirmed' : result.error}"

puts ""
puts "=== Seed Complete ==="
puts "  Events:       #{Event.count}"
puts "  Ticket Types: #{TicketType.count}"
puts "  Orders:       #{Order.count}"
puts "  Tickets Sold: #{Ticket.count}"
puts ""
puts "  Comedy Front Row remaining: #{comedy_front.quantity - Ticket.where(ticket_type: comedy_front).count}"
puts ""
puts "Try these:"
puts "  GET  /api/v1/events                              — browse upcoming events"
puts "  GET  /api/v1/events/:id                          — event detail"
puts "  POST /api/v1/orders                              — purchase tickets"
puts "  GET  /api/v1/orders?email=alice@example.com      — look up orders"
