module SinatraWebsocket
  module Ext
    module Sinatra
      module Request

        # Taken from skinny https://github.com/sj26/skinny and updated to support Firefox
        def websocket?
          env['HTTP_CONNECTION'] && env['HTTP_UPGRADE'] &&
            env['HTTP_CONNECTION'].split(',').map(&:strip).map(&:downcase).include?('upgrade') &&
            env['HTTP_UPGRADE'].downcase == 'websocket'
        end

        # Taken from skinny https://github.com/sj26/skinny
        def websocket(options={}, &blk)
          env['skinny.websocket'] ||= begin
            raise RuntimeError, "Not a WebSocket request" unless websocket?
            SinatraWebsocket::Connection.from_env(env, options, &blk)
          end
        end
      end
    end # module::Sinatra
  end # module::Ext
end # module::SinatraWebsocket
defined?(Sinatra) && Sinatra::Request.send(:include, SinatraWebsocket::Ext::Sinatra::Request)
