require "test_helper"

module PagerTree
  module Integrations
    module FormatConverters
      class YamlJsonConverterTest < ActiveSupport::TestCase
        test "convert_to_json with valid JSON input returns formatted JSON" do
          json_input = '{"name": "test", "age": 30}'
          expected = "{\n  \"name\": \"test\",\n  \"age\": 30\n}"

          result = YamlJsonConverter.convert_to_json(json_input)

          assert_equal expected, result
        end

        test "convert_to_json with valid JSON input and pretty false returns compact JSON" do
          json_input = '{"name": "test", "age": 30}'
          expected = '{"name":"test","age":30}'

          result = YamlJsonConverter.convert_to_json(json_input, pretty: false)

          assert_equal expected, result
        end

        test "convert_to_json with valid YAML input returns formatted JSON" do
          yaml_input = "name: test\nage: 30"
          expected = "{\n  \"name\": \"test\",\n  \"age\": 30\n}"

          result = YamlJsonConverter.convert_to_json(yaml_input)

          assert_equal expected, result
        end

        test "convert_to_json with valid YAML input and pretty false returns compact JSON" do
          yaml_input = "name: test\nage: 30"
          expected = '{"name":"test","age":30}'

          result = YamlJsonConverter.convert_to_json(yaml_input, pretty: false)

          assert_equal expected, result
        end

        test "convert_to_json with complex nested YAML structure" do
          yaml_input = <<~YAML
            users:
              - name: John
                details:
                  age: 30
                  city: NYC
              - name: Jane
                details:
                  age: 25
                  city: LA
            settings:
              debug: true
              timeout: 5000
          YAML

          result = YamlJsonConverter.convert_to_json(yaml_input)
          parsed = JSON.parse(result)

          assert_equal "John", parsed["users"][0]["name"]
          assert_equal 30, parsed["users"][0]["details"]["age"]
          assert_equal "NYC", parsed["users"][0]["details"]["city"]
          assert_equal "Jane", parsed["users"][1]["name"]
          assert_equal 25, parsed["users"][1]["details"]["age"]
          assert_equal "LA", parsed["users"][1]["details"]["city"]
          assert_equal true, parsed["settings"]["debug"]
          assert_equal 5000, parsed["settings"]["timeout"]
        end

        test "convert_to_json with complex nested JSON structure" do
          json_input = '{"users":[{"name":"John","details":{"age":30,"city":"NYC"}},{"name":"Jane","details":{"age":25,"city":"LA"}}],"settings":{"debug":true,"timeout":5000}}'

          result = YamlJsonConverter.convert_to_json(json_input)
          parsed = JSON.parse(result)

          assert_equal "John", parsed["users"][0]["name"]
          assert_equal 30, parsed["users"][0]["details"]["age"]
          assert_equal "NYC", parsed["users"][0]["details"]["city"]
          assert_equal "Jane", parsed["users"][1]["name"]
          assert_equal 25, parsed["users"][1]["details"]["age"]
          assert_equal "LA", parsed["users"][1]["details"]["city"]
          assert_equal true, parsed["settings"]["debug"]
          assert_equal 5000, parsed["settings"]["timeout"]
        end

        test "convert_to_json with invalid input raises InvalidFormatError" do
          invalid_input = "this is neither JSON nor YAML: {invalid"

          assert_raises(YamlJsonConverter::InvalidFormatError) do
            YamlJsonConverter.convert_to_json(invalid_input)
          end
        end

        test "convert_to_yaml with valid JSON input returns YAML" do
          json_input = '{"name": "test", "age": 30}'

          result = YamlJsonConverter.convert_to_yaml(json_input)
          parsed = YAML.safe_load(result)

          assert_equal "test", parsed["name"]
          assert_equal 30, parsed["age"]
        end

        test "convert_to_yaml with valid YAML input returns normalized YAML" do
          yaml_input = "name: test\nage: 30"

          result = YamlJsonConverter.convert_to_yaml(yaml_input)
          parsed = YAML.safe_load(result)

          assert_equal "test", parsed["name"]
          assert_equal 30, parsed["age"]
        end

        test "convert_to_yaml with complex nested JSON structure" do
          json_input = '{"users":[{"name":"John","details":{"age":30,"city":"NYC"}},{"name":"Jane","details":{"age":25,"city":"LA"}}],"settings":{"debug":true,"timeout":5000}}'

          result = YamlJsonConverter.convert_to_yaml(json_input)
          parsed = YAML.safe_load(result)

          assert_equal "John", parsed["users"][0]["name"]
          assert_equal 30, parsed["users"][0]["details"]["age"]
          assert_equal "NYC", parsed["users"][0]["details"]["city"]
          assert_equal "Jane", parsed["users"][1]["name"]
          assert_equal 25, parsed["users"][1]["details"]["age"]
          assert_equal "LA", parsed["users"][1]["details"]["city"]
          assert_equal true, parsed["settings"]["debug"]
          assert_equal 5000, parsed["settings"]["timeout"]
        end

        test "convert_to_yaml with complex nested YAML structure" do
          yaml_input = <<~YAML
            users:
              - name: John
                details:
                  age: 30
                  city: NYC
              - name: Jane
                details:
                  age: 25
                  city: LA
            settings:
              debug: true
              timeout: 5000
          YAML

          result = YamlJsonConverter.convert_to_yaml(yaml_input)
          parsed = YAML.safe_load(result)

          assert_equal "John", parsed["users"][0]["name"]
          assert_equal 30, parsed["users"][0]["details"]["age"]
          assert_equal "NYC", parsed["users"][0]["details"]["city"]
          assert_equal "Jane", parsed["users"][1]["name"]
          assert_equal 25, parsed["users"][1]["details"]["age"]
          assert_equal "LA", parsed["users"][1]["details"]["city"]
          assert_equal true, parsed["settings"]["debug"]
          assert_equal 5000, parsed["settings"]["timeout"]
        end

        test "convert_to_yaml with invalid input raises InvalidFormatError" do
          invalid_input = "this is neither JSON nor YAML: {invalid"

          assert_raises(YamlJsonConverter::InvalidFormatError) do
            YamlJsonConverter.convert_to_yaml(invalid_input)
          end
        end

        test "detect_format identifies JSON correctly" do
          json_input = '{"name": "test", "age": 30}'

          result = YamlJsonConverter.detect_format(json_input)

          assert_equal :json, result
        end

        test "detect_format identifies YAML correctly" do
          yaml_input = "name: test\nage: 30"

          result = YamlJsonConverter.detect_format(yaml_input)

          assert_equal :yaml, result
        end

        test "detect_format returns unknown for invalid input" do
          invalid_input = "this is neither JSON nor YAML: {invalid"

          result = YamlJsonConverter.detect_format(invalid_input)

          assert_equal :unknown, result
        end

        test "detect_format identifies empty JSON object" do
          json_input = "{}"

          result = YamlJsonConverter.detect_format(json_input)

          assert_equal :json, result
        end

        test "detect_format identifies empty JSON array" do
          json_input = "[]"

          result = YamlJsonConverter.detect_format(json_input)

          assert_equal :json, result
        end

        test "detect_format identifies empty YAML document" do
          yaml_input = "---"

          result = YamlJsonConverter.detect_format(yaml_input)

          assert_equal :yaml, result
        end

        test "convert_to_json handles arrays in JSON" do
          json_input = '["item1", "item2", "item3"]'
          expected = "[\n  \"item1\",\n  \"item2\",\n  \"item3\"\n]"

          result = YamlJsonConverter.convert_to_json(json_input)

          assert_equal expected, result
        end

        test "convert_to_json handles arrays in YAML" do
          yaml_input = "- item1\n- item2\n- item3"

          result = YamlJsonConverter.convert_to_json(yaml_input)
          parsed = JSON.parse(result)

          assert_equal ["item1", "item2", "item3"], parsed
        end

        test "convert_to_yaml handles arrays in JSON" do
          json_input = '["item1", "item2", "item3"]'

          result = YamlJsonConverter.convert_to_yaml(json_input)
          parsed = YAML.safe_load(result)

          assert_equal ["item1", "item2", "item3"], parsed
        end

        test "convert_to_yaml handles arrays in YAML" do
          yaml_input = "- item1\n- item2\n- item3"

          result = YamlJsonConverter.convert_to_yaml(yaml_input)
          parsed = YAML.safe_load(result)

          assert_equal ["item1", "item2", "item3"], parsed
        end

        test "convert_to_json handles null values in JSON" do
          json_input = '{"name": null, "age": 30}'

          result = YamlJsonConverter.convert_to_json(json_input)
          parsed = JSON.parse(result)

          assert_nil parsed["name"]
          assert_equal 30, parsed["age"]
        end

        test "convert_to_json handles null values in YAML" do
          yaml_input = "name: null\nage: 30"

          result = YamlJsonConverter.convert_to_json(yaml_input)
          parsed = JSON.parse(result)

          assert_nil parsed["name"]
          assert_equal 30, parsed["age"]
        end

        test "convert_to_yaml handles null values in JSON" do
          json_input = '{"name": null, "age": 30}'

          result = YamlJsonConverter.convert_to_yaml(json_input)
          parsed = YAML.safe_load(result)

          assert_nil parsed["name"]
          assert_equal 30, parsed["age"]
        end

        test "convert_to_yaml handles null values in YAML" do
          yaml_input = "name: null\nage: 30"

          result = YamlJsonConverter.convert_to_yaml(yaml_input)
          parsed = YAML.safe_load(result)

          assert_nil parsed["name"]
          assert_equal 30, parsed["age"]
        end

        test "convert_to_json handles boolean values correctly" do
          yaml_input = "enabled: true\ndisabled: false"

          result = YamlJsonConverter.convert_to_json(yaml_input)
          parsed = JSON.parse(result)

          assert_equal true, parsed["enabled"]
          assert_equal false, parsed["disabled"]
        end

        test "convert_to_yaml handles boolean values correctly" do
          json_input = '{"enabled": true, "disabled": false}'

          result = YamlJsonConverter.convert_to_yaml(json_input)
          parsed = YAML.safe_load(result)

          assert_equal true, parsed["enabled"]
          assert_equal false, parsed["disabled"]
        end

        test "convert_to_json handles numeric values correctly" do
          yaml_input = "integer: 42\nfloat: 3.14\nnegative: -10"

          result = YamlJsonConverter.convert_to_json(yaml_input)
          parsed = JSON.parse(result)

          assert_equal 42, parsed["integer"]
          assert_equal 3.14, parsed["float"]
          assert_equal(-10, parsed["negative"])
        end

        test "convert_to_yaml handles numeric values correctly" do
          json_input = '{"integer": 42, "float": 3.14, "negative": -10}'

          result = YamlJsonConverter.convert_to_yaml(json_input)
          parsed = YAML.safe_load(result)

          assert_equal 42, parsed["integer"]
          assert_equal 3.14, parsed["float"]
          assert_equal(-10, parsed["negative"])
        end

        test "json? private method returns true for valid JSON" do
          valid_json = '{"test": "value"}'

          result = YamlJsonConverter.send(:json?, valid_json)

          assert result
        end

        test "json? private method returns false for invalid JSON" do
          invalid_json = '{"test": value}'

          result = YamlJsonConverter.send(:json?, invalid_json)

          assert_not result
        end

        test "yaml? private method returns true for valid YAML" do
          valid_yaml = "test: value"

          result = YamlJsonConverter.send(:yaml?, valid_yaml)

          assert result
        end

        test "yaml? private method returns false for invalid YAML" do
          invalid_yaml = "[\ninvalid yaml syntax"

          result = YamlJsonConverter.send(:yaml?, invalid_yaml)

          assert_not result
        end

        test "handles whitespace in input correctly" do
          json_with_whitespace = '  {"name": "test"}  '
          yaml_with_whitespace = "  name: test  "

          json_result = YamlJsonConverter.convert_to_json(json_with_whitespace)
          yaml_result = YamlJsonConverter.convert_to_yaml(yaml_with_whitespace)

          assert JSON.parse(json_result)["name"] == "test"
          assert YAML.safe_load(yaml_result)["name"] == "test"
        end
      end
    end
  end
end
