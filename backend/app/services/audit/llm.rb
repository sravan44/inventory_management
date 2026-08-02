# frozen_string_literal: true

module Audit
  # Translates a natural-language request into a CONSTRAINED filter hash (ADR-0016).
  # Gated on OPENAI_API_KEY; returns nil when unavailable (callers fall back to
  # keyword search). The LLM only ever produces the small JSON shape below — never
  # raw queries — and callers still sanitize it (Audit::LogSearch), so a prompt
  # can't inject a query.
  module Llm
    SYSTEM_PROMPT = <<~PROMPT
      Translate the user's request about audit logs into a JSON object with ONLY
      these optional keys:
        action_contains : string (a keyword to match the action/message)
        actor_type      : "Identity::User" or "Identity::ApiKey"
        date_from       : "YYYY-MM-DD"
        date_to         : "YYYY-MM-DD"
      Omit any key you cannot infer. Respond with JSON only, no prose.
    PROMPT

    def self.translate(text)
      return nil if client.nil?

      client.translate(text)
    rescue StandardError => e
      Rails.logger.warn("[Audit::Llm] #{e.class}: #{e.message}")
      nil
    end

    def self.client
      return @client if defined?(@client)

      @client = ENV["OPENAI_API_KEY"].present? ? OpenAiClient.new(ENV["OPENAI_API_KEY"]) : nil
    end

    class OpenAiClient
      MODEL = ENV.fetch("OPENAI_MODEL", "gpt-4o-mini")

      def initialize(api_key)
        @client = OpenAI::Client.new(access_token: api_key)
      end

      def translate(text)
        response = @client.chat(parameters: {
          model: MODEL,
          response_format: { type: "json_object" },
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            { role: "user", content: text.to_s }
          ]
        })
        JSON.parse(response.dig("choices", 0, "message", "content"))
      end
    end
  end
end
