# encoding: UTF-8

require 'roda'
require 'seconds'
require 'concode'
require 'concurrent'
require 'message_bus'
require 'dotenv/load'
require 'roda/session_middleware'

require_relative 'middleware/session_debugger'

MessageBus.configure(:backend=>:memory)

class InsecureChat < Roda
  use MessageBus::Rack::Middleware

  use RodaSessionMiddleware,  
    cookie_options: { http_only: false },
    secret: "f941d19b52a9b3bea9ac76bb6c92ebb9d2bc7ccda799253e4a3d3b7eb4441d0f"

  use Rack::CommonLogger
  use SessionDebugger if ENV['RACK_ENV'] == 'development'

  plugin :halt
  plugin :json
  plugin :public
  plugin :slash_path_empty
  plugin :render, engine: 'slim'
  plugin :cookies, domain: 'sle.compute.army', path: '/'

  rooms = Concurrent::Map.new

  # cleans up inactive rooms
  Concurrent::TimerTask.new do 
    rooms.each do |name,map|
      rooms.delete name if map.fetch(:active, Time.now) < 1.hour.ago
    end
  end.execute
  
  route do |r|
    r.public

    r.on ENV['MAGIC_URL'] do 
      session['instructor'] = true
      
      generator = Concode::Generator.new
      code = generator.generate Time.now

      room = Concurrent::Map.new
      room.put_if_absent :active, Time.now
      room.put_if_absent :users, Concurrent::Array.new
      rooms[code] = room

      r.redirect code
    end

    r.is do
      r.get do
        view :welcome
      end

      r.post do 
        code = r.POST['code'].strip
        
        if code.nil? or rooms[code].nil?
          view :welcome, locals: { invalid_code: true }
        else
          r.redirect code
        end
      end
    end

    r.on rooms.keys do |code|
      r.get 'register' do 
        view :register
      end

      r.post 'register' do 
        first = r.POST['first']
        last = r.POST['last']
        r.redirect if first.nil? or first.strip.empty?
        r.redirect if last.nil? or last.strip.empty?
        session['name'] = "#{first.strip.capitalize} #{last.strip.capitalize}"
        r.redirect "/#{code}"
      end

      room = rooms[code]
      user_id = r.cookies['user_id']

      if user_id.nil? or user_id.to_i.negative? or room[:users][user_id.to_i].nil?
        r.redirect "#{code}/register" unless name = session['name']
        room[:users] |= [name]
        user_id = room[:users].index name
        response.set_cookie 'user_id', value: user_id, expires: 30.minutes.from_now
      else
        name = room[:users][user_id.to_i]
      end
      
      r.get 'reset' do 
        MessageBus.reliable_pub_sub.expire_all_backlogs!
        r.redirect "/#{code}"
      end

      r.is do 
        r.get do 
          view :chat, locals: { 
            title: 'Hack Chat', 
            instructor: session['instructor'] 
          }
        end

        r.post do 
          MessageBus.publish "/#{code}", user: name, text: r.POST['text']
          'done'
        end
      end
    
      r.post 'enter' do
        MessageBus.publish "/#{code}/enter", name
        'done'
      end
    end

    # no such room, redirect them home
    view :welcome, locals: { invalid_code: true }
  end
end

run InsecureChat.freeze.app
