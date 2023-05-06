class LineBotController < ApplicationController
  require "line/bot"
  protect_from_forgery with: :null_session #422Error対策

  def callback
    # LINEで送られてきたメッセージのデータを取得
    # puts "コルバ" # PostmanでCallbackメソッドが動いているか確認するために書いた。
    # binding.pry # パラメータ確認用
    body = request.body.read #中身空っぽ #これが問題だな→Postmanだと空になるっぽい

    # LINE以外からリクエストが来た場合 Error を返す
    signature = request.env["HTTP_X_LINE_SIGNATURE"]
    unless client.validate_signature(body, signature) #ここで400エラー判定されてるっぽい
      head :bad_request and return #されてるなー。→bodyの中身が空でなければ、スルーされる。
    end

    # LINEで送られてきたメッセージを適切な形式に変形
    events = client.parse_events_from(body)
    events.each do |event|
      # LINE からテキストが送信された場合
      if (event.type === Line::Bot::Event::MessageType::Text)
        # LINE からテキストが送信されたときの処理を記述する
        # Task10で追記した
        message = event["message"]["text"]
        message = message.chomp #不要な改行をなくすメソッド（複数個に弱い）
        # binding.pry
        # 送信されたメッセージをデータベースに保存するコードを書こう
        ifmessage(message)
        binding.pry #インスタンス変数でないとなぜかリターンがない。
        # case message
        #   when "一覧表示"
        #     # 一覧表示はできるが、見えにくい。
        #     reply_message = {
        #       type: "text", # 入力したメッセージ（上のtext変数）／これがないとエラーになる
        #       text: "【今までに登録したタスク】\n#{Task.pluck(:title).join("\n")}"
        #     }
        #     # return reply_message
        #   when "削除"
        #     # これだと最初のタスクしか消せない。
        #     text = Task.first.title #削除されるタスクのタイトル
        #     Task.first.destroy #タスクの削除
        #     reply_message = {
        #       type: "text", # 入力したメッセージ（上のtext変数）
        #       text: "bomb!\n\"#{text}\"\nは削除されました！！"
        #     }
        #     # return reply_message
        #   else
        #     Task.create!(title: message)
        #     reply_message = {
        #       type: "text", # 入力したメッセージ（上のtext変数）
        #       text: "ぽーーん！\n\"#{message}\"\nが登録されました！！"
        #       # \n今まで登録されたタスクは・・・\n#{Task.pluck(:title)}\nです。"
        #     }
        # end

        # client.reply_message(event["replyToken"], reply_message)
        client.reply_message(event["replyToken"], @reply_message)
        # ここまでTask10で追記
      end
    end
    # LINE の webhook API との連携をするために status code 200 を返す
    render json: { status: :ok }
  end

  private

  def client
    @client ||= Line::Bot::Client.new do |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    end
  end

  def ifmessage(message)
    # binding.pry
    case message
      when "一覧表示"
        # 一覧表示はできるが、見えにくい。
        @reply_message = {
          type: "text", # 入力したメッセージ（上のtext変数）／これがないとエラーになる
          text: "【今までに登録したタスク】\n#{Task.pluck(:title).join("\n")}"
        }
      when "削除"
        # これだと最初のタスクしか消せない。
        text = Task.first.title #削除されるタスクのタイトル
        Task.first.destroy #タスクの削除
        @reply_message = {
          type: "text", # 入力したメッセージ（上のtext変数）
          text: "bomb!\n\"#{text}\"\nは削除されました！！"
        }
      when "全削除"
        Task.destroy_all #タスクの削除
        @reply_message = {
          type: "text", # 入力したメッセージ（上のtext変数）
          text: "bomb!\n全てのタスクは削除されました！"
        }
      else
        Task.create!(title: message)
        @reply_message = {
          type: "text", # 入力したメッセージ（上のtext変数）
          text: "ぽーーん！\n\"#{message}\"\nが登録されました！！"
          # \n今まで登録されたタスクは・・・\n#{Task.pluck(:title)}\nです。"
        }
    end
    # binding.pry
    # return reply_message # returnが機能してない。インスタンス変数にしたらうまくいった。
    # return testmessage = reply_message
    # client.reply_message(event["replyToken"], reply_message) # 使ってる変数が多い。
  end
end
