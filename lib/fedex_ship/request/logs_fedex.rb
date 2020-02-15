require 'fedex_ship/request/base'
require 'logger'
module FedexShip
  module Request
    class LogsFedex < Base

      def ship_serv_log(info)
        begin
          date = Date.today.to_s
          info = (Time.now).to_s + ' ' + info
          log = File.open('log/shipment_' + date + '.log','a')
          log.puts(info)
          log.close
        rescue Exception => ex.to_s
          puts ex.to_s
          log.close
        end
      end

      def rate_serv_log(info)
        begin
          date = Date.today.to_s
          info = (Time.now).to_s + ' ' + info
          log = File.open('log/rate_' + date + '.log','a')
          log.puts(info)
          log.close
        rescue Exception => ex.to_s
          puts ex.to_s
          log.close
        end
      end

      def track_serv_log(info)
        begin
          date = Date.today.to_s
          info = (Time.now).to_s + ' ' + info
          log = File.open('log/track_' + date + '.log','a')
          log.puts(info)
          log.close
        rescue Exception => ex.to_s
          puts ex.to_s
          log.close
        end
      end

      def pickup_serv_log(info)
        begin
          date = Date.today.to_s
          info = (Time.now).to_s + ' ' + info
          log = File.open('log/pickup_' + date + '.log','a')
          log.puts(info)
          log.close
        rescue Exception => ex.to_s
          puts ex.to_s
          log.close
        end
      end

      def delete_ship_serv_log(info)
        begin
          date = Date.today.to_s
          info = (Time.now).to_s + ' ' + info
          log = File.open('log/delete_shipment_' + date + '.log','a')
          log.puts(info)
          log.close
        rescue Exception => ex.to_s
          puts ex.to_s
          log.close
        end
      end

    end
  end
end