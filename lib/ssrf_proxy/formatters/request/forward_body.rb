#
# Copyright (c) 2015-2017 Brendan Coles <bcoles@gmail.com>
# SSRF Proxy - https://github.com/bcoles/ssrf_proxy
# See the file 'LICENSE.md' for copying permission
#

module SSRFProxy
  module Formatter
    module Request
      #
      # Forward client HTTP request body
      #
      class ForwardBody
        include Logging

        def format(client_request, ssrf_request)
          return ssrf_request if client_request.body.eql?('')

          if ssrf_request.body.eql?('')
            ssrf_request.body = client_request.body.to_s
          else
            ssrf_request.body = "#{ssrf_request.body}&#{client_request.body}"
          end

          ssrf_request
        end
      end
    end
  end
end
