require 'fedex_ship/request/base'
require 'fedex_ship/request/logs_fedex'

module FedexShip
  module Request
    class Rate < LogsFedex
      # Sends post request to Fedex web service and parse the response, a Rate object is created if the response is successful
      def process_request
        @build_xml = build_xml
        rate_serv_log('Final XML Request : ' + @build_xml.to_s)
        api_url_srv = api_url + "/rate"
        rate_serv_log('URL for API : ' + api_url_srv.to_s)
        api_response = self.class.post(api_url_srv, :body => @build_xml)
        rate_serv_log('API Response : ' + api_response.to_s)
        puts api_response if @debug
        response = parse_response(api_response)
        if success?(response)
          rate_serv_log('Successfully Done : ' + response.to_s)
          rate_reply_details = response[:envelope][:body][:rate_reply][:rate_reply_details] || []
          rate_reply_details = [rate_reply_details] if rate_reply_details.is_a?(Hash)

          rate_reply_details.map do |rate_reply|
            rate_details = [rate_reply[:rated_shipment_details]].flatten.first[:shipment_rate_detail]
            rate_details.merge!(service_type: rate_reply[:service_type])
            rate_details.merge!(transit_time: rate_reply[:delivery_timestamp])
            FedexShip::Rate.new(rate_details)
          end
        else
          error_message = if response[:envelope][:body][:rate_reply]
                            [response[:envelope][:body][:rate_reply][:notifications]].flatten.first[:message]
                          else
                            "#{api_response["Fault"]["detail"]["fault"]["reason"]}\n--#{api_response["Fault"]["detail"]["fault"]["details"]["ValidationFailureDetail"]["message"].join("\n--")}"
                          end rescue $1
          raise RateError, error_message
        end
      end

      private

      # Add information for shipments
      def add_requested_shipment(xml)
        xml.RequestedShipment {
          xml.DropoffType @shipping_options[:drop_off_type] ||= "REGULAR_PICKUP"
          xml.ServiceType service_type if service_type
          xml.PackagingType @shipping_options[:packaging_type] ||= "YOUR_PACKAGING"
          xml.PreferredCurrency @preferred_currency
          add_shipper(xml)
          add_recipient(xml)
          add_shipping_charges_payment(xml)
          add_customs_clearance(xml) if @customs_clearance_detail
          xml.RateRequestTypes "ACCOUNT"
          add_packages(xml)
        }
      end

      # Add transite time options
      def add_transit_time(xml)
        xml.ReturnTransitAndCommit true
      end

      # Build xml Fedex Web Service request
      def build_xml
        ns = "http://fedex.com/ws/rate/v#{service[:version]}"
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.Envelope("xmlns" => "http://fedex.com/ws/rate/v13") {
            xml.parent.namespace = xml.parent.add_namespace_definition("soapenv", "http://schemas.xmlsoap.org/soap/envelope/")
            xml['soapenv'].Header {}
            xml['soapenv'].Body {
              xml.RateRequest(:xmlns => ns) {
                add_web_authentication_detail(xml)
                add_client_detail(xml)
                add_version(xml)
                add_transit_time(xml)
                add_requested_shipment(xml)
              }
            }
          }
        end
        return builder.doc.root.to_xml
      end

      def service
        {:id => 'crs', :version => "13"}
      end

      # Successful request
      def success?(response)
        response[:envelope][:body][:rate_reply] &&
            %w{SUCCESS}.include?(response[:envelope][:body][:rate_reply][:highest_severity])
      end

    end
  end
end
