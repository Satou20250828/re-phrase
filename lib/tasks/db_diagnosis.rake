namespace :db do
  desc "DB接続診断（URLパース/認証/DB存在確認/作成試行）"
  task diagnose: :environment do
    require "uri"
    require "pg"
    require "active_record/tasks/database_tasks"

    if File.exist?(Rails.root.join(".env"))
      File.foreach(Rails.root.join(".env")) do |line|
        entry = line.strip
        next if entry.empty? || entry.start_with?("#")
        next unless entry.include?("=")

        key, value = entry.split("=", 2)
        key = key.strip
        value = value.to_s.strip
        value = value[1..-2] if (value.start_with?('"') && value.end_with?('"')) || (value.start_with?("'") && value.end_with?("'"))
        ENV[key] = value unless key.empty?
      end
    end

    puts "=== DB診断開始 ==="

    raw_url = ENV["DATABASE_URL"].to_s.strip
    if raw_url.empty?
      puts "1) DATABASE_URL: 未設定（フォールバック設定を利用）"
    else
      masked_url = raw_url.gsub(%r{(postgres(?:ql)?://[^:]+:)[^@]+@}, '\1****@')
      puts "1) DATABASE_URL: #{masked_url}"
    end

    connection_params = {
      host: ENV.fetch("DB_HOST", "localhost"),
      port: ENV.fetch("DB_PORT", 5432).to_i,
      user: ENV.fetch("DB_USERNAME", "vscode"),
      password: ENV.fetch("DB_PASSWORD", "postgres"),
      dbname: ENV.fetch("DB_NAME_DEVELOPMENT", "re_phrase_development")
    }

    puts "2) URLパース確認"
    if raw_url.empty?
      puts "  - スキップ（未設定）"
    else
      begin
        uri = URI.parse(raw_url)
        if %w[postgres postgresql].include?(uri.scheme) && uri.host.present?
          connection_params[:host] = uri.host
          connection_params[:port] = uri.port if uri.port
          connection_params[:user] = uri.user if uri.user
          connection_params[:password] = uri.password if uri.password
          connection_params[:dbname] = uri.path.sub(%r{\A/}, "") if uri.path.present?
          puts "  - 成功: scheme=#{uri.scheme} host=#{uri.host} port=#{connection_params[:port]}"
        else
          puts "  - 失敗: scheme または host が不正。フォールバック設定で続行します。"
        end
      rescue URI::InvalidURIError => e
        puts "  - 失敗: URIエラー（#{e.message}）。フォールバック設定で続行します。"
      end
    end

    puts "3) 認証確認"
    begin
      conn = PG.connect(connection_params)
      conn.exec("SELECT 1")
      conn.close
      puts "  - 成功: 認証OK"
    rescue PG::ConnectionBad => e
      msg = e.message
      if msg.include?("password authentication failed")
        puts "  - 失敗: 認証エラー（ユーザー名/パスワード不一致）"
      else
        puts "  - 失敗: 接続エラー（#{msg.lines.first&.strip}）"
      end
      puts "  - ヒント（ロール/DB確認コマンド）:"
      puts "    psql -h #{connection_params[:host]} -p #{connection_params[:port]} -U postgres -d postgres -c \"\\du\""
      puts "    psql -h #{connection_params[:host]} -p #{connection_params[:port]} -U postgres -d postgres -c \"\\l\""
      puts "=== DB診断終了（失敗） ==="
      exit 1
    end

    puts "4) DB存在確認"
    begin
      admin_params = connection_params.merge(dbname: "postgres")
      admin_conn = PG.connect(admin_params)
      dbname = connection_params[:dbname]
      exists = admin_conn.exec_params("SELECT 1 FROM pg_database WHERE datname = $1 LIMIT 1", [dbname]).ntuples.positive?
      admin_conn.close

      if exists
        puts "  - 成功: DB '#{dbname}' は存在します"
      else
        puts "  - 未作成: DB '#{dbname}' が存在しません。作成を試行します。"
        begin
          db_config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "primary").first
          ActiveRecord::Tasks::DatabaseTasks.create(db_config)
          puts "  - 成功: DB '#{dbname}' を作成しました"
        rescue StandardError => e
          puts "  - 失敗: DB作成に失敗（#{e.class} - #{e.message}）"
          puts "=== DB診断終了（失敗） ==="
          exit 1
        end
      end
    rescue PG::Error => e
      puts "  - 失敗: DB存在確認でエラー（#{e.message.lines.first&.strip}）"
      puts "=== DB診断終了（失敗） ==="
      exit 1
    end

    puts "=== DB診断終了（成功） ==="
  end
end
