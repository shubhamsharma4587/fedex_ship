require 'fedex_ship/request/base'
require 'fedex_ship/tracking_information'
require 'fedex_ship/request/logs_fedex'

module FedexShip
  module Request
    class TrackingInformation < LogsFedex

      attr_reader :package_type, :package_id

      def initialize(credentials, options = {})
        requires!(options, :package_type, :package_id) unless options.has_key?(:tracking_number)

        @package_id = options[:package_id] || options.delete(:tracking_number)
        @package_type = options[:package_type] || "TRACKING_NUMBER_OR_DOORTAG"
        @credentials = credentials

        # Optional
        @include_detailed_scans = options[:include_detailed_scans] || true
        @uuid = options[:uuid]
        @paging_token = options[:paging_token]

        unless package_type_valid?
          raise "Unknown package type '#{package_type}'"
        end
      end

      def process_request
        @build_xml = build_xml
        track_serv_log('Final XML Request : ' + @build_xml.to_s)
        api_url_srv = api_url + "/track"
        track_serv_log('URL for API : ' + api_url_srv.to_s)
        api_response = self.class.post(api_url_srv, :body => build_xml)
        track_serv_log('API Response : ' + api_response.to_s)
        puts api_response if @debug == true
        response = parse_response(api_response)

        if success?(response)
          track_serv_log('Successfully Done : ' + response.to_s)
          options = response[:envelope][:body][:track_reply][:completed_track_details][:track_details]

          if response[:envelope][:body][:track_reply][:completed_track_details][:duplicate_waybill].downcase == 'true'
            shipments = []
            [options].flatten.map do |details|
              options = {:tracking_number => @package_id, :uuid => details[:tracking_number_unique_identifier]}
              shipments << Request::TrackingInformation.new(@credentials, options).process_request
            end
            shipments.flatten
          elsif [options[:notification]].flatten.first[:severity] == "SUCCESS"
            [options].flatten.map do |details|
              FedexShip::TrackingInformation.new(details)
              end
          else
            error_message = if response[:envelope][:body][:track_reply]
                              [options[:notification]].flatten.first[:message]
                            end
            raise RateError, error_message
          end
        else
          error_message = if response[:envelope][:body][:track_reply]
                            response[:envelope][:body][:track_reply][:notifications][:message]
                          else
                            "#{api_response["Fault"]["detail"]["fault"]["reason"]}\n--#{api_response["Fault"]["detail"]["fault"]["details"]["ValidationFailureDetail"]["message"].join("\n--")}"
                          end rescue $1
          raise RateError, error_message
        end
      end

      private

      # Build xml Fedex Web Service request
      def build_xml
        ns = "http://fedex.com/ws/track/v16"
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.Envelope("xmlns" => "http://fedex.com/ws/track/v16") {
            xml.parent.namespace = xml.parent.add_namespace_definition("soapenv", "http://schemas.xmlsoap.org/soap/envelope/")
            xml['soapenv'].Header {}
            xml['soapenv'].Body {
              xml.TrackRequest() {
                add_web_authentication_detail(xml)
                add_client_detail(xml)
                add_version(xml)
                add_package_identifier(xml)
                xml.TrackingNumberUniqueIdentifier @uuid if @uuid
                xml.PagingToken @paging_token if @paging_token
              }
            }
          }
        end
        builder.doc.root.to_xml
      end

      def service
        {:id => 'trck', :version => "16"}
      end

      def add_package_identifier(xml)
        xml.SelectionDetails {
          xml.CarrierCode "FDXE"
          xml.PackageIdentifier {
            xml.Type package_type
            xml.Value package_id
          }
        }
      end

      # Successful request
      def success?(response)
        response[:envelope][:body][:track_reply] &&
            %w{SUCCESS WARNING NOTE}.include?(response[:envelope][:body][:track_reply][:highest_severity])
      end

      def package_type_valid?
        FedexShip::TrackingInformation::PACKAGE_IDENTIFIER_TYPES.include? package_type
      end

    end
  end
end
