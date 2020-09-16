require 'roda'
require 'json'

# let's you view and edit your session hash
class SessionDebugger < Roda
  plugin :flash
  plugin :middleware
  plugin :named_templates

  template :form, engine: 'slim' do
    <<~TEMPLATE
    h3 Session Editor
    - if flash = session.delete("_flash")
      font color='red'
        b =flash['message']
      br
      br
    - else
      p If you don't know what to do, then I don't understand how you ended up here. 
    form method='post'
      textarea name='session' rows=20 cols=75
        =JSON.pretty_generate(session.to_hash)
      br
      br
      input type='submit'
    TEMPLATE
  end

  route do |r|
    unless ENV['RACK_ENV'] == 'development'
      raise 'Session debugger is for development only!' 
    end

    r.on 'debug' do
      r.post do
        session.replace JSON.parse(r.POST['session'])
        flash['message'] = 'Session successfully updated!'
        r.redirect
      rescue => ex
        flash['message'] = "Whoops! #{ex.message}"
        r.redirect
      end

      r.get do
        render :form
      end
    end
  end
end