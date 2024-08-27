#!/bin/bash

# Пути для проверки
BASE_PATH="/run/media/deck/SN512/SERVER"
DOMAIN_PATH="${BASE_PATH}/DOMAINS/rrr.local"
INDEX_PATH="${DOMAIN_PATH}/index.php"

# Проверка пользователя и группы
check_user_group() {
    path=$1
    expected_user=$2
    expected_group=$3

    user=$(stat -c '%U' $path)
    group=$(stat -c '%G' $path)

    if [[ "$user" != "$expected_user" || "$group" != "$expected_group" ]]; then
        echo "Ошибка: Неправильные владелец или группа для $path. Ожидалось $expected_user:$expected_group, но найдено $user:$group."
    else
        echo "ОК: Владелец и группа для $path настроены верно."
    fi
}

# Проверка прав доступа
check_permissions() {
    path=$1
    expected_perms=$2

    perms=$(stat -c '%a' $path)

    if [[ "$perms" != "$expected_perms" ]]; then
        echo "Ошибка: Неправильные права для $path. Ожидалось $expected_perms, но найдено $perms."
    else
        echo "ОК: Права доступа для $path настроены верно."
    fi
}

# Проверка процессов
check_process() {
    process=$1
    user=$2

    if pgrep -u $user $process > /dev/null; then
        echo "ОК: Процесс $process работает под пользователем $user."
    else
        echo "Ошибка: Процесс $process не найден под пользователем $user."
    fi
}

# Проверка монтирования
check_mount() {
    mount_point=$1

    if mount | grep $mount_point > /dev/null; then
        echo "ОК: Файловая система $mount_point смонтирована."
    else
        echo "Ошибка: Файловая система $mount_point не смонтирована."
    fi
}

# Выполнение проверок
echo "Проверка прав доступа и владельцев:"
check_user_group $BASE_PATH "deck" "webdev"
check_permissions $BASE_PATH "755"
check_user_group $DOMAIN_PATH "deck" "webdev"
check_permissions $DOMAIN_PATH "755"
check_user_group $INDEX_PATH "deck" "webdev"
check_permissions $INDEX_PATH "755"

echo ""
echo "Проверка процессов:"
check_process "nginx" "deck"
check_process "php-fpm" "nobody"

echo ""
echo "Проверка монтирования:"
check_mount "/run/media/deck/SN512"

echo "Проверка завершена."

