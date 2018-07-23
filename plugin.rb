# name: omniauth-atb-discourse
# about: Plugin for Discourse to allow OAuth via ActiveTextbook
# version: 0.0.1
# authors: Catherine Mackenzie

require 'omniauth-oauth2'

class AtbAuthenticator < ::Auth::Authenticator
  def name
    'atb'
  end

  def after_authenticate(auth_token)
    result = Auth::Result.new

    data = auth_token[:info]
    result.name = name = data[:name]
    result.email = email = data[:email]
    atb_uid = auth_token[:id]

    current_info = ::PluginStore.get('atb', "atb_uid_#{atb_uid}")

    result.user = User.find(current_info[:user_id]) if current_info.present?

    result.extra_data = {
      id: atb_uid,
      is_student: data[:is_student]
    }

    result
  end

  def after_create_account(user, auth)
    data = auth[:extra_data]
    user.grant_admin! if data[:is_student].present? && !data[:is_student]
    ::PluginStore.set('atb', "atb_uid_#{data[:id]}", {user_id: user.id})
  end

  def register_middleware(omniauth)
    omniauth.provider :atb,
      SiteSetting.login.atb_oauth_id,
      SiteSetting.login.atb_oauth_secret
  end
end

module OmniAuth
  module Strategies
    class ActiveTextbook < OmniAuth::Strategies::OAuth2
      option :name, :atb
      option :client_options, {
        site: SiteSetting.login.atb_site,
        authorize_path: '/oauth/authorize',
        token_path: '/oauth/token'                        
      }

      uid { raw_info['id'] }

      info do
        {
          email: raw_info['email'],
          name: raw_info['first_name'],
          is_student: raw_info['is_student']
        }
      end

      def raw_info
        @raw_info ||= access_token.get('/me').parsed
      end
    end
  end
end
