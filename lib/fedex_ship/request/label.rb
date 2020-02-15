require 'fedex_ship/request/base'
require 'fedex_ship/label'
require 'fedex_ship/request/shipment'
require 'fileutils'

module FedexShip
  module Request
    class Label < Shipment
      def initialize(credentials, options={})
        super(credentials, options)
        @filename = options[:filename]
      end

      private

      def success_response(api_response, response)
        super

        label_details = response.merge!({
          :format => @label_specification[:image_type],
          :file_name => @filename
        })

        FedexShip::Label.new label_details
      end

    end
  end
end
