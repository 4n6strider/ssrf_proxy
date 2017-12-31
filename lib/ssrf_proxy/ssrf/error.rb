#
# Copyright (c) 2015-2018 Brendan Coles <bcoles@gmail.com>
# SSRF Proxy - https://github.com/bcoles/ssrf_proxy
# See the file 'LICENSE.md' for copying permission
#

module SSRFProxy
  class SSRF
    #
    # SSRFProxy::SSRF errors
    #
    module Error
      #
      # SSRFProxy::SSRF errors
      #
      class Error < StandardError; end

      exceptions = %w[
        NoUrlPlaceholder
        InvalidSsrfRequest
        InvalidSsrfRequestMethod
        InvalidUpstreamProxy
        InvalidClientRequest
        InvalidResponse
        ConnectionTimeout
        ConnectionFailed
      ]
      exceptions.each do |e|
        const_set(e, Class.new(Error))
      end
    end
  end
end
