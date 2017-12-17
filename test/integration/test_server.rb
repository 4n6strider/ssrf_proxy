#
# Copyright (c) 2015-2017 Brendan Coles <bcoles@gmail.com>
# SSRF Proxy - https://github.com/bcoles/ssrf_proxy
# See the file 'LICENSE.md' for copying permission
#
require './test/test_helper.rb'
require './test/integration_test_helper.rb'

#
# @note SSRFProxy::Server integration tests
#
class TestIntegrationSSRFProxyServer < Minitest::Test

  #
  # @note start Celluloid before tasks
  #
  def before_setup
    Celluloid.shutdown
    Celluloid.boot
  end

  #
  # @note (re)set default SSRF and SSRF Proxy options
  #
  def setup
    @url = 'http://127.0.0.1:8088/curl?url=xxURLxx'
  end

  #
  # @note stop Celluloid
  #
  def teardown
    Celluloid.shutdown
  end

  #
  # @note check a HTTP response is valid
  #
  def validate_response(res)
    assert(res)
    assert(res =~ %r{\AHTTP/\d\.\d [\d]+ })
    true
  end

  #
  # @note test server socket
  #
  def test_server_socket
    server_opts = SERVER_DEFAULT_OPTS.dup
    ssrf_opts = SSRF_DEFAULT_OPTS.dup
    ssrf_opts[:url] = @url
    start_server(ssrf_opts, server_opts)
    Timeout.timeout(5) do
      begin
        TCPSocket.new(server_opts['interface'], server_opts['port']).close
        assert(true)
      rescue => e
        assert(false,
          "Connection to #{server_opts['interface']}:#{server_opts['port']} failed: #{e.message}")
      end
    end
  end

  #
  # @note test server address in use
  #
  def test_server_address_in_use
    server_opts = SERVER_DEFAULT_OPTS.dup
    ssrf_opts = SSRF_DEFAULT_OPTS.dup
    ssrf_opts[:url] = @url
    ssrf = SSRFProxy::HTTP.new(ssrf_opts)
    assert_raises SSRFProxy::Server::Error::AddressInUse do
      SSRFProxy::Server.new(ssrf, server_opts['interface'], 8088)
    end
  end

  #
  # @note test server upstream proxy unresponsive
  #
  def test_server_upstream_proxy_unresponsive
    server_opts = SERVER_DEFAULT_OPTS.dup
    ssrf_opts = SSRF_DEFAULT_OPTS.dup
    ssrf_opts[:url] = @url
    ssrf_opts[:proxy] = "http://#{server_opts['interface']}:99999"
    ssrf = SSRFProxy::HTTP.new(ssrf_opts)
    ssrf.logger.level = ::Logger::WARN
    assert_raises SSRFProxy::Server::Error::RemoteProxyUnresponsive do
      SSRFProxy::Server.new(ssrf, server_opts['interface'], server_opts['port'])
    end
  end

  #
  # @note test server remote host unresponsive
  #
  def test_server_host_unresponsive
    server_opts = SERVER_DEFAULT_OPTS.dup
    ssrf_opts = SSRF_DEFAULT_OPTS.dup
    ssrf_opts[:url] = 'http://127.0.0.1:99999/curl?url=xxURLxx'
    ssrf = SSRFProxy::HTTP.new(ssrf_opts)
    ssrf.logger.level = ::Logger::WARN
    assert_raises SSRFProxy::Server::Error::RemoteHostUnresponsive do
      SSRFProxy::Server.new(ssrf, server_opts['interface'], server_opts['port'])
    end
  end

  #
  # @note test server remote host unresponsive
  #
  def test_server_invalid_response
    server_opts = SERVER_DEFAULT_OPTS.dup

    # Configure SSRF options
    ssrf_opts = SSRF_DEFAULT_OPTS.dup
    # HTTP URL scheme for HTTPS server
    ssrf_opts[:url] = 'http://127.0.0.1:8089/curl?url=xxURLxx'
    ssrf_opts[:timeout] = 2

    # Start SSRF Proxy server and open connection
    start_server(ssrf_opts, server_opts)

    http = Net::HTTP::Proxy('127.0.0.1', '8081').new('127.0.0.1', '8088')
    http.open_timeout = 5
    http.read_timeout = 5

    res = http.request Net::HTTP::Get.new('/', {})
    assert(res)
    assert(503, res.code)
  end

  #
  # @note test upstream HTTP proxy server
  #
  def test_upstream_proxy
    # Start upstream HTTP proxy server
    assert(start_proxy_server('127.0.0.1', 8008),
      'Could not start upstream HTTP proxy server')

    server_opts = SERVER_DEFAULT_OPTS.dup

    # Configure SSRF options
    ssrf_opts = SSRF_DEFAULT_OPTS.dup
    ssrf_opts[:url] = @url
    ssrf_opts[:proxy] = 'http://127.0.0.1:8008/'
    ssrf_opts[:match] = '<textarea>(.*)</textarea>\z'
    ssrf_opts[:strip] = 'server,date'
    ssrf_opts[:guess_mime] = true
    ssrf_opts[:guess_status] = true
    ssrf_opts[:forward_cookies] = true
    ssrf_opts[:body_to_uri] = true
    ssrf_opts[:auth_to_uri] = true
    ssrf_opts[:cookies_to_uri] = true
    ssrf_opts[:timeout] = 2

    # Start SSRF Proxy server and open connection
    start_server(ssrf_opts, server_opts)

    http = Net::HTTP::Proxy('127.0.0.1', '8081').new('127.0.0.1', '8088')
    http.open_timeout = 10
    http.read_timeout = 10

    res = http.request Net::HTTP::Get.new('/', {})
    assert(res)
    assert(res.body =~ %r{<title>public</title>})
  end

  #
  # @note test server with raw TCP socket
  #
  def test_proxy_socket
    server_opts = SERVER_DEFAULT_OPTS.dup

    # Configure SSRF options
    ssrf_opts = SSRF_DEFAULT_OPTS.dup
    ssrf_opts[:url] = @url
    ssrf_opts[:match] = '<textarea>(.*)</textarea>\z'
    ssrf_opts[:strip] = 'server,date'
    ssrf_opts[:guess_mime] = true
    ssrf_opts[:guess_status] = true
    ssrf_opts[:forward_cookies] = true
    ssrf_opts[:body_to_uri] = true
    ssrf_opts[:auth_to_uri] = true
    ssrf_opts[:cookies_to_uri] = true
    ssrf_opts[:timeout] = 2

    # Start SSRF Proxy server and open connection
    start_server(ssrf_opts, server_opts)

    # valid HTTP/1.0 request
    client = TCPSocket.new(server_opts['interface'], server_opts['port'])
    client.write("GET http://127.0.0.1:8088/ HTTP/1.0\n\n")
    res = client.readpartial(1024)
    client.close
    validate_response(res)
    assert(res =~ %r{<title>public</title>})

    # valid HTTP/1.1 request
    client = TCPSocket.new(server_opts['interface'], server_opts['port'])
    client.write("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    res = client.readpartial(1024)
    client.close
    validate_response(res)
    assert(res =~ %r{<title>public</title>})

    # invalid HTTP/1.0 request
    client = TCPSocket.new(server_opts['interface'], server_opts['port'])
    client.write("GET / HTTP/1.0\n\n")
    res = client.readpartial(1024)
    client.close
    validate_response(res)
    assert(res =~ %r{\AHTTP/1\.0 502 Bad Gateway})

    # invalid HTTP/1.1 request
    client = TCPSocket.new(server_opts['interface'], server_opts['port'])
    client.write("GET / HTTP/1.1\n\n")
    res = client.readpartial(1024)
    client.close
    validate_response(res)
    assert(res =~ %r{\AHTTP/1\.0 502 Bad Gateway})

    # CONNECT tunnel
    client = TCPSocket.new(server_opts['interface'], server_opts['port'])
    client.write("CONNECT 127.0.0.1:8088 HTTP/1.0\n\n")
    res = client.readpartial(1024)
    validate_response(res)
    assert(res =~ %r{\AHTTP/1\.0 200 Connection established\r\n\r\n\z})
    client.write("GET / HTTP/1.1\nHost: 127.0.0.1:8088\n\n")
    res = client.readpartial(1024)
    validate_response(res)
    client.close
    assert(res =~ %r{<title>public</title>})

    # CONNECT tunnel host unreachable
    client = TCPSocket.new(server_opts['interface'], server_opts['port'])
    client.write("CONNECT 10.99.88.77:80 HTTP/1.0\n\n")
    res = client.readpartial(1024)
    validate_response(res)
    client.close
    assert(res =~ %r{\AHTTP/1\.0 504 Timeout})
  end

  #
  # @note test forwarding headers, method, body and cookies with Net::HTTP requests
  #
  def test_forwarding_net_http
    server_opts = SERVER_DEFAULT_OPTS.dup

    # Configure SSRF options
    ssrf_opts = SSRF_DEFAULT_OPTS.dup
    ssrf_opts[:url] = 'http://127.0.0.1:8088/curl_proxy'
    ssrf_opts[:method] = 'GET'
    ssrf_opts[:post_data] = 'url=xxURLxx'
    ssrf_opts[:match] = '<textarea>(.*)</textarea>\z'
    ssrf_opts[:strip] = 'server,date'
    ssrf_opts[:guess_mime] = true
    ssrf_opts[:guess_status] = true
    ssrf_opts[:forward_method] = true
    ssrf_opts[:forward_headers] = true
    ssrf_opts[:forward_body] = true
    ssrf_opts[:forward_cookies] = true
    ssrf_opts[:timeout] = 2

    # Start SSRF Proxy server and open connection
    start_server(ssrf_opts, server_opts)

    http = Net::HTTP::Proxy('127.0.0.1', '8081').new('127.0.0.1', '8088')
    http.open_timeout = 10
    http.read_timeout = 10

    # junk request data
    junk1 = ('a'..'z').to_a.sample(8).join.to_s
    junk2 = ('a'..'z').to_a.sample(8).join.to_s
    junk3 = ('a'..'z').to_a.sample(8).join.to_s
    junk4 = ('a'..'z').to_a.sample(8).join.to_s

    # check if method and post data are forwarded
    req = Net::HTTP::Post.new('/submit')
    req.set_form_data('data1' => junk1, 'data2' => junk2)
    res = http.request req
    assert(res)
    assert_equal(junk1, res.body.scan(%r{<p>data1: (#{junk1})</p>}).flatten.first)
    assert_equal(junk2, res.body.scan(%r{<p>data2: (#{junk2})</p>}).flatten.first)

    # check if method and headers (including cookies) are forwarded
    headers = { 'header1' => junk1,
                'header2' => junk2,
                'cookie'  => "junk3=#{junk3}; junk4=#{junk4}" }
    req = Net::HTTP::Post.new('/headers', headers.to_hash)
    req.set_form_data({})
    res = http.request req
    assert(res)
    assert(res.body =~ %r{<p>Header1: #{junk1}</p>})
    assert(res.body =~ %r{<p>Header2: #{junk2}</p>})
    assert(res.body =~ /junk3=#{junk3}/)
    assert(res.body =~ /junk4=#{junk4}/)

    # test forwarding method and headers with compression headers
    headers = { 'accept-encoding' => 'deflate, gzip' }
    req = Net::HTTP::Post.new('/', headers.to_hash)
    req.set_form_data({})
    res = http.request req
    assert(res)
    assert(res.body =~ %r{<title>public</title>})
  end

  #
  # @note test server with https request using 'ssl' rule
  #
  def test_proxy_https_net_http
    # Configure SSRF options
    ssrf_opts = SSRF_DEFAULT_OPTS.dup
    ssrf_opts[:url] = @url
    ssrf_opts[:match] = '<textarea>(.*)</textarea>\z'
    ssrf_opts[:rules] = 'ssl'
    ssrf_opts[:insecure] = true
    ssrf_opts[:timeout] = 2

    # Configure server options
    server_opts = SERVER_DEFAULT_OPTS.dup
    server_opts['port'] = '8082'

    # Start SSRF Proxy server and open connection
    start_server(ssrf_opts, server_opts)

    http = Net::HTTP::Proxy('127.0.0.1', '8082').new('127.0.0.1', '8089')
    http.open_timeout = 10
    http.read_timeout = 10

    # get request method
    res = http.request Net::HTTP::Get.new('/', {})
    assert(res)
    assert_includes(res.body.to_s, '<title>public</title>')
  end

  #
  # @note test server with Net::HTTP requests
  #
  def test_proxy_net_http
    server_opts = SERVER_DEFAULT_OPTS.dup

    # Configure SSRF options
    ssrf_opts = SSRF_DEFAULT_OPTS.dup
    ssrf_opts[:url] = @url
    ssrf_opts[:match] = '<textarea>(.*)</textarea>\z'
    ssrf_opts[:strip] = 'server,date'
    ssrf_opts[:guess_mime] = true
    ssrf_opts[:guess_status] = true
    ssrf_opts[:forward_cookies] = true
    ssrf_opts[:body_to_uri] = true
    ssrf_opts[:auth_to_uri] = true
    ssrf_opts[:cookies_to_uri] = true
    ssrf_opts[:timeout] = 2

    # Start SSRF Proxy server and open connection
    start_server(ssrf_opts, server_opts)

    http = Net::HTTP::Proxy('127.0.0.1', '8081').new('127.0.0.1', '8088')
    http.open_timeout = 10
    http.read_timeout = 10

    # get request method
    res = http.request Net::HTTP::Get.new('/', {})
    assert(res)
    assert(res.body =~ %r{<title>public</title>})

    # strip headers
    assert(res['Server'].nil?)
    assert(res['Date'].nil?)

    # post request method
    headers = {}
    req = Net::HTTP::Post.new('/', headers.to_hash)
    req.set_form_data({})
    res = http.request req
    assert(res)
    assert(res.body =~ %r{<title>public</title>})

    # body to URI
    junk1 = ('a'..'z').to_a.sample(8).join.to_s
    junk2 = ('a'..'z').to_a.sample(8).join.to_s

    url = '/submit'
    headers = {}
    req = Net::HTTP::Post.new(url, headers.to_hash)
    req.set_form_data('data1' => junk1, 'data2' => junk2)
    res = http.request req
    assert(res)
    assert_equal(junk1, res.body.scan(%r{<p>data1: (#{junk1})</p>}).flatten.first)
    assert_equal(junk2, res.body.scan(%r{<p>data2: (#{junk2})</p>}).flatten.first)

    url = '/submit?query'
    headers = {}
    req = Net::HTTP::Post.new(url, headers.to_hash)
    req.set_form_data('data1' => junk1, 'data2' => junk2)
    res = http.request req
    assert(res)
    assert_equal(junk1, res.body.scan(%r{<p>data1: (#{junk1})</p>}).flatten.first)
    assert_equal(junk2, res.body.scan(%r{<p>data2: (#{junk2})</p>}).flatten.first)

    # auth to URI
    url = '/auth'
    headers = {}
    req = Net::HTTP::Get.new(url, headers.to_hash)
    req.basic_auth('admin user', 'test password!@#$%^&*()_+-={}|\:";\'<>?,./')
    res = http.request req
    assert(res)
    assert(res.body =~ %r{<title>authentication successful</title>})

    # cookies to URI
    cookie_name = ('a'..'z').to_a.sample(8).join.to_s
    cookie_value = ('a'..'z').to_a.sample(8).join.to_s
    url = '/submit'
    headers = {}
    headers['Cookie'] = "#{cookie_name}=#{cookie_value}"
    res = http.request Net::HTTP::Get.new(url, headers.to_hash)
    assert(res)
    assert(res.body =~ %r{<p>#{cookie_name}: #{cookie_value}</p>})

    url = '/submit?query'
    headers = {}
    headers['Cookie'] = "#{cookie_name}=#{cookie_value}"
    res = http.request Net::HTTP::Get.new(url, headers.to_hash)
    assert(res)
    assert(res.body =~ %r{<p>#{cookie_name}: #{cookie_value}</p>})

    # ask password
    url = '/auth'
    res = http.request Net::HTTP::Get.new(url, {})
    assert(res)
    assert_equal('Basic realm="127.0.0.1:8088"', res['WWW-Authenticate'])

    # detect redirect
    url = '/redirect'
    res = http.request Net::HTTP::Get.new(url, {})
    assert(res)
    assert_equal('/admin', res['Location'])

    # guess mime
    url = "/#{('a'..'z').to_a.sample(8).join}.ico"
    res = http.request Net::HTTP::Get.new(url, {})
    assert(res)
    assert_equal('image/x-icon', res['Content-Type'])

    # guess status
    url = '/auth'
    res = http.request Net::HTTP::Get.new(url, {})
    assert(res)
    assert_equal(401, res.code.to_i)

    # CONNECT tunnel
    http = Net::HTTP::Proxy('127.0.0.1', '8081').new('127.0.0.1', '8088')
    http.open_timeout = 10
    http.read_timeout = 10
    res = http.request Net::HTTP::Get.new('/', {})
    assert(res)
    assert(res.body =~ %r{<title>public</title>})

    # CONNECT tunnel host unreachable
    http = Net::HTTP::Proxy('127.0.0.1', '8081').new('10.99.88.77', '80')
    http.open_timeout = 10
    http.read_timeout = 10
    res = http.request Net::HTTP::Get.new('/', {})
    assert(res)
    assert_equal(504, res.code.to_i)
  end

  #
  # @note test forwarding headers, method, body and cookies with cURL requests
  #
  def test_forwarding_curl
    # Configure path to curl
    skip 'Could not find curl executable. Skipping curl tests...' unless curl_path

    server_opts = SERVER_DEFAULT_OPTS.dup

    # Configure SSRF options
    ssrf_opts = SSRF_DEFAULT_OPTS.dup
    ssrf_opts[:url] = 'http://127.0.0.1:8088/curl_proxy'
    ssrf_opts[:method] = 'GET'
    ssrf_opts[:post_data] = 'url=xxURLxx'
    ssrf_opts[:match] = '<textarea>(.*)</textarea>\z'
    ssrf_opts[:strip] = 'server,date'
    ssrf_opts[:guess_mime] = true
    ssrf_opts[:guess_status] = true
    ssrf_opts[:forward_method] = true
    ssrf_opts[:forward_headers] = true
    ssrf_opts[:forward_body] = true
    ssrf_opts[:forward_cookies] = true
    ssrf_opts[:timeout] = 2

    # Start SSRF Proxy server and open connection
    start_server(ssrf_opts, server_opts)

    # junk request data
    junk1 = ('a'..'z').to_a.sample(8).join.to_s
    junk2 = ('a'..'z').to_a.sample(8).join.to_s
    junk3 = ('a'..'z').to_a.sample(8).join.to_s
    junk4 = ('a'..'z').to_a.sample(8).join.to_s

    # check if method and post data are forwarded
    cmd = [curl_path, '-isk',
           '-X', 'POST',
           '-d', "data1=#{junk1}&data2=#{junk2}",
           '--proxy', '127.0.0.1:8081',
           'http://127.0.0.1:8088/submit']
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert_equal(junk1, res.scan(%r{<p>data1: (#{junk1})</p>}).flatten.first)
    assert_equal(junk2, res.scan(%r{<p>data2: (#{junk2})</p>}).flatten.first)

    # check if method and headers (including cookies) are forwarded
    cmd = [curl_path, '-isk',
           '-X', 'POST',
           '-d', '',
           '-H', "header1: #{junk1}",
           '-H', "header2: #{junk2}",
           '--cookie', "junk3=#{junk3}; junk4=#{junk4}",
           '--proxy', '127.0.0.1:8081',
           'http://127.0.0.1:8088/headers']
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert(res =~ %r{<p>Header1: #{junk1}</p>})
    assert(res =~ %r{<p>Header2: #{junk2}</p>})
    assert(res =~ /junk3=#{junk3}/)
    assert(res =~ /junk4=#{junk4}/)

    # test forwarding method and headers with compression headers
    cmd = [curl_path, '-isk',
           '-X', 'POST',
           '-d', '',
           '--compressed',
           '--proxy', '127.0.0.1:8081',
           'http://127.0.0.1:8088/']
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert(res =~ %r{<title>public</title>})
  end

  #
  # @note test server with https request using 'ssl' rule
  #
  def test_proxy_https_curl
    # Configure SSRF options
    ssrf_opts = SSRF_DEFAULT_OPTS.dup
    ssrf_opts[:url] = @url
    ssrf_opts[:match] = '<textarea>(.*)</textarea>\z'
    ssrf_opts[:rules] = 'ssl'
    ssrf_opts[:insecure] = true
    ssrf_opts[:timeout] = 2

    # Configure server options
    server_opts = SERVER_DEFAULT_OPTS.dup
    server_opts['port'] = '8082'

    # Start SSRF Proxy server and open connection
    start_server(ssrf_opts, server_opts)

    # get request method
    cmd = [curl_path, '-isk',
           '-X', 'GET',
           '--proxy', '127.0.0.1:8082',
           'http://127.0.0.1:8089/']
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert_includes(res, '<title>public</title>')
  end

  #
  # @note test server with curl requests
  #
  def test_proxy_curl
    skip 'Could not find curl executable. Skipping curl tests...' unless curl_path

    server_opts = SERVER_DEFAULT_OPTS.dup

    # Configure SSRF options
    ssrf_opts = SSRF_DEFAULT_OPTS.dup
    ssrf_opts[:url] = @url
    ssrf_opts[:match] = '<textarea>(.*)</textarea>\z'
    ssrf_opts[:strip] = 'server,date'
    ssrf_opts[:guess_mime] = true
    ssrf_opts[:guess_status] = true
    ssrf_opts[:forward_cookies] = true
    ssrf_opts[:body_to_uri] = true
    ssrf_opts[:auth_to_uri] = true
    ssrf_opts[:cookies_to_uri] = true
    ssrf_opts[:timeout] = 2

    # Start SSRF Proxy server and open connection
    start_server(ssrf_opts, server_opts)

    # invalid request
    cmd = [curl_path, '-isk',
           '-X', 'GET',
           '--proxy', '127.0.0.1:8081',
           "http://127.0.0.1:8088/#{'A' * 5000}"]
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert(res =~ %r{\AHTTP/1\.0 502 Bad Gateway})

    # get request method
    cmd = [curl_path, '-isk',
           '-X', 'GET',
           '--proxy', '127.0.0.1:8081',
           'http://127.0.0.1:8088/']
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert(res =~ %r{<title>public</title>})

    # strip headers
    assert(res !~ /^Server: /)
    assert(res !~ /^Date: /)

    # post request method
    cmd = [curl_path, '-isk',
           '-X', 'POST',
           '-d', '',
           '--proxy', '127.0.0.1:8081',
           'http://127.0.0.1:8088/']
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert(res =~ %r{<title>public</title>})

    # invalid request method
    cmd = [curl_path, '-isk',
           '-X', ('a'..'z').to_a.sample(8).join.to_s,
           '--proxy', '127.0.0.1:8081',
           'http://127.0.0.1:8088/']
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert(res =~ %r{\AHTTP/1\.0 502 Bad Gateway})

    # body to URI
    junk1 = ('a'..'z').to_a.sample(8).join.to_s
    junk2 = ('a'..'z').to_a.sample(8).join.to_s
    data = "data1=#{junk1}&data2=#{junk2}"

    cmd = [curl_path, '-isk',
           '-X', 'POST',
           '-d', data.to_s,
           '--proxy', '127.0.0.1:8081',
           'http://127.0.0.1:8088/submit']
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)

    assert_equal(junk1, res.scan(%r{<p>data1: (#{junk1})</p>}).flatten.first)
    assert_equal(junk2, res.scan(%r{<p>data2: (#{junk2})</p>}).flatten.first)

    cmd = [curl_path, '-isk',
           '-X', 'POST',
           '-d', data.to_s,
           '--proxy', '127.0.0.1:8081',
           'http://127.0.0.1:8088/submit?query']
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert_equal(junk1, res.scan(%r{<p>data1: (#{junk1})</p>}).flatten.first)
    assert_equal(junk2, res.scan(%r{<p>data2: (#{junk2})</p>}).flatten.first)

    # auth to URI
    cmd = [curl_path, '-isk',
           '--proxy', '127.0.0.1:8081',
           '-u', 'admin user:test password!@#$%^&*()_+-={}|\:";\'<>?,./',
           'http://127.0.0.1:8088/auth']
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert(res =~ %r{<title>authentication successful</title>})

    cmd = [curl_path, '-isk',
           '--proxy', '127.0.0.1:8081',
           '-u', (1..255).to_a.shuffle.pack('C*'),
           'http://127.0.0.1:8088/auth']
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert(res =~ %r{<title>401 Unauthorized</title>})

    # cookies to URI
    cookie_name = ('a'..'z').to_a.sample(8).join.to_s
    cookie_value = ('a'..'z').to_a.sample(8).join.to_s
    cmd = [curl_path, '-isk',
           '--cookie', "#{cookie_name}=#{cookie_value}",
           '--proxy', '127.0.0.1:8081',
           'http://127.0.0.1:8088/submit']
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert(res =~ %r{<p>#{cookie_name}: #{cookie_value}</p>})

    cmd = [curl_path, '-isk',
           '--cookie', "#{cookie_name}=#{cookie_value}",
           '--proxy', '127.0.0.1:8081',
           'http://127.0.0.1:8088/submit?query']
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert(res =~ %r{<p>#{cookie_name}: #{cookie_value}</p>})

    # ask password
    cmd = [curl_path, '-isk',
           '--proxy', '127.0.0.1:8081',
           'http://127.0.0.1:8088/auth']
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert(res =~ /^WWW-Authenticate: Basic realm="127\.0\.0\.1:8088"$/i)

    # detect redirect
    cmd = [curl_path, '-isk',
           '--proxy', '127.0.0.1:8081',
           'http://127.0.0.1:8088/redirect']
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert(res =~ %r{^Location: /admin$}i)

    # guess mime
    cmd = [curl_path, '-isk',
           '--proxy', '127.0.0.1:8081',
           "http://127.0.0.1:8088/#{('a'..'z').to_a.sample(8).join}.ico"]
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert(res =~ %r{^Content-Type: image\/x\-icon$}i)

    # guess status
    cmd = [curl_path, '-isk',
           '--proxy', '127.0.0.1:8081',
           'http://127.0.0.1:8088/auth']
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert(res =~ %r{\AHTTP/\d\.\d 401 Unauthorized})

    # WebSocket request
    cmd = [curl_path, '-isk',
           '--proxy', '127.0.0.1:8081',
           'http://127.0.0.1:8088/auth',
           '-H', 'Upgrade: WebSocket']
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert(res =~ %r{\AHTTP/1\.0 502 Bad Gateway})

    # CONNECT tunnel
    cmd = [curl_path, '-isk',
           '-X', 'GET',
           '--proxytunnel',
           '--proxy', '127.0.0.1:8081',
           'http://127.0.0.1:8088/']
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert(res =~ %r{<title>public</title>})

    # CONNECT tunnel host unreachable
    cmd = [curl_path, '-isk',
           '-X', 'GET',
           '--proxytunnel',
           '--proxy', '127.0.0.1:8081',
           'http://10.99.88.77/']
    res = IO.popen(cmd, 'r+').read.to_s
    validate_response(res)
    assert(res =~ %r{\AHTTP/1\.0 504 Timeout})
  end
end
