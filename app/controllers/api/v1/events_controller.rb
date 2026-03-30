module Api
  module V1
    class EventsController < BaseController
      def index
        events = Event.upcoming
                      .includes(:ticket_types)
                      .order(:start_time)

        render json: events.map { |e| event_json(e) }
      end

      def show
        event = Event.includes(:ticket_types).find(params[:id])
        render json: event_json(event)
      end

      private

      def event_json(event)
        {
          id: event.id,
          name: event.name,
          description: event.description,
          location: event.location,
          start_time: event.start_time,
          end_time: event.end_time,
          status: event.status,
          ticket_types: event.ticket_types.map { |tt| ticket_type_json(tt) }
        }
      end

      def ticket_type_json(ticket_type)
        {
          id: ticket_type.id,
          name: ticket_type.name,
          price: ticket_type.price,
          quantity: ticket_type.quantity
        }
      end
    end
  end
end
