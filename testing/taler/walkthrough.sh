#!/usr/bin/env bash
# This file is in the public domain.
# Original: https://git.taler.net/marketing.git/tree/presentations/2023-fsf/walkthrough.sh?id=fa3c0187a422b8514032e82fbecec83f890d7d70

#########
# This is an example of the steps needed to install and run GNU Taler
########

# This script assume root privileges.
# Use this if you know what you are doing.

export LANGUAGE=C
export LC_ALL=C
export LANG=C
export LC_CTYPE=C

set -e

export CURRENCY=EUR
export EXCHANGE_IBAN=DE940993
export MERCHANT_IBAN=DE463312
export ALICE_IBAN=DE474361
export BOB_IBAN=DE731371

read -rp "Setup GNU Taler for $CURRENCY!. Press any key to start..."
echo ==========================================================================
echo ==========================================================================
echo ==========================================================================
echo "1/8 Update and install tools"

# TODO:
# apt update
# apt install -y gnupg less vim procps curl inetutils-ping jq net-tools man

echo ----------------------------------------
read -rp "1/8 tools installed. Press any key to continue..."
echo ==========================================================================
echo ==========================================================================
echo ==========================================================================
echo "2/8 Setup dns config and database "

#using this hosts as alias for localhost
#it will be useful for nginx configuration
echo 127.0.0.1 bank.taler auditor.taler exchange.taler merchant.taler | tee -a /etc/hosts

#install database and create a default user for the whole setup
# TODO:
# apt install -y postgresql
service postgresql start
su - postgres -c "createuser -d -l -r -s root"
psql postgres -c "ALTER USER root PASSWORD 'root'"

#create the database that we are going to use
createdb auditor
createdb exchange
createdb merchant
createdb sandbox
createdb nexus

echo ----------------------------------------
read -rp "2/8 databases created. Press any key to continue..."
echo ==========================================================================
echo ==========================================================================
echo ==========================================================================
echo "3/8 Install GNU Taler components "

# TODO:
# yes no | apt install -y \
#     libeufin-sandbox \
#     libeufin-nexus \
#     taler-exchange \
#     taler-auditor \
#     taler-merchant \
#     taler-harness \
#     taler-wallet-cli

echo ----------------------------------------
read -rp "3/8 all components installed. Press any key to continue..."
echo ==========================================================================
echo ==========================================================================
echo ==========================================================================
echo "4/8 Setup NGINX reverse proxy"

# TODO:
# apt install -y nginx

# TODO:
#enable sandbox and config server to http://bank.taler/
ln -s /etc/nginx/sites-available/libeufin-sandbox /etc/nginx/sites-enabled/
sed 's/server_name localhost/server_name bank.taler/' -i /etc/nginx/sites-available/libeufin-sandbox

# TODO:
#enable auditor and config server to http://auditor.taler/
ln -s /etc/nginx/sites-available/taler-auditor /etc/nginx/sites-enabled/
sed 's/server_name localhost/server_name auditor.taler/' -i /etc/nginx/sites-available/taler-auditor
sed 's_location /taler-auditor/_location /_' -i /etc/nginx/sites-available/taler-auditor

# TODO:
#enable exchange and config server to http://exchange.taler/
ln -s /etc/nginx/sites-available/taler-exchange /etc/nginx/sites-enabled/
sed 's/server_name localhost/server_name exchange.taler/' -i /etc/nginx/sites-available/taler-exchange
sed 's_location /taler-exchange/_location /_' -i /etc/nginx/sites-available/taler-exchange

# TODO:
#enable merchant and config server to http://merchant.taler/
ln -s /etc/nginx/sites-available/taler-merchant /etc/nginx/sites-enabled/
sed 's/server_name localhost/server_name merchant.taler/' -i /etc/nginx/sites-available/taler-merchant
sed 's_location /taler-merchant/_location /_' -i /etc/nginx/sites-available/taler-merchant

# TODO:
#set nginx user to root se we dont have problems reading sockets with root ownership
sed 's/^user www-data/user root/' -i /etc/nginx/nginx.conf

# TODO:
#notify all services that are exposed with other host
sed 's/X-Forwarded-Host "localhost"/X-Forwarded-Host $host/' -i /etc/nginx/sites-available/*

#run the http server as daemon
nginx

echo ----------------------------------------
read -rp "4/8 web interface exposed. Press any key to continue..."
echo ==========================================================================
echo ==========================================================================
echo ==========================================================================
echo "5/8 Setup BANK instance and some accounts"

#environment config for libeufin-sandbox tool
export LIBEUFIN_SANDBOX_DB_CONNECTION="postgresql:///sandbox"
export LIBEUFIN_SANDBOX_URL="http://localhost:5016/"
export LIBEUFIN_SANDBOX_USERNAME="admin"
export LIBEUFIN_SANDBOX_ADMIN_PASSWORD="bank"
export LIBEUFIN_SANDBOX_PASSWORD=$LIBEUFIN_SANDBOX_ADMIN_PASSWORD

#environment config for libeufin-nexus tool
export LIBEUFIN_NEXUS_DB_CONNECTION="postgresql:///nexus"
export LIBEUFIN_NEXUS_URL="http://localhost:5017/"
export LIBEUFIN_NEXUS_USERNAME="nexus_admin"
export LIBEUFIN_NEXUS_PASSWORD="secret_nexus"

# bank configuration
# * bank-deb-limit is how much the admin account balance can go negative
# * users-deb-limit is how much an account balance can go negative
# * with-sigup-bonus will give 100 to new signups
# * captcha-url is where the user going to complete wire transfers
libeufin-sandbox config \
    --bank-debt-limit 1000000 \
    --users-debt-limit 10000 \
    --with-signup-bonus \
    --currency $CURRENCY \
    --captcha-url http://bank.taler/ \
    default

# TODO:
#bank SPA configuration
# * bankendBaseURL points where the backend is located
# * allowRegistrations shows or hide the registration button in the login form
# * bankName is used in the title
mkdir /etc/libeufin/
cat >/etc/libeufin/demobank-ui-settings.js <<EOF
globalThis.talerDemobankSettings = {
  backendBaseURL: "http://bank.taler/demobanks/default/",
  allowRegistrations: true,
  bankName: "FSF Bank"
}
EOF

#setting up the bank with a default exchange so
#user will be able to withdraw using GNU Taler wallets
libeufin-sandbox default-exchange --demobank default http://exchange.taler/ payto://iban/$EXCHANGE_IBAN

# nexus configuration
libeufin-nexus superuser $LIBEUFIN_NEXUS_USERNAME --password $LIBEUFIN_NEXUS_PASSWORD

# start services
libeufin-sandbox serve --port 5016 --ipv4-only --no-localhost-only >log.sandbox 2>err.sandbox &
libeufin-nexus serve --port 5017 --ipv4-only --no-localhost-only >log.nexus 2>err.nexus &

echo "5/8 Waiting for nexus and sanbox to be ready"
grep -q "Application started:" <(tail -f err.sandbox -n +0)
grep -q "Application started:" <(tail -f err.nexus -n +0)

echo "5/8 Creating accounts"
LIBEUFIN_SANDBOX_USERNAME="exchange" LIBEUFIN_SANDBOX_PASSWORD="123" libeufin-cli sandbox demobank register \
    --iban $EXCHANGE_IBAN --name "Exchange company" --public
LIBEUFIN_SANDBOX_USERNAME="merchant" LIBEUFIN_SANDBOX_PASSWORD="123" libeufin-cli sandbox demobank register \
    --iban $MERCHANT_IBAN --name "Merchant company" --public
LIBEUFIN_SANDBOX_USERNAME="alice" LIBEUFIN_SANDBOX_PASSWORD="123" libeufin-cli sandbox demobank register \
    --iban $ALICE_IBAN --name "Alice" --no-public
LIBEUFIN_SANDBOX_USERNAME="bob" LIBEUFIN_SANDBOX_PASSWORD="123" libeufin-cli sandbox demobank register \
    --iban $BOB_IBAN --name "Bob" --no-public

echo "5/8 Creating the EBICs connection between sandbox and nexus"

#EBIC spec: https://www.ebics.org/
### open sandbox to nexus
libeufin-cli sandbox ebicshost create --host-id ebicHost
libeufin-cli sandbox demobank new-ebicssubscriber \
    --host-id ebicHost \
    --partner-id ebicPartner \
    --user-id ebicExchange \
    --bank-account exchange

### connection nexus to sandbox
libeufin-cli connections new-ebics-connection \
    --ebics-url http://localhost:5016/ebicsweb \
    --host-id ebicHost \
    --partner-id ebicPartner \
    --ebics-user-id ebicExchange \
    nexus-conn

libeufin-cli connections connect nexus-conn
libeufin-cli connections download-bank-accounts nexus-conn
libeufin-cli connections import-bank-account \
    --offered-account-id exchange \
    --nexus-bank-account-id nexus-exchange \
    nexus-conn

#Setup tasks sync sandbox state with nexus database
libeufin-cli accounts task-schedule nexus-exchange \
    --task-type=submit \
    --task-name=submit-payments-5secs \
    --task-cronspec='*/1 * * * *'

libeufin-cli accounts task-schedule nexus-exchange \
    --task-type=fetch \
    --task-name=fetch-5secs \
    --task-cronspec='*/1 * * * *' \
    --task-param-level=report \
    --task-param-range-type=latest

### configuration of nexus
echo "5/8 Creating nexus facade for the exchange"

#Expose Bank Integration API
#https://docs.taler.net/core/api-bank-integration.html
libeufin-cli facades new-taler-wire-gateway-facade \
    --currency $CURRENCY \
    --facade-name taler-exchange \
    nexus-conn nexus-exchange

#Setup a user to be able to acces the Bank Integration API
libeufin-cli users create exchange-nexus --password exchange-nexus-password
libeufin-cli permissions grant user exchange-nexus \
    facade taler-exchange \
    facade.talerwiregateway.transfer
libeufin-cli permissions grant user exchange-nexus \
    facade taler-exchange \
    facade.talerwiregateway.history

echo ----------------------------------------
read -rp "5/8 banking system ready. Press any key to continue..."
echo ==========================================================================
echo ==========================================================================
echo ==========================================================================
echo "6/8 Setup Exchange"

#Documentation: https://docs.taler.net/taler-exchange-manual.html

taler-config -s exchange -o master_public_key -V "$(taler-exchange-offline setup)"
taler-config -s exchange -o base_url -V http://exchange.taler/

#database location
taler-config -s exchangedb-postgres -o config -V postgres:///exchange
taler-config -s exchange-account-1 -o payto_uri -V "payto://iban/$EXCHANGE_IBAN?receiver-name=Exchanger"
taler-config -s exchange-account-1 -o enable_debit -V yes
taler-config -s exchange-account-1 -o enable_credit -V yes

#nexus connection
taler-config -s exchange-accountcredentials-1 -o wire_gateway_url -V http://localhost:5017/facades/taler-exchange/taler-wire-gateway/
taler-config -s exchange-accountcredentials-1 -o username -V exchange-nexus
taler-config -s exchange-accountcredentials-1 -o password -V exchange-nexus-password

#monetary policy
taler-config -s taler -o currency -V $CURRENCY
taler-config -s taler -o aml_threshold -V $CURRENCY:10000
taler-config -s taler -o currency_round_unit -V $CURRENCY:0.1

#Generate coins denominations from value 0.1 to 20
# * fees by operations: refresh, refund, deposit and withdraw
#   * no fee for refund, refresh and withdraw
#   * 0.1 fee for deposit
# * legal duration: defines for how long the exchange needs to keep records for this denominations (6 years)
# * spend duration: defines for how long clients have to spend these coins (2 years)
# * withdraw duration: defines for how long this can be withdrawn (7 days)

taler-harness deployment gen-coin-config \
    --min-amount $CURRENCY:0.1 \
    --max-amount $CURRENCY:20 >>/etc/taler/taler.conf

# override default withdraw duration to 1 year
for coinSection in $(taler-config --list-sections | grep COIN); do
    taler-config -s "$coinSection" -o duration_withdraw -V "1 year"
done

#create tables
taler-exchange-dbinit

#start crypto helpers
taler-exchange-secmod-eddsa -l log.secmod.eddsa -L debug &
taler-exchange-secmod-rsa -l log.secmod.rsa -L debug &
taler-exchange-secmod-cs -l log.secmod.cs -L debug &

#start http service
taler-exchange-httpd -l log.exchange -L debug &

echo "6/8 Waiting for exchange HTTP service"
sleep 1
grep -q "Updating keys of denomination" <(tail -F log.secmod.rsa -n +0)

echo "6/8 Enable exchange wire transfer"

#enable account and wire fee configuration
#in real world this should be done in a safe box
taler-exchange-offline \
    enable-account "$(taler-config -s exchange-account-1 -o payto_uri)" \
    global-fee 2023 $CURRENCY:0 $CURRENCY:0 $CURRENCY:0 1year 1year 10 \
    wire-fee 2023 iban $CURRENCY:0.1 $CURRENCY:0.1 \
    upload

#sync exchange config and upload signed values
taler-exchange-offline download sign upload

echo "6/8 Waiting for key signed"
curl --unix-socket /run/taler/exchange-httpd/exchange-http.sock \
    --max-time 2 \
    --retry-connrefused \
    --retry-delay 1 \
    --retry 10 \
    http://exchange.taler/keys &>/dev/null

#watches for incoming wire transfers from customers
taler-exchange-wirewatch -l log.wirewatch -L debug &

#executes outgoing wire transfers
taler-exchange-transfer -l log.transfer -L debug &

#aggregates and executes wire transfers
taler-exchange-aggregator -l log.aggregator -L debug &

#closes expired reserves
taler-exchange-closer -l log.closer -L debug &

echo ----------------------------------------
read -rp "6/8 exchange ready. Press any key to continue..."
echo ==========================================================================
echo ==========================================================================
echo ==========================================================================
echo "7/8 Setup auditor"

taler-config -s auditor -o base_url -V http://auditor.taler/
taler-config -s auditordb-postgres -o config -V postgres:///auditor

#add exchange into the auditor
taler-auditor-exchange -m "$(taler-config -s exchange -o master_public_key)" -u "$(taler-config -s exchange -o base_url)"

#create database tables
taler-auditor-dbinit

echo "7/8 Notify the exchange about the auditor"

#notify the exchange about the auditor
#in real world this should be done in a safe box
taler-exchange-offline enable-auditor "$(taler-auditor-offline setup)" "$(taler-config -s auditor -o base_url)" the_auditor upload

#start the http service
taler-auditor-httpd -l log.auditor -L debug &

echo ----------------------------------------
read -rp "7/8 auditor ready. Press any key to continue..."
echo ==========================================================================
echo ==========================================================================
echo ==========================================================================
echo "8/8 Setup merchant"

taler-config -s merchantdb-postgres -o config -V postgres:///merchant

taler-config -s merchant-exchange-fsf -o exchange_base_url -V "$(taler-config -s exchange -o base_url)"
taler-config -s merchant-exchange-fsf -o master_key -V "$(taler-config -s exchange -o master_public_key)"
taler-config -s merchant-exchange-fsf -o currency -V $CURRENCY

taler-config -s merchant-auditor-fsf -o auditor_base_url -V "$(taler-config -s auditor -o base_url)"
taler-config -s merchant-auditor-fsf -o auditor_key -V "$(taler-auditor-offline setup)"
taler-config -s merchant-auditor-fsf -o currency -V $CURRENCY

taler-merchant-dbinit

taler-merchant-httpd -a secret-token:secret -l log.merchant -L debug &

echo "8/8 creating the first instance"
sleep 1

#create a default instance
# * deposits will go to $MERCHANT_IBAN
# * name: FSF
# * password: secret
curl 'http://merchant.taler/management/instances' \
    --unix-socket /var/run/taler/merchant-httpd/merchant-http.sock \
    -X POST -H 'Authorization: Bearer secret-token:secret' \
    --data-raw '{"id":"default","accounts":[{"payto_uri":"payto://iban/'$MERCHANT_IBAN'?receiver-name=merchant"}],"default_pay_delay":{"d_us":7200000000},"default_wire_fee_amortization":1,"default_wire_transfer_delay":{"d_us":172800000000},"name":"FSF","email":"","default_max_deposit_fee":"'$CURRENCY':3","default_max_wire_fee":"'$CURRENCY':3","auth":{"method":"token","token":"secret-token:secret"},"address":{},"jurisdiction":{}}'

# create a product to be sold
curl 'http://merchant.taler/instances/default/private/products' \
    --unix-socket /var/run/taler/merchant-httpd/merchant-http.sock \
    -X POST -H 'Authorization: Bearer secret-token:secret' \
    -d @shirt.json

echo ----------------------------------------
read -rp "8/8 merchant ready. Press any key to close."
echo ==========================================================================
echo ==========================================================================
echo ==========================================================================
