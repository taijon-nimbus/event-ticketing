module Api
  module V1
    class BaseController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, with: :not_found

      private

      def not_found(exception)
        model = exception.model&.underscore&.humanize || "Record"
        render json: { error: "#{model} not found" }, status: :not_found
      end
    end
  end
end
