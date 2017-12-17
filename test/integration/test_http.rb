#
# Copyright (c) 2015-2017 Brendan Coles <bcoles@gmail.com>
# SSRF Proxy - https://github.com/bcoles/ssrf_proxy
# See the file 'LICENSE.md' for copying permission
#
require './test/test_helper.rb'
require './test/integration_test_helper.rb'

#
# @note SSRFProxy::HTTP integration tests
#
class TestIntegrationSSRFProxyHTTP < Minitest::Test
  parallelize_me!

  #
  # @note check a SSRFProxy::HTTP object is valid
  #
  def validate(ssrf)
    assert_equal(SSRFProxy::HTTP, ssrf.class)
    assert(ssrf.url)
    assert(ssrf.url.scheme)
    assert(ssrf.url.host)
    assert(ssrf.url.port)
    true
  end

  #
  # @note check a HTTP response is valid
  #
  def validate_response(res)
    assert(res)
    assert(res['url'])
    assert(res['duration'])
    assert_match(/\AHTTP\/\d\.\d [\d]+ /, res['status_line'])
    assert(res['http_version'])
    assert(res['code'])
    assert(res['message'])
    assert(res['headers'])
    true
  end

  #
  # @note test upstream HTTP proxy server
  #
  def test_upstream_proxy
    # Start upstream HTTP proxy server
    assert(start_proxy_server('127.0.0.1', 8008),
      'Could not start upstream HTTP proxy server')

    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/net_http?url=xxURLxx'
    opts[:proxy] = 'http://127.0.0.1:8008/'

    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/')
    validate_response(res)
    assert_includes(res['body'], '<title>public</title>')
  end

  #
  # @note test send_uri GET method with Net::HTTP SSRF
  #
  def test_send_uri_get_net_http
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = "http://127.0.0.1:8088/net_http?url=xxURLxx"
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/')
    validate_response(res)
    assert_equal('public', res['title'])

    res = ssrf.send_uri('http://127.0.0.1:8088/admin')
    validate_response(res)
    assert_equal('administration', res['title'])

    res = ssrf.send_uri('http://127.0.0.1:8088/auth')
    validate_response(res)
    assert_equal('401 Unauthorized', res['title'])
  end

  #
  # @note test send_uri HEAD method with Net::HTTP SSRF
  #
  def test_send_uri_head_net_http
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/net_http?url=xxURLxx'
    opts[:method] = 'HEAD'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/')
    validate_response(res)
  end

  #
  # @note test send_uri POST method with Net::HTTP SSRF
  # 
  def test_send_uri_post_net_http
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/net_http'
    opts[:method] = 'POST'
    opts[:post_data] = 'url=xxURLxx'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/')
    validate_response(res)
    assert_equal('public', res['title'])

    res = ssrf.send_uri('http://127.0.0.1:8088/auth')
    validate_response(res)
    assert_equal('401 Unauthorized', res['title'])
  end

  #
  # @note test send_uri match with Net::HTTP SSRF
  # 
  def test_send_uri_match_net_http
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/net_http?url=xxURLxx'
    opts[:match] = '<textarea>(.+)</textarea>'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri("http://127.0.0.1:8088/")
    validate_response(res)
    assert(res['body'].start_with?('<html>'))
    refute_includes(res['body'], 'Response:')
    refute_includes(res['body'], '<textarea>')
  end

  #
  # @note test send_uri guess_mime with Net::HTTP SSRF
  # 
  def test_send_uri_guess_mine_net_http
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/net_http?url=xxURLxx'
    opts[:guess_mime] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri("http://127.0.0.1:8088/#{('a'..'z').to_a.sample(8).join}.ico")
    validate_response(res)
    assert(res['headers'] =~ /^Content-Type: image\/x\-icon$/i)
  end

  #
  # @note test send_uri guess_status with Net::HTTP SSRF
  # 
  def test_send_uri_guess_status_net_http
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/net_http?url=xxURLxx'
    opts[:guess_status] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/auth')
    validate_response(res)
    assert_equal('HTTP/1.1 401 Unauthorized', res['status_line'])
  end

  #
  # @note test send_uri ask password with Net::HTTP SSRF
  # 
  def test_send_uri_ask_password_net_http
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/net_http?url=xxURLxx'
    opts[:guess_status] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/auth')
    validate_response(res)
    assert(res['headers'] =~ /^WWW-Authenticate: Basic realm="127\.0\.0\.1:8088"$/i)
  end

  #
  # @note test send_uri detect redirect with Net::HTTP SSRF
  # 
  def test_send_uri_detect_redirect_net_http
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = "http://127.0.0.1:8088/net_http?url=xxURLxx"
    opts[:guess_status] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/redirect')
    validate_response(res)
    assert(res['headers'] =~ /^Location: \/admin$/i)
  end

  #
  # @note test send_uri ip_encoding with Net::HTTP SSRF
  # 
  def test_send_uri_ip_encoding_net_http
    %w[int oct hex dotted_hex].each do |encoding|
      opts = SSRF_DEFAULT_OPTS.dup
      opts[:url] = "http://127.0.0.1:8088/net_http?url=xxURLxx"
      opts[:ip_encoding] = encoding
      ssrf = SSRFProxy::HTTP.new(opts)
      validate(ssrf)

      res = ssrf.send_uri('http://127.0.0.1:8088/')
      validate_response(res)
      assert_equal('public', res['title'])

      res = ssrf.send_uri('http://127.0.0.1:8088/auth')
      validate_response(res)
      assert_equal('401 Unauthorized', res['title'])
    end
  end

  #
  # @note test send_uri GET method with OpenURI SSRF
  #
  def test_send_uri_get_openuri
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = "http://127.0.0.1:8088/openuri?url=xxURLxx"
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/')
    validate_response(res)
    assert_equal('public', res['title'])

    res = ssrf.send_uri('http://127.0.0.1:8088/admin')
    validate_response(res)
    assert_equal('administration', res['title'])

    res = ssrf.send_uri('http://127.0.0.1:8088/auth')
    validate_response(res)
    assert_includes(res['body'], '401 Unauthorized')
  end

  #
  # @note test send_uri HEAD method with OpenURI SSRF
  #
  def test_send_uri_head_openuri
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = "http://127.0.0.1:8088/openuri?url=xxURLxx"
    opts[:method] = 'HEAD'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/')
    validate_response(res)
  end

  #
  # @note test send_uri POST method with OpenURI SSRF
  #
  def test_send_uri_post_openuri
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/openuri'
    opts[:method] = 'POST'
    opts[:post_data] = 'url=xxURLxx'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/')
    validate_response(res)
    assert_equal('public', res['title'])

    res = ssrf.send_uri('http://127.0.0.1:8088/auth')
    validate_response(res)
    assert_includes(res['body'], '401 Unauthorized')
  end

  #
  # @note test send_uri match with OpenURI SSRF
  #
  def test_send_uri_match_openuri
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = "http://127.0.0.1:8088/openuri?url=xxURLxx"
    opts[:match] = '<textarea>(.+)</textarea>'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri("http://127.0.0.1:8088/")
    validate_response(res)
    assert(res['body'].start_with?('<html>'))
    refute_includes(res['body'], 'Response:')
    refute_includes(res['body'], '<textarea>')
  end

  #
  # @note test send_uri guess_mime with OpenURI SSRF
  #
  def test_send_uri_guess_mime_openuri
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/openuri?url=xxURLxx'
    opts[:guess_mime] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri("http://127.0.0.1:8088/#{('a'..'z').to_a.sample(8).join}.ico")
    validate_response(res)
    assert(res['headers'] =~ /^Content-Type: image\/x\-icon$/i)

  end
  #
  # @note test send_uri ip_encoding with OpenURI SSRF
  #
  def test_send_uri_ip_encoding_openuri
    %w[int oct hex dotted_hex].each do |encoding|
      opts = SSRF_DEFAULT_OPTS.dup
      opts[:url] = 'http://127.0.0.1:8088/openuri?url=xxURLxx'
      opts[:ip_encoding] = encoding
      ssrf = SSRFProxy::HTTP.new(opts)
      validate(ssrf)

      res = ssrf.send_uri('http://127.0.0.1:8088/')
      validate_response(res)
      assert_equal('public', res['title'])

      res = ssrf.send_uri('http://127.0.0.1:8088/auth')
      validate_response(res)
      assert_includes(res['body'], '401 Unauthorized')
    end
  end

  #
  # @note test send_uri with cURL SSRF
  #
  def test_send_uri_curl
    # http get
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/curl?url=xxURLxx'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/')
    validate_response(res)
    assert_equal('public', res['title'])

    res = ssrf.send_uri('http://127.0.0.1:8088/admin')
    validate_response(res)
    assert_equal('administration', res['title'])

    res = ssrf.send_uri('http://127.0.0.1:8088/auth')
    validate_response(res)
    assert_equal('401 Unauthorized', res['title'])

    # http head
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/curl?url=xxURLxx'
    opts[:method] = 'HEAD'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/')
    validate_response(res)

    # http post
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/curl'
    opts[:method] = 'POST'
    opts[:post_data] = 'url=xxURLxx'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/')
    validate_response(res)
    assert_equal('public', res['title'])

    res = ssrf.send_uri('http://127.0.0.1:8088/auth')
    validate_response(res)
    assert_equal('401 Unauthorized', res['title'])

    # match
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = "http://127.0.0.1:8088/curl?url=xxURLxx"
    opts[:match] = '<textarea>(.+)</textarea>'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri("http://127.0.0.1:8088/")
    validate_response(res)
    assert(res['body'].start_with?('<html>'))
    refute_includes(res['body'], 'Response:')
    refute_includes(res['body'], '<textarea>')

    # guess mime
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = "http://127.0.0.1:8088/curl?url=xxURLxx"
    opts[:guess_mime] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri("http://127.0.0.1:8088/#{('a'..'z').to_a.sample(8).join}.ico")
    validate_response(res)
    assert(res['headers'] =~ /^Content-Type: image\/x\-icon$/i)

    # guess status
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/curl?url=xxURLxx'
    opts[:guess_status] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/auth')
    validate_response(res)
    assert_equal('HTTP/1.1 401 Unauthorized', res['status_line'])

    # ask password
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/curl?url=xxURLxx'
    opts[:guess_status] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/auth')
    validate_response(res)
    assert(res['headers'] =~ /^WWW-Authenticate: Basic realm="127\.0\.0\.1:8088"$/i)

    # detect redirect
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/curl?url=xxURLxx'
    opts[:guess_status] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/redirect')
    validate_response(res)
    assert(res['headers'] =~ /^Location: \/admin$/i)

    # ip encoding
    %w[int oct hex dotted_hex].each do |encoding|
      opts = SSRF_DEFAULT_OPTS.dup
      opts[:url] = 'http://127.0.0.1:8088/curl?url=xxURLxx'
      opts[:ip_encoding] = encoding
      ssrf = SSRFProxy::HTTP.new(opts)
      validate(ssrf)

      res = ssrf.send_uri('http://127.0.0.1:8088/')
      validate_response(res)
      assert_equal('public', res['title'])

      res = ssrf.send_uri('http://127.0.0.1:8088/auth')
      validate_response(res)
      assert_equal('401 Unauthorized', res['title'])
    end
  end

  #
  # @note test send_uri with Typhoeus SSRF
  #
  def test_send_uri_typhoeus
    # http get
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/typhoeus?url=xxURLxx'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/')
    validate_response(res)
    assert_equal('public', res['title'])

    res = ssrf.send_uri('http://127.0.0.1:8088/admin')
    validate_response(res)
    assert_equal('administration', res['title'])

    res = ssrf.send_uri('http://127.0.0.1:8088/auth')
    validate_response(res)
    assert_equal('401 Unauthorized', res['title'])

    # http head
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/typhoeus?url=xxURLxx'
    opts[:method] = 'HEAD'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/')
    validate_response(res)

    # http post
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/typhoeus'
    opts[:method] = 'POST'
    opts[:post_data] = 'url=xxURLxx'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/')
    validate_response(res)
    assert_equal('public', res['title'])

    res = ssrf.send_uri('http://127.0.0.1:8088/auth')
    validate_response(res)
    assert_equal('401 Unauthorized', res['title'])

    # match
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/typhoeus?url=xxURLxx'
    opts[:match] = '<textarea>(.+)</textarea>'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri("http://127.0.0.1:8088/")
    validate_response(res)
    assert(res['body'].start_with?('<html>'))
    refute_includes(res['body'], 'Response:')
    refute_includes(res['body'], '<textarea>')

    # guess mime
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/typhoeus?url=xxURLxx'
    opts[:guess_mime] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri("http://127.0.0.1:8088/#{('a'..'z').to_a.sample(8).join}.ico")
    validate_response(res)
    assert(res['headers'] =~ /^Content-Type: image\/x\-icon$/i)

    # guess status
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/typhoeus?url=xxURLxx'
    opts[:guess_status] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/auth')
    validate_response(res)
    assert_equal('HTTP/1.1 401 Unauthorized', res['status_line'])

    # ask password
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/typhoeus?url=xxURLxx'
    opts[:guess_status] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_uri('http://127.0.0.1:8088/auth')
    validate_response(res)
    assert(res['headers'] =~ /^WWW-Authenticate: Basic realm="127\.0\.0\.1:8088"$/i)

    # detect redirect
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/typhoeus?url=xxURLxx'
    opts[:guess_status] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)
    
    res = ssrf.send_uri('http://127.0.0.1:8088/redirect')
    validate_response(res)
    assert(res['headers'] =~ /^Location: \/admin$/i)

    # ip encoding
    %w[int oct hex dotted_hex].each do |encoding|
      opts = SSRF_DEFAULT_OPTS.dup
      opts[:url] = 'http://127.0.0.1:8088/typhoeus?url=xxURLxx'
      opts[:ip_encoding] = encoding
      ssrf = SSRFProxy::HTTP.new(opts)
      validate(ssrf)

      res = ssrf.send_uri('http://127.0.0.1:8088/')
      validate_response(res)
      assert_equal('public', res['title'])

      res = ssrf.send_uri('http://127.0.0.1:8088/auth')
      validate_response(res)
      assert_equal('401 Unauthorized', res['title'])
    end
  end

  #
  # @note test send_uri with invalid input
  #
  def test_send_uri_invalid
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/net_http?url=xxURLxx'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    assert_raises SSRFProxy::HTTP::Error::InvalidClientRequest do
      ssrf.send_uri(nil)
      ssrf.send_uri([])
      ssrf.send_uri({})
      ssrf.send_uri([[]])
      ssrf.send_uri([{}])
    end

    assert_raises SSRFProxy::HTTP::Error::InvalidClientRequest do
      ssrf.send_uri('http://127.0.0.1/', headers: { 'upgrade' => 'WebSocket' })
    end

    assert_raises SSRFProxy::HTTP::Error::InvalidClientRequest do
      ssrf.send_uri('http://127.0.0.1/', headers: { "#{('a'..'z').to_a.sample(8).join}" => {} })
    end
  end

  #
  # @note test send_request with Net:HTTP SSRF
  #
  def test_send_request_net_http
    # http get
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/net_http?url=xxURLxx'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('public', res['title'])

    res = ssrf.send_request("GET /admin HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('administration', res['title'])

    res = ssrf.send_request("GET /auth HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('401 Unauthorized', res['title'])

    # http head
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/net_http?url=xxURLxx'
    opts[:method] = 'HEAD'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)

    # http post
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/net_http'
    opts[:method] = 'POST'
    opts[:post_data] = 'url=xxURLxx'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('public', res['title'])

    res = ssrf.send_request("GET /auth HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('401 Unauthorized', res['title'])

    # match
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/net_http?url=xxURLxx'
    opts[:match] = '<textarea>(.+)</textarea>'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert(res['body'].start_with?('<html>'))
    refute_includes(res['body'], 'Response:')
    refute_includes(res['body'], '<textarea>')

    # guess mime
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/net_http?url=xxURLxx'
    opts[:guess_mime] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET /#{('a'..'z').to_a.sample(8).join}.ico HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert(res['headers'] =~ /^Content-Type: image\/x\-icon$/i)

    # guess status
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/net_http?url=xxURLxx'
    opts[:guess_status] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET /auth HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('HTTP/1.1 401 Unauthorized', res['status_line'])

    # ask password
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/net_http?url=xxURLxx'
    opts[:guess_status] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET /auth HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert(res['headers'] =~ /^WWW-Authenticate: Basic realm="127\.0\.0\.1:8088"$/i)

    # detect redirect
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/net_http?url=xxURLxx'
    opts[:guess_status] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)
      
    res = ssrf.send_uri('http://127.0.0.1:8088/redirect')
    validate_response(res)
    assert(res['headers'] =~ /^Location: \/admin$/i)

    # body to URI
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/net_http?url=xxURLxx'
    opts[:body_to_uri] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    junk1 = "#{('a'..'z').to_a.sample(8).join}"
    junk2 = "#{('a'..'z').to_a.sample(8).join}"
    data = "data1=#{junk1}&data2=#{junk2}"

    req = "POST /submit HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Content-Length: #{data.length}\n"
    req << "\n"
    req << "#{data}"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_includes(res['body'], "data1: #{junk1}")
    assert_includes(res['body'], "data2: #{junk2}")

    req = "POST /submit?query HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Content-Length: #{data.length}\n"
    req << "\n"
    req << "#{data}"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_includes(res['body'], "data1: #{junk1}")
    assert_includes(res['body'], "data2: #{junk2}")

    # cookies to URI
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/net_http?url=xxURLxx'
    opts[:cookies_to_uri] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    cookie_name = "#{('a'..'z').to_a.sample(8).join}"
    cookie_value = "#{('a'..'z').to_a.sample(8).join}"
    req = "GET /submit HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Cookie: #{cookie_name}=#{cookie_value}\n"
    req << "\n"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_includes(res['body'], "#{cookie_name}: #{cookie_value}")

    req = "GET /submit?query HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Cookie: #{cookie_name}=#{cookie_value}\n"
    req << "\n"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_includes(res['body'], "#{cookie_name}: #{cookie_value}")

    # ip encoding
    %w[int oct hex dotted_hex].each do |encoding|
      opts = SSRF_DEFAULT_OPTS.dup
      opts[:url] = 'http://127.0.0.1:8088/net_http?url=xxURLxx'
      opts[:ip_encoding] = encoding
      ssrf = SSRFProxy::HTTP.new(opts)
      validate(ssrf)

      res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
      validate_response(res)
      assert_equal('public', res['title'])

      res = ssrf.send_request("GET /auth HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
      validate_response(res)
      assert_equal('401 Unauthorized', res['title'])
    end
  end

  #
  # @note test send_request with OpenURI SSRF
  #
  def test_send_request_openuri
    # http get
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/openuri?url=xxURLxx'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('public', res['title'])

    res = ssrf.send_request("GET /admin HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('administration', res['title'])

    res = ssrf.send_request("GET /auth HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_includes(res['body'], '401 Unauthorized')

    # http head
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/openuri?url=xxURLxx'
    opts[:method] = 'HEAD'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)

    # http post
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/openuri'
    opts[:method] = 'POST'
    opts[:post_data] = 'url=xxURLxx'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('public', res['title'])

    res = ssrf.send_request("GET /auth HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_includes(res['body'], '401 Unauthorized')

    # match
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/openuri?url=xxURLxx'
    opts[:match] = '<textarea>(.+)</textarea>'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert(res['body'].start_with?('<html>'))
    refute_includes(res['body'], 'Response:')
    refute_includes(res['body'], '<textarea>')

    # guess mime
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/openuri?url=xxURLxx'
    opts[:guess_mime] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET /#{('a'..'z').to_a.sample(8).join}.ico HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert(res['headers'] =~ %r{^Content-Type: image/x\-icon$}i)

    # body to URI
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/openuri?url=xxURLxx'
    opts[:body_to_uri] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    junk1 = "#{('a'..'z').to_a.sample(8).join}"
    junk2 = "#{('a'..'z').to_a.sample(8).join}"
    data = "data1=#{junk1}&data2=#{junk2}"

    req = "POST /submit HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Content-Length: #{data.length}\n"
    req << "\n"
    req << "#{data}"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_includes(res['body'], "data1: #{junk1}")
    assert_includes(res['body'], "data2: #{junk2}")

    req = "POST /submit?query HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Content-Length: #{data.length}\n"
    req << "\n"
    req << "#{data}"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_includes(res['body'], "data1: #{junk1}")
    assert_includes(res['body'], "data2: #{junk2}")

    # cookies to URI
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/openuri?url=xxURLxx'
    opts[:cookies_to_uri] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    cookie_name = "#{('a'..'z').to_a.sample(8).join}"
    cookie_value = "#{('a'..'z').to_a.sample(8).join}"
    req = "GET /submit HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Cookie: #{cookie_name}=#{cookie_value}\n"
    req << "\n"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_includes(res['body'], "#{cookie_name}: #{cookie_value}")

    req = "GET /submit?query HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Cookie: #{cookie_name}=#{cookie_value}\n"
    req << "\n"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_includes(res['body'], "#{cookie_name}: #{cookie_value}")

    # ip encoding
    %w[int oct hex dotted_hex].each do |encoding|
      opts = SSRF_DEFAULT_OPTS.dup
      opts[:url] = 'http://127.0.0.1:8088/openuri?url=xxURLxx'
      opts[:ip_encoding] = encoding
      ssrf = SSRFProxy::HTTP.new(opts)
      validate(ssrf)

      res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
      validate_response(res)
      assert_equal('public', res['title'])

      res = ssrf.send_request("GET /auth HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
      validate_response(res)
      assert_includes(res['body'], '401 Unauthorized')
    end
  end

  #
  # @note test send_request with cURL SSRF
  #
  def test_send_request_curl
    # http get
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/curl?url=xxURLxx'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('public', res['title'])

    res = ssrf.send_request("GET /admin HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('administration', res['title'])

    res = ssrf.send_request("GET /auth HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('401 Unauthorized', res['title'])

    # http head
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/curl?url=xxURLxx'
    opts[:method] = 'HEAD'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)

    # post
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/curl'
    opts[:method] = 'POST'
    opts[:post_data] = 'url=xxURLxx'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('public', res['title'])

    res = ssrf.send_request("GET /auth HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('401 Unauthorized', res['title'])

    # match
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/curl?url=xxURLxx'
    opts[:match] = '<textarea>(.+)</textarea>'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert(res['body'].start_with?('<html>'))
    refute_includes(res['body'], 'Response:')
    refute_includes(res['body'], '<textarea>')

    # guess mime
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/curl?url=xxURLxx'
    opts[:guess_mime] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET /#{('a'..'z').to_a.sample(8).join}.ico HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert(res['headers'] =~ /^Content-Type: image\/x\-icon$/i)

    # guess status
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/curl?url=xxURLxx'
    opts[:guess_status] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET /auth HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('HTTP/1.1 401 Unauthorized', res['status_line'])

    # ask password
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/curl?url=xxURLxx'
    opts[:guess_status] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET /auth HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert(res['headers'] =~ /^WWW-Authenticate: Basic realm="127\.0\.0\.1:8088"$/i)

    # detect redirect
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/curl?url=xxURLxx'
    opts[:guess_status] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)
      
    res = ssrf.send_uri('http://127.0.0.1:8088/redirect')
    validate_response(res)
    assert(res['headers'] =~ /^Location: \/admin$/i)

    # body to URI
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/curl?url=xxURLxx'
    opts[:body_to_uri] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    junk1 = "#{('a'..'z').to_a.sample(8).join}"
    junk2 = "#{('a'..'z').to_a.sample(8).join}"
    data = "data1=#{junk1}&data2=#{junk2}"

    req = "POST /submit HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Content-Length: #{data.length}\n"
    req << "\n"
    req << "#{data}"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_includes(res['body'], "data1: #{junk1}")
    assert_includes(res['body'], "data2: #{junk2}")

    req = "POST /submit?query HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Content-Length: #{data.length}\n"
    req << "\n"
    req << "#{data}"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_includes(res['body'], "data1: #{junk1}")
    assert_includes(res['body'], "data2: #{junk2}")

    # cookies to URI
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/curl?url=xxURLxx'
    opts[:cookies_to_uri] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    cookie_name = "#{('a'..'z').to_a.sample(8).join}"
    cookie_value = "#{('a'..'z').to_a.sample(8).join}"
    req = "GET /submit HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Cookie: #{cookie_name}=#{cookie_value}\n"
    req << "\n"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_includes(res['body'], "#{cookie_name}: #{cookie_value}")

    req = "GET /submit?query HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Cookie: #{cookie_name}=#{cookie_value}\n"
    req << "\n"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_includes(res['body'], "#{cookie_name}: #{cookie_value}")

    # auth to URI
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/curl?url=xxURLxx'
    opts[:auth_to_uri] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    req = "GET /auth HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Authorization: Basic #{Base64.encode64('admin user:test password!@#$%^&*()_+-={}|\:";\'<>?,./').delete("\n")}\n"
    req << "\n"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_equal('authentication successful', res['title'])

    req = "GET /auth HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Authorization: Basic #{Base64.encode64((0 .. 255).to_a.pack('C*')).delete("\n")}\n"
    req << "\n"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_equal('401 Unauthorized', res['title'])

    # auth to URI - malformed
    req = "GET /auth HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Authorization: Basic #{"#{('a'..'z').to_a.sample(8).join}"}\n"
    req << "\n"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_equal('401 Unauthorized', res['title'])

    # ip encoding
    %w[int oct hex dotted_hex].each do |encoding|
      opts = SSRF_DEFAULT_OPTS.dup
      opts[:url] = 'http://127.0.0.1:8088/curl?url=xxURLxx'
      opts[:ip_encoding] = encoding
      ssrf = SSRFProxy::HTTP.new(opts)
      validate(ssrf)

      res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
      validate_response(res)
      assert_equal('public', res['title'])

      res = ssrf.send_request("GET /auth HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
      validate_response(res)
      assert_equal('401 Unauthorized', res['title'])
    end
  end

  #
  # @note test send_request with Typhoeus SSRF
  #
  def test_send_request_typhoeus
    # http get
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/typhoeus?url=xxURLxx'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('public', res['title'])

    res = ssrf.send_request("GET /admin HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('administration', res['title'])

    res = ssrf.send_request("GET /auth HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('401 Unauthorized', res['title'])

    # http head
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/typhoeus?url=xxURLxx'
    opts[:method] = 'HEAD'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)

    # http post
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/typhoeus'
    opts[:method] = 'POST'
    opts[:post_data] = 'url=xxURLxx'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('public', res['title'])

    res = ssrf.send_request("GET /auth HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('401 Unauthorized', res['title'])

    # match
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/typhoeus?url=xxURLxx'
    opts[:match] = '<textarea>(.+)</textarea>'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert(res['body'].start_with?('<html>'))
    refute_includes(res['body'], 'Response:')
    refute_includes(res['body'], '<textarea>')

    # guess mime
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/typhoeus?url=xxURLxx'
    opts[:guess_mime] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET /#{('a'..'z').to_a.sample(8).join}.ico HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert(res['headers'] =~ /^Content-Type: image\/x\-icon$/i)

    # guess status
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/typhoeus?url=xxURLxx'
    opts[:guess_status] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET /auth HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert_equal('HTTP/1.1 401 Unauthorized', res['status_line'])

    # ask password
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/typhoeus?url=xxURLxx'
    opts[:guess_status] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    res = ssrf.send_request("GET /auth HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    validate_response(res)
    assert(res['headers'] =~ /^WWW-Authenticate: Basic realm="127\.0\.0\.1:8088"$/i)

    # detect redirect
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/typhoeus?url=xxURLxx'
    opts[:guess_status] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)
      
    res = ssrf.send_uri('http://127.0.0.1:8088/redirect')
    validate_response(res)
    assert(res['headers'] =~ /^Location: \/admin$/i)

    # body to URI
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/typhoeus?url=xxURLxx'
    opts[:body_to_uri] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    junk1 = "#{('a'..'z').to_a.sample(8).join}"
    junk2 = "#{('a'..'z').to_a.sample(8).join}"
    data = "data1=#{junk1}&data2=#{junk2}"

    req = "POST /submit HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Content-Length: #{data.length}\n"
    req << "\n"
    req << "#{data}"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_includes(res['body'], "data1: #{junk1}")
    assert_includes(res['body'], "data2: #{junk2}")

    req = "POST /submit?query HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Content-Length: #{data.length}\n"
    req << "\n"
    req << "#{data}"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_includes(res['body'], "data1: #{junk1}")
    assert_includes(res['body'], "data2: #{junk2}")

    # cookies to URI
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/typhoeus?url=xxURLxx'
    opts[:cookies_to_uri] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    cookie_name = "#{('a'..'z').to_a.sample(8).join}"
    cookie_value = "#{('a'..'z').to_a.sample(8).join}"
    req = "GET /submit HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Cookie: #{cookie_name}=#{cookie_value}\n"
    req << "\n"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_includes(res['body'], "#{cookie_name}: #{cookie_value}")

    req = "GET /submit?query HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Cookie: #{cookie_name}=#{cookie_value}\n"
    req << "\n"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_includes(res['body'], "#{cookie_name}: #{cookie_value}")

    # auth to URI
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/typhoeus?url=xxURLxx'
    opts[:auth_to_uri] = true
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    req = "GET /auth HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Authorization: Basic #{Base64.encode64('admin user:test password!@#$%^&*()_+-={}|\:";\'<>?,./').delete("\n")}\n"
    req << "\n"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_equal('authentication successful', res['title'])

    req = "GET /auth HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Authorization: Basic #{Base64.encode64((0 .. 255).to_a.shuffle.pack('C*')).delete("\n")}\n"
    req << "\n"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_equal('401 Unauthorized', res['title'])

    # auth to URI - malformed
    req = "GET /auth HTTP/1.1\n"
    req << "Host: 127.0.0.1:8088\n"
    req << "Authorization: Basic #{"#{('a'..'z').to_a.sample(8).join}"}\n"
    req << "\n"
    res = ssrf.send_request(req)
    validate_response(res)
    assert_equal('401 Unauthorized', res['title'])

    # ip encoding
    %w[int oct hex dotted_hex].each do |encoding|
      opts = SSRF_DEFAULT_OPTS.dup
      opts[:url] = 'http://127.0.0.1:8088/typhoeus?url=xxURLxx'
      opts[:ip_encoding] = encoding
      ssrf = SSRFProxy::HTTP.new(opts)
      validate(ssrf)

      res = ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
      validate_response(res)
      assert_equal('public', res['title'])

      res = ssrf.send_request("GET /auth HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
      validate_response(res)
      assert_equal('401 Unauthorized', res['title'])
    end
  end

  #
  # @note test send_request with invalid input
  #
  def test_send_request_invalid
    opts = SSRF_DEFAULT_OPTS.dup
    opts[:url] = 'http://127.0.0.1:8088/net_http?url=xxURLxx'
    ssrf = SSRFProxy::HTTP.new(opts)
    validate(ssrf)

    urls = [
      'http://', 'ftp://', 'smb://', '://z', '://z:80',
      [], [[[]]], {}, {{}=>{}}, '', nil, 0x00, false, true,
      '://127.0.0.1/file.ext?query1=a&query2=b'
    ]
    urls.each do |url|
      assert_raises SSRFProxy::HTTP::Error::InvalidClientRequest do
        ssrf.send_request("GET #{url} HTTP/1.0\n\n")
      end
    end
    assert_raises SSRFProxy::HTTP::Error::InvalidClientRequest do
      ssrf.send_request("GET / HTTP/1.0\n")
    end
    assert_raises SSRFProxy::HTTP::Error::InvalidClientRequest do
      ssrf.send_request("GET / HTTP/1.1\n\n")
    end
    assert_raises SSRFProxy::HTTP::Error::InvalidClientRequest do
      method = ('a'..'z').to_a.sample(8).join
      ssrf.send_request("#{method} / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    end
    assert_raises SSRFProxy::HTTP::Error::InvalidClientRequest do
      ssrf.send_request("GET / HTTP/1.1\nHost: 127.0.0.1:8088\nUpgrade: WebSocket\n\n")
    end
  end
end
