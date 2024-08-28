#!/bin/bash

# Функция для проверки наличия Distrobox
check_distrobox_installed() {
    if ! command -v distrobox &> /dev/null; then
        echo "Ошибка: Distrobox не установлен. Пожалуйста, установите Distrobox и создайте контейнер с Ubuntu 20.04."
        exit 1
    fi
}

# Функция для проверки и запуска контейнера Distrobox
start_distrobox() {
    if [ "$IS_CONTAINER" == "true" ]; then
        echo "Вы находитесь внутри контейнера Distrobox. Пропускаем проверку контейнера."
        return
    fi

    distrobox_list=$(distrobox list | grep ubuntu-20-04)
    if [ -z "$distrobox_list" ]; then
        echo "Ошибка: Контейнер 'ubuntu-20-04' не найден. Пожалуйста, создайте контейнер с Ubuntu 20.04."
        exit 1
    fi

    echo "Проверяю, запущен ли контейнер 'ubuntu-20-04'..."
    container_status=$(distrobox status ubuntu-20-04 | grep Running)
    if [ -z "$container_status" ]; then
        echo "Контейнер 'ubuntu-20-04' не запущен. Запускаю его..."
        distrobox start ubuntu-20-04
    fi
}

# Функция для получения установленных версий PHP
get_installed_php_versions() {
    if [ "$IS_CONTAINER" == "true" ]; then
        php_versions=$(ls /usr/sbin/php-fpm* 2>/dev/null | sed 's/.*php-fpm\([0-9\.]*\)/\1/' | sort -u)
    else
        php_versions=$(distrobox enter ubuntu-20-04 -- bash -c "ls /usr/sbin/php-fpm* 2>/dev/null | sed 's/.*php-fpm\([0-9\.]*\)/\1/' | sort -u")
    fi
    echo "$php_versions"
}

# Функция для получения текущей версии PHP
get_current_php_version() {
    if [ "$IS_CONTAINER" == "true" ]; then
        php_version=$(php -r 'echo PHP_VERSION;' | grep -oP '^[0-9]+\.[0-9]+')
    else
        php_version=$(distrobox enter ubuntu-20-04 -- bash -c "php -r 'echo PHP_VERSION;' | grep -oP '^[0-9]+\.[0-9]+'")
    fi
    echo "$php_version"
}

# Функция для добавления записи в /etc/hosts
add_host_entry() {
    local site_name=$1
    if ! grep -q "$site_name" /etc/hosts; then
        echo "127.0.0.1 $site_name" | sudo tee -a /etc/hosts > /dev/null
        echo "Запись $site_name добавлена в /etc/hosts"
    else
        echo "Запись $site_name уже существует в /etc/hosts"
    fi
}

# Функция для удаления записи из /etc/hosts
remove_host_entry() {
    local site_name=$1
    sudo sed -i "/$site_name/d" /etc/hosts
    echo "Запись $site_name удалена из /etc/hosts"
}

# Функция для показа главного меню
show_menu() {
    clear
    echo "Выберите действие:"
    echo "1 - Управление PHP-FPM"
    echo "2 - Управление сайтами"
    echo "8 - Перезагрузка nginx"
    echo "9 - Страница с подсказками"
    echo "0 - Выход"
}

# Функция для управления PHP-FPM
manage_php() {
    clear

    # Получаем установленные версии PHP
    php_versions=$(get_installed_php_versions)

    if [ -z "$php_versions" ]; then
        echo "Ошибка: Не удалось определить установленные версии PHP."
        echo "Нажмите любую клавишу для продолжения..."
        read -n 1 -s
        return
    fi

    echo "Выберите версию PHP:"
    select php_version in $php_versions; do
        if [ -n "$php_version" ]; then
            break
        else
            echo "Неверный выбор."
        fi
    done

    echo "Останавливаю все процессы PHP..."
    if [ "$IS_CONTAINER" == "true" ]; then
        pkill php
    else
        distrobox enter ubuntu-20-04 -- sudo pkill php
    fi

    echo "Запускаю PHP-FPM версии $php_version в контейнере 'ubuntu-20-04'..."
    if [ "$IS_CONTAINER" == "true" ]; then
        sudo php-fpm$php_version -D
    else
        distrobox enter ubuntu-20-04 -- sudo php-fpm$php_version -D
    fi

    echo "PHP-FPM $php_version запущен."
    echo "Нажмите любую клавишу для продолжения..."
    echo ""
    echo ""
    read -n 1 -s
}

# Функция для управления сайтами
manage_sites() {
    clear
    echo "Управление сайтами:"
    echo "1 - Список сайтов"
    echo "2 - Создать сайт"
    echo "3 - Редактировать конфиг сайта"
    echo "4 - Удалить сайт"
    echo "0 - Вернуться в главное меню"

    read -p "Выберите действие: " action

    case $action in
        1)
            list_sites
            ;;
        2)
            create_site
            ;;
        3)
            edit_site_config
            ;;
        4)
            delete_site
            ;;
        0)
            return
            ;;
        *)
            echo "Неверный выбор."
            ;;
    esac
}

# Функция для показа списка сайтов
list_sites() {
    clear
    echo "Список сайтов:"
    for site in /run/media/deck/SN512/SERVER/DOMAINS/*; do
        if [ -d "$site" ]; then
            site_name=$(basename "$site")
            config_file="/run/media/deck/SN512/SERVER/nginx_configx/$site_name.conf"
            if [ -f "$config_file" ]; then
                echo "$site_name (конфиг: $config_file)"
            else
                echo "$site_name (конфиг отсутствует)"
            fi
        fi
    done
    echo ""
    echo "Нажмите любую клавишу для возврата..."
    read -n 1 -s
}

# Функция для создания нового сайта
create_site() {
    clear
    read -p "Введите название нового сайта: " site_name
    site_dir="/run/media/deck/SN512/SERVER/DOMAINS/$site_name"
    config_file="/run/media/deck/SN512/SERVER/nginx_configx/$site_name.conf"

    if [ -d "$site_dir" ]; then
        echo "Ошибка: Сайт с таким именем уже существует."
        return
    fi

    echo "Создаю папку для сайта..."
    sudo mkdir -p "$site_dir"
    sudo chmod 755 "$site_dir"

    echo "Создаю конфиг для сайта..."
    cat <<EOL | sudo tee "$config_file" > /dev/null
server {
    listen       80;
    server_name  $site_name;
    root $site_dir;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOL

    echo "Добавляю запись в /etc/hosts..."
    add_host_entry "$site_name"

    echo "Создаю файл index.php..."
    echo "<?php phpinfo(); ?>" | sudo tee "$site_dir/index.php" > /dev/null

    echo "Применяю права к папке и файлу..."
    sudo chown -R http:webdev "$site_dir"
    sudo chmod 644 "$site_dir/index.php"

    php_version=$(get_current_php_version)

    if [ -z "$php_version" ]; then
        echo "Ошибка: Не удалось определить текущую версию PHP-FPM."
    else
        echo "Перезапускаю PHP-FPM версии $php_version..."
        if [ "$IS_CONTAINER" == "true" ]; then
            sudo pkill php
            sudo php-fpm$php_version -D
        else
            distrobox enter ubuntu-20-04 -- sudo pkill php
            distrobox enter ubuntu-20-04 -- sudo php-fpm$php_version -D
        fi
    fi

    echo "Сайт $site_name создан и конфиг добавлен."
    reload_nginx
    echo "nginx перезагружен"
    echo "Нажмите любую клавишу для возврата в меню..."
    read -n 1 -s
}

# Функция для редактирования конфигурации сайта
edit_site_config() {
    clear
    read -p "Введите название сайта для редактирования: " site_name
    config_file="/run/media/deck/SN512/SERVER/nginx_configx/$site_name.conf"

    if [ ! -f "$config_file" ]; then
        echo "Ошибка: Конфигурационный файл для сайта $site_name не найден."
        return
    fi

    echo "Открываю конфиг для редактирования..."
    sudo nano "$config_file"

    echo "Перезагружаю nginx..."
    reload_nginx
    echo "nginx перезагружен"
    echo "Нажмите любую клавишу для возврата в меню..."
    read -n 1 -s
}

# Функция для удаления сайта
delete_site() {
    clear
    read -p "Введите название сайта для удаления: " site_name
    site_dir="/run/media/deck/SN512/SERVER/DOMAINS/$site_name"
    config_file="/run/media/deck/SN512/SERVER/nginx_configx/$site_name.conf"

    if [ ! -d "$site_dir" ]; then
        echo "Ошибка: Сайт с именем $site_name не найден."
        return
    fi

    echo "Удаляю папку сайта..."
    sudo rm -rf "$site_dir"

    echo "Удаляю конфиг для сайта..."
    sudo rm -f "$config_file"

    echo "Удаляю запись из /etc/hosts..."
    remove_host_entry "$site_name"

    echo "Перезагружаю nginx..."
    reload_nginx
    echo "nginx перезагружен"
    echo "Сайт $site_name удален."
    echo "Нажмите любую клавишу для возврата в меню..."
    read -n 1 -s
}

# Функция для перезагрузки nginx
reload_nginx() {
    echo "Перезагружаю nginx..."
    sudo systemctl reload nginx
}

# Основной цикл меню
IS_CONTAINER=false
while true; do
    show_menu
    read -p "Выберите действие: " choice

    case $choice in
        1)
            manage_php
            ;;
        2)
            manage_sites
            ;;
        8)
            reload_nginx
            echo "Nginx перезагружен."
            echo "Нажмите любую клавишу для продолжения..."
            read -n 1 -s
            ;;
        9)
            echo "Ваша страница с подсказками будет здесь."
            echo "Нажмите любую клавишу для продолжения..."
            read -n 1 -s
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Неверный выбор."
            ;;
    esac
done
