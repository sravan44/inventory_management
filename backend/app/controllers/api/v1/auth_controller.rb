# frozen_string_literal: true

module Api
  module V1
    # Global (apex-host) auth endpoints. NOT tenant-scoped: a user may belong to
    # zero or many tenants, so login/registration precede any tenant context.
    class AuthController < BaseController
      before_action :authenticate_user!, only: :logout_all

      # POST /api/v1/auth/register — create a user and auto-login (return a pair).
      def register
        user = Identity::User.new(register_params)

        if user.save
          render json: token_payload(Identity::AuthenticationService.issue_for(user)),
                 status: :created
        else
          render_error(:unprocessable_entity, "validation_failed",
                       "Registration failed.", details: errors_from(user))
        end
      end

      # POST /api/v1/auth/login
      def login
        result = Identity::AuthenticationService.authenticate(
          email: login_params[:email],
          password: login_params[:password]
        )
        render json: token_payload(result), status: :ok
      rescue Identity::AuthenticationService::InvalidCredentials
        render_error(:unauthorized, "invalid_credentials", "Invalid email or password.")
      end

      # POST /api/v1/auth/refresh
      def refresh
        result = Identity::AuthenticationService.refresh(refresh_token_param)
        render json: token_payload(result), status: :ok
      rescue Identity::AuthenticationService::InvalidRefreshToken
        render_error(:unauthorized, "invalid_refresh_token", "Refresh token is invalid or expired.")
      end

      # POST /api/v1/auth/logout — revoke this refresh token (idempotent).
      def logout
        Identity::AuthenticationService.revoke(refresh_token_param)
        head :no_content
      end

      # POST /api/v1/auth/logout_all — revoke every refresh token for the user.
      def logout_all
        Identity::AuthenticationService.revoke_all(current_user)
        head :no_content
      end

      private

      def register_params
        params.require(:user).permit(:email, :password, :first_name, :last_name)
      end

      def login_params
        params.permit(:email, :password)
      end

      def refresh_token_param
        params.permit(:refresh_token)[:refresh_token]
      end

      def token_payload(result)
        {
          access_token: result.access_token,
          token_type: "Bearer",
          expires_in: Identity::JwtCodec::DEFAULT_TTL.to_i,
          refresh_token: result.refresh_token,
          user: user_json(result.user),
          memberships: memberships_json(result.user)
        }
      end
    end
  end
end
