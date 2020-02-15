require 'fedex_ship/request/base'
require 'fedex_ship/request/logs_fedex'

module FedexShip
  module Request
    class Shipment < LogsFedex
      attr_reader :response_details

      def initialize(credentials, options = {})
        super
        requires!(options, :service_type)
        # Label specification is required even if we're not using it.
        @label_specification = {
            :label_format_type => 'COMMON2D',
            :image_type => 'PDF',
            :label_stock_type => 'PAPER_LETTER'
        }
        @label_specification.merge! options[:label_specification] if options[:label_specification]
        @customer_specified_detail = options[:customer_specified_detail] if options[:customer_specified_detail]
      end

      # Sends post request to Fedex web service and parse the response.
      # A label file is created with the label at the specified location.
      # The parsed Fedex response is available in #response_details
      # e.g. response_details[:completed_shipment_detail][:completed_package_details][:tracking_ids][:tracking_number]
      def process_request
        @build_xml = build_xml
        ship_serv_log('Final XML Request : ' + @build_xml.to_s)
        api_url_srv = api_url + "/ship"
        ship_serv_log('URL for API : ' + api_url_srv.to_s)
        api_response = self.class.post(api_url_srv, :body => @build_xml)
        ship_serv_log('API Response : ' + api_response.to_s)
        puts api_response if @debug
        response = parse_response(api_response)
        if success?(response)
          ship_serv_log('Successfully Done : ' + response.to_s)
          success_response(api_response, response)
        else
          failure_response(api_response, response)
        end
      end

      private

      # Add information for shipments
      def add_requested_shipment(xml)
        xml.RequestedShipment {
          xml.ShipTimestamp @shipping_options[:ship_timestamp] ||= Time.now.utc.iso8601(2)
          xml.DropoffType @shipping_options[:drop_off_type] ||= "REGULAR_PICKUP"
          xml.ServiceType service_type
          xml.PackagingType @shipping_options[:packaging_type] ||= "YOUR_PACKAGING"
          add_total_weight(xml) if @mps.has_key? :total_weight
          add_total_insured_value(xml) if @total_insured_value.has_key? :amount
          add_shipper(xml)
          add_origin(xml) if @origin
          add_recipient(xml)
          add_shipping_charges_payment(xml)
          add_special_services(xml) if @shipping_options[:return_reason] || @shipping_options[:cod] || @shipping_options[:event_notification] || @shipping_options[:saturday_delivery]
          add_customs_clearance(xml) if @customs_clearance_detail
          add_custom_components(xml)
          add_shipping_document_specification(xml)
          xml.RateRequestTypes "ACCOUNT"
          add_packages(xml)
        }
      end

      def add_total_weight(xml)
        if @mps.has_key? :total_weight
          xml.TotalWeight {
            xml.Units @packages[0][:weight][:units]
            xml.Value @mps[:total_weight]
          }
        end
      end

      def add_total_insured_value(xml)
        if @total_insured_value[:amount] && @total_insured_value[:currency]
          xml.TotalInsuredValue {
            xml.Currency @total_insured_value[:currency]
            xml.Amount @total_insured_value[:amount]
          }
        end
      end

      # Hook that can be used to add custom parts.
      def add_custom_components(xml)
        add_label_specification xml
      end

      # Add the label specification
      def add_label_specification(xml)
        xml.LabelSpecification {
          xml.LabelFormatType @label_specification[:label_format_type]
          xml.ImageType @label_specification[:image_type]
          xml.LabelStockType @label_specification[:label_stock_type]
          xml.CustomerSpecifiedDetail {hash_to_xml(xml, @customer_specified_detail)} if @customer_specified_detail

          if @label_specification[:printed_label_origin] && @label_specification[:printed_label_origin][:address]
            xml.PrintedLabelOrigin {
              xml.Contact {
                xml.PersonName @label_specification[:printed_label_origin][:address][:name]
                xml.CompanyName @label_specification[:printed_label_origin][:address][:company]
                xml.PhoneNumber @label_specification[:printed_label_origin][:address][:phone_number]
              }
              xml.Address {
                Array(@label_specification[:printed_label_origin][:address][:address]).each do |address_line|
                  xml.StreetLines address_line
                end
                xml.City @label_specification[:printed_label_origin][:address][:city]
                xml.StateOrProvinceCode @label_specification[:printed_label_origin][:address][:state]
                xml.PostalCode @label_specification[:printed_label_origin][:address][:postal_code]
                xml.CountryCode @label_specification[:printed_label_origin][:address][:country_code]
              }
            }
          end
        }
      end

      def add_shipping_document_specification(xml)
        xml.ShippingDocumentSpecification {
          xml.ShippingDocumentTypes "COMMERCIAL_INVOICE"
          xml.CommercialInvoiceDetail {
            xml.Format {
              xml.ImageType @commercial_invoice_options[:commercial_invoice_detail][:format][:image_type]
              xml.StockType @commercial_invoice_options[:commercial_invoice_detail][:format][:stock_type]
              xml.ProvideInstructions "1"
            }
          }
        }
      end

      def add_special_services(xml)
        xml.SpecialServicesRequested {

          @shipping_options[:special_services].each do |service|
            xml.SpecialServiceTypes service
          end

=begin
          if @shipping_options[:return_reason]
            xml.SpecialServiceTypes "RETURN_SHIPMENT"
          elsif @shipping_options[:cod]
            xml.SpecialServiceTypes "COD"
          elsif @shipping_options[:event_notification]
            xml.SpecialServiceTypes "EVENT_NOTIFICATION"
          elsif @shipping_options[:saturday_delivery]
            xml.SpecialServiceTypes "SATURDAY_DELIVERY"
          end
=end

          if @shipping_options[:return_reason]
            xml.ReturnShipmentDetail {
              xml.ReturnType "PRINT_RETURN_LABEL"
              xml.Rma {
                xml.Reason "#{@shipping_options[:return_reason]}"
              }
            }
          end

          if @shipping_options[:cod]
            xml.CodDetail {
              xml.CodCollectionAmount {
                xml.Currency @shipping_options[:cod][:currency].upcase if @shipping_options[:cod][:currency]
                xml.Amount @shipping_options[:cod][:amount] if @shipping_options[:cod][:amount]
              }
              xml.CollectionType @shipping_options[:cod][:collection_type] if @shipping_options[:cod][:collection_type]
            }
            # add_shipping_document_specification
          end

          if @shipping_options[:event_notification]
            xml.EventNotificationDetail {
              xml.AggregationType "PER_SHIPMENT"
              xml.PersonalMessage @shipping_options[:event_notification][:personal_message]
              @shipping_options[:event_notification][:email_address].each_with_index do |email, index|
                xml.EventNotifications {
                  xml.Role @shipping_options[:event_notification][:role][index].upcase
                  @shipping_options[:event_notification][:events].each do |event|
                    xml.Events event
                  end
                  xml.NotificationDetail {
                    xml.NotificationType "EMAIL"
                    xml.EmailDetail {
                      xml.EmailAddress email
                    }
                    xml.Localization {
                      xml.LanguageCode "EN"
                    }
                  }
                  xml.FormatSpecification {
                    xml.Type @shipping_options[:event_notification][:type]
                  }
                }
              end
            }
            # add_shipping_document_specification
          end

        }
      end

      # Callback used after a failed shipment response.
      def failure_response(api_response, response)
        error_message = if response[:envelope][:body][:process_shipment_reply]
                          [response[:envelope][:body][:process_shipment_reply][:notifications]].flatten.first[:message]
                        else
                          "#{api_response["Fault"]["detail"]["fault"]["reason"]}\n--#{api_response["Fault"]["detail"]["fault"]["details"]["ValidationFailureDetail"]["message"].join("\n--")}"
                        end rescue $1
        raise RateError, error_message
      end

      # Callback used after a successful shipment response.
      def success_response(api_response, response)
        @response_details = response[:envelope][:body][:process_shipment_reply]
      end

      # Build xml Fedex Web Service request
      def build_xml
        ns = "http://fedex.com/ws/ship/v21"
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.Envelope("xmlns" => "http://fedex.com/ws/ship/v21") {
            xml.parent.namespace = xml.parent.add_namespace_definition("soapenv", "http://schemas.xmlsoap.org/soap/envelope/")
            xml['soapenv'].Header {}
            xml['soapenv'].Body {
              xml.ProcessShipmentRequest() {
                add_web_authentication_detail(xml)
                add_client_detail(xml)
                add_version(xml)
                add_requested_shipment(xml)
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
        response[:envelope][:body][:process_shipment_reply] &&
            %w{SUCCESS WARNING NOTE}.include?(response[:envelope][:body][:process_shipment_reply][:highest_severity])
      end

    end
  end
end
