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
        message = event["message"]["text"] #lineで入力したメッセージ
        userid = event["source"]["userId"] #Sp2で追加。ユーザ情報
        message = message.chomp #不要な改行をなくすメソッド（複数個は無理）
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
      when "一覧" #自ユーザの登録したタスク
        # binding.pry
        list = Task.all.where(user: userid).map.with_index(1) do |task, i| #Sp2で修正した。
          "#{i}: #{task.title}"
        end.join("\n")
        @linemsg = "【今までに登録したタスク】\n#{list}"
      when /削除\d/ #特定のタスクを削除する。
        # binding.pry
        delete = Task.all.where(user: userid) #自ユーザのタスクをHashでもらう[task1,task2...]（各taskにレコードがある）
        id = message.gsub(/削除/, "").strip.to_i - 1 #"削除"と余計な空白を消して残った文字列を数値化
        # binding.pry
        task = delete[id] #整数化されたidでTaskを出力する
        task.destroy! #タスクの削除
        @linemsg = "タスク #{id}: 「#{task.title}」 を削除しました！"
      when "削除" #自ユーザの最初のタスクを消す
        # binding.pry
        deltitle = Task.where(user: userid).first.title #削除されるタスクのタイトル
        Task.where(user: userid).first.destroy #タスクの削除
        @linemsg = "bomb!\n\"#{deltitle}\"\nは削除されました！！"
      when "全削除" #自ユーザのタスクを全て消す
        Task.where(user: userid).destroy_all #タスクの削除
        @linemsg = "BooooooomB！\n全てのタスクは削除されました！"
      when "全表示" #ユーザ関係なく全てのタスク表示
        list = Task.all.map do |task| #Sp2で修正した。
          "#{task.id}: #{task.title}"
        end.join("\n")
        @linemsg = "【今までに登録したタスク】\n#{list}"
      else # その他＝タスクの登録
        Task.create!(title: message,user: userid)
        @linemsg = "ぽーーん！\n\"#{message}\"\nが登録されました！！"
    end
  end
end
