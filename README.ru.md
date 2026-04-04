# Ansible Role: Nexus 3 OSS — документация на русском

Полный справочник переменных и история проекта — в основном [**README.md**](README.md) (английский, в т.ч. для Ansible Galaxy).

## Назначение

Роль устанавливает и настраивает **Sonatype Nexus Repository Manager 3 OSS**. Повторный запуск плейбука обновляет конфигурацию, кроме **неизменяемых после создания** параметров [blobstore](https://help.sonatype.com/repomanager3/repository-management#RepositoryManagement-BlobStores).

## Требования

- Актуальный **Ansible** (см. `meta/main.yml`).
- Поддерживаемая ОС (в CI: Rocky Linux 9, Debian 12 и др.).
- На **целевом хосте** установлен **rsync** (нужен роли для синхронизации Groovy-скриптов).
- На контроллере: **Python**, зависимости из **`requirements.txt`**, в т.ч. **jmespath** (фильтр `json_query`).
- **Java 8** (OpenJDK 8 рекомендует Sonatype).

## Пример деплоя (`install.yml`)

Переменные для группы **`[nexus]`** Ansible подхватывает из каталога **`group_vars/nexus/`** (рядом с плейбуком). Префиксы `01-` … `13-` задают порядок слияния файлов.

| Файл | Назначение |
|------|------------|
| `01-core.yml` | Версия, архив, пароль админа, hostname, timezone, bearer token |
| `02-docker-repos.yml` | Docker proxy/hosted/group, cleanup policies |
| `03-npm-repos.yml` | NPM |
| `04-apt-ubuntu-…`, `05-06-apt-debian-…`, `07-apt-repos.yml` | APT (агрегатор в `07`) |
| `08-09-yum-almalinux-…`, `10-yum-repos.yml` | YUM (агрегатор в `10`) |
| `11-backup.yml` | Еженедельный бэкап БД и blobstore |
| `12-scheduled-tasks.yml` | Docker GC, compact blobstore |
| `13-rbac-gitlab.yml` | Роли, пользователь GitLab CI |

Почему не `defaults/main.yml` роли: там значения по умолчанию для потребителей Galaxy; пример инсталляции удобнее держать отдельно в `group_vars`.

```bash
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -U pip && pip install -r requirements.txt

export ANSIBLE_CONFIG="$PWD/ansible.cfg"
ansible-playbook -i inventory-localdomain.ini install.yml \
  --private-key ~/.ssh/id_rsa -v
```

Подставьте свой инвентарь и ключ. Для WSL путь к репозиторию: `/mnt/c/.../ansible-role-nexus3-oss`.

## Репозитории Linux (имена в Nexus)

### APT (`nexus_config_apt: true`)

| Репозиторий в Nexus | Upstream | Suite (distribution) |
|---------------------|----------|------------------------|
| `apt-ubuntu-24.04-noble` | https://archive.ubuntu.com/ubuntu/ | noble (Ubuntu 24.04 LTS) |
| `apt-debian-12-bookworm` | https://deb.debian.org/debian | bookworm (Debian 12) |
| `apt-debian-13-trixie` | https://deb.debian.org/debian | trixie (Debian 13) |

### YUM (`nexus_config_yum: true`)

| Репозиторий в Nexus | Upstream |
|---------------------|----------|
| `yum-almalinux-9-x86_64-baseos` | https://repo.almalinux.org/almalinux/9/BaseOS/x86_64/os/ |
| `yum-almalinux-9-x86_64-appstream` | https://repo.almalinux.org/almalinux/9/AppStream/x86_64/os/ |
| `yum-almalinux-10-x86_64-baseos` | https://repo.almalinux.org/almalinux/10/BaseOS/x86_64/os/ |
| `yum-almalinux-10-x86_64-appstream` | https://repo.almalinux.org/almalinux/10/AppStream/x86_64/os/ |

Каталоги **blob-apt** и **blob-yum** заданы в **`vars/blob_vars.yml`**.

## Blobstore: «сжатие» и обслуживание

В Nexus **нет прозрачного gzip-хранилища** артефактов. Освобождение места на диске делается задачей **Compact blob store** (`typeId: blobstore.compact`): убираются неиспользуемые блоки после удаления компонентов.

В **`group_vars/nexus/12-scheduled-tasks.yml`** настроено еженедельное compact для blobstore **`default`**, **`blob-docker`**, **`blob-npm`**, **`blob-apt`**, **`blob-yum`** (имена как в `vars/blob_vars.yml`). Время разнесено по минутам в воскресенье, чтобы не пересекаться с бэкапом.

Дополнительно:

- **Cleanup policies** (например для Docker) — в `group_vars/nexus/02-docker-repos.yml`.
- **Docker GC** (`repository.docker.gc`) — ежедневно в 02:30 для репозитория `docker-hosted`.
- Рекурсивная проверка владельца каталогов blobstore (долго на больших данных): см. в [README.md](README.md) переменную **`nexus_blobstores_recurse_owner`**.

## Резервное копирование

В **`group_vars/nexus/11-backup.yml`** включено:

- **`nexus_backup_configure: true`** — в Nexus создаётся **запланированная задача** со встроенным Groovy-скриптом (шаблон `templates/backup.groovy.j2`).
- **Расписание:** воскресенье **02:00** (Quartz: `0 0 2 ? * SUN`).
- **Содержимое копии:** каталоги вида `{{ nexus_backup_dir }}/blob-backup-<дата-время>/` с **дампом БД** (`db/`) и **копией blobstore** с диска Nexus.
- **`nexus_backup_rotate: true`**, **`nexus_backup_keep_rotations: 4`** — хранятся до **четырёх** последних полных наборов (практически месяц при еженедельном запуске).

Каталог бэкапов по умолчанию: **`/var/nexus-backup`**. Для сетевого/S3-монтажа можно отключить создание каталога ролью: **`nexus_backup_dir_create: false`**.

### Восстановление

Как в основном README: запуск плейбука с extra-var **`nexus_restore_point=<YYYY-MM-dd-HH-mm-ss>`** (имя каталога бэкапа без префикса `blob-backup-`). Подробности и ограничения — раздел **Backups** в [README.md](README.md).

**Важно:** на очень больших blobstore встроенный бэкап через копирование из процесса Nexus требует проверки нагрузки и места на диске; для production часто дополняют снапшотами СХД или внешними средствами.

## Безопасность

- Пароль администратора задайте в **`group_vars/nexus/01-core.yml`** или через **Ansible Vault**, не коммитьте секреты в открытом виде.
- Пользователь **gitlab-ci** и пароль **`CHANGE_ME`** в **`group_vars/nexus/13-rbac-gitlab.yml`** смените перед production.

## Лицензия и авторы

См. [README.md](README.md) (GNU GPLv3, ссылки на авторов и форк).
