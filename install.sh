#!/bin/bash

# Warna
G="\e[92m"
R="\e[91m"
C="\e[36m"
NC="\e[0m"

# 1. Bersihkan layar dan minta input domain terlebih dahulu
clear
echo -e "${C}===============================================${NC}"
echo -e "${G}         SETUP DOMAIN LBJ TUNNELING            ${NC}"
echo -e "${C}===============================================${NC}"
echo -e ""
# Tambahan </dev/tty memastikan input tidak terlewat jika diinstal via bash pipe
read -p "Masukkan Domain Anda (contoh: vpn.domain.com): " domain_input </dev/tty

echo -e "\n${G}Domain berhasil disimpan: ${domain_input}${NC}\n"

# 2. Proses Install Paket Wajib (Proses akan terlihat di layar)
echo -e "${C}===============================================${NC}"
echo -e "${G}     INSTALLING DEPENDENCIES (MOHON TUNGGU)    ${NC}"
echo -e "${C}===============================================${NC}"
apt-get update -y
apt-get install -y sqlite3 wget curl vnstat

# 3. Buat folder dan simpan domain
mkdir -p /etc/vpn
echo "$domain_input" > /etc/vpn/domain.txt

# 4. Download modul dari GitHub
echo -e "\n${C}===============================================${NC}"
echo -e "${G}      MENDOWNLOAD MODUL DARI GITHUB...         ${NC}"
echo -e "${C}===============================================${NC}"

# PASTIKAN MENGGANTI URL DI BAWAH INI DENGAN REPO ANDA
REPO_URL="https://raw.githubusercontent.com/efrossey/lbj-tunneling/refs/heads/main"

cd /usr/bin
# Menghilangkan opsi -q agar progres download (100%) terlihat jelas
wget -O menu "${REPO_URL}/menu" && chmod +x menu
wget -O m-ssh "${REPO_URL}/m-ssh" && chmod +x m-ssh
wget -O m-vmess "${REPO_URL}/m-vmess" && chmod +x m-vmess

# 5. Setup Database Pertama Kali
echo -e "\n${G}Menyiapkan Database...${NC}"
if [ ! -f /etc/vpn/database.db ]; then
    sqlite3 /etc/vpn/database.db "CREATE TABLE IF NOT EXISTS users (username TEXT, protocol TEXT, exp_date TEXT, ip_limit INTEGER DEFAULT 0, password TEXT, quota INTEGER DEFAULT 0, status TEXT DEFAULT 'active');"
fi

if [ ! -f /etc/vpn/client.txt ]; then 
    echo "LBJ-Server" > /etc/vpn/client.txt
fi

echo -e "\n${C}===============================================${NC}"
echo -e "${G}               INSTALASI SELESAI               ${NC}"
echo -e "${C}===============================================${NC}"
echo -e "Ketik ${G}menu${NC} di terminal untuk masuk ke panel."
