#!/bin/bash

# Базовый путь
BASE_PATH="/run/media/deck/SN512/SERVER/DOMAINS"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Проверка пользователя и группы
check_user_group() {
    path=$1
    expected_user=$2
    expected_group=$3

    user=$(stat -c '%U' "$path")
    group=$(stat -c '%G' "$path")

    if [[ "$user" != "$expected_user" || "$group" != "$expected_group" ]]; then
        echo -e "${RED}Ошибка: Неправильные владелец или группа для $path. Ожидалось $expected_user:$expected_group, но найдено $user:$group.${NC}"
    else
        echo -e "${GREEN}ОК: Владелец и группа для $path настроены верно.${NC}"
    fi
}

# Проверка прав доступа
check_permissions() {
    path=$1
    expected_perms=$2

    perms=$(stat -c '%a' "$path")

    if [[ "$perms" != "$expected_perms" ]]; then
        echo -e "${RED}Ошибка: Неправильные права для $path. Ожидалось $expected_perms, но найдено $perms.${NC}"
    else
        echo -e "${GREEN}ОК: Права доступа для $path настроены верно.${NC}"
    fi
}

# Проверка процессов
check_process() {
    process=$1
    expected_user=$2

    actual_user=$(ps aux | grep "$process" | grep -v grep | awk '{print $1}' | head -n 1)

    if [[ -z "$actual_user" ]]; then
        echo -e "${RED}Ошибка: Процесс $process не найден.${NC}"
    elif [[ "$actual_user" != "$expected_user" ]]; then
        echo -e "${RED}Ошибка: Процесс $process работает под пользователем $actual_user, ожидалось $expected_user.${NC}"
    else
        echo -e "${GREEN}ОК: Процесс $process работает под пользователем $expected_user.${NC}"
    fi
}

# Проверка монтирования
check_mount() {
    mount_point=$1

    if mount | grep "$mount_point" > /dev/null; then
        echo -e "${GREEN}ОК: Файловая система $mount_point смонтирована.${NC}"
    else
        echo -e "${RED}Ошибка: Файловая система $mount_point не смонтирована.${NC}"
    fi
}

# Обновление прав доступа
update_permissions() {
    sudo chown -R deck:webdev "$1"
    sudo chmod -R 755 "$1"
}

# Исправление прав доступа для системных директорий
fix_system_permissions() {
    sudo chmod 755 /run/media
    sudo chmod 755 /run/media/deck
}

# Меню выбора
while true; do
    echo "Выберите опцию:"
    echo "1 - Выполнить проверку"
    echo "2 - Исправить права доступа"
    echo "0 - Выход"

    read -rp "Введите номер опции: " option

    if [[ "$option" == "1" ]]; then
        # Выполнение проверок для всех сайтов
        for site_path in "$BASE_PATH"/*; do
            if [ -d "$site_path" ]; then
                echo "Проверка сайта: $(basename "$site_path")"

                check_user_group "$site_path" "deck" "webdev"
                check_permissions "$site_path" "755"

                index_path="$site_path/index.php"
                if [ -f "$index_path" ]; then
                    check_user_group "$index_path" "deck" "webdev"
                    check_permissions "$index_path" "755"
                else
                    echo -e "${RED}Ошибка: index.php не найден в $site_path.${NC}"
                fi

                echo ""
            fi
        done

        echo "Проверка процессов:"
        check_process "nginx" "http"
        check_process "php-fpm" "deck"

        echo ""
        echo "Проверка монтирования:"
        check_mount "/run/media/deck/SN512"

        echo "Проверка завершена."

    elif [[ "$option" == "2" ]]; then
        # Обновление прав доступа для всех сайтов
        for site_path in "$BASE_PATH"/*; do
            if [ -d "$site_path" ]; then
                echo "Исправление прав доступа для сайта: $(basename "$site_path")"
                update_permissions "$site_path"
            fi
        done

        # Исправление прав доступа для системных директорий
        echo "Исправление прав доступа для системных директорий:"
        fix_system_permissions

        echo "Исправление завершено."

    elif [[ "$option" == "0" ]]; then
        echo "Выход из скрипта."
        break
    else
        echo -e "${RED}Ошибка: Неверная опция.${NC}"
    fi

    echo "" # Добавляем пустую строку перед повторным показом меню
done
