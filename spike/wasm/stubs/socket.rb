# frozen_string_literal: true

# Stands in for socket, a native extension that isn't in the WebAssembly build, as WASI has no sockets. ipaddr, which
# endpoints load, only needs its address families to load, and endpoints, which run curl, can't run in it anyway.
class Socket
  AF_UNSPEC = 0
  AF_INET = 2
  AF_INET6 = 30
end
