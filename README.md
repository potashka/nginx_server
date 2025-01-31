# Проект: Nginx-сервер с балансировкой и Samba-файловым хранилищем

Проект создан в YandexCloud.
Потестировать можно адреса
http://89.169.146.181 # samba_proxy
http://51.250.88.60 # VM 2
http://51.250.12.24 # VM 3

# Создание проекта с ручной настройкой машин

# **Настройка инфраструктуры: Samba + Autofs + Nginx + Python HTTP-сервер**
Этот документ описывает процесс настройки **файлового сервера Samba**, **автоматического монтирования CIFS (autofs)** и **прокси-сервера Nginx** для балансировки нагрузки между двумя веб-серверами.

---

## **1. Создание виртуальных машин в Yandex Cloud**
Виртуальные машины создавались с помощью **Terraform**. После успешного создания можно получить IP-адреса с помощью:
```bash
terraform output
```
Вывод:
```plaintext
vm1_external_ip = "89.169.146.181"
vm1_internal_ip = "10.128.0.10"
vm2_external_ip = "51.250.88.60"
vm2_internal_ip = "10.128.0.3"
vm3_external_ip = "51.250.12.24"
vm3_internal_ip = "10.128.0.9"
```

---

## **2. Настройка файлового сервера (Samba) на VM1**
### **2.1. Подключение к VM1**
```bash
ssh ubuntu@89.169.146.181
```

### **2.2. Установка Samba**
```bash
sudo apt update
sudo apt install -y samba
```

### **2.3. Создание пользователя для Samba**
```bash
sudo useradd -m smbuser
sudo passwd smbuser  # Задаем пароль
sudo smbpasswd -a smbuser  # Добавляем пользователя в Samba
```

Создание тестового файла 
```bash
sudo -u smbuser touch /home/smbuser/testfile.txt
echo "Hello from Samba server" | sudo tee /home/smbuser/testfile.txt
```

### **2.4. Настройка Samba**
Редактируем конфигурационный файл:
```bash
sudo nano /etc/samba/smb.conf
```
Добавляем:
```ini
[global]
   workgroup = WORKGROUP
   security = user

[smbshare]
   path = /home/smbuser
   browseable = yes
   writable = no
   read only = yes
   guest ok = no
   valid users = smbuser
```
Применяем настройки:
```bash
sudo systemctl restart smbd
sudo systemctl enable smbd
```

---

## **3. Настройка автомонтирования (autofs) на VM2 и VM3**
### **3.1. Подключение**
```bash
ssh ubuntu@51.250.88.60  # VM2
# или
ssh ubuntu@51.250.12.24  # VM3
```

### **3.2. Установка autofs и CIFS-utils**
```bash
sudo apt update
sudo apt install -y autofs cifs-utils
```

### **3.3. Создание файла `/etc/smb-credentials`**
```bash
sudo nano /etc/smb-credentials
```
Добавляем:
```plaintext
username=smbuser
password=*****
```
Устанавливаем правильные права:
```bash
sudo chmod 600 /etc/smb-credentials
```

### **3.4. Настройка `/etc/auto.smb.shares`**
```bash
sudo nano /etc/auto.smb.shares
```
Добавляем:
```
smbuser -fstype=cifs,rw,credentials=/etc/smb-credentials ://89.169.146.181/smbshare
```

### **3.5. Настройка `/etc/auto.master`**
```bash
sudo nano /etc/auto.master
```
Добавляем строку:
```
/mnt/smb /etc/auto.smb.shares --timeout=60 --ghost
```

### **3.6. Перезапуск autofs**
```bash
sudo systemctl restart autofs
```

### **3.7. Проверка монтирования**
```bash
ls -l /mnt/smb
```

---

## **4. Настройка Python HTTP-серверов на VM2 и VM3**
### **4.1. Подключение**
```bash
ssh ubuntu@51.250.88.60  # VM2
# или
ssh ubuntu@51.250.12.24  # VM3
```

### **4.2. Создание systemd-сервиса для HTTP-сервера**
```bash
sudo nano /etc/systemd/system/http-server.service
```
Добавляем:
```ini
[Unit]
Description=Simple Python HTTP Server
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/mnt/smb
ExecStart=/usr/bin/python3 -m http.server 8000 --directory /mnt/smb
Restart=always

[Install]
WantedBy=multi-user.target
```

### **4.3. Запуск сервиса**
```bash
sudo systemctl daemon-reload
sudo systemctl enable http-server
sudo systemctl start http-server
```

### **4.4. Проверка работы сервера**
```bash
curl http://localhost:8000
```

---

## **5. Настройка прокси-сервера и балансировки нагрузки (Nginx) на VM1**
### **5.1. Подключение к VM1**
```bash
ssh ubuntu@89.169.146.181
```

### **5.2. Установка Nginx**
```bash
sudo apt update
sudo apt install -y nginx
```

### **5.3. Настройка конфигурации Nginx**
```bash
sudo nano /etc/nginx/nginx.conf
```
Добавляем:
```nginx
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    upstream backend_servers {
        server 51.250.88.60:8000;  # VM2
        server 51.250.12.24:8000;  # VM3
    }

    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://backend_servers;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
```

### **5.4. Перезапуск Nginx**
```bash
sudo nginx -t  # Проверяем конфиг
sudo systemctl restart nginx
```

---

## **6. Открытие портов в Yandex Cloud**

Как правило, машины запускаются с открырми портами

---

## **7. Финальная проверка**
### **7.1. Проверить Samba**
```bash
smbclient -L //89.169.146.181 -U smbuser
```

### **7.2. Проверить доступ к веб-серверам**
```bash
curl http://51.250.88.60:8000
curl http://51.250.12.24:8000
```

### **7.3. Проверить балансировку Nginx**
```bash
curl http://89.169.146.181
```
При нескольких запросах страницы должны приходить **то с VM2, то с VM3**.


# Автоматизированная натсройка

Альтернативный проект автоматизирует развёртывание и настройку трех виртуальных машин в Яндекс.Облаке (Yandex Cloud) при помощи **Terraform** и **Ansible**. В результате получается решение, где:
1. **ВМ1** (samba-proxy) — выполняет роль Samba-файлового сервера и Nginx-прокси/балансировщика.
2. **ВМ2** (web-node-1) и **ВМ3** (web-node-2) — монтируют общую Samba-папку и запускают простой веб-сервер (`python3 -m http.server`), чтобы Nginx на ВМ1 мог балансировать запросы между ними.

В рамках решения мы:
- Разворачиваем три виртуальные машины с помощью **Terraform**.
- На ВМ1 через **Ansible** устанавливаем **Samba** (для файлового сервиса) и **Nginx** (для проксирования и балансировки).
- На ВМ2 и ВМ3 устанавливаем **cifs-utils + autofs** (для автомонтирования Samba-ресурса) и запускаем Python-веб-сервера.  

В итоге:
- Пользователи могут обращаться к ВМ1 по HTTP (80 порт), а Nginx будет прозрачно перенаправлять (и балансировать) запросы к двум бэкендам — ВМ2 и ВМ3, каждый из которых показывает/раздаёт файлы, взятые из расшаренной директории Samba на ВМ1.

---

## Архитектура решения
```plaintext
      (Интернет/клиент)
             |
         [ Nginx ]  <- прокси + балансировщик (ВМ1), тут же Samba
           /   \
          /     \
  [ Python HTTP ]  [ Python HTTP ]
    (ВМ2, cifs)       (ВМ3, cifs)

Samba-файловый ресурс -> /home/smbuser (ВМ1)
Автомонтирован на ВМ2 и ВМ3 -> /mnt/smb
```

1. **Samba (ВМ1)**  
   Предоставляет сетевой ресурс (homedir `smbuser`) по протоколу SMB.  
2. **Autofs + CIFS (ВМ2/ВМ3)**  
   При обращении к `/mnt/smb` монтирует Samba-ресурс, что делает папку доступной локально.  
3. **Python HTTP-сервер (ВМ2/ВМ3)**  
   Запускается на порту `8000`, раздаёт содержимое `/mnt/smb`.  
4. **Nginx (ВМ1)**  
   Слушает 80 порт, проксирует запросы на порт `8000` ВМ2 и ВМ3 (по внутренним IP или публичным — зависит от настройки), организуя балансировку нагрузки.  

---

## Структура проекта

```
nginx_server/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars
│   └── outputs.tf
└── ansible/
    ├── inventory.ini
    ├── site.yml
    ├── group_vars/
    │   └── all.yml
    └── roles/
        ├── samba_proxy/
        │   ├── tasks/
        │   │   └── main.yml
        │   └── templates/
        │       ├── smb.conf.j2
        │       └── nginx.conf.j2
        |       └── testfile.txt.j2
        └── web_nodes/
            ├── tasks/
            │   └── main.yml
            └── templates/
                ├── auto.master.j2
                ├── auto.smb.j2
                └── python-webserver.service.j2
```

### Основные каталоги:
1. **terraform/**  
   - `main.tf` и `variables.tf` — Terraform-конфигурации для развёртывания 3 машин.  
   - `terraform.tfvars` — файл со значениями переменных (folder_id, ключи и т.п.).  
   - `outputs.tf` — выводит публичные/внутренние IP адреса.

2. **ansible/**  
   - `inventory.ini` — список хостов с их IP, сгруппирован по ролям (`samba_proxy`, `web_nodes`).  
   - `site.yml` — главный плейбук, который запускает две роли.  
   - `group_vars/all.yml` — общие переменные (пароли, IP-адреса).  
   - **roles/**:
     - `samba_proxy/` — устанавливает и настраивает Samba + Nginx.
     - `web_nodes/` — настраивает автомонтирование CIFS, запускает Python-сервер через systemd.

***Пример задачи для создания тестового файла***
В роли samba_proxy, в tasks/main.yml, есть такой блок:


- name: Place test file in smbuser's home
  become: yes
  copy:
    src: testfile.txt.j2
    dest: /home/smbuser/testfile.txt
    owner: smbuser
    group: smbuser
    mode: '0644'

Тем самым Ansible кладёт подготовленный шаблон testfile.txt.j2 (в котором содержится текст «Hello from Samba server») в домашнюю директорию пользователя smbuser.
---

## Шаги развертывания

1. **Установить Terraform и Ansible** на рабочую машину (ваш локальный компьютер или CI/CD-агент).
2. **Перейти** в каталог `nginx_server/terraform/`.
3. **Заполнить** `terraform.tfvars` (cloud_id, folder_id, ключ сервисного аккаунта или OAuth-токен, SSH-ключ, и т.д.).
4. **Инициализировать и создать ресурсы**:
   ```bash
   cd terraform
   terraform init
   terraform apply
   ```
   - Подтвердите вводом `yes`.  
   - В результате будут созданы три виртуальные машины, VPC-сеть, подсеть и т.д.
5. **Скопировать IP-адреса** (или использовать `terraform output`), подставить их в `ansible/inventory.ini`:
   ```ini
   [samba_proxy]
   samba-proxy ansible_host=51.250.xx.xx

   [web_nodes]
   web-node-1 ansible_host=51.250.yy.yy
   web-node-2 ansible_host=51.250.zz.zz

   [all:vars]
   ansible_user=ubuntu
   ansible_ssh_private_key_file=~/.ssh/id_rsa
   ```
6. **Отредактировать** `ansible/group_vars/all.yml`, указав при необходимости нужный пароль для smbuser (`samba_password`), IP для проксирования (если берёте внутренние IP).
7. **Запустить Ansible**:
   ```bash
   cd ../ansible
   ansible-playbook -i inventory.ini site.yml
   ```
   - Ansible установит Samba, создаст пользователя `smbuser`, запустит Nginx на ВМ1 и настроит web-серверы на ВМ2, ВМ3 (cifs-utils, autofs, python-webserver через systemd), положит тестовый файл testfile.txt в /home/smbuser.

---

## Примеры фрагментов команд (сниппеты)

1. **Создание машин Terraform**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
2. **Вывод IP-адресов** из Terraform:
   ```bash
   terraform output
   ```
3. **Запуск Ansible**:
   ```bash
   ansible-playbook -i inventory.ini site.yml
   ```
4. **Проверка Samba** на веб-нодах (ВМ2/ВМ3):
   ```bash
   ls /mnt/smb
   ```
   Должны увидеть файлы из `/home/smbuser` на ВМ1.
5. **Проверка Nginx** (балансировщика) на ВМ1:
   ```bash
   curl http://<PUBLIC_IP_OF_VM1>
   ```
   Ответы будут приходить с ВМ2 или ВМ3, где запущен Python-сервер.

***Проверка работы и тестового файла***
После выполнения плейбуков Ansible, вы можете убедиться, что всё работает:

На веб-нодах (ВМ2 или ВМ3):

ssh ubuntu@<IP_WEB_NODE>
ls -l /mnt/smb
Там должен находиться файл testfile.txt, созданный на ВМ1.

Через Python-сервер (порт 8000):

curl http://<IP_WEB_NODE>:8000/testfile.txt
Если увидите текст, записанный в testfile.txt.j2 («Hello from Samba server»), значит веб-сервер действительно отдаёт содержимое папки /mnt/smb.

Через Nginx (ВМ1, порт 80):

curl http://<IP_SAMBA_PROXY>/testfile.txt

Запрос будет сбалансирован на одну из веб-нод, а вы получите тот же файл. Обновляя страницу или повторяя curl, вы можете попасть то на ВМ2, то на ВМ3 (по умолчанию задан политика **round robin**).

---

## Результаты
- **Файловый сервер (Samba)** позволяет безопасно хранить файлы в `/home/smbuser` на ВМ1.  
- **Автомонтирование (autofs + CIFS)** даёт удобный доступ к этому ресурсу на ВМ2 и ВМ3 без ручной команды `mount`.  
- **Простой веб-сервер** (`python3 -m http.server`) на ВМ2/ВМ3 демонстрирует содержимое смонтированного каталога `/mnt/smb`.  
- **Nginx** принимает HTTP-запросы и сбалансированно перенаправляет на оба веб-сервера, распределяя нагрузку.

Таким образом, мы реализуем **полноценный стенд** для прокси-балансировки и файлового хранилища в одной инфраструктуре, с минимальной ручной работой благодаря Terraform и Ansible.
```
