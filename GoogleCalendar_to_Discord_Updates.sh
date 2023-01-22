#!/bin/bash -xvu

# カレンダーからイベントを取得して、差分をDiscordに通知する

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

  # 過去のデータを取得して、差分を抽出
  if [ -s ${work_dir}/events_old/${calendar_id}_events ]; then
    diff ${work_dir}/events_old/${calendar_id}_events $tmp-${calendar_id}_events > $tmp-${calendar_id}_diff
  fi

  # 差分があればDiscordに通知
  if [ -s $tmp-${calendar_id}_diff ]; then
    while read line; do
      if [ "${line:0:1}" = ">" ]; then
        # Discordに通知
        curl -X POST -H "Content-Type: application/json" -d "{\"content\": \"${line:2}\"}" ${DISCORD_WEBHOOK_URL}
      fi
    done < $tmp-${calendar_id}_diff
  fi

  # 今回の結果を過去データとして保存
  mkdir -p ${work_dir}/events_old
  mv $tmp-${calendar_id}_events ${work_dir}/events_old/${calendar_id}_events
done

# 一時ファイルの削除
rm -f $tmp-*

# 終了
exit 0
