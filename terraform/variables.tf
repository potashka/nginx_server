variable "yc_cloud_id" {
  type        = string
  description = "Идентификатор облака Yandex Cloud"
}

variable "yc_folder_id" {
  type        = string
  description = "Идентификатор каталога (folder) Yandex Cloud"
}

variable "yc_zone" {
  type        = string
  description = "Зона размещения (например, ru-central1-a)"
}

variable "instance_image" {
  type        = string
  description = "ID или имя образа (image/family) для VM"
}

variable "ssh_public_key" {
  type        = string
  description = "Публичный SSH-ключ"
}

variable "instance_user" {
  type        = string
  description = "Пользователь в метаданных для авторизации по SSH"
}

variable "service_account_key_file" {
  type        = string
  description = "Путь к JSON-файлу сервисного аккаунта Yandex Cloud"
}
