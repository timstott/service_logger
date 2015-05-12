require 'spec_helper'
require 'timecop'
require 'sinatra'

class SinatraApp < Sinatra::Base
  get '/ok' do
    'Hello Sinatra'
  end

  get '/error' do
    fail StandardError, 'Hello Sinatra Error'
  end
end

SinatraApp.configure do |app|
  app.use ServiceLogger::Rack::Logger
end

describe 'Rack request logger with Sinatra' do
  before(:all) { Timecop.freeze(time_anchor) }
  after(:all)  { Timecop.return }

  before do
    ServiceLogger.configure do |config|
      config.service_name    = 'hello_world_app'
      config.service_version = '1.0'
      config.log_target      = target
    end

    ServiceLogger::Logging.reset
  end
  let(:target) { StringIO.new }
  let(:app)    { SinatraApp.new }
  let(:json_line) do
    target.rewind
    JSON.parse(target.read)
  end

  context 'when the request is successful' do
    it 'logs the request' do
      get '/ok',
          { username: 'yoshi' },
          'HTTP_USER_AGENT' => 'Chrome'

      expect(json_line).to match(
        'version'             => '1.1',
        'host'                => be_a(String),
        'short_message'       => 'GET /ok?username=yoshi',
        'full_message'        => '',
        'timestamp'           => '1450171805.123',
        'level'               => 6,
        '_event'              => 'http_request',
        '_service.name'       => 'hello_world_app',
        '_service.version'    => '1.0',
        '_request.method'     => 'GET',
        '_request.path'       => '/ok',
        '_request.params'     => { 'username' => 'yoshi' },
        '_request.request_ip' => '127.0.0.1',
        '_request.user_agent' => 'Chrome',
        '_request.status'     => 200,
        '_request.request_id' => nil,
        '_request.duration'   => be_an(Integer),
      )
    end
  end

  context 'when the request raises an exception' do
    it 'logs the request with the exception' do
      get '/error',
          { username: 'yoshi' },
          'HTTP_USER_AGENT' => 'Chrome'

      expect(json_line).to match(
        'version'              => '1.1',
        'host'                 => be_a(String),
        'short_message'        => 'GET /error?username=yoshi',
        'full_message'         => '',
        'timestamp'            => '1450171805.123',
        'level'                => 3,
        '_event'               => 'http_request',
        '_service.name'        => 'hello_world_app',
        '_service.version'     => '1.0',
        '_request.method'      => 'GET',
        '_request.path'        => '/error',
        '_request.params'      => { 'username' => 'yoshi' },
        '_request.request_ip'  => '127.0.0.1',
        '_request.user_agent'  => 'Chrome',
        '_request.request_id'  => nil,
        '_request.duration'    => be_an(Integer),
        '_exception.klass'     => 'StandardError',
        '_exception.message'   => 'Hello Sinatra Error',
        '_exception.backtrace' => be_a(String),
      )
      expect(json_line).to_not include('_request.status')
    end
  end
end
