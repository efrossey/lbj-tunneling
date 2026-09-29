#!/bin/bash

# Warna
G="\e[92m"
R="\e[91m"
C="\e[36m"
NC="\e[0m"

# Membuat direktori sistem dasar
mkdir -p /etc/vpn

clear
echo -e "${C}===============================================${NC}"
echo -e "${G}         SETUP DOMAIN LBJ TUNNELING            ${NC}"
echo -e "${C}===============================================${NC}"
echo -e ""
read -p "Masukkan Domain Anda (contoh: vpn.domain.com): " domain_input

# Menyimpan domain ke file yang dibaca oleh skrip menu
echo "$domain_input" > /etc/vpn/domain.txt

echo -e "\n${G}Domain berhasil disimpan: ${domain_input}${NC}\n"
echo -e "Memulai download modul skrip LBJ Tunneling..."

# URL RAW dari GitHub Anda (JANGAN LUPA DIGANTI)
REPO_URL="https://raw.githubusercontent.com/USERNAME-GITHUB-ANDA/NAMA-REPO-ANDA/main"

# Proses Download & Pemasangan Izin Eksekusi
cd /usr/bin
wget -qO menu "${REPO_URL}/menu" && chmod +x menu
wget -qO m-ssh "${REPO_URL}/m-ssh" && chmod +x m-ssh
wget -qO m-vmess "${REPO_URL}/m-vmess" && chmod +x m-vmess

# Membuat struktur database pertama kali jika belum ada
if [ ! -f /etc/vpn/database.db ]; then
    sqlite3 /etc/vpn/database.db "CREATE TABLE IF NOT EXISTS users (username TEXT, protocol TEXT, exp_date TEXT, ip_limit INTEGER DEFAULT 0, password TEXT, quota INTEGER DEFAULT 0, status TEXT DEFAULT 'active');"
fi

# Membuat file default client name jika belum ada
if [ ! -f /etc/vpn/client.txt ]; then 
    echo "LBJ-Server" > /etc/vpn/client.txt
fi

echo -e "\n${C}===============================================${NC}"
echo -e "${G}               INSTALASI SELESAI               ${NC}"
echo -e "${C}===============================================${NC}"
echo -e "Ketik ${G}menu${NC} di terminal untuk masuk ke panel."
