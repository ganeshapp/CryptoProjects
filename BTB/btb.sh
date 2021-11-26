#!/bin/bash
# This is an installation script for installing Binance Trade Bot on Oracle Free tier cloud (Ubuntu)

BinanceFolder=BTBot

Installversion=Gapp_1.0_27-11-2021 

BinanceBot="git clone https://github.com/tntwist/binance-trade-bot.git"
BinanceBotVersion="TnTwist master"
echo "Binance trading bot will be installed with ${BinanceBot}"

UserBot="$USER"
echo "User name is ${UserBot}"
PyVer38="Yes"
PATH=$PATH:/home/${UserBot}/.local/bin;export $PATH
sudo apt update -y
sudo apt-get update -y
sudo apt install ntp git python3 idle3 python3-pip sqlite3 -y
pip install websockets==8.1

_dir="${1:-${PWD}}"

[ ! -d "$_dir" ] && { echo "Error: Directory $_dir not found."; exit 2; }
 
WorkingDirectoryBot="${_dir}/${BinanceFolder}/binance-trade-bot"
WorkingDirectoryTelegram="${_dir}/${BinanceFolder}/BTB-manager-telegram"
WorkingDirectoryBTBChart="${_dir}/${BinanceFolder}/binance-chart-plugin-telegram-bot"
DescriptionBot="Binance Trade Bot - ${BinanceFolder}"
DescriptionTelegram="BTB-manager-telegram - ${BinanceFolder}"

mkdir $BinanceFolder
cd $BinanceFolder

git init  
$BinanceBot
git clone https://github.com/lorcalhost/BTB-manager-telegram.git

cd binance-trade-bot
pip3 install -r requirements.txt
cd ..
cd BTB-manager-telegram
pip3 install -r requirements.txt
cd ..

mkdir -p ${WorkingDirectoryTelegram}/custom_scripts

git clone https://github.com/marcozetaa/binance-chart-plugin-telegram-bot.git

cat <<EOF >${WorkingDirectoryBTBChart}/config
[config]
bot_path=${WorkingDirectoryBot}
min_timestamp = 0
EOF
cd binance-chart-plugin-telegram-bot
pip3 install -r requirements.txt

cat <<EOF >${WorkingDirectoryTelegram}/config/custom_scripts.json
{
  "💰 Current coin progress": "custom_scripts/current_coin_progress.sh",
  "💰 All coins progress": "custom_scripts/all_coins_progress.sh",
  "Crypto chart": "python3 ../binance-chart-plugin-telegram-bot/db_chart.py",
  "Reset Ratios (stop bot before this)": "custom_scripts/reset_ratio.sh",
  "Update crypto chart": "bash -c 'cd ../binance-chart-plugin-telegram-bot && git pull'",
  "Database warmup": "cd ../binance-trade-bot && python3 database_warmup.py"
}
EOF


cat <<'EOF' >${WorkingDirectoryTelegram}/custom_scripts/current_coin_progress.sh
#!/bin/bash
sqlite3 -cmd '.timeout 1000' ../binance-trade-bot/data/crypto_trading.db "select id,alt_trade_amount, datetime, alt_coin_id from trade_history where selling=0 and state='COMPLETE' and alt_coin_id=(select alt_coin_id from trade_history order by id DESC limit 1);" > results
starting_value=$(sed -n '1p' results| awk -F\| '{print $2}')
while read p; do
   echo -n "Trade no: "
   echo $p | awk -F\| '{print $1}'
   echo -n "Hodlings: "
   echo $p | awk -F\| '{print $2}'
   echo -n "Date: "
   echo $p | awk -F\| '{print $3}'
   echo -n "Grow: "
   value=$(echo $p | awk -F\| '{print $2}')
   grow=$(awk "BEGIN {print ($value/$starting_value*100)-100}")
   echo -n $grow
   echo "%"
   echo
done <results
echo -n "Current coin: "
echo $(sed -n '1p' results| awk -F\| '{print $4}')
EOF
sudo chmod +x ${WorkingDirectoryTelegram}/custom_scripts/current_coin_progress.sh

cat <<'EOF' >${WorkingDirectoryTelegram}/custom_scripts/all_coins_progress.sh
#!/bin/bash
DATABASE=../binance-trade-bot/data/crypto_trading.db
while read p; do
   echo -n "Coin: "
   echo $p
   jumps=$(sqlite3 -cmd '.timeout 1000' $DATABASE "select count(id) from trade_history where alt_coin_id='$p' and selling=0 and state='COMPLETE';")
   if [[ $jumps -gt 0 ]]
   then
	first_date=$(sqlite3 -cmd '.timeout 1000' $DATABASE "select datetime from trade_history where alt_coin_id='$p' and selling=0 and state='COMPLETE' order by id asc limit 1;")
	echo -n "First coin bought at: "
	echo $first_date
     echo -n "Starting value: "
     first_value=$(sqlite3 -cmd '.timeout 1000' $DATABASE "select alt_trade_amount from trade_history where alt_coin_id='$p' and selling=0 and state='COMPLETE' order by id asc limit 1;")
     echo $first_value
     echo -n "Last value: "
     last_value=$(sqlite3 -cmd '.timeout 1000' $DATABASE "select alt_trade_amount from trade_history where alt_coin_id='$p' and selling=0 and state='COMPLETE' order by id DESC limit 1;")
     echo $last_value
     echo -n "Grow: "
     grow=$(awk "BEGIN {print ($last_value/$first_value*100)-100}")
     echo -n $grow
     echo "%"	
	echo -n "Starting value: "
	crypto_coin_id=$(sqlite3 -cmd '.timeout 1000' $DATABASE "select crypto_coin_id from trade_history where alt_coin_id='$p' and selling=0 and state='COMPLETE' order by id asc limit 1;")
	first_value2=$(sqlite3 -cmd '.timeout 1000' $DATABASE "select crypto_trade_amount from trade_history where alt_coin_id='$p' and selling=0 and state='COMPLETE' order by id asc limit 1;")
	echo -n $first_value2
     echo -n " "
     echo $crypto_coin_id
     echo -n "Last value Buy/Sell: "
     last_valueb=$(sqlite3 -cmd '.timeout 1000' $DATABASE "select crypto_trade_amount  from trade_history where alt_coin_id='$p' and selling=0 and state='COMPLETE' order by id DESC limit 1;")
     last_values=$(sqlite3 -cmd '.timeout 1000' $DATABASE "select crypto_trade_amount  from trade_history where alt_coin_id='$p' and selling=1 and state='COMPLETE' order by id DESC limit 1;")
     echo -n $last_valueb
     echo -n " / "
     echo -n " "
     echo -n $last_values
     echo $crypto_coin_id
     echo -n "Grow Buy/Sell: "
     growb=$(awk "BEGIN {print ($last_valueb/$first_value2*100)-100}")
     grows=$(awk "BEGIN {print ($last_values/$first_value2*100)-100}")
     echo -n $growb
     echo -n "% / "
     echo -n $grows
     echo "%"
	echo -n "Number of trades: "
	echo $jumps
   else
     echo "Coin has not yet been bought"
   fi
     echo
done <../binance-trade-bot/supported_coin_list
EOF
sudo chmod +x ${WorkingDirectoryTelegram}/custom_scripts/all_coins_progress.sh

cat <<'EOF' >${WorkingDirectoryTelegram}/custom_scripts/reset_ratio.sh
#!/bin/bash
sqlite3 ../binance-trade-bot/data/crypto_trading.db "update pairs set ratio = null"

echo -n "Finished Reset"
EOF
sudo chmod +x ${WorkingDirectoryTelegram}/custom_scripts/reset_ratio.sh


cat <<EOF >BTB${BinanceFolder}.service
[Unit]
Description=${DescriptionBot}
After=network.target
[Service]
ExecStart=/usr/bin/python3 -u -m binance_trade_bot
WorkingDirectory=${WorkingDirectoryBot}
StandardOutput=inherit
StandardError=inherit
Restart=on-failure
User=${UserBot}
[Install]
WantedBy=multi-user.target
EOF
sudo mv BTB${BinanceFolder}.service /etc/systemd/system/BTB${BinanceFolder}.service
sudo systemctl start BTB${BinanceFolder}.service
sudo systemctl enable BTB${BinanceFolder}.service


cat <<EOF >BTBTelegram${BinanceFolder}.service
[Unit]
Description=${DescriptionTelegram}
After=network.target BTB${BinanceFolder}.service
[Service]
ExecStart=/usr/bin/python3 -u -m btb_manager_telegram -p "../binance-trade-bot"
WorkingDirectory=${WorkingDirectoryTelegram}
StandardOutput=inherit
StandardError=inherit
Restart=always
User=${UserBot}
[Install]
WantedBy=multi-user.target
EOF
sudo mv BTBTelegram${BinanceFolder}.service /etc/systemd/system/BTBTelegram${BinanceFolder}.service
sudo systemctl start BTBTelegram${BinanceFolder}.service
sudo systemctl enable BTBTelegram${BinanceFolder}.service

################################################################################################################################################
# Start User parameters Fill in field section
# User parameter setup. Fill in your details here
# 1) Fill in below your user.cfg details.
# Update your API keys and your bridge coins. The rest can be kept as default
#

cat <<EOF >${WorkingDirectoryBot}/user.cfg 
[binance_user_config]
api_key=API
api_secret_key=KEY
current_coin=
bridge=USDT
tld=com
hourToKeepScoutHistory=1
scout_multiplier=5
scout_sleep_time=1
strategy=multiple_coins
buy_timeout=10
sell_timeout=10
buy_order_type=limit
sell_order_type=market
#AdditionalParameters=Below_is_only_for_TnTwist_Master
enable_paper_trading=False
sell_max_price_change=0.005
buy_max_price_change=0.005
trade_fee=auto
price_type=orderbook
auto_adjust_bnb_balance=true
auto_adjust_bnb_balance_rate=3
#BinanceBotVersion=${BinanceBotVersion}
#BinanceBotInstallFolder=${BinanceFolder}
#InstallScript=${Installversion}
EOF

##################################################################
# 2) Fill in below your supported coins, which you would like to trade
# Note: EOF is not a coin, but End Of File for creating the Supported Coin List file
#

cat <<EOF >${WorkingDirectoryBot}/supported_coin_list
BTC
ETH
SOL
EOF

##################################################################
# 3) Fill in below your Telegram Bot ID's
#

cat <<EOF >${WorkingDirectoryBot}/config/apprise.yml
# Define version
version: 1
# Define your URLs (Mandatory!)
# URLs should start with - (remove the comment symbol #)
# Replace the values with your tokens/ids
# For example a telegram URL would look like:
# - tgram://123456789:AABx8iXjE5C-vG4SDhf6ARgdFgxYxhuHb4A/-606743502
urls:
- tgram://TOKEN/CHAT_ID
  # - discord://WebhookID/WebhookToken/
  # - slack://tokenA/tokenB/tokenC
  # More options here: https://github.com/caronc/apprise
EOF

# End Script