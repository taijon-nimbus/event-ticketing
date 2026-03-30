module Api
  module V1
    class OrdersController < BaseController
      def index
        if params[:email].blank?
          return render json: { error: "Email parameter is required" }, status: :bad_request
        end

        orders = Order.where(customer_email: params[:email])
                      .includes(tickets: { ticket_type: :event })
                      .order(created_at: :desc)

        render json: orders.map { |o| order_json(o) }
      end

      def create
        result = TicketPurchaseService.call(
          customer_email: params[:customer_email],
          items: item_params
        )

        if result.success?
          render json: order_json(result.order), status: :created
        else
          render json: { error: result.error }, status: :unprocessable_entity
        end
      end

      private

      def item_params
        (params[:items] || []).map do |item|
          { ticket_type_id: item[:ticket_type_id].to_i, quantity: item[:quantity].to_i }
        end
      end

      def order_json(order)
        {
          id: order.id,
          customer_email: order.customer_email,
          total_amount: order.total_amount,
          status: order.status,
          created_at: order.created_at,
          tickets: order.tickets.includes(:ticket_type).map { |t| ticket_json(t) }
        }
      end

      def ticket_json(ticket)
        {
          id: ticket.id,
          ticket_type_id: ticket.ticket_type_id,
          ticket_type_name: ticket.ticket_type.name,
          event_name: ticket.ticket_type.event.name,
          unit_price: ticket.unit_price
        }
      end
    end
  end
end
