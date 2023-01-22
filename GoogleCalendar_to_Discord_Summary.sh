#!/bin/bash -xvu

# カレンダーからイベントを取得して、今日のサマリを送信する

# 初期設定
tmp=$(mktemp)

work_dir="$(dirname $0)" # スクリプトのあるディレクトリ
filename="$(basename $0)" # スクリプトのファイル名
mkdir -p ${work_dir}/log # ログディレクトリ
exec 2> ${work_dir}/log/${filename}.$(date +%Y%m%d_%H%M%S) # 標準エラー出力をログファイルに出力
cd ${work_dir}

# 外部の変数ファイルを取得
source ${work_dir}/keys.sh

# カレンダーイベントの取得
cat ${work_dir}/target_calendars.txt |
while read calendar_id; do
  python3 ${work_dir}/get_event_gcal.py ${calendar_id} > $tmp-${calendar_id}_events

  # カレンダーデータのうち、本日の予定を取得する
  today=$(date +%Y-%m-%d)
  cat $tmp-${calendar_id}_events |
  # 今日の日付で始まる行を取得
  grep -e "^${today}" |
  # 今日の日付を削除
  sed -e "s/^${today} //" |
  # 予定の開始時間を整形
  sed 's/^.*T\([0-9][0-9]\):\([0-9][0-9]\).* \(.*$\)/\1:\2 \3/' > $tmp-${calendar_id}_events_today

  while read event; do
    # 通知するメッセージを作成
    message="【${calendar_id}】${event}"
    # discordに通知
    curl -X POST -H "Content-Type: application/json" -d "{\"content\": \"${message}\"}" ${DISCORD_WEBHOOK_URL}
  done < $tmp-${calendar_id}_events_today
done

# 一時ファイルの削除
rm -f $tmp-*

# 終了
exit 0