require 'roda'
require 'ims/lti'
require 'seconds'
require 'concurrent'

class LTI < Roda
  plugin :halt
  plugin :middleware

  # track oauth nonce to prevent replay attacks
  nonces = Concurrent::Map.new

  Concurrent::TimerTask.new(execution_interval: 1.minutes) do 
    nonces.each_pair do |nonce,time|
      nonces.delete nonce if time < 2.minutes.ago
    end
  end.execute

  route do |r|
    r.on 'lti', method: 'post' do
      unless r.POST['lti_message_type'] == 'basic-lti-launch-request'
        r.halt 400, 'Bad lti_message_type.' 
      end

      launch_url = URI::HTTPS.build(host: env['HTTP_HOST'], path: r.path)
      
      launch_auth = IMS::LTI::Services::MessageAuthenticator.new(
        launch_url, r.POST, ENV['LTI_SECRET']
      )

      unless launch_auth.valid_signature?
        r.halt 401, "Invalid LTI signature"
      end

      if Time.now.getutc.to_i - r.POST['oauth_timestamp'].to_i > 1.minute
        r.halt 401, "LTI signature is too old to verify."
      end

      if nonces[r.POST['oauth_nonce']]
        r.halt 401, "Cannot reuse nonce in LTI signature."
      else 
        nonces.put_if_absent r.POST['oauth_nonce'], Time.now
      end

      email = r.POST['lis_person_contact_email_primary']

      # their primary email address *must* be a westpoint.edu  
      if email.nil? or not email.ends_with? '@westpoint.edu'
        r.halt 401, "Your primary email address in Canvas must end with <b>westpoint.edu</b>"
      end
      
      # this hackery tell Roda to call the next app in the middleware stack
      throw :next, true
    end    
  end
end