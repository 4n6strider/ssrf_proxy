#
# Copyright (c) 2015-2018 Brendan Coles <bcoles@gmail.com>
# SSRF Proxy - https://github.com/bcoles/ssrf_proxy
# See the file 'LICENSE.md' for copying permission
#

module SSRFProxy
  module Formatter
    module Placeholder
      #
      # Remove URL scheme from request URL
      #
      class NoProto
        include Logging

        def format(url, client_request)
          url.to_s.gsub(%r{^https?://}, '')
        end
      end
    end
  end
end
