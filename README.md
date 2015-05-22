# SinatraWebsocket

Makes it easy to upgrade any request to a websocket connection.

SinatraWebsocket is a fork of [Skinny](https://github.com/sj26/skinny) merged with [Rack WebSocket](https://github.com/imanel/websocket-rack). It provides helpers methods to detect if a request is a WebSocket request and defer to an [EM::WebSocket::Connection](https://github.com/igrigorik/em-websocket).


## Put this in your pipe ...

```ruby

require 'sinatra'
require 'sinatra-websocket'

set :server, 'thin'
set :sockets, []

get '/' do
  return erb(:index) if !request.websocket?
  
  request.websocket do |ws|
    ws.onopen do
      ws.send("Hello World!")
      settings.sockets << ws
    end
    ws.onmessage do |msg|
      EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
    end
    ws.onclose do
      warn("websocket closed")
      settings.sockets.delete(ws)
    end
  end
end

__END__
@@ index
<html>
  <body>
     <h1>Simple Echo & Chat Server</h1>
     <form id="form">
       <input type="text" id="input" value="send a message"></input>
     </form>
     <div id="msgs"></div>
  </body>

  <script type="text/javascript">
    window.onload = function(){
      (function(){
        var show = function(el){
          return function(msg){ el.innerHTML = msg + '<br />' + el.innerHTML; }
        }(document.getElementById('msgs'));

        var ws       = new WebSocket('ws://' + window.location.host + window.location.pathname);
        ws.onopen    = function()  { show('websocket opened'); };
        ws.onclose   = function()  { show('websocket closed'); }
        ws.onmessage = function(m) { show('websocket message: ' +  m.data); };

        var sender = function(f){
          var input     = document.getElementById('input');
          input.onclick = function(){ input.value = "" };
          f.onsubmit    = function(){
            ws.send(input.value);
            input.value = "send a message";
            return false;
          }
        }(document.getElementById('form'));
      })();
    }
  </script>
</html>

```

## And Smoke It

```
ruby echo.rb
```


## Copyright

Copyright (c) 2012 Caleb Crane.

Portions of this software are Copyright (c) Bernard Potocki <bernard.potocki@imanel.org> and Samuel Cochran.

See License.txt for more details.
