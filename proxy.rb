#!/usr/bin/env ruby

require 'rack'
require 'faraday'
require 'faraday_middleware/aws_signers_v4'
require 'net/http/persistent'
require 'yaml'

config = YAML.load_file('config.yaml')

UPSTREAM_URL = config['upstream_url']
UPSTREAM_SERVICE_NAME = config['upstream_service_name']
UPSTREAM_REGION = config['upstream_region']
LISTEN_PORT = config['listen_port'] || 8080


unless ENV['AWS_ACCESS_KEY_ID'].nil? || ENV['AWS_SECRET_ACCESS_KEY'].nil? || ENV['AWS_SESSION_TOKEN'].nil?
  CREDENTIALS = Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'],ENV['AWS_SECRET_ACCESS_KEY'],ENV['AWS_SESSION_TOKEN'])
else
  CREDENTIALS = Aws::InstanceProfileCredentials.new
end

app = Proc.new do |env|
    postdata = env['rack.input'].read

    client = Faraday.new(url: UPSTREAM_URL) do |faraday|
      faraday.request(:aws_signers_v4, credentials: CREDENTIALS, service_name: UPSTREAM_SERVICE_NAME, region: UPSTREAM_REGION)
      faraday.adapter(:net_http_persistent)
    end

    if env['REQUEST_METHOD'] == 'GET'
      response = client.get "#{env['REQUEST_PATH']}?#{env['QUERY_STRING']}"
    elsif env['REQUEST_METHOD'] == 'HEAD'
      response = client.head "#{env['REQUEST_PATH']}?#{env['QUERY_STRING']}"
    elsif env['REQUEST_METHOD'] == 'POST'
      response = client.post "#{env['REQUEST_PATH']}?#{env['QUERY_STRING']}", "#{postdata}"
    else
      response = nil
    end
    puts "#{response.status} #{env['REQUEST_METHOD']} #{env['REQUEST_PATH']}?#{env['QUERY_STRING']} #{postdata}"
    [response.status, {}, [response.body]]
end

webrick_options = {
  :Port => LISTEN_PORT,
}

Rack::Handler::WEBrick.run app, webrick_options
