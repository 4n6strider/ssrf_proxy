# coding: utf-8
#
# Copyright (c) 2015-2017 Brendan Coles <bcoles@gmail.com>
# SSRF Proxy - https://github.com/bcoles/ssrf_proxy
# See the file 'LICENSE.md' for copying permission
#
require './test/test_helper'

class SSRFProxyHTTPTest < Minitest::Test
  require './test/common/constants.rb'

  # configure ssrf
  def setup
    @opts = SSRF_DEFAULT_OPTS.dup
  end

  #
  # @note check a SSRFProxy::HTTP object is valid
  #
  def validate(ssrf)
    assert_equal(SSRFProxy::HTTP, ssrf.class)
    assert(ssrf.scheme)
    assert(ssrf.host)
    assert(ssrf.port)
    assert(ssrf.url)
    true
  end

  #
  # @note test creating SSRFProxy::HTTP objects with GET method
  #
  def test_ssrf_method_get
    ssrf = SSRFProxy::HTTP.new('http://127.0.0.1/xxURLxx', @opts)
    validate(ssrf)
    @opts['post_data'] = 'xxURLxx'
    SSRFProxy::HTTP.new('http://127.0.0.1/', @opts)
    validate(ssrf)
  end

  #
  # @note test creating SSRFProxy::HTTP objects with HEAD method
  #
  def test_ssrf_method_head
    @opts['method'] = 'HEAD'
    ssrf = SSRFProxy::HTTP.new('http://127.0.0.1/xxURLxx', @opts)
    validate(ssrf)
    @opts['post_data'] = 'xxURLxx'
    SSRFProxy::HTTP.new('http://127.0.0.1/', @opts)
    validate(ssrf)
  end

  #
  # @note test creating SSRFProxy::HTTP objects with DELETE method
  #
  def test_ssrf_method_delete
    @opts['method'] = 'DELETE'
    ssrf = SSRFProxy::HTTP.new('http://127.0.0.1/xxURLxx', @opts)
    validate(ssrf)
    @opts['post_data'] = 'xxURLxx'
    SSRFProxy::HTTP.new('http://127.0.0.1/', @opts)
    validate(ssrf)
  end

  #
  # @note test creating SSRFProxy::HTTP objects with POST method
  #
  def test_ssrf_method_post
    @opts['method'] = 'POST'
    ssrf = SSRFProxy::HTTP.new('http://127.0.0.1/xxURLxx', @opts)
    validate(ssrf)
    @opts['post_data'] = 'xxURLxx'
    SSRFProxy::HTTP.new('http://127.0.0.1/', @opts)
    validate(ssrf)
  end

  #
  # @note test creating SSRFProxy::HTTP objects with PUT method
  #
  def test_ssrf_method_put
    @opts['method'] = 'PUT'
    ssrf = SSRFProxy::HTTP.new('http://127.0.0.1/xxURLxx', @opts)
    validate(ssrf)
    @opts['post_data'] = 'xxURLxx'
    SSRFProxy::HTTP.new('http://127.0.0.1/', @opts)
    validate(ssrf)
  end

  #
  # @note test creating SSRFProxy::HTTP objects with OPTIONS method
  #
  def test_ssrf_method_options
    @opts['method'] = 'OPTIONS'
    ssrf = SSRFProxy::HTTP.new('http://127.0.0.1/xxURLxx', @opts)
    validate(ssrf)
    @opts['post_data'] = 'xxURLxx'
    SSRFProxy::HTTP.new('http://127.0.0.1/', @opts)
    validate(ssrf)
  end

  #
  # @note test creating SSRFProxy::HTTP objects with invalid URL
  #
  def test_ssrf_request_invalid
    urls = [
      'http://', 'ftp://', 'smb://', '://z', '://z:80',
      [], [[[]]], {}, {{}=>{}}, '', nil, "\x00", false, true,
      'xxURLxx://127.0.0.1/file.ext?query1=a&query2=b',
      'ftp://127.0.0.1',
      'ftp://xxURLxx@127.0.0.1/file.ext?query1=a&query2=b',
      'ftp://xxURLxx/file.ext?query1=a&query2=b',
      'ftp://http:xxURLxx@localhost'
    ]
    urls.each do |url|
      assert_raises SSRFProxy::HTTP::Error::InvalidSsrfRequest do
        SSRFProxy::HTTP.new(url, @opts)
      end
      assert_raises SSRFProxy::HTTP::Error::InvalidSsrfRequest do
        SSRFProxy::HTTP.new(url, {})
      end
      ssrf = nil
      begin
        url = URI::parse(url)
        assert_raises SSRFProxy::HTTP::Error::InvalidSsrfRequest do
          ssrf = SSRFProxy::HTTP.new(url, @opts)
        end
        assert_raises SSRFProxy::HTTP::Error::InvalidSsrfRequest do
          ssrf = SSRFProxy::HTTP.new(url, {})
        end
      rescue URI::InvalidURIError
      end
      assert_nil(ssrf)
    end
  end

  #
  # @note test creating SSRFProxy::HTTP objects with invalid reqest method
  #
  def test_request_method_invalid
    url = 'http://127.0.0.1/xxURLxx'
    assert_raises SSRFProxy::HTTP::Error::InvalidSsrfRequestMethod do
      SSRFProxy::HTTP.new( url, {'method' => nil} )
    end
    assert_raises SSRFProxy::HTTP::Error::InvalidSsrfRequestMethod do
      SSRFProxy::HTTP.new( url, { 'method' => "#{('a'..'z').to_a.shuffle[0,8].join}"} )
    end
  end

  #
  # @note test xxURLxx placeholder with GET method
  #
  def test_xxurlxx_placeholder_get
    urls = [
      'http://127.0.0.1',
      'http://xxURLxx@127.0.0.1/file.ext?query1=a&query2=b',
      'http://xxURLxx/file.ext?query1=a&query2=b',
      'http://http:xxURLxx@localhost'
    ]
    urls.each do |url|
      assert_raises SSRFProxy::HTTP::Error::NoUrlPlaceholder do
        SSRFProxy::HTTP.new(url, @opts)
      end
      assert_raises SSRFProxy::HTTP::Error::NoUrlPlaceholder do
        SSRFProxy::HTTP.new(URI::parse(url), @opts)
      end
      assert_raises SSRFProxy::HTTP::Error::NoUrlPlaceholder do
        SSRFProxy::HTTP.new(url, {})
      end
      assert_raises SSRFProxy::HTTP::Error::NoUrlPlaceholder do
        SSRFProxy::HTTP.new(URI::parse(url), {})
      end
    end
  end

  #
  # @note test xxURLxx placeholder with POST method
  #
  def test_xxurlxx_placeholder_post
    urls = [
      'http://127.0.0.1/'
    ]
    urls.each do |url|
      ssrf = SSRFProxy::HTTP.new(url, {'method' => 'POST', 'post_data' => 'xxURLxx'})
      validate(ssrf)
      assert_equal(SSRFProxy::HTTP, ssrf.class)
    end
  end

  #
  # @note test the xxURLxx placeholder regex parser
  #
  def test_xxurlxx_invalid
    (0..255).each do |i|
      buf = [i.to_s(16)].pack('H*')
      begin
        ssrf = SSRFProxy::HTTP.new("http://127.0.0.1/file.ext?query1=a&query2=xx#{buf}URLxx", @opts)
      rescue SSRFProxy::HTTP::Error::NoUrlPlaceholder, SSRFProxy::HTTP::Error::InvalidSsrfRequest
      end
      assert_nil(ssrf) unless buf == 'x'
    end
  end

  #
  # @note test invalid IP encoding
  #
  def test_ip_encoding_invalid
    url = 'http://127.0.0.1/xxURLxx'
    assert_raises SSRFProxy::HTTP::Error::InvalidIpEncoding do
      ssrf = SSRFProxy::HTTP.new( url, {'ip_encoding' => nil} )
      validate(ssrf)
    end
  end

  #
  # @note test upstream proxy
  #
  def test_upstream_proxy_invalid
    url = 'http://127.0.0.1/xxURLxx'
    assert_raises SSRFProxy::HTTP::Error::InvalidUpstreamProxy do
      SSRFProxy::HTTP.new( url, {'proxy' => nil} )
    end
    assert_raises SSRFProxy::HTTP::Error::InvalidUpstreamProxy do
      SSRFProxy::HTTP.new( url, {'proxy' => '://127.0.0.1:8080'} )
    end
    assert_raises SSRFProxy::HTTP::Error::InvalidUpstreamProxy do
      SSRFProxy::HTTP.new( url, {'proxy' => 'http://'} )
    end
    assert_raises SSRFProxy::HTTP::Error::InvalidUpstreamProxy do
      SSRFProxy::HTTP.new( url, {'proxy' => 'http:127.0.0.1:8080'} )
    end
    assert_raises SSRFProxy::HTTP::Error::InvalidUpstreamProxy do
      SSRFProxy::HTTP.new( url, {'proxy' => 'socks://127.0.0.1/'} )
    end
    assert_raises SSRFProxy::HTTP::Error::InvalidUpstreamProxy do
      SSRFProxy::HTTP.new( url, {'proxy' => 'tcp://127.0.0.1/'} )
    end
    assert_raises SSRFProxy::HTTP::Error::InvalidUpstreamProxy do
      SSRFProxy::HTTP.new( url, {'proxy' => 'tcp://127.0.0.1:1234/'} )
    end
  end

  #
  # @note test send_request method
  #
  def test_send_request_invalid
    url = 'http://127.0.0.1/xxURLxx'
    ssrf = SSRFProxy::HTTP.new( url )
    validate(ssrf)
    assert_raises SSRFProxy::HTTP::Error::InvalidClientRequest do
      response = ssrf.send_request(nil)
    end
    assert_raises SSRFProxy::HTTP::Error::InvalidClientRequest do
      response = ssrf.send_request("GET / HTTP/1.1\n\n")
    end
    assert_raises SSRFProxy::HTTP::Error::InvalidClientRequest do
      method = "#{('a'..'z').to_a.shuffle[0,8].join}"
      response = ssrf.send_request("#{method} / HTTP/1.1\nHost: 127.0.0.1\n\n")
    end
  end

  #
  # @note test send_uri method
  #
  def test_send_uri_invalid
    url = 'http://127.0.0.1/xxURLxx'
    assert_raises SSRFProxy::HTTP::Error::InvalidClientRequest do
      ssrf = SSRFProxy::HTTP.new(url)
      validate(ssrf)
      ssrf.send_uri(nil, 'GET', {}, '')
    end
    assert_raises SSRFProxy::HTTP::Error::InvalidClientRequest do
      method = "#{('a'..'z').to_a.shuffle[0,8].join}"
      ssrf = SSRFProxy::HTTP.new(url, {'forward_method' => true})
      validate(ssrf)
      ssrf.send_uri('http://127.0.0.1/', method, {}, '')
    end
  end

  #
  # @note test logger
  #
  def test_logger
    ssrf = SSRFProxy::HTTP.new('http://127.0.0.1/xxURLxx', @opts)
    assert_equal('2', ssrf.logger.level.to_s)
    ssrf.logger.level = Logger::INFO
    assert_equal('1', ssrf.logger.level.to_s)
    ssrf.logger.level = Logger::DEBUG
    assert_equal('0', ssrf.logger.level.to_s)
  end

  #
  # @note test accessors
  #
  def test_accessors
    assert_equal(true, SSRFProxy::HTTP.public_method_defined?(:url))
    assert_equal(true, SSRFProxy::HTTP.public_method_defined?(:scheme))
    assert_equal(true, SSRFProxy::HTTP.public_method_defined?(:host))
    assert_equal(true, SSRFProxy::HTTP.public_method_defined?(:port))
    assert_equal(true, SSRFProxy::HTTP.public_method_defined?(:proxy))
    assert_equal(true, SSRFProxy::HTTP.public_method_defined?(:logger))
  end

  #
  # @note test public methods
  #
  def test_public_methods
    assert_equal(true, SSRFProxy::HTTP.public_method_defined?(:send_uri))
    assert_equal(true, SSRFProxy::HTTP.public_method_defined?(:send_request))
  end

  #
  # @note test private methods
  #
  def test_private_methods
    assert_equal(true, SSRFProxy::HTTP.private_method_defined?(:parse_options))
    assert_equal(true, SSRFProxy::HTTP.private_method_defined?(:send_http_request))
    assert_equal(true, SSRFProxy::HTTP.private_method_defined?(:run_rules))
    assert_equal(true, SSRFProxy::HTTP.private_method_defined?(:encode_ip))
    assert_equal(true, SSRFProxy::HTTP.private_method_defined?(:guess_status))
    assert_equal(true, SSRFProxy::HTTP.private_method_defined?(:guess_mime))
  end
end
