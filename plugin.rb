# name: omniauth-atb-discourse
# about: Plugin for Discourse to allow OAuth via ActiveTextbook
# version: 0.0.1
# authors: Catherine Mackenzie

require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class ActiveTextbook < OmniAuth::Strategies::OAuth2
      option :name, :atb
      option :client_options, {
        site: '',
        authorize_url: '/oauth/authorize',
        token_url: '/oauth/token'                        
      }

      uid { raw_info['id'] }

      info do
        {
          email: raw_info['email'],
          first_name: raw_info['first_name'],
          last_name: raw_info['last_name'],
          student: raw_info['student']
        }
      end

      def raw_info
        @raw_info ||= access_token.get('/me').parsed
      end
    end
  end
end
