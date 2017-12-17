#
# Copyright (c) 2015-2017 Brendan Coles <bcoles@gmail.com>
# SSRF Proxy - https://github.com/bcoles/ssrf_proxy
# See the file 'LICENSE.md' for copying permission
#

require './test/common/http_server.rb'
require './test/common/proxy_server.rb'

#
# @note check for cURL executable
#
def curl_path
  ['/usr/sbin/curl', '/usr/bin/curl'].each do |path|
    return path if File.executable?(path)
  end
  nil
end

#
# @note start SSRF Proxy server
#
def start_server(ssrf_opts, server_opts)
  puts 'Starting SSRF Proxy server...'

  # setup ssrf
  ssrf = SSRFProxy::HTTP.new(ssrf_opts)
  ssrf.logger.level = ::Logger::WARN

  # start proxy server
  Thread.new do
    begin
      ssrf_proxy = SSRFProxy::Server.new(ssrf, server_opts['interface'], server_opts['port'])
      ssrf_proxy.logger.level = ::Logger::WARN
      ssrf_proxy.serve
    rescue => e
      puts "Error: Could not start SSRF Proxy server: #{e.message}"
    end
  end
  puts 'Waiting for SSRF Proxy server to start...'
  sleep 1
end

#
# @note start upstream HTTP proxy server
#
@proxy_server ||= begin
  puts 'Starting HTTP proxy test server...'
  interface = '127.0.0.01'
  port = 8008
  Thread.new do
    begin
      ProxyServer.new.run(interface, port.to_i)
    rescue => e
      puts "Error: Could not start HTTP proxy server: #{e}"
    end
  end
end

#
# @note start test HTTP server
#
@http_server ||= begin
  puts 'Starting HTTP test server...'
  begin
    Thread.new do
      HTTPServer.new(
        'interface' => '127.0.0.1',
        'port' => '8088',
        'ssl' => false,
        'verbose' => false,
        'debug' => false)
    end
  rescue => e
    puts "Error: Could not start test HTTP server: #{e}"
  end
end

#
# @note start test HTTPS server
#
@https_server ||= begin
  puts 'Starting HTTPS test server...'
  begin
    Thread.new do
      HTTPServer.new(
       'interface' => '127.0.0.1',
       'port' => '8089',
       'ssl' => true,
       'verbose' => false,
       'debug' => false)
    end
  rescue => e
    puts "Error: Could not start test HTTPS server: #{e}"
  end
end

puts 'Waiting for test servers to start...'
sleep 1
