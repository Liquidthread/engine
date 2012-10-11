module Locomotive
  module ActionController
    module AgeGate

      extend ActiveSupport::Concern

      included do
        before_filter :verify_age
      end

      module ClassMethods
        def bypass_urls
          @bypass_urls || []
        end
        def bypass_age_gate(*args)
          @bypass_urls = args
        end
      end

      def verify_age
        unless bypass? || verified?
          session[:original_request] = request.fullpath
          redirect_to LPAPath
        else
          check_verification
        end
      end

      protected

      LPAPath             = "/lpa"
      BotAgentMatcher     = /alexa|bot|crawl(er|ing)|facebookexternalhit|feedburner|google web preview|nagios|postrank|pingdom|slurp|spider|yahoo!|yandex/
      VerificationAge     = 21
      DaysPerYear         = 365
      UnderageRedirectURL = "http://www.centurycouncil.org/landing"
      BypassParam         = :bypass_lpa
      ProtectedController = "locomotive/public/pages"

      def check_verification
        if !params[:lpa].nil?
          day, month, year, remember = params[:lpa].values_at(:day, :month, :year, :remember)
          redirect_to LPAPath && return if day.nil? || month.nil? || year.nil?

          supplied_age_in_days = Date.today - Date.parse("#{day}/#{month}/#{year}")

          if supplied_age_in_days >= VerificationAge * DaysPerYear
            session[:verified_at]             = Time.now
            session[:age_verified]            = true
            if remember
              session[:verification_duration] = 1.week
            else
              session[:verification_duration] = 1.hour
            end
            redirect_url                      = session[:original_request] || "/"
            session[:original_request]        = nil
            redirect_to redirect_url
          else
            redirect_to UnderageRedirectURL
          end
        end
      end

      def bypass?
        agent_is_bot?             ||
        !controller_protected?    ||
        !params[BypassParam].nil? ||
        ApplicationController.bypass_urls.include?(path.split("/").first)
      end

      def verified?
        session[:age_verified] && !verification_expired?
      end

      def verification_expired?
        !session[:verification_duration].nil? &&
        !session[:verified_at].nil?           &&
        session[:verification_duration] < Time.now - session[:verified_at]
      end

      def agent_is_bot?
        agent.downcase =~ BotAgentMatcher
      end

      def controller_protected?
        params[:controller] == ProtectedController && "/#{path}" != LPAPath
      end

      def path
        params[:path] || ''
      end

      def agent
        request.env["HTTP_USER_AGENT"] || ''
      end

    end
  end
end
