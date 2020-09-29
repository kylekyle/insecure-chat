# encoding: UTF-8

require 'roda'
require 'seconds'
require 'concode'
require 'concurrent'
require 'message_bus'
require 'dotenv/load'
require 'roda/session_middleware'

require_relative 'middleware/lti'
require_relative 'middleware/session_debugger'

MessageBus.configure(:backend=>:memory)

class InsecureChat < Roda
  use MessageBus::Rack::Middleware

  use RodaSessionMiddleware, 
    secret: ENV['SESSION_SECRET'], 
    cookie_options: { http_only: false }

  use LTI
  use Rack::CommonLogger
  use SessionDebugger if ENV['RACK_ENV'] == 'development'

  plugin :halt
  plugin :json
  plugin :public
  plugin :slash_path_empty
  plugin :render, engine: 'slim'
  plugin :cookies, domain: 'insecure.compute.army', path: '/'

  rooms = Concurrent::Map.new

  # cleans up inactive rooms
  Concurrent::TimerTask.new do 
    rooms.each do |name,map|
      rooms.delete name if map.fetch(:active, Time.now) < 1.hour.ago
    end
  end.execute
  
  route do |r|
    r.public

    r.on 'lti' do 
      link = Concode::Generator.new
      title = r.POST['context_label']
      sections = r.POST['custom_canvas_course_section_ids'].split(',')

      codes = sections.map do |section| 
        code = link.generate section

        room = Concurrent::Map.new
        room.put_if_absent :name, title
        room.put_if_absent :active, Time.now
        room.put_if_absent :users, Concurrent::Array.new

        rooms[code] = room
        code
      end

      # this is where we store the user's name for the purposes of resetting 
      # and instructors that have multiple sections and don't come directly 
      # from the lti endpoint to the chat room
      session['name'] = r.POST['lis_person_name_full']

      roles = r.POST['custom_canvas_membership_roles']
      
      if roles['TeacherEnrollment'] || roles['DesignerEnrollment']
        session['instructor'] = true
      end

      if sections.one? 
        code = link.generate sections.first
        r.redirect "/#{code}"
      else
        links = codes.map do |code|
          "<br>&nbsp;&nbsp;&nbsp;&nbsp;&bull; <a href='/#{code}'>#{code}</a>"
        end
        
        view :card, locals: {
          title: 'Insecure Chat', 
          text: "You are in multiple sections of this course. Lucky you! Choose a chat room to join:<br> #{links.join}"
        }
      end
    end

    r.is do       
      view :card, locals: {
        title: '¯\_(ツ)_/¯', 
        text: "Whoops! Couldn't find the chat room for your class. Try accessing this page from the <b>Insecure Chat</b> link on your Canvas course page."
      }
    end
    
    r.on rooms.keys do |code|
      room = rooms[code]
      user_id = r.cookies['user_id']

      if user_id.nil? or user_id.to_i.negative? or room[:users][user_id.to_i].nil?
        unless name = session['name']
          r.halt 401, view(:card, locals: {
            title: '¯\_(ツ)_/¯', 
            text: "Whoops! Something went wrong. Try logging in from Canvas again."
          })
        end

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
            title: room[:name], 
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
    r.redirect '/'
  end
end


run InsecureChat.freeze.app