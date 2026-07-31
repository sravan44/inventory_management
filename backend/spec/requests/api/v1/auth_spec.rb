require "swagger_helper"

# rswag DSL: these examples run as real request tests (run_test! issues the HTTP
# call and asserts the declared status) AND are the source for the OpenAPI doc
# (`rake rswag:specs:swaggerize`). One spec, three jobs: test + docs + Postman.
RSpec.describe "Auth", type: :request do
  path "/api/v1/auth/register" do
    post "Register a new user (auto-login)" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, example: "sam@acme.io" },
              password: { type: :string, example: "hunter2pw" },
              first_name: { type: :string, example: "Sam" },
              last_name: { type: :string, example: "Rivera" }
            },
            required: %w[email password]
          }
        },
        required: %w[user]
      }

      response "201", "user created; returns token pair + user + memberships" do
        let(:payload) { { user: { email: "sam@acme.io", password: "hunter2pw", first_name: "Sam" } } }
        run_test!
      end

      response "422", "validation failed" do
        let(:payload) { { user: { email: "bad", password: "x" } } }
        run_test!
      end

      response "400", "user param missing" do
        let(:payload) { { email: "sam@acme.io" } }
        run_test!
      end
    end
  end

  path "/api/v1/auth/login" do
    post "Log in" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, example: "sam@acme.io" },
          password: { type: :string, example: "hunter2pw" }
        },
        required: %w[email password]
      }

      response "200", "token pair + user + memberships" do
        before { Identity::User.create!(email: "sam@acme.io", password: "hunter2pw") }
        let(:payload) { { email: "sam@acme.io", password: "hunter2pw" } }
        run_test!
      end

      response "401", "invalid credentials" do
        let(:payload) { { email: "sam@acme.io", password: "nope" } }
        run_test!
      end
    end
  end

  path "/api/v1/auth/refresh" do
    post "Rotate tokens with a refresh token" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: { refresh_token: { type: :string } },
        required: %w[refresh_token]
      }

      response "200", "new token pair" do
        let(:payload) do
          user = Identity::User.create!(email: "sam@acme.io", password: "hunter2pw")
          _record, raw = Identity::RefreshToken.issue(user)
          { refresh_token: raw }
        end
        run_test!
      end

      response "401", "invalid or expired refresh token" do
        let(:payload) { { refresh_token: "nope" } }
        run_test!
      end
    end
  end

  path "/api/v1/auth/logout" do
    post "Log out (revoke one refresh token)" do
      tags "Auth"
      consumes "application/json"
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: { refresh_token: { type: :string } },
        required: %w[refresh_token]
      }

      response "204", "revoked (idempotent)" do
        let(:payload) do
          user = Identity::User.create!(email: "sam@acme.io", password: "hunter2pw")
          _record, raw = Identity::RefreshToken.issue(user)
          { refresh_token: raw }
        end
        run_test!
      end
    end
  end

  path "/api/v1/auth/logout_all" do
    post "Log out everywhere (revoke all refresh tokens)" do
      tags "Auth"
      security [ { bearer_auth: [] } ]

      response "204", "all sessions revoked" do
        let(:user) { Identity::User.create!(email: "sam@acme.io", password: "hunter2pw") }
        let(:Authorization) { "Bearer #{Identity::JwtCodec.encode({ sub: user.id.to_s })}" }
        run_test!
      end

      response "401", "missing/invalid token" do
        let(:Authorization) { "Bearer not.a.jwt" }
        run_test!
      end
    end
  end

  path "/api/v1/me" do
    get "Current user + memberships" do
      tags "Identity"
      produces "application/json"
      security [ { bearer_auth: [] } ]

      response "200", "the current user and their memberships" do
        let(:user) { Identity::User.create!(email: "sam@acme.io", password: "hunter2pw") }
        let(:Authorization) { "Bearer #{Identity::JwtCodec.encode({ sub: user.id.to_s })}" }
        run_test!
      end

      response "401", "missing/invalid token" do
        let(:Authorization) { "Bearer not.a.jwt" }
        run_test!
      end
    end
  end
end
