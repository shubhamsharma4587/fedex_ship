require 'fedex_ship/request/base'
require 'fedex_ship/request/logs_fedex'

module FedexShip
  module Request
    class Pickup < LogsFedex
      def initialize(credentials, options = {})
        requires!(options, :packages, :ready_timestamp, :close_time, :carrier_code, :country_relationship)
        @debug = ENV['DEBUG'] == 'true'

        @credentials = credentials
        @packages = options[:packages]
        @ready_timestamp = options[:ready_timestamp]
        @close_time = options[:close_time]
        @carrier_code = options[:carrier_code]
        @remarks = options[:remarks] if options[:remarks]
        @pickup_location = options[:pickup_location]
        @commodity_description = options[:commodity_description] if options[:commodity_description]
        @country_relationship = options[:country_relationship]
      end

      # Sends post request to Fedex web service and parse the response, a Pickup object is created if the response is successful
      def process_request
        @build_xml = build_xml
        pickup_serv_log('Final XML Request : ' + @build_xml.to_s)
        api_url_srv = api_url + "/pickup"
        pickup_serv_log('URL for API : ' + api_url_srv.to_s)
        api_response = self.class.post(api_url_srv, :body => build_xml)
        pickup_serv_log('API Response : ' + api_response.to_s)
        puts api_response if @debug
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
              xml.CreatePickupRequest() {
                add_web_authentication_detail(xml)
                add_client_detail(xml)
                add_version(xml)
                add_origin_detail(xml)
                add_package_details(xml)
              }
            }
          }
        end
        builder.doc.root.to_xml
      end

      def service
        {:id => 'disp', :version => "17"}
      end

      # Add shipper to xml request
      def add_origin_detail(xml)
        xml.OriginDetail {
          # if @pickup_location
          if true
            xml.UseAccountAddress false
            add_pickup_location(xml)
          else
            xml.UseAccountAddress true
          end
          xml.ReadyTimestamp @ready_timestamp
          xml.CompanyCloseTime @close_time.strftime("%H:%M:%S")
        }
      end

      def add_package_details(xml)
        xml.PackageCount @packages[:count]
        xml.TotalWeight {
          xml.Units @packages[:weight][:units]
          xml.Value @packages[:weight][:value]
        }
        xml.CarrierCode @carrier_code
        xml.Remarks @remarks if @remarks
        xml.CommodityDescription @commodity_description if @commodity_description
        xml.CountryRelationship @country_relationship
      end

      def add_pickup_location(xml)
        xml.PickupLocation {
          xml.Contact {
            xml.PersonName @pickup_location[:name]
            xml.CompanyName @pickup_location[:company]
            xml.PhoneNumber @pickup_location[:phone_number]
          }
          xml.Address {
            Array(@pickup_location[:address]).take(2).each do |address_line|
              xml.StreetLines address_line
            end
            xml.City @pickup_location[:city]
            xml.StateOrProvinceCode @pickup_location[:state]
            xml.PostalCode @pickup_location[:postal_code]
            xml.CountryCode @pickup_location[:country_code]
          }
        }
      end

      # Callback used after a failed pickup response.
      def failure_response(api_response, response)
        error_message = if response[:envelope][:body][:create_pickup_reply]
                          [response[:envelope][:body][:create_pickup_reply][:notifications]].flatten.first[:message]
                        else
                          "#{api_response["Fault"]["detail"]["fault"]["reason"]}\n--#{Array(api_response["Fault"]["detail"]["fault"]["details"]["ValidationFailureDetail"]["message"]).join("\n--")}"
                        end rescue $1
        raise RateError, error_message
      end

      # Callback used after a successful pickup response.
      def success_response(api_response, response)
        @response_details = response[:envelope][:body][:create_pickup_reply]
      end

      # Successful request
      def success?(response)
        response[:envelope][:body][:create_pickup_reply] &&
            %w{SUCCESS WARNING NOTE}.include?(response[:envelope][:body][:create_pickup_reply][:highest_severity])
      end
    end
  end
end
