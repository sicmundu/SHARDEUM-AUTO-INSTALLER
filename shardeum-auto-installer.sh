#!/bin/bash

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Загрузка конфигурационного файла с GitHub
CONFIG_URL="https://raw.githubusercontent.com/sicmundu/SHARDEUM-AUTO-INSTALLER/main/config.sh"
curl -O $CONFIG_URL

# Использование переменных из конфигурационного файла
source config.sh

# Приветственное сообщение
echo -e "${GREEN}Добро пожаловать в автоматический установщик Shardeum Node от p0k${NC}"

# ASCII Art
echo -e "${GREEN}"
cat << "EOF"
  /$$$$$$  /$$   /$$  /$$$$$$  /$$$$$$$  /$$$$$$$  /$$$$$$$$ /$$   /$$ /$$      /$$
 /$$__  $$| $$  | $$ /$$__  $$| $$__  $$| $$__  $$| $$_____/| $$  | $$| $$$    /$$$
| $$  \__/| $$  | $$| $$  \ $$| $$  \ $$| $$  \ $$| $$      | $$  | $$| $$$$  /$$$$
|  $$$$$$ | $$$$$$$$| $$$$$$$$| $$$$$$$/| $$  | $$| $$$$$   | $$  | $$| $$ $$/$$ $$
 \____  $$| $$__  $$| $$__  $$| $$__  $$| $$  | $$| $$__/   | $$  | $$| $$  $$$| $$
 /$$  \ $$| $$  | $$| $$  | $$| $$  \ $$| $$  | $$| $$      | $$  | $$| $$\  $ | $$
|  $$$$$$/| $$  | $$| $$  | $$| $$  | $$| $$$$$$$/| $$$$$$$$|  $$$$$$/| $$ \/  | $$
 \______/ |__/  |__/|__/  |__/|__/  |__/|_______/ |________/ \______/ |__/     |__/
EOF
echo -e "${NC}"
sleep 2

# Функция для отображения анимации спиннера
show_spinner() {
    local -r FRAMES='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local -r NUMBER_OF_FRAMES=${#FRAMES}
    local -r INTERVAL=0.1
    local -r CMDS_PID=$1

    local frame=0
    while kill -0 "$CMDS_PID" &>/dev/null; do
        # Выводим анимацию только в терминал, не в лог-файл
        echo -ne "${FRAMES:frame++%NUMBER_OF_FRAMES:1}" > /dev/tty
        sleep $INTERVAL
        echo -ne "\r" > /dev/tty
    done
}




# Функция для проверки успешности выполнения команды
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Успешно!${NC}"
    else
        echo -e "${RED}Не удалось.${NC}"
        exit 1
    fi
}

# Проверка, запущен ли скрипт с правами root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Этот скрипт должен быть запущен с правами root${NC}"
   exit 1
fi

# Проверка интернет-соединения
if ! ping -c 1 8.8.8.8 &> /dev/null; then
    echo -e "${RED}Требуется интернет-соединение, но оно недоступно.${NC}"
    exit 1
fi


# Проверка наличия curl
if ! command -v curl &> /dev/null; then
    echo "Установка curl..."
    sudo apt-get install -y curl
    check_success
fi


# Установка Docker, если не установлен
if ! command -v docker &> /dev/null; then
    echo "Установка Docker..."
    (sudo apt-get update && sudo apt-get install -y docker.io) & show_spinner $!
    check_success
    sleep 2
else
     echo -e "${YELLOW}Docker уже установлен.${NC}"
    sleep 1
fi

# Start Docker if not running
if ! systemctl is-active --quiet docker; then
    echo "Запуск Docker..."
    (sudo systemctl start docker) & show_spinner $!
    check_success
    sleep 2
else
    echo -e "${YELLOW}Docker уже запущен.${NC}"
    sleep 1
fi

# Add user to docker group to avoid permission issues
if ! groups $USER | grep &>/dev/null '\bdocker\b'; then
    echo "Добавление текущего пользователя в группу docker..."
    (sudo usermod -aG docker $USER) & show_spinner $!
    check_success
    sleep 2
else
    echo -e "${YELLOW}Пользователь уже в группе docker.${NC}"
    sleep 1
fi    

# Install docker-compose if not installed
if ! command -v docker-compose &> /dev/null; then
    echo "Установка docker-compose..."
    (sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose) & show_spinner $!
    check_success
    sleep 2
else
    echo -e "${YELLOW}docker-compose уже установлен.${NC}"
    sleep 1
fi


# Загрузка и запуск установщика Shardeum
echo "Загрузка installer.sh..."
curl -O ${SHARDEUM_INSTALLER_URL}
if [ $? -eq 0 ]; then
    echo "Загрузка успешна."
    sleep 1
else
    echo "Не удалось загрузить installer.sh."
    sleep 1
    exit 1
fi

echo "Установка прав на выполнение для installer.sh..."
chmod +x installer.sh
if [ $? -eq 0 ]; then
    echo "Права успешно установлены."
    sleep 1
else
    echo "Не удалось установить права."
    sleep 1
    exit 1
fi

# Запрос ввода пользователя
read -p "Запуская этот установщик, вы соглашаетесь с тем, что команда Shardeum сможет собирать эти данные. (Y/n)? " COLLECT_DATA
read -p "Хотите запустить веб-панель управления? (Y/n): " RUN_DASHBOARD
read -p "Установите пароль для доступа к панели управления: " DASHBOARD_PASSWORD
read -p "Введите порт (1025-65536) для доступа к веб-панели управления (по умолчанию 8080): " DASHBOARD_PORT
read -p "Если вы хотите установить явный внешний IP, введите IPv4-адрес (по умолчанию=авто): " EXTERNAL_IP
read -p "Если вы хотите установить явный внутренний IP, введите IPv4-адрес (по умолчанию=авто): " INTERNAL_IP
read -p "Введите первый порт (1025-65536) для p2p-сообщения (по умолчанию 9001): " P2P_PORT1
read -p "Введите второй порт (1025-65536) для p2p-сообщения (по умолчанию 10001): " P2P_PORT2
read -p "Какой базовый каталог должен использовать узел (по умолчанию ~/.shardeum): " BASE_DIRECTORY

# Запуск установщика с вводом пользователя в фоновом режиме
echo "Запуск установщика..."
{
    echo "$COLLECT_DATA"
    echo "$RUN_DASHBOARD"
    echo "$DASHBOARD_PASSWORD"
    echo "$DASHBOARD_PORT"
    echo "$EXTERNAL_IP"
    echo "$INTERNAL_IP"
    echo "$P2P_PORT1"
    echo "$P2P_PORT2"
    echo "$BASE_DIRECTORY"
} | nohup ./installer.sh > installer.log 2>&1 &


# Получение PID фонового процесса
INSTALLER_PID=$!

# Показать спиннер во время работы установщика
echo "Установка.."
show_spinner $INSTALLER_PID


# Получить IP-адрес сервера
SERVER_IP=$(curl -s https://ipinfo.io/ip)
if [ -z "$SERVER_IP" ]; then
    SERVER_IP="localhost"
fi

# Проверка, успешно ли завершился установщик
wait $INSTALLER_PID
INSTALLER_EXIT_CODE=$?
if [ $INSTALLER_EXIT_CODE -eq 0 ]; then
    # Отобразить ссылку для доступа к GUI
    echo -e "${YELLOW}IP-адрес сервера: ${SERVER_IP}${NC}"
    echo -e "${GREEN}Установка успешно завершена!${NC}"

    # Отобразить ссылку для продолжения установки
    echo -e "${YELLOW}Перейдите по адресу https://docs.shardeum.org/node/run/validator#step-4-open-validator-gui для дальнейших шагов установки.${NC}"
else
    echo "Установка не удалась с кодом выхода $INSTALLER_EXIT_CODE."
fi
