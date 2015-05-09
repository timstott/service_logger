require 'logger'
require 'json'

module ServiceLogger
  # Graylog Extended Log Format (GELF) Formatter v1.1
  # Specification https://www.graylog.org/resources/gelf-2/
  class GELFFormatter < Logger::Formatter
    include Utilities

    VERSION               = '1.1'.freeze
    SYSLOG_LEVELS_MAPPING = {
      'DEBUG'   => 7,
      'INFO'    => 6,
      'WARN'    => 4,
      'ERROR'   => 3,
      'FATAL'   => 2,
      'UNKNOWN' => 1,
    }.freeze

    def initialize(opts)
      @service_name    = opts.fetch(:service_name)
      @service_version = opts.fetch(:service_version)
      @host            = opts.fetch(:host)
    end

    # Format log event in GELF
    #
    # Message structure
    # {
    #   short_message: 'GET /hello_world', # REQUIRED
    #   full_message:  String,             # OPTIONAL
    #   type:          String,             # OPTIONAL
    #   timestamp:     Time,               # OPTIONAL
    #   data:          Hash,               # OPTIONAL
    #   exception:     Exception,          # OPTIONAL
    # }
    def call(severity, time, _progname, message)
      event = {
        'version'          => VERSION,
        'host'             => @host,
        'short_message'    =>  message.fetch(:short_message),
        'full_message'     => '',
        'timestamp'        => unix_time_with_ms(message.fetch(:timestamp, time)),
        'level'            => severity_to_syslog_level(severity),
        '_event_type'      => message.fetch(:type, 'custom'),
        '_service.name'    => @service_name,
        '_service.version' => @service_version,
      }

      event.merge! extract_data(message.delete(:data))
      event.merge! extract_exception(message.delete(:exception))

      JSON.dump(event)
    end

    def severity_to_syslog_level(severity)
      SYSLOG_LEVELS_MAPPING[severity]
    end

    # Extract data hash into GELF additional fields
    #
    # Input data
    # {
    #   'request' => {
    #     'metohd' => 'GET'
    #   },
    #   'name' => 'bob'
    # }
    #
    # Output
    # {
    #   '_request.method' => 'GET',
    #   '_name' => 'bob',
    # }
    def extract_data(data)
      (data || {}).each_with_object({}) do |(key, values), hash|
        if values.is_a? Hash
          values.each do |sub_key, sub_values|
            hash["_#{key}.#{sub_key}"] = sub_values
          end
        else
          hash["_#{key}"] = values
        end
        hash
      end
    end

    private

    def extract_exception(e)
      return {} if e.nil?
      {
        '_exception.backtrace' => e.backtrace.join("\n"),
        '_exception.message'   => e.message,
        '_exception.klass'     => e.class.to_s,
      }
    end
  end
end
