# Проект: Nginx-сервер с балансировкой и Samba-файловым хранилищем

## Описание и цель
Данный проект автоматизирует развёртывание и настройку трех виртуальных машин в Яндекс.Облаке (Yandex Cloud) при помощи **Terraform** и **Ansible**. В результате получается решение, где:
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
   - Ansible установит Samba, создаст пользователя `smbuser`, запустит Nginx на ВМ1 и настроит web-серверы на ВМ2, ВМ3 (cifs-utils, autofs, python-webserver через systemd).

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

---

## Результаты
- **Файловый сервер (Samba)** позволяет безопасно хранить файлы в `/home/smbuser` на ВМ1.  
- **Автомонтирование (autofs + CIFS)** даёт удобный доступ к этому ресурсу на ВМ2 и ВМ3 без ручной команды `mount`.  
- **Простой веб-сервер** (`python3 -m http.server`) на ВМ2/ВМ3 демонстрирует содержимое смонтированного каталога `/mnt/smb`.  
- **Nginx** принимает HTTP-запросы и сбалансированно перенаправляет на оба веб-сервера, распределяя нагрузку.

Таким образом, мы реализуем **полноценный стенд** для прокси-балансировки и файлового хранилища в одной инфраструктуре, с минимальной ручной работой благодаря Terraform и Ansible.
```
