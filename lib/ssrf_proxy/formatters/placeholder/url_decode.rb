#
# Copyright (c) 2015-2017 Brendan Coles <bcoles@gmail.com>
# SSRF Proxy - https://github.com/bcoles/ssrf_proxy
# See the file 'LICENSE.md' for copying permission
#

module SSRFProxy
  module Formatter
    module Placeholder
      #
      # URL decode client request
      #
      class URLDecode
        include Logging

        def format(url, client_request)
          CGI.unescape(url.to_s).to_s
        end
      end
    end
  end
end
