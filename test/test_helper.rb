#
# Copyright (c) 2015-2017 Brendan Coles <bcoles@gmail.com>
# SSRF Proxy - https://github.com/bcoles/ssrf_proxy
# See the file 'LICENSE.md' for copying permission
#
require 'simplecov'
require 'coveralls'
if ENV['COVERALLS']
  SimpleCov.formatter = Coveralls::SimpleCov::Formatter
end
SimpleCov.start do
  add_filter 'test/common/'
  add_filter 'test/unit/'
  add_filter 'test/integration/'
  add_filter 'test/integration_test_helper.rb'
end

require 'minitest/autorun'
require 'minitest/reporters'
Minitest::Reporters.use! [
  Minitest::Reporters::SpecReporter.new(:color => true),
  Minitest::Reporters::MeanTimeReporter.new
]

require 'ssrf_proxy'
require './test/common/constants.rb'

$root_dir = File.join(File.expand_path(File.dirname(File.realpath(__FILE__))), '..')

#
# @note check a SSRFProxy::HTTP object is valid
#
def valid_ssrf?(ssrf)
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
def valid_http_response?(res)
  assert(res)
  assert(res =~ %r{\AHTTP/\d\.\d [\d]+ })
  true
end

#
# @note check a HTTP response is valid
#
def valid_ssrf_response?(res)
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
