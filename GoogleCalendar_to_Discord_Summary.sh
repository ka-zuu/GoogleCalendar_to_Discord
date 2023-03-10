#!/bin/bash -xvu

# カレンダーからイベントを取得して、今日のサマリを送信する

# 初期設定
tmp=$(mktemp)

work_dir=$(dirname "$0") # スクリプトのあるディレクトリ
filename=$(basename "$0") # スクリプトのファイル名
mkdir -p "${work_dir}/log" # ログディレクトリ
exec 2> "${work_dir}/log/${filename}.$(date +%Y%m%d_%H%M%S)" # 標準エラー出力をログファイルに出力
cd "${work_dir}" || exit 1

# 外部の変数ファイルを取得
# shellcheck source=/dev/null
source "${work_dir}/keys.sh"

# カレンダーイベントの取得
while read -r calendar_id; do
  python3 "${work_dir}/get_event_gcal_service_account.py" "${calendar_id}" > "$tmp-${calendar_id}_events"

  # カレンダーデータのうち、本日の予定を取得する
  today=$(date +%Y-%m-%d)
  cat "$tmp-${calendar_id}_events" |
  # 今日の日付で始まる行を取得
  grep -e "^${today}" |
  # 予定の開始時間を整形
  sed 's/^.*T\([0-9][0-9]\):\([0-9][0-9]\).* \(.*$\)/\1:\2 \3/' |
  awk '{if(NF==1){print "終日",$0}else{print $0}}' > "$tmp-${calendar_id}_today"

  if [ -s "$tmp-${calendar_id}_today" ]; then
    # 今日の予定がある場合、各行にカレンダー名を付与して、1行にまとめる
    cat <(echo "【${calendar_id}】" ) "$tmp-${calendar_id}_today" >> "$tmp-today_summary"

  else
    # 今日の予定がない場合、Discordに通知
    echo -e "【${calendar_id}】\n今日の予定はありません" >> "$tmp-today_summary"
  fi
done < "${work_dir}/target_calendars.txt"

# Discordに通知
cat "$tmp-today_summary" |
# 改行を削除して、一行にまとめる
sed "s/$/\\\n/" |
tr -d "\n" > "$tmp-today_summary2"

curl -X POST -H "Content-Type: application/json" -d '{"content": "'"$(cat $tmp-today_summary2)"'"}' "${DISCORD_WEBHOOK_URL}"

# 一時ファイルの削除
rm -f "$tmp"-*

# 終了
exit 0