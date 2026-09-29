#!/bin/bash
# ==========================================
# AUTO SCRIPT LBJ TUNNELING (CORE + MENU)
# OS Support: Debian 11/12 & Ubuntu 20.04+
# ==========================================

G="\e[92m"; O="\e[93m"; C="\e[36m"; R="\e[91m"; NC="\e[0m"

clear
echo -e "${C}===============================================${NC}"
echo -e "${G}     AUTO INSTALLER LBJ TUNNELING SCRIPT       ${NC}"
echo -e "${C}===============================================${NC}\n"

# 1. INPUT DOMAIN
read -p "Masukkan Domain Anda (contoh: vpn.domain.com): " domain_input </dev/tty
if [[ -z "$domain_input" ]]; then
    echo -e "${R}Domain tidak boleh kosong! Instalasi dibatalkan.${NC}"; exit 1
fi
echo -e "\n${O}Domain Anda: ${domain_input}${NC}"
echo -e "${G}Memulai Instalasi Sistem... Jangan tutup terminal!${NC}\n"; sleep 2

# 2. UPDATE OS & INSTALL DEPENDENCIES
echo -e "${C}[1/10] Menginstal Dependensi Sistem...${NC}"
apt-get update -y && apt-get upgrade -y
apt-get install -y bzip2 gzip coreutils curl unzip wget socat bc jq chrony sqlite3 vnstat iptables iptables-persistent net-tools nginx certbot ufw dropbear stunnel4 python3

# 3. SETUP DIREKTORI & DOMAIN
echo -e "${C}[2/10] Menyiapkan Direktori & File...${NC}"
mkdir -p /etc/vpn
mkdir -p /etc/xray
mkdir -p /var/log/xray
touch /var/log/xray/access.log && touch /var/log/xray/error.log
chmod 777 /var/log/xray/*.log
echo "$domain_input" > /etc/vpn/domain.txt
echo "LBJ-Server" > /etc/vpn/client.txt
date -d "+360 days" +"%Y-%m-%d" > /etc/vpn/exp.txt
timedatectl set-timezone Asia/Jakarta

# 4. GENERATE SSL (ACME.SH)
echo -e "${C}[3/10] Menerbitkan Sertifikat SSL...${NC}"
systemctl stop nginx
curl -sL https://get.acme.sh | sh -s email=admin@${domain_input}
/root/.acme.sh/acme.sh --server letsencrypt --register-account -m admin@${domain_input}
/root/.acme.sh/acme.sh --issue -d ${domain_input} --standalone -k ec-256
/root/.acme.sh/acme.sh --installcert -d ${domain_input} --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc
chmod 644 /etc/xray/xray.crt && chmod 644 /etc/xray/xray.key

# 5. INSTALL XRAY CORE
echo -e "${C}[4/10] Menginstal Xray Core...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
chown -R root:root /etc/xray && chmod 755 /etc/xray

# 6. SETUP SSH (DROPBEAR, STUNNEL, WEBSOCKET)
echo -e "${C}[5/10] Memasang Dropbear, Stunnel & WebSocket...${NC}"
sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/g' /etc/default/dropbear
sed -i 's/DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS="-p 143"/g' /etc/default/dropbear
echo "/bin/false" >> /etc/shells
systemctl restart dropbear && systemctl enable dropbear

cat > /etc/stunnel/stunnel.conf << END
cert = /etc/xray/xray.crt
key = /etc/xray/xray.key
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[dropbear]
accept = 8443
connect = 127.0.0.1:109
END
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
systemctl restart stunnel4 && systemctl enable stunnel4

cat > /usr/local/bin/ws-dropbear << 'END'
#!/usr/bin/python3
import socket, threading, select
LISTEN_PORT = 8080
FORWARD_PORT = 109
FORWARD_IP = '127.0.0.1'
BUFLEN = 4096

def handle_client(client_socket):
    try:
        remote_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        remote_socket.connect((FORWARD_IP, FORWARD_PORT))
        request = client_socket.recv(BUFLEN)
        if request:
            req_str = request.decode('utf-8', errors='ignore')
            if "HTTP" in req_str:
                response = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"
                client_socket.send(response.encode())
            else:
                remote_socket.send(request)
        sockets = [client_socket, remote_socket]
        while True:
            r, _, _ = select.select(sockets, [], [])
            if client_socket in r:
                data = client_socket.recv(BUFLEN)
                if not data: break
                remote_socket.send(data)
            if remote_socket in r:
                data = remote_socket.recv(BUFLEN)
                if not data: break
                client_socket.send(data)
    except: pass
    finally:
        client_socket.close()
        remote_socket.close()

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', LISTEN_PORT))
    server.listen(100)
    while True:
        client, addr = server.accept()
        threading.Thread(target=handle_client, args=(client,)).start()

if __name__ == '__main__': main()
END
chmod +x /usr/local/bin/ws-dropbear
cat > /etc/systemd/system/ws-dropbear.service << END
[Unit]
Description=Python WebSocket Dropbear
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/ws-dropbear
Restart=always
[Install]
WantedBy=multi-user.target
END
systemctl daemon-reload && systemctl enable ws-dropbear && systemctl start ws-dropbear

# 7. SETUP DATABASE SQLITE3
echo -e "${C}[6/10] Membangun Database SQLite...${NC}"
DB_FILE="/etc/vpn/database.db"
sqlite3 "$DB_FILE" "CREATE TABLE IF NOT EXISTS users (username TEXT, protocol TEXT, exp_date TEXT, ip_limit INTEGER DEFAULT 0, password TEXT, quota INTEGER DEFAULT 0, status TEXT DEFAULT 'active');"

# 8. MENGUNDUH FILE DARI GITHUB
echo -e "${C}[7/10] Mengunduh Modul & Menu LBJ...${NC}"

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!! GANTI BARIS DI BAWAH INI SESUAI REPOSITORY GITHUB ANDA !!!
REPO_URL="https://raw.githubusercontent.com/efrossey/lbj-tunneling/refs/heads/main"
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

cd /usr/bin
wget -O menu "${REPO_URL}/menu" && chmod +x menu
wget -O m-ssh "${REPO_URL}/m-ssh" && chmod +x m-ssh
wget -O m-vmess "${REPO_URL}/m-vmess" && chmod +x m-vmess
wget -O m-vless "${REPO_URL}/m-vless" && chmod +x m-vless
wget -O m-trojan "${REPO_URL}/m-trojan" && chmod +x m-trojan

echo -e "${C}[8/10] Menerapkan Konfigurasi Xray & Nginx...${NC}"
wget -O /etc/xray/config.json "${REPO_URL}/config.json"
wget -O /etc/nginx/conf.d/xray.conf "${REPO_URL}/xray.conf"

sed -i "s/DOMAIN_VPS_ANDA/${domain_input}/g" /etc/nginx/conf.d/xray.conf
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

# 9. RESTART SERVICES
echo -e "${C}[9/10] Konfigurasi Akhir & Restart Service...${NC}"
systemctl enable xray && systemctl restart xray
systemctl enable nginx && systemctl restart nginx

# 10. SETUP AUTO-MENU & REBOOT
echo -e "${C}[10/10] Menyiapkan Auto-Start Menu & Reboot...${NC}"
if ! grep -q "menu" /root/.profile; then
    echo 'clear' >> /root/.profile
    echo 'menu' >> /root/.profile
fi

clear
echo -e "${C}===============================================${NC}"
echo -e "${G}       INSTALASI LBJ TUNNELING SELESAI         ${NC}"
echo -e "${C}===============================================${NC}"
echo -e "Domain     : ${O}${domain_input}${NC}"
echo -e "Sertifikat : ${G}Sukses Terbit (ECC)${NC}"
echo -e "${C}===============================================${NC}"
echo -e "${O}VPS akan otomatis direboot dalam 5 detik...${NC}"
echo -e "${C}===============================================${NC}"
rm -f /root/install.sh
sleep 5
reboot
