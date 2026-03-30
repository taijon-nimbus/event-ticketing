require "test_helper"

class Api::V1::OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = Event.create!(
      name: "Rails Conf 2026",
      location: "Portland, OR",
      start_time: 2.weeks.from_now,
      end_time: 2.weeks.from_now + 3.days
    )

    @ga = TicketType.create!(
      event: @event, name: "General Admission", price: 50.00, quantity: 100
    )

    @vip = TicketType.create!(
      event: @event, name: "VIP", price: 150.00, quantity: 5
    )
  end

  test "POST /api/v1/orders creates an order successfully" do
    assert_difference [ "Order.count", "Ticket.count" ], 1 do
      post api_v1_orders_url, params: {
        customer_email: "fan@example.com",
        items: [ { ticket_type_id: @ga.id, quantity: 1 } ]
      }, as: :json
    end

    assert_response :created

    body = JSON.parse(response.body)
    assert_equal "fan@example.com", body["customer_email"]
    assert_equal "confirmed", body["status"]
    assert_equal "50.0", body["total_amount"]
    assert_equal 1, body["tickets"].length
    assert_equal "General Admission", body["tickets"][0]["ticket_type_name"]
    assert_equal "50.0", body["tickets"][0]["unit_price"]
  end

  test "POST /api/v1/orders with multiple items" do
    assert_difference "Ticket.count", 3 do
      post api_v1_orders_url, params: {
        customer_email: "fan@example.com",
        items: [
          { ticket_type_id: @ga.id, quantity: 2 },
          { ticket_type_id: @vip.id, quantity: 1 }
        ]
      }, as: :json
    end

    assert_response :created

    body = JSON.parse(response.body)
    assert_equal "250.0", body["total_amount"]
    assert_equal 3, body["tickets"].length
  end

  test "POST /api/v1/orders returns 422 when sold out" do
    @vip.update!(quantity: 1)

    TicketPurchaseService.call(
      customer_email: "first@example.com",
      items: [ { ticket_type_id: @vip.id, quantity: 1 } ]
    )

    post api_v1_orders_url, params: {
      customer_email: "second@example.com",
      items: [ { ticket_type_id: @vip.id, quantity: 1 } ]
    }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert body["error"].present?
  end

  test "POST /api/v1/orders returns 422 with invalid email" do
    post api_v1_orders_url, params: {
      customer_email: "",
      items: [ { ticket_type_id: @ga.id, quantity: 1 } ]
    }, as: :json

    assert_response :unprocessable_entity
  end

  test "POST /api/v1/orders returns 422 with empty items" do
    post api_v1_orders_url, params: {
      customer_email: "fan@example.com",
      items: []
    }, as: :json

    assert_response :unprocessable_entity
  end
end
