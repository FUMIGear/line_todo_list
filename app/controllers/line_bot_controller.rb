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
        # binding.pry
        # 送信されたメッセージをデータベースに保存するコードを書こう
        # @task = Task.new(title: message)
        Task.create!(title: message)
        # binding.pry #ここまで進んだ。saveメソッドの作り込み
        # puts Task.pluck(:title) #.select(:title)よりこっちの方がいいかも
        # respond_to do |format|
          # if @task.save
            # format.html { redirect_to task_url(@task), notice: "Task was successfully created." }
            # format.json { render :show, status: :created, location: @task }
          # else
            # format.html { render :new, status: :unprocessable_entity }
            # format.json { render json: @task.errors, status: :unprocessable_entity }
          # end
        # end
        # ここまでコード
        # LINEに返すメッセージを考えてみよう。""は改行しても繋がってる。
        reply_message = {
          type: "text", # 入力したメッセージ（上のtext変数）
          text: "ぽーーん！\n\"#{message}\"\nが登録されました！！"
          # \n今まで登録されたタスクは・・・\n#{Task.pluck(:title)}\nです。"
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
# end

  # Task6で作ったコード（callbackメソッドの中身は作る必要なかった）
  # def callback
    # binding.pry
    # @task = Task.new(title: params[:title])
    # # binding.pry
    # respond_to do |format|
    #   if @task.save
    #     # format.html { redirect_to task_url(@task), notice: "Task was successfully created." }
    #     format.json { render :show, status: :created, location: @task }
    #   else
    #     # format.html { render :new, status: :unprocessable_entity }
    #     format.json { render json: @task.errors, status: :unprocessable_entity }
    #   end
    # end
  # end

end
