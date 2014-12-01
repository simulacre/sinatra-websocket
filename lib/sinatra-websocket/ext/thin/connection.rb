module SinatraWebsocket
  module Ext
    module Thin
      module Connection
        def self.included(base)
          base.class_eval do
            alias :receive_data_without_websocket :receive_data
            alias :receive_data :receive_data_with_websocket

            alias :unbind_without_websocket :unbind
            alias :unbind :unbind_with_websocket

            alias :receive_data_without_flash_policy_file :receive_data
            alias :receive_data :receive_data_with_flash_policy_file

            alias :pre_process_without_websocket :pre_process
            alias :pre_process :pre_process_with_websocket
          end
        end

        attr_accessor :websocket

        # Set 'async.connection' Rack env
        def pre_process_with_websocket
          @request.env['async.connection'] = self
          pre_process_without_websocket
        end

        # Is this connection WebSocket?
        def websocket?
          !self.websocket.nil?
        end

        # Skip default receive_data if this is
        # WebSocket connection
        def receive_data_with_websocket(data)
          if self.websocket?
            self.websocket.receive_data(data)
          else
            receive_data_without_websocket(data)
          end
        end

        # Skip standard unbind it this is
        # WebSocket connection
        def unbind_with_websocket
          self.websocket? && self.websocket.unbind
          unbind_without_websocket
        end

        # Send flash policy file if requested
        def receive_data_with_flash_policy_file(data)
          # thin require data to be proper http request - in it's not
          # then @request.parse raises exception and data isn't parsed
          # by futher methods. Here we only check if it is flash
          # policy file request ("<policy-file-request/>\000") and
          # if so then flash policy file is returned. if not then
          # rest of request is handled.
          if (data == "<policy-file-request/>\000")
            file =  '<?xml version="1.0"?><cross-domain-policy><allow-access-from domain="*" to-ports="*"/></cross-domain-policy>'
            # ignore errors - we will close this anyway
            send_data(file) rescue nil
            close_connection_after_writing
          else
            receive_data_without_flash_policy_file(data)
          end
        end

      end # module::Connection
    end # module::Thin
  end # module::Ext
end # module::SinatraWebsocket
defined?(Thin) && Thin::Connection.send(:include, SinatraWebsocket::Ext::Thin::Connection)
