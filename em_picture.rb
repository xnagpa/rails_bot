require 'eventmachine'
require 'evma_httpserver'
require 'vkontakte_api'
require 'pry'
require 'json'
require 'em-http-request'

class MyHttpServer < EM::Connection
  include EM::HttpServer
  attr_accessor :token
  attr_accessor :version
  attr_accessor :hiragana
  attr_accessor :common_log
  attr_accessor :users_log
  attr_accessor :error_log
  @@players = {}

   def post_init
     super
     no_environment_strings
   end

   def send_response(text)
     response = EM::DelegatedHttpResponse.new(self)
     response.status = 200
     response.content_type 'text/string'
     response.content = text
     response.send_response
   end

   def new_message?
     if @http_post_content
       begin
         if @request_body['type'] == 'message_new'
           return true
         else
           return false
         end
      rescue JSON::ParserError
        send_response('ok')
        false
      end
     end
   end

   def existing_player?
     new_message? && !new_player?
   end 

   def fact?
     if @http_post_content
       begin
         if @request_body['type'] == 'message_new' && ['fact', 'Fact', 'факт', 'Факт'].include?(@request_body['object']['body'])
           return true
         else
           return false
         end
      rescue JSON::ParserError
        send_response('ok')
        false
      end
     end
   end

   def hiragana? 
     if @http_post_content 
       begin
         if @request_body['type'] == 'message_new' && ['хирагана', 'Хирагана'].include?(@request_body['object']['body'])
           return true
         else
           return false
         end
      rescue JSON::ParserError
        send_response('ok')
        false
      end
     end
   end

   def fact?
     if @http_post_content
       begin
         if @request_body['type'] == 'message_new' && ['факт', 'Факт', 'Fact', 'fact'].include?(@request_body['object']['body'])
           return true
         else
           return false
         end
      rescue JSON::ParserError
        send_response('ok')
        false
      end
     end
   end

   def exit?
     if @http_post_content
       begin
         if @request_body['type'] == 'message_new' && ['стоп', 'Стоп'].include?(@request_body['object']['body'])
           return true
         else
           return false
         end
      rescue JSON::ParserError
        send_response('ok')
        false
      end
     end
   end

   def menu?
     if @http_post_content
       begin
         if @request_body['type'] == 'message_new' && ['меню', 'Меню', 'Привет', 'привет'].include?(@request_body['object']['body'])
           return true
         else
           return false
         end
      rescue JSON::ParserError
        send_response('ok')
        false
      end
     end
   end

   def send_vk_message(message)
     http = EventMachine::HttpRequest.new('https://api.vk.com/method/messages.send').post(
         body:  {
          access_token: token,
          v: version,
          user_id: @request_body['object']['user_id'],
          message: message,
          random_id: Random.new_seed,
          attachment: ['photo-165384569_456239909', 'photo-165384569_456239910', 'photo-165384569_456239911',
                       'photo-165384569_456239912', 'photo-165384569_456239913', 'photo-165384569_456239914',
                       'photo-165384569_456239915', 'photo-165384569_456239916', 'photo-165384569_456239917', 
                       'photo-165384569_456239918'].sample 
       })
   end

   def picture?
     if @http_post_content
       begin
         if @request_body['type'] == 'message_new' && ['пикча', 'картинка'].include?(@request_body['object']['body'])
           return true
         else
           return false
         end
      rescue JSON::ParserError
        send_response('ok')
        false
      end
     end
   end

   def kekus_player
     @@players[@request_body['object']['user_id']]
   end

   def new_player?
     @@players[@request_body['object']['user_id']].nil?
   end

   def message_body
     @request_body['object']['body']
   end

   def random_hiragana
     question = Hash[*hiragana.to_a.sample]
     { question: question.keys.first, answer: question.values.first }
   end

  def clean_players
    @@players.each do |k, v|
      puts "CLEAN PLAYERS #{Time.now - v[:created_at]} CONDITION:#{((Time.now - v[:created_at])/60).to_i > 10}"
      @@players.delete(k) if ((Time.now - v[:created_at])/60).to_i > 120
    end
  end
  
   def process_http_request
      send_response('ok')
      puts "PLAYERS: #{@@players}" 

      @request_body = JSON.parse(@http_post_content) if @http_post_content
      
      clean_players
      
      user = @request_body['object']['user_id'] if @http_post_content

      if hiragana?
        question = Hash[*hiragana.to_a.sample]
        
        message = if new_player?
                    @@players[user] = random_hiragana.merge!(count: 0, created_at: Time.now)
                    "Как читается #{@@players[user][:question]}?"
                  else
                    "Как читается #{@@players[user][:question]}?" 
                  end

        send_vk_message(message)
      elsif exit?
        if @@players[user]
          count = @@players[user][:count]
          @@players.delete(user)
          send_vk_message("Правильных ответов #{count}.\nПриходи еще!")
        end
      elsif menu?
        send_vk_message("Набери 'факт'.Узнай забавный факт о Японии.\n
                         Набери 'хирагана'. Учи японскую азбуку Хирагана.\n
                         Набери 'стоп', когда Хирагана надоест и узнай свой результат.\n
                         По всем вопросам пиши в личку @id1146548(Админу).\n
                         Хорошей игры!")
      elsif existing_player?
        puts "ANSWER:#{@@players[user][:answer]}|USER_ANSWER:#{message_body}|#{@@players[user][:answer].include?(message_body.downcase)}"
        if @@players[user][:answer].include?(message_body.downcase)
          @@players[user].merge!(random_hiragana).merge!(created_at: Time.now)
          @@players[user][:count] += 1
          send_vk_message("Правильно, следующий вопрос!\nКак читается #{@@players[user][:question]}?")
        else
          answer = @@players[user][:answer].first
          @@players[user].merge!(random_hiragana).merge!(created_at: Time.now)
          send_vk_message("Неправильно!\nОтвет: #{answer}\nКак читается #{@@players[user][:question]}?")
        end
      elsif !fact?
        send_vk_message("Набери 'факт'.Узнай забавный факт о Японии.\n
                         Набери 'хирагана'. Учи японскую азбуку Хирагана.\n
                         Набери 'стоп', когда Хирагана надоест и узнай свой результат.\n
                         По всем вопросам пиши в личку @id1146548(Админу).\n
                         Хорошей игры!")
      end
   end
end

EM.run{
  EM.start_server('127.0.0.1', 8086, MyHttpServer) do |conn|
    conn.token = '739f979e9a39b4661e8c93dfd2ea0876d8c057c29633a3f3c4fd7551a6629cd84960b15953be76a1437fa'
    conn.version = '5.50'
    conn.hiragana = {'い'=>['и'], 'ろ'=>['ро'], 'は'=>['ха', 'ва'], 'に'=>['ни'], 'ほ'=>['хо'], 'へ'=>['э', 'хэ'], 'と'=>['то'],
'ち'=>['ти','чи'], 'り'=>['ри'], 'ぬ'=>['ну'], 'る'=>['ру'], 'を'=>['о', 'во'], 
'わ'=>['ва'], 'か'=>['ка'], 'よ'=>['е', 'ё'], 'た'=>['та'], 'れ'=>['рэ'], 'そ'=>['со'],
'つ'=>['цу', 'тсу'], 'ね'=>['нэ'], 'な'=>['на'], 'ら'=>['ра'], 'む'=>['му'],
'う'=>['у'], 'の'=>['но'], 'お'=>['о'], 'く'=>['ку'], 'や'=>['я'], 'ま'=>['ма'],
'け'=>['кэ'], 'ふ'=>['фу'], 'こ'=>['ко'], 'え'=>['э'], 'て'=>['тэ'],
'あ'=>['а'], 'さ'=>['са'], 'き'=>['ки'], 'ゆ'=>['ю'], 'め'=>['мэ'], 'み'=>['ми'], 'し'=>['си', 'ши'],
'ひ'=>['хи'], 'も'=>['мо'], 'せ'=>['сэ'], 'す'=>['су'], 'ん'=>['н']}
    conn.users_log = File.open('./users.log', 'a')
    conn.error_log = File.open('./error.log', 'a')
    conn.common_log = File.open('./common_log.log', 'a')
  end
}



