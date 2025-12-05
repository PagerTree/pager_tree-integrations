# lib/pager_tree/integrations/format_converters/yaml_json_converter.rb
require "yaml"
require "json"

module PagerTree
  module Integrations
    module FormatConverters
      class YamlJsonConverter
        class InvalidFormatError < StandardError; end

        class << self
          def convert_to_json(str, pretty: true)
            format = detect_format(str)

            case format
            when :json
              data = JSON.parse(str)
              pretty ? JSON.pretty_generate(data) : data.to_json
            when :yaml
              data = YAML.safe_load(str)
              pretty ? JSON.pretty_generate(data) : data.to_json
            else
              raise InvalidFormatError, "Input is neither valid JSON nor YAML"
            end
          end

          def convert_to_yaml(str)
            format = detect_format(str)

            case format
            when :json
              data = JSON.parse(str)
              data.to_yaml
            when :yaml
              data = YAML.safe_load(str)
              data.to_yaml
            else
              raise InvalidFormatError, "Input is neither valid JSON nor YAML"
            end
          end

          def detect_format(str)
            return :json if json?(str)
            return :yaml if yaml?(str)
            :unknown
          end

          private

          def json?(str)
            JSON.parse(str)
            true
          rescue JSON::ParserError
            false
          end

          def yaml?(str)
            YAML.safe_load(str)
            true
          rescue Psych::SyntaxError
            false
          end
        end
      end
    end
  end
end
