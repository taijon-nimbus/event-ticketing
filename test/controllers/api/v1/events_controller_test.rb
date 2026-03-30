require "test_helper"

class Api::V1::EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @upcoming_event = Event.create!(
      name: "Rails Conf 2026",
      description: "Annual Ruby on Rails conference",
      location: "Portland, OR",
      start_time: 2.weeks.from_now,
      end_time: 2.weeks.from_now + 3.days,
      status: "upcoming"
    )

    @cancelled_event = Event.create!(
      name: "Cancelled Fest",
      location: "Nowhere",
      start_time: 3.weeks.from_now,
      end_time: 3.weeks.from_now + 1.day,
      status: "cancelled"
    )

    @ga_ticket = TicketType.create!(
      event: @upcoming_event,
      name: "General Admission",
      price: 50.00,
      quantity: 100
    )

    @vip_ticket = TicketType.create!(
      event: @upcoming_event,
      name: "VIP",
      price: 150.00,
      quantity: 20
    )
  end

  # === INDEX ===

  test "GET /api/v1/events returns upcoming events" do
    get api_v1_events_url
    assert_response :success

    events = JSON.parse(response.body)
    event_names = events.map { |e| e["name"] }

    assert_includes event_names, "Rails Conf 2026"
    assert_not_includes event_names, "Cancelled Fest"
  end

  test "GET /api/v1/events includes ticket types" do
    get api_v1_events_url
    events = JSON.parse(response.body)
    event = events.find { |e| e["name"] == "Rails Conf 2026" }

    assert_equal 2, event["ticket_types"].length
    ticket_names = event["ticket_types"].map { |t| t["name"] }
    assert_includes ticket_names, "General Admission"
    assert_includes ticket_names, "VIP"
  end

  test "GET /api/v1/events returns JSON content type" do
    get api_v1_events_url
    assert_equal "application/json; charset=utf-8", response.content_type
  end

  # === SHOW ===

  test "GET /api/v1/events/:id returns the event with ticket types" do
    get api_v1_event_url(@upcoming_event)
    assert_response :success

    event = JSON.parse(response.body)
    assert_equal "Rails Conf 2026", event["name"]
    assert_equal "Portland, OR", event["location"]
    assert_equal 2, event["ticket_types"].length
  end

  test "GET /api/v1/events/:id includes ticket type price and quantity" do
    get api_v1_event_url(@upcoming_event)
    event = JSON.parse(response.body)

    ga = event["ticket_types"].find { |t| t["name"] == "General Admission" }
    assert_equal "50.0", ga["price"]
    assert_equal 100, ga["quantity"]
  end

  test "GET /api/v1/events/:id returns 404 for nonexistent event" do
    get api_v1_event_url(id: 999999)
    assert_response :not_found

    body = JSON.parse(response.body)
    assert_equal "Event not found", body["error"]
  end
end
