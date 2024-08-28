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

        # Обновление прав доступа
        update_permissions "$site_path"

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
