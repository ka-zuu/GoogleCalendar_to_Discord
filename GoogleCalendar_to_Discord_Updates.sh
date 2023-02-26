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
  python3 ${work_dir}/get_event_gcal_service_account.py ${calendar_id} > $tmp-${calendar_id}_events

  # 過去のデータを取得して、差分を抽出
  if [ -s ${work_dir}/events_old/${calendar_id}_events ]; then
    # 過去のデータから昨日の日付を含む行は除く
    cat ${work_dir}/events_old/${calendar_id}_events |
    grep -v "$(date -d "1 day ago" +%Y-%m-%d)" |
    # 差分を取る
    diff - $tmp-${calendar_id}_events > $tmp-${calendar_id}_diff
  fi

  # 差分があればDiscordに通知するために追記
  if [ -s $tmp-${calendar_id}_diff ]; then
    cat $tmp-${calendar_id}_diff |
    # 予定の日時を整形
    sed 's/^\(.*\)T\([0-9][0-9]\):\([0-9][0-9]\).* \(.*$\)/\1 \2:\3 \4/' |
    # >か<で始まる行だけを取得
    grep -e "^>" -e "^<" |
    # 差分を日本語にする
    sed -e 's/^>/追加/' -e 's/^</削除/' |
    cat <(echo "【${calendar_id}】") - >> $tmp-diff_for_send
  fi

  # 今回の結果を過去データとして保存
  mkdir -p ${work_dir}/events_old
  mv $tmp-${calendar_id}_events ${work_dir}/events_old/${calendar_id}_events
done

# 送信する差分があれば、Discordに通知
if [ -s $tmp-diff_for_send ]; then
  cat $tmp-diff_for_send |
  # 改行を削除して、一行にまとめる
  sed "s/$/\\\n/" |
  tr -d "\n" > $tmp-diff_for_send2

  # Discordに通知
  curl -X POST -H "Content-Type: application/json" -d '{"content": "'"$(cat $tmp-diff_for_send2)"'"}' ${DISCORD_WEBHOOK_URL}
fi

# 一時ファイルの削除
rm -f $tmp-*

# 終了
exit 0
