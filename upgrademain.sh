#!/bin/bash
cd $HOME
rm -rf xion
git clone https://github.com/burnt-labs/xion.git
cd xion
git checkout v14.0.0
make install

sudo systemctl restart xiond && sudo journalctl -u xiond -fo cat
