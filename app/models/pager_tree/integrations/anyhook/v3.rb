require "timeout"

module PagerTree::Integrations
  class AnyHook::V1 < Integration
    OPTIONS = [
      {key: :token, type: :string, default: nil},
      {key: :capture_additional_data, type: :boolean, default: false},
      {key: :title_mapping, type: :string, default: "title"},
      {key: :description_mapping, type: :string, default: "description"},
      {key: :urgency_mapping, type: :string, default: "urgency"},
      {key: :tags_mapping, type: :string, default: "tags"},
      {key: :incident_mapping, type: :string, default: "meta.incident"},
      {key: :incident_severity_mapping, type: :string, default: "meta.incident_severity"},
      {key: :incident_message_mapping, type: :string, default: "meta.incident_message"},
      {key: :dedup_keys_mapping, type: :string, default: "dedup_keys"},
      {key: :thirdparty_id_mapping, type: :string, default: "id"},
      {key: :action_mappings, type: :string, default: "[]"}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    after_initialize do
      self.option_token ||= nil
      self.option_capture_additional_data ||= false
      self.option_title_mapping ||= "title"
      self.option_description_mapping ||= "description"
      self.option_urgency_mapping ||= "urgency"
      self.option_tags_mapping ||= "tags"
      self.option_incident_mapping ||= "meta.incident"
      self.option_incident_severity_mapping ||= "meta.incident_severity"
      self.option_incident_message_mapping ||= "meta.incident_message"
      self.option_dedup_keys_mapping ||= "dedup_keys"
      self.option_thirdparty_id_mapping ||= "id"
      self.option_action_mappings ||= "[]"
    end

    def adapter_should_block_incoming?(request)
      self.option_token.present? && (request.headers["pagertree-token"] != self.option_token)
    end

    def adapter_supports_incoming?
      true
    end

    def adapter_supports_outgoing?
      false
    end

    def adapter_incoming_can_defer?
      true
    end

    def adapter_thirdparty_id
      @adapter_thirdparty_id ||= _dig_mapping(option_thirdparty_id_mapping) || SecureRandom.uuid
    end

    # Determines the action (create, acknowledge, resolve, other) based on action_mappings.
    # Example action_mappings JSON:
    # [
    #   {
    #     "action": "create",
    #     "conditions": [
    #       {
    #         "logical_operator": "OR",
    #         "conditions": [
    #           {
    #             "logical_operator": "AND",
    #             "conditions": [
    #               {"key": "data.severity", "value": 5, "operator": "=="},
    #               {"key": "message", "value": "outage", "operator": "contains"}
    #             ]
    #           },
    #           {"key": "status", "value": "critical", "operator": "=="}
    #         ]
    #       }
    #     ]
    #   },
    #   {
    #     "action": "resolve",
    #     "conditions": [
    #       {"key": "status", "value": "resolved", "operator": "starts_with"}
    #     ]
    #   }
    # ]
    # Returns the first matching action or falls back to event_type.
    def adapter_action
      action_mappings = JSON.parse(option_action_mappings) rescue []

      action_mappings.each do |entry|
        next unless entry.is_a?(Hash)
        action = entry["action"]
        conditions = Array(entry["conditions"])
        next unless action && conditions.any?

        return action.to_sym if evaluate_conditions(conditions, depth: 0)
      end

      # Fallback to original event_type logic
      case _adapter_incoming_request_params.dig("event_type")&.to_s&.downcase&.strip
      when "create"
        :create
      when "acknowledge"
        :acknowledge
      when "resolve"
        :resolve
      else
        :other
      end
    end

    private

    # Evaluates a conditions array, supporting nested AND/OR logic.
    # Example conditions:
    # [
    #   {
    #     "logical_operator": "OR",
    #     "conditions": [
    #       {
    #         "logical_operator": "AND",
    #         "conditions": [
    #           {"key": "data.severity", "value": 5, "operator": "=="},
    #           {"key": "message", "value": "outage", "operator": "contains"}
    #         ]
    #       },
    #       {"key": "status", "value": "critical", "operator": "=="}
    #     ]
    #   }
    # ]
    # Returns true if the conditions evaluate to true, false otherwise.
    def evaluate_conditions(conditions, depth: 0)
      # Limit recursion depth to prevent stack overflow
      return false if depth > 10

      # If conditions is a flat array of condition hashes, treat as AND
      if conditions.all? { |c| c.is_a?(Hash) && c.key?("key") && c.key?("value") }
        return conditions.all? { |condition| evaluate_condition(condition) }
      end

      # Otherwise, expect a single group with logical_operator and conditions
      group = conditions.first
      return false unless group.is_a?(Hash) && group["logical_operator"] && group["conditions"]

      logical_operator = group["logical_operator"].upcase
      sub_conditions = Array(group["conditions"])
      return false unless sub_conditions.any? && %w[AND OR].include?(logical_operator)

      case logical_operator
      when "AND"
        sub_conditions.all? { |c| evaluate_conditions([c], depth: depth + 1) }
      when "OR"
        sub_conditions.any? { |c| evaluate_conditions([c], depth: depth + 1) }
      else
        false
      end
    end

    # Evaluates a single condition hash.
    # Example condition:
    # {"key": "data.severity", "value": 5, "operator": "=="}
    # Supported operators: ==, !=, <, >, <=, >=, contains, not_contains, containsi,
    # in, not_in, is_null, not_null, true, false, starts_with, ends_with, empty, not_empty, regex
    # Returns true if the condition is met, false otherwise.
    def evaluate_condition(condition)
      key = condition["key"]
      value = condition["value"]
      operator = condition["operator"] || "=="
      return false unless key && value

      actual_value = _dig_mapping(key)
      return false unless actual_value

      # Limit input length to prevent excessive processing
      actual_value = actual_value.to_s[0..1000] # Cap at 1000 characters

      case operator
      when "=="
        actual_value == value.to_s
      when "!="
        actual_value != value.to_s
      when "<"
        actual_value.to_f < value.to_f
      when ">"
        actual_value.to_f > value.to_f
      when "<="
        actual_value.to_f <= value.to_f
      when ">="
        actual_value.to_f >= value.to_f
      when "contains"
        actual_value.include?(value.to_s)
      when "not_contains"
        !actual_value.include?(value.to_s)
      when "containsi"
        actual_value.downcase.include?(value.to_s.downcase)
      when "in"
        Array(JSON.parse(value.to_s) rescue []).include?(actual_value.to_s)
      when "not_in"
        !Array(JSON.parse(value.to_s) rescue []).include?(actual_value.to_s)
      when "is_null"
        actual_value.nil?
      when "not_null"
        !actual_value.nil?
      when "true"
        actual_value == true || actual_value.to_s.downcase == "true" || actual_value.to_s == "1"
      when "false"
        actual_value == false || actual_value.to_s.downcase == "false" || actual_value.to_s == "0"
      when "starts_with"
        actual_value.start_with?(value.to_s)
      when "ends_with"
        actual_value.end_with?(value.to_s)
      when "empty"
        actual_value.to_s.empty? || (actual_value.is_a?(Array) && actual_value.empty?)
      when "not_empty"
        !actual_value.to_s.empty? || (actual_value.is_a?(Array) && !actual_value.empty?)
      else
        false
      end
    end

    # Resolves a mapping to a value from the incoming request params.
    # Supports simple JSON paths (e.g., "data.title") or templates with placeholders
    # (e.g., "#{.data.title} - abc123 #{.meta.other_value}").
    # Example mappings:
    # title_mapping: "#{.data.title} - abc123 #{.meta.other_value}"
    # description_mapping: "#{.data.description} (ID: #{.id})"
    # For a payload: {"data": {"title": "Server Down", "description": "Outage"}, "meta": {"other_value": "urgent"}, "id": "12345"}
    # Returns: "Server Down - abc123 urgent" for title_mapping
    # Missing fields resolve to empty strings. Limits placeholders to 10 for performance.
    def _dig_mapping(mapping)
      return nil if mapping.blank?

      # Check if mapping is a template with placeholders (e.g., "#{.path.to.field}")
      if mapping.match?(/\#\{[^\}]+\}/)
        # Limit number of placeholders to prevent excessive processing
        placeholders = mapping.scan(/\#\{([^\}]+)\}/).flatten
        return nil if placeholders.size > 10 # Arbitrary limit to prevent abuse

        result = mapping.dup
        placeholders.each do |path|
          keys = path.sub(/^\./, "").split(".") # Remove leading . if present
          value = _adapter_incoming_request_params.dig(*keys) || "" # Fallback to empty string
          result.gsub!("\#{#{path}}", value.to_s)
        end
        result
      else
        # Existing behavior for simple JSON paths
        keys = mapping.split(".")
        _adapter_incoming_request_params.dig(*keys)
      end
    end

    # Resolves the title using title_mapping.
    # Example: title_mapping: "#{.data.title} - #{.meta.other_value}"
    # For payload: {"data": {"title": "Server Down"}, "meta": {"other_value": "urgent"}}
    # Returns: "Server Down - urgent"
    def _title
      _dig_mapping(option_title_mapping)
    end

    # Resolves the description using description_mapping.
    # Example: description_mapping: "#{.data.description} (ID: #{.id})"
    # For payload: {"data": {"description": "Outage"}, "id": "12345"}
    # Returns: "Outage (ID: 12345)"
    def _description
      _dig_mapping(option_description_mapping)
    end

    # Resolves tags using tags_mapping.
    # Example: tags_mapping: "data.tags"
    # For payload: {"data": {"tags": ["tag1", "tag2"]}}
    # Returns: ["tag1", "tag2"]
    def _tags
      tags = _dig_mapping(option_tags_mapping)
      Array(tags).compact_blank.map(&:to_s).uniq
    end

    # Resolves urgency using urgency_mapping, expecting low|medium|high|critical.
    # Example: urgency_mapping: "data.urgency"
    # For payload: {"data": {"urgency": "high"}}
    # Returns: "high"
    def _urgency
      text = _dig_mapping(option_urgency_mapping)
      return nil unless text
      matches = /(?<urgency>low|medium|high|critical)/.match(text.to_s.downcase.strip)
      matches ? matches[:urgency].to_s : nil
    end

    # Resolves incident flag using incident_mapping.
    # Example: incident_mapping: "meta.incident"
    # For payload: {"meta": {"incident": true}}
    # Returns: true
    def _incident
      !!_dig_mapping(option_incident_mapping)
    end

    # Resolves incident message using incident_message_mapping.
    # Example: incident_message_mapping: "#{.data.message} - #{.meta.source}"
    # For payload: {"data": {"message": "Outage"}, "meta": {"source": "system"}}
    # Returns: "Outage - system"
    def _incident_message
      _dig_mapping(option_incident_message_mapping)
    end

    # Resolves incident severity using incident_severity_mapping.
    # Example: incident_severity_mapping: "meta.incident_severity"
    # For payload: {"meta": {"incident_severity": "critical"}}
    # Returns: "CRITICAL"
    def _incident_severity
      _dig_mapping(option_incident_severity_mapping)&.to_s&.upcase&.strip
    end

    # Resolves meta data, excluding incident-related keys.
    # Example: for incident_mapping: "meta.incident", meta: {"incident": true, "other": "value"}
    # Returns: {"other": "value"}
    def _meta
      meta_key = option_incident_mapping.match?(/\#\{/) ? "meta" : option_incident_mapping.split(".")[0]
      meta = _dig_mapping(meta_key)
      return {} unless meta.is_a?(Hash)
      meta.except(
        option_incident_mapping.split(".")[-1],
        option_incident_severity_mapping.split(".")[-1],
        option_incident_message_mapping.split(".")[-1]
      )
    end

    # Collects additional data if capture_additional_data is true.
    # Excludes mapped fields and reserved keys.
    def _additional_datums
      if self.option_capture_additional_data == true
        _adapter_incoming_request_params.except(
          *[
            option_thirdparty_id_mapping,
            option_title_mapping,
            option_description_mapping,
            option_urgency_mapping,
            option_tags_mapping,
            option_incident_mapping.split(".")[0], # meta
            option_dedup_keys_mapping,
            "event_type",
            "pagertree_integration_id"
          ].map { |m| m.split(".") }.flatten.uniq
        ).map do |key, value|
          AdditionalDatum.new(format: "text", label: key, value: value.to_s)
        end
      else
        []
      end
    end

    # Resolves dedup keys using dedup_keys_mapping.
    # Example: dedup_keys_mapping: "data.dedup_keys"
    # For payload: {"data": {"dedup_keys": ["key1", "key2"]}}
    # Returns: ["key1", "key2"]
    def _dedup_keys
      Array(_dig_mapping(option_dedup_keys_mapping)).map(&:to_s).compact_blank.uniq
    end

    # Normalizes incoming request params by downcasing keys.
    def _adapter_incoming_request_params
      adapter_incoming_request_params.transform_keys(&:downcase)
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        description: _description,
        urgency: _urgency,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: _dedup_keys,
        incident: _incident,
        incident_severity: _incident_severity,
        incident_message: _incident_message,
        tags: _tags,
        meta: _meta,
        additional_data: _additional_datums
      )
    end
  end
end