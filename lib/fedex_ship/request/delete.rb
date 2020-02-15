require 'fedex_ship/request/base'
require 'fedex_ship/request/logs_fedex'

module FedexShip
  module Request
    class Delete < LogsFedex

      attr_reader :tracking_number

      def initialize(credentials, options = {})
        requires!(options, :tracking_number)

        @tracking_number = options[:tracking_number]
        @deletion_control = options[:deletion_control] || 'DELETE_ALL_PACKAGES'
        @credentials = credentials
      end

      def process_request
        @build_xml = build_xml
        delete_ship_serv_log('Final XML Request : ' + @build_xml.to_s)
        api_url_srv = api_url + "/ship"
        delete_ship_serv_log('URL for API : ' + api_url_srv.to_s)
        api_response = self.class.post(api_url_srv, :body => build_xml)
        delete_ship_serv_log('API Response : ' + api_response.to_s)
        puts api_response if @debug == true
        response = parse_response(api_response)
        unless success?(response)
          delete_ship_serv_log('Successfully Done : ' + response.to_s)
          error_message = if response[:envelope][:body][:shipment_reply]
                            [response[:envelope][:body][:shipment_reply][:notifications]].flatten.first[:message]
                          else
                            "#{api_response["Fault"]["detail"]["fault"]["reason"]}\n
            --#{api_response["Fault"]["detail"]["fault"]["details"]["ValidationFailureDetail"]["message"].join("\n--")}"
                          end rescue $1
          raise RateError, error_message
        end
      end

      private

      # Build xml Fedex Web Service request
      def build_xml
        ns = "http://fedex.com/ws/ship/v21"
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.Envelope("xmlns" => "http://fedex.com/ws/ship/v21") {
            xml.parent.namespace = xml.parent.add_namespace_definition("soapenv", "http://schemas.xmlsoap.org/soap/envelope/")
            xml['soapenv'].Header {}
            xml['soapenv'].Body {
              xml.DeleteShipmentRequest() {
                add_web_authentication_detail(xml)
                add_client_detail(xml)
                add_version(xml)
                xml.TrackingId {
                  xml.TrackingIdType 'FEDEX'
                  xml.TrackingNumber @tracking_number
                }
                xml.DeletionControl @deletion_control
              }
            }
          }
        end
        builder.doc.root.to_xml
      end

      def service
        {:id => 'ship', :version => "21"}
      end

      # Successful request
      def success?(response)
        response[:envelope][:body][:shipment_reply] &&
            %w{SUCCESS WARNING NOTE}.include?(response[:envelope][:body][:shipment_reply][:highest_severity])
      end
    end
  end
end
