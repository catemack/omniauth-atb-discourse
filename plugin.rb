# name: omniauth-atb-discourse
# about: Plugin for Discourse to allow OAuth via ActiveTextbook
# version: 0.0.1
# authors: Catherine Mackenzie

enabled_site_setting :atb_oauth_enabled

require 'omniauth-oauth2'

class AtbAuthenticator < ::Auth::Authenticator
  def name
    'atb'
  end

  def enabled?
    SiteSetting.atb_oauth_enabled
  end

  def after_authenticate(auth_token)
    result = Auth::Result.new

    data = auth_token[:info]
    result.name = name = data[:name]
    result.email = email = data[:email]
    result.email_valid = result.email.present?
    atb_uid = auth_token[:id]

    current_info = ::PluginStore.get('atb', "atb_uid_#{atb_uid}")

    if current_info.present?
      result.user = User.find(current_info[:user_id])
    else
      result.user = User.find_by_email(result.email)
      
      if result.user.present? && atb_uid.present?
        ::PluginStore.set('atb', "atb_uid_#{data[:id]}", {user_id: user.id})
      end
    end

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
    omniauth.provider :active_textbook,
      name: 'atb',
      setup: lambda { |env|
        strategy = env["omniauth.strategy"]
        strategy.options[:client_id] = SiteSetting.atb_oauth_id
        strategy.options[:client_secret] = SiteSetting.atb_oauth_secret
        strategy.options[:client_options] = {
          site: SiteSetting.atb_site,
          authorize_url: "#{SiteSetting.atb_site}/oauth/authorize",
          token_url: "#{SiteSetting.atb_site}/oauth/token"
        }
      }
  end
end

class OmniAuth::Strategies::ActiveTextbook < OmniAuth::Strategies::OAuth2
  option :name, :atb

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

auth_provider title: 'Sign in with ActiveTextbook',
  message: 'Log in with your ActiveTextbook account.',
  frame_width: 920,
  frame_height: 800,
  authenticator: AtbAuthenticator.new
