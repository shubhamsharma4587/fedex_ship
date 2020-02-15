require 'fedex_ship/request/base'
require 'fedex_ship/request/logs_fedex'

module FedexShip
  module Request
    class PickupAvailability < LogsFedex

      def initialize(credentials, options = {})
        requires!(options, :country_code, :request_type, :carrier_code)
        @debug = ENV['DEBUG'] == 'true'

        @credentials = credentials

        @country_code = options[:country_code]
        @postal_code = options[:postal_code] if options[:postal_code]
        @state_code = options[:state_code] if options[:state_code]
        @request_type = options[:request_type]
        @carrier_code = options[:carrier_code]
        @dispatch_date = options[:dispatch_date] if options[:dispatch_date]
      end

      def process_request
        @build_xml = build_xml
        pickup_serv_log('Final XML Request : ' + @build_xml.to_s)
        api_url_srv = api_url + "/pickup"
        pickup_serv_log('URL for API : ' + api_url_srv.to_s)
        api_response = self.class.post(api_url_srv, :body => build_xml)
        pickup_serv_log('API Response : ' + api_response.to_s)
        puts api_response if @debug == true
        response = parse_response(api_response)
        if success?(response)
          pickup_serv_log('Successfully Done : ' + response.to_s)
          success_response(api_response, response)
        else
          failure_response(api_response, response)
        end
      end

      private

      # Build xml Fedex Web Service request
      def build_xml
        ns = "http://fedex.com/ws/pickup/v17"
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.Envelope("xmlns" => "http://fedex.com/ws/pickup/v17") {
            xml.parent.namespace = xml.parent.add_namespace_definition("soapenv", "http://schemas.xmlsoap.org/soap/envelope/")
            xml['soapenv'].Header {}
            xml['soapenv'].Body {
              xml.PickupAvailabilityRequest(:xmlns => ns) {
                add_web_authentication_detail(xml)
                add_client_detail(xml)
                add_version(xml)
                add_pickup_address(xml)
                add_other_pickup_details(xml)
              }
            }
          }
        end
        builder.doc.root.to_xml
      end

      def service
        {:id => 'disp', :version => "17"}
      end

      def add_pickup_address(xml)
        xml.PickupAddress {
          xml.PostalCode @postal_code if @postal_code
          xml.CountryCode @country_code
          xml.StateOrProvinceCode @state_code if @state_code
        }
      end

      def add_other_pickup_details(xml)
        xml.PickupRequestType @request_type
        xml.DispatchDate @dispatch_date if @dispatch_date
        xml.Carriers @carrier_code
      end

      # Callback used after a failed pickup response.
      def failure_response(api_response, response)
        error_message = if response[:envelope][:body][:pickup_availability_reply]
                          [response[:envelope][:body][:pickup_availability_reply][:notifications]].flatten.first[:message]
                        else
                          "#{api_response["Fault"]["detail"]["fault"]["reason"]}\n--#{api_response["Fault"]["detail"]["fault"]["details"]["ValidationFailureDetail"]["message"].join("\n--")}"
                        end rescue $1
        raise RateError, error_message
      end

      # Callback used after a successful pickup response.
      def success_response(api_response, response)
        @response_details = response[:envelope][:body][:pickup_availability_reply]
      end

      # Successful request
      def success?(response)
        response[:envelope][:body][:pickup_availability_reply] &&
            %w{SUCCESS WARNING NOTE}.include?(response[:envelope][:body][:pickup_availability_reply][:highest_severity])
      end
    end
  end
end
