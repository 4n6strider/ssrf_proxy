# coding: utf-8
#
# Copyright (c) 2015-2016 Brendan Coles <bcoles@gmail.com>
# SSRF Proxy - https://github.com/bcoles/ssrf_proxy
# See the file 'LICENSE.md' for copying permission
#

# ouput
require 'logger'
require 'colorize'
String.disable_colorization = false

# proxy server
require 'socket'

# threading
require 'celluloid/current'
require 'celluloid/io'

# command line option parsing
require 'getoptlong'

# http parsing
require 'net/http'
require 'uri'
require 'cgi'
require 'webrick'
require 'stringio'
require 'base64'
require 'htmlentities'

# client request url rules
require 'digest'
require 'base32'

# ip encoding
require 'ipaddress'

# SSRF Proxy gem libs
require 'ssrf_proxy/version'
require 'ssrf_proxy/http'
require 'ssrf_proxy/server'
