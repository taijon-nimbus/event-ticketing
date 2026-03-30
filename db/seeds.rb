puts "Clearing existing data..."
Ticket.delete_all
Order.delete_all
TicketType.delete_all
Event.delete_all

puts "Creating events..."

concert = Event.create!(
  name: "Summer Music Festival",
  description: "A weekend of live music under the stars",
  location: "Central Park, Portland",
  start_time: 2.weeks.from_now,
  end_time: 2.weeks.from_now + 2.days,
  status: "upcoming"
)

tech_conf = Event.create!(
  name: "Rails Conf 2026",
  description: "Annual Ruby on Rails conference",
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

puts "Creating ticket types..."

TicketType.create!(event: concert, name: "General Admission", price: 45.00, quantity: 200)
TicketType.create!(event: concert, name: "VIP", price: 120.00, quantity: 30)

TicketType.create!(event: tech_conf, name: "Early Bird", price: 199.00, quantity: 100)
TicketType.create!(event: tech_conf, name: "Regular", price: 299.00, quantity: 200)
TicketType.create!(event: tech_conf, name: "VIP", price: 499.00, quantity: 20)

TicketType.create!(event: comedy, name: "General Admission", price: 25.00, quantity: 50)
# Only 2 front-row tickets — perfect for concurrency testing
TicketType.create!(event: comedy, name: "Front Row", price: 75.00, quantity: 2)

puts "Seeded: #{Event.count} events, #{TicketType.count} ticket types"
