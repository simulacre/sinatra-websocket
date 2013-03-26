require 'thin'
require 'em-websocket'
require 'sinatra-websocket/ext/thin/connection'
require 'sinatra-websocket/ext/sinatra/request'

module SinatraWebsocket
  class Connection < ::EventMachine::WebSocket::Connection
    class << self
      def from_env(env, options = {})
        if env.include?('async.orig_callback')
          callback_key = 'async.orig_callback'
        elsif env.include?(Thin::Request::ASYNC_CALLBACK)
          callback_key = Thin::Request::ASYNC_CALLBACK
        else
          raise 'Could not find an async callback in our environment!'
        end
        socket     = env[callback_key].receiver
        request    = request_from_env(env)
        connection = Connection.new(env, socket, :debug => options[:debug])
        yield(connection) if block_given?
        connection.dispatch(request) ? async_response : failure_response
      end

      #######
      # Taken from WebSocket Rack
      # https://github.com/imanel/websocket-rack
      #######

      # Parse Rack env to em-websocket-compatible format
      # this probably should be moved to Base in future
      def request_from_env(env)
        request = {}
        request['path']   = env['REQUEST_URI'].to_s
        request['method'] = env['REQUEST_METHOD']
        request['query']  = env['QUERY_STRING'].to_s
        request['Body']   = env['rack.input'].read

        env.each do |key, value|
          if key.match(/HTTP_(.+)/)
            request[$1.downcase.gsub('_','-')] ||= value
          end
        end
        request
      end

      # Standard async response
      def async_response
        [-1, {}, []]
      end

      # Standard 400 response
      def failure_response
        [ 400, {'Content-Type' => 'text/plain'}, [ 'Bad request' ] ]
      end
    end # class << self


    #########################
    ### EventMachine part ###
    #########################

    # Overwrite new from EventMachine
    # we need to skip standard procedure called
    # when socket is created - this is just a stub
    def self.new(*args)
      instance = allocate
      instance.__send__(:initialize, *args)
      instance
    end

    # Overwrite send_data from EventMachine
    # delegate send_data to rack server
    def send_data(*args)
      EM.next_tick do
        @socket.send_data(*args)
      end
    end

    # Overwrite close_connection from EventMachine
    # delegate close_connection to rack server
    def close_connection(*args)
      EM.next_tick do
        @socket.close_connection(*args)
      end
    end

    #########################
    ### EM-WebSocket part ###
    #########################

    # Overwrite initialize from em-websocket
    # set all standard options and disable
    # EM connection inactivity timeout
    def initialize(app, socket, options = {})
      @app     = app
      @socket  = socket
      @options = options
      @debug   = options[:debug] || false
      @ssl     = socket.backend.respond_to?(:ssl?) && socket.backend.ssl?

      socket.websocket = self
      socket.comm_inactivity_timeout = 0

      debug [:initialize]
    end

    def get_peername
      @socket.get_peername
    end

    # Overwrite dispath from em-websocket
    # we already have request headers parsed so
    # we can skip it and call build_with_request
    def dispatch(data)
      return false if data.nil?
      debug [:inbound_headers, data]
      @handler = EventMachine::WebSocket::HandlerFactory.build_with_request(self, data, data['Body'], @ssl, @debug)
      unless @handler
        # The whole header has not been received yet.
        return false
      end
      @handler.run
      return true
    end
  end
end # module::SinatraWebSocket
