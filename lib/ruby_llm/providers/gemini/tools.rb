# frozen_string_literal: true

module RubyLLM
  module Providers
    module Gemini
      # Tools methods for the Gemini API implementation
      module Tools
        # Format tools for Gemini API
        def format_tools(tools)
          return [] if tools.empty?

          [{
            functionDeclarations: tools.values.map { |tool| function_declaration_for(tool) }
          }]
        end

        # Extract tool calls from response data
        def extract_tool_calls(data)
          return nil unless data

          # Get the first candidate
          candidate = data.is_a?(Hash) ? data.dig('candidates', 0) : nil
          return nil unless candidate

          # Get the parts array from content
          parts = candidate.dig('content', 'parts')
          return nil unless parts.is_a?(Array)

          # Find the function call part
          function_call_part = parts.find { |p| p['functionCall'] }
          return nil unless function_call_part

          # Get the function call data
          function_data = function_call_part['functionCall']
          return nil unless function_data

          # Create a unique ID for the tool call
          id = SecureRandom.uuid

          # Return the tool call in the expected format
          {
            id => ToolCall.new(
              id: id,
              name: function_data['name'],
              arguments: function_data['args']
            )
          }
        end

        private

        # Format a single tool for Gemini API
        def function_declaration_for(tool)
          {
            name: tool.name,
            description: tool.description,
            parameters: tool.parameters.any? ? format_parameters(tool.parameters) : nil
          }.compact
        end

        def format_parameter(param)
          formatted_param = {
            type: param_type_for_gemini(param.type),
            description: param.description,                
          }
          if param.type.to_s == 'array' && param.items && param.items['type']            
            formatted_param[:items] = {
              type: param_type_for_gemini(param.items['type']),
              # description: param.items.description
            }
          elsif param.type.to_s == 'object' && param.properties
            formatted_param[:properties] = param.properties.transform_values do |param|
              format_parameter(param)
            end
          end
          formatted_param.compact
        end

        # Format tool parameters for Gemini API
        def format_parameters(parameters)
          {
            type: 'OBJECT',
            properties: parameters.transform_values do |param|
              format_parameter(param)
            end,
            required: parameters.select { |_, p| p.required }.keys.map(&:to_s)
          }
        end        

        # Convert RubyLLM param types to Gemini API types
        def param_type_for_gemini(type)
          case type.to_s.downcase
          when 'integer', 'number', 'float' then 'NUMBER'
          when 'boolean' then 'BOOLEAN'
          when 'array' then 'ARRAY'
          when 'object' then 'OBJECT'
          else 'STRING'
          end
        end
      end
    end
  end
end
