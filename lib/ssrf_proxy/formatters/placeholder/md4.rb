#
# Copyright (c) 2015-2017 Brendan Coles <bcoles@gmail.com>
# SSRF Proxy - https://github.com/bcoles/ssrf_proxy
# See the file 'LICENSE.md' for copying permission
#

module SSRFProxy
  module Formatter
    module Placeholder
      #
      # Convert placeholder to MD4 hash
      #
      class MD4
        include Logging

        def format(url, client_request)
          OpenSSL::Digest::MD4.hexdigest(url.to_s)
        end
      end
    end
  end
end
