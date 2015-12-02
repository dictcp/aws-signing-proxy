#!/usr/bin/env ruby

require 'rack'
require 'faraday'
require 'faraday_middleware/aws_signers_v4'
require 'net/http/persistent'
require 'yaml'

LISTEN_PORT = ARGV[0] || 8080

unless ENV['AWS_ACCESS_KEY_ID'].nil? || ENV['AWS_SECRET_ACCESS_KEY'].nil?
  CREDENTIALS = Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'],ENV['AWS_SECRET_ACCESS_KEY'])
else
  CREDENTIALS = Aws::InstanceProfileCredentials.new
end

app = Proc.new do |env|
  postdata = env['rack.input'].read

  headers = env.select {|k,v| k.start_with? 'HTTP_', 'CONTENT_' }
                .map{|key,val| [ key.sub(/^HTTP_/,''), val ] }
                .map{|key,val| { key.gsub(/_/,'-') => val} }
                .select {|key,_| key != 'HOST'}
                .reduce Hash.new, :merge

  upstream_protocol = headers["X-UPSTREAM-PROTOCOL"] || "https"
  upstream_service_name = headers["X-UPSTREAM-SERVICE-NAME"] || "es"
  upstream_region = headers["X-UPSTREAM-REGION"] || "us-east-1"
  upstream_url = headers["X-UPSTREAM-URL"] || "#{upstream_protocol}://#{env['SERVER_NAME']}"

  client = Faraday.new(url: upstream_url) do |faraday|
    faraday.request(:aws_signers_v4, credentials: CREDENTIALS, service_name: upstream_service_name, region: upstream_region)
    faraday.adapter(:net_http_persistent)
  end

  if env['REQUEST_METHOD'] == 'GET'
    response = client.get "#{env['REQUEST_PATH']}?#{env['QUERY_STRING']}", {}, headers
  elsif env['REQUEST_METHOD'] == 'HEAD'
    response = client.head "#{env['REQUEST_PATH']}?#{env['QUERY_STRING']}", {}, headers
  elsif env['REQUEST_METHOD'] == 'POST'
    response = client.post "#{env['REQUEST_PATH']}?#{env['QUERY_STRING']}", "#{postdata}", headers
  elsif env['REQUEST_METHOD'] == 'PUT'
    response = client.put "#{env['REQUEST_PATH']}?#{env['QUERY_STRING']}", "#{postdata}", headers
  elsif env['REQUEST_METHOD'] == 'DELETE'
    response = client.delete "#{env['REQUEST_PATH']}?#{env['QUERY_STRING']}", {}, headers
  else
    response = nil
  end
  puts "#{response.status} #{env['REQUEST_METHOD']} #{env['REQUEST_PATH']}?#{env['QUERY_STRING']} #{postdata}"
  [response.status, response.headers, [response.body]]
end

webrick_options = {
    :Port => LISTEN_PORT,
}

Rack::Handler::WEBrick.run app, webrick_options
