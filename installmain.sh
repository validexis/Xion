#!/bin/bash
sudo apt update && apt upgrade -y
sudo apt install -y curl git jq lz4 build-essential

sudo rm -rf /usr/local/go
curl -Ls https://go.dev/dl/go1.23.0.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
eval $(echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh)
eval $(echo 'export PATH=$PATH:$HOME/go/bin' | tee -a $HOME/.profile)
echo "export PATH=$PATH:/usr/local/go/bin:/usr/local/bin:$HOME/go/bin" >> $HOME/.bash_profile
source $HOME/.bash_profile

cd $HOME
rm -rf xion
git clone https://github.com/burnt-labs/xion.git
cd xion
git checkout v14.0.0
make install

xiond init Node --chain-id=xion-mainnet-1

xiond config set client chain-id xion-mainnet-1
xiond config set client keyring-backend file
xiond config set client node tcp://localhost:26657

curl -Ls https://ss.xion.nodestake.org/genesis.json > $HOME/.xiond/config/genesis.json 
curl -Ls https://ss.xion.nodestake.org/addrbook.json > $HOME/.xiond/config/addrbook.json

seed="6df32f0e5142861ea9ddfdde0fdb50698bceb760@rpc.xion.nodestake.org:666"
sed -i.bak -e "s/^seed *=.*/seed = \"$seed\"/" ~/.xiond/config/config.toml
peers=$(curl -s https://ss.xion.nodestake.org/peers.txt)
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" ~/.xiond/config/config.toml

sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.0001uxion\"|" $HOME/.xiond/config/app.toml
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.xiond/config/config.toml
sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $HOME/.xiond/config/config.toml

sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.xiond/config/app.toml 
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.xiond/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"19\"/" $HOME/.xiond/config/app.toml

CUSTOM_PORT=162

sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:${CUSTOM_PORT}58\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:${CUSTOM_PORT}57\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:${CUSTOM_PORT}60\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:${CUSTOM_PORT}56\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":${CUSTOM_PORT}66\"%" $HOME/.xiond/config/config.toml
sed -i -e "s%^address = \"tcp://localhost:1317\"%address = \"tcp://localhost:${CUSTOM_PORT}17\"%; s%^address = \":8080\"%address = \":${CUSTOM_PORT}80\"%; s%^address = \"localhost:9090\"%address = \"localhost:${CUSTOM_PORT}90\"%; s%^address = \"localhost:9091\"%address = \"localhost:${CUSTOM_PORT}91\"%; s%^address = \"0.0.0.0:8545\"%address = \"0.0.0.0:${CUSTOM_PORT}45\"%; s%^ws-address = \"0.0.0.0:8546\"%ws-address = \"0.0.0.0:${CUSTOM_PORT}46\"%" $HOME/.xiond/config/app.toml

xiond config set client node tcp://localhost:${CUSTOM_PORT}57

sudo tee /etc/systemd/system/xiond.service > /dev/null <<EOF
[Unit]
Description=xiond Daemon
After=network-online.target

[Service]
User=$USER
ExecStart=$(which xiond) start
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

SNAP_NAME=$(curl -s https://ss.xion.nodestake.org/ | egrep -o ">20.*\.tar.lz4" | tr -d ">")
curl -o - -L https://ss.xion.nodestake.org/${SNAP_NAME}  | lz4 -c -d - | tar -x -C $HOME/.xiond

sudo systemctl daemon-reload
sudo systemctl enable xiond
sudo systemctl restart xiond && sudo journalctl -u xiond -fo cat
