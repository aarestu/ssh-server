#!/bin/bash
if [ "${EUID}" -ne 0 ]; then
  echo "You need to run this script as root"
  exit 1
fi

# set time GMT +7
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# set locale
sed -i 's/AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config

# install service software
apt-get --reinstall --fix-missing install -y screen wget
echo "clear" >>.profile
echo "neofetch" >>.profile

# Edit file /etc/systemd/system/rc-local.service
cat >/etc/systemd/system/rc-local.service <<-END
[Unit]
  Description=/etc/rc.local
  ConditionPathExists=/etc/rc.local
[Service]
  Type=forking
  ExecStart=/etc/rc.local start
  TimeoutSec=0
  StandardOutput=tty
  RemainAfterExit=yes
  SysVStartPriority=99
[Install]
  WantedBy=multi-user.target
END

# nano /etc/rc.local
cat >/etc/rc.local <<-END
#!/bin/sh -e
# rc.local
# By default this script does nothing.
exit 0
END

# Ubah izin akses
chmod +x /etc/rc.local

# enable rc local
systemctl enable rc-local
systemctl start rc-local.service

# install dropbear
sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=143/g' /etc/default/dropbear
echo "/bin/false" >>/etc/shells
echo "/usr/sbin/nologin" >>/etc/shells
/etc/init.d/dropbear restart

# install badvpn
curl -o /usr/bin/badvpn-udpgw https://raw.githubusercontent.com/powermx/badvpn/master/badvpn-udpgw64
chmod +x /usr/bin/badvpn-udpgw

sed -i '$ i\screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7100 --max-clients 500' /etc/rc.local
sed -i '$ i\screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7200 --max-clients 500' /etc/rc.local
sed -i '$ i\screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500' /etc/rc.local

screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7100 --max-clients 500
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7200 --max-clients 500
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500

# install ws

cat >/etc/systemd/system/ws-non-tls.service <<-END
[Unit]
  Description=Python Proxy Mod WS
  Documentation=https://t.me/aarestu
  After=network.target nss-lookup.target

[Service]
  Type=simple
  User=root
  CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
  AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
  NoNewPrivileges=true
  ExecStart=/usr/bin/python3 -O /usr/local/bin/ws-non-tls.py 80
  Restart=on-failure

[Install]
  WantedBy=multi-user.target
END

cat >/etc/systemd/system/ws-non-tls.service <<-END
[Unit]
  Description=Python Proxy Mod WS
  Documentation=https://t.me/aarestu
  After=network.target nss-lookup.target

[Service]
  Type=simple
  User=root
  CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
  AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
  NoNewPrivileges=true
  ExecStart=/usr/bin/python3 -O /usr/local/bin/ws-tls.py 443
  Restart=on-failure

[Install]
  WantedBy=multi-user.target
END


# enable ws
systemctl enable ws-non-tls
systemctl enable ws-tls
systemctl start ws-non-tls.service
systemctl start ws-tls.service

echo "DONE!"