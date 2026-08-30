module StepUpAuthentication
  extend ActiveSupport::Concern

  private
    def issue_step_up_challenge!(purpose)
      challenge, code = StepUpChallenge.issue_for!(Current.user, purpose)
      LoginOtpMailer.with(user: Current.user, code: code).verification_code.deliver_later
      challenge
    end

    def verify_step_up_challenge(challenge_token, code, purpose)
      challenge = StepUpChallenge.find_signed(challenge_token, purpose: :step_up_challenge)
      return :invalid_challenge unless challenge&.user == Current.user && challenge.purpose == purpose

      if Current.user.verify_totp(code)
        challenge.update!(consumed_at: Time.current)
        return challenge.grant_token
      end

      result = challenge.verify(code)
      result == :verified ? challenge.grant_token : result
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      :invalid_challenge
    end

    def valid_step_up_grant?(token, purpose)
      StepUpGrant.consume(token, Current.user, purpose)
    end

    def require_step_up!(purpose)
      return true if valid_step_up_grant?(request.headers["X-Step-Up-Token"] || params[:step_up_token], purpose)

      render_api_error("STEP_UP_REQUIRED", status: :unauthorized, details: { purpose: purpose })
      false
    end
end
