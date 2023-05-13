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
        userid = event["source"]["userId"] #Sp2で追加。
        message = message.chomp #不要な改行をなくすメソッド（複数個に弱い）
        # binding.pry

        # 送信されたメッセージをデータベースに保存するコードを書こう
        ifmessage(message, userid)
        # binding.pry # インスタンス変数でないとなぜかリターンがない。
        reply_message = {
          type: "text", # 入力したメッセージ（上のtext変数）
          text: @linemsg
        }
        client.reply_message(event["replyToken"], reply_message)
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

  def ifmessage(message, userid)
    # binding.pry
    case message
      when "一覧表示"
        # 模範回答を元に自分なりに作り直した。
        # binding.pry
        list = Task.all.where(user: userid).map.with_index do |task, i| #Sp2で修正した。
          "#{i+1}: #{task.title}"
          # "#{task.id}: #{task.title}"
        end.join("\n")
        # 色々やったけど、each文の使い方として間違ってる。
        # list2 = Task.all.where(user: userid).pluck(:title) # これで特定のuserの配列を出力
        # list2.each_with_index do |task, i|
        #   binding.pry
        #   test = "#{i+1}：#{task}\n"
        #   test2 = test+test2
        # #   puts "#{i}：#{task}"
        # end
        @linemsg = "【今までに登録したタスク】\n#{list}"
    	  # tasks.map { |task| "#{index}: #{task.body}" }.join("\n")
      when /削除\d/
        # binding.pry
        id = message.gsub(/削除/, "").strip.to_i #"削除"と余計な空白を消して残った文字列を数値化
        task = Task.find(id) #整数化されたidでTaskを出力する
        task.destroy! # タスクの削除
        @linemsg = "タスク #{id}: 「#{task.title}」 を削除しました！"
      when "削除"
        # binding.pry
        # これだと最初のタスクしか消せない。
        text = Task.where(user: userid).first.title #削除されるタスクのタイトル
        Task.first.destroy #タスクの削除
        @linemsg = "bomb!\n\"#{text}\"\nは削除されました！！"
      when "全削除"
        Task.destroy_all #タスクの削除
        @linemsg = "bomb!\n全てのタスクは削除されました！"
      else
        Task.create!(title: message,user: userid)
        @linemsg = "ぽーーん！\n\"#{message}\"\nが登録されました！！"
    end
  end
end
