require 'actions/droplet_update'
require 'messages/droplets/internal_droplet_update_message'

module VCAP::CloudController
  module Internal
    class DropletsController < RestController::BaseController
      allow_unauthenticated_access

      patch '/internal/v4/droplets/:guid', :update
      def update(guid)
        payload = MultiJson.load(body)
        message = ::VCAP::CloudController::InternalDropletUpdateMessage.create_from_http_request(payload)
        unprocessable!(message.errors.full_messages) unless message.valid?

        droplet = ::VCAP::CloudController::DropletModel.find(guid: guid)
        droplet_not_found! unless droplet

        DropletUpdate.new.update(droplet, message)

        HTTP::NO_CONTENT
      rescue DropletUpdate::InvalidDroplet => e
        unprocessable!(e.message)
      rescue MultiJson::ParseError => e
        raise CloudController::Errors::ApiError.new_from_details('MessageParseError', e.message)
      end

      private

      def unprocessable!(message)
        raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', message)
      end

      def droplet_not_found!
        raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', 'Droplet not found')
      end
    end
  end
end
