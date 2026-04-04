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
| `13-users-rbac.yml` | Пользователи (repo-dev/test/stage/prod, gitlab-ci), роли и привилегии |

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

## Локальные пользователи Nexus (`13-users-rbac.yml`)

У каждой учётной записи свои переменные: **`*_nexus_username`**, **`*_nexus_password`**, **`*_nexus_email`** (по тому же принципу, что и `gitlab_ci_*`). Пароли задавайте через **Vault**.

| Логин (по умолчанию) | Переменная пароля | Роли | Доступ к репозиториям |
|----------------------|-------------------|------|------------------------|
| `repo-dev` | `repo_dev_nexus_password` | `repo-readers` | Все репозитории из примера — **чтение и browse**, Docker login; **без записи** |
| `repo-test` | `repo_test_nexus_password` | `repo-readers` | то же |
| `repo-stage` | `repo_stage_nexus_password` | `repo-readers` | то же |
| `repo-prod` | `repo_prod_nexus_password` | `repo-readers` | то же |
| `gitlab-ci` | `gitlab_ci_nexus_password` | `repo-readers`, `ci-publisher` | Как у read-only **плюс запись** в **docker-hosted**, **npm-hosted**, **private-release** |

**Имена репозиториев** в текущем примере `group_vars` (для ориентира):

- **Maven:** `central`, `jboss`, `private-release`, `public`
- **Docker:** `docker-proxy`, `docker-hosted`, `docker-group`
- **NPM:** `npm-proxy`, `npm-hosted`, `npm-group`
- **APT:** `apt-ubuntu-24.04-noble`, `apt-ubuntu-24.04-noble-security`, `apt-debian-12-bookworm`, `apt-debian-12-bookworm-security`, `apt-debian-13-trixie`, `apt-debian-13-trixie-updates`, `apt-debian-13-trixie-backports`, `apt-debian-13-trixie-security`
- **YUM:** `yum-almalinux-9-x86_64-baseos`, `yum-almalinux-9-x86_64-appstream`, `yum-almalinux-10-x86_64-baseos`, `yum-almalinux-10-x86_64-appstream`

Та же сводка продублирована комментарием в начале **`group_vars/nexus/13-users-rbac.yml`**.

## Репозитории Linux (имена в Nexus)

### APT (`nexus_config_apt: true`)

| Репозиторий в Nexus | Upstream | Suite (distribution) |
|---------------------|----------|------------------------|
| `apt-ubuntu-24.04-noble` | https://archive.ubuntu.com/ubuntu/ | noble (Ubuntu 24.04 LTS) |
| `apt-ubuntu-24.04-noble-security` | https://security.ubuntu.com/ubuntu/ | noble-security (Ubuntu 24.04) |
| `apt-debian-12-bookworm` | https://deb.debian.org/debian | bookworm (Debian 12) |
| `apt-debian-12-bookworm-security` | https://deb.debian.org/debian-security | bookworm-security (Debian 12) |
| `apt-debian-13-trixie` | https://deb.debian.org/debian | trixie (Debian 13) |
| `apt-debian-13-trixie-updates` | https://deb.debian.org/debian | trixie-updates (Debian 13) |
| `apt-debian-13-trixie-backports` | https://deb.debian.org/debian | trixie-backports (Debian 13) |
| `apt-debian-13-trixie-security` | https://deb.debian.org/debian-security | trixie-security (Debian 13) |

### YUM (`nexus_config_yum: true`)

| Репозиторий в Nexus | Upstream |
|---------------------|----------|
| `yum-almalinux-9-x86_64-baseos` | https://repo.almalinux.org/almalinux/9/BaseOS/x86_64/os/ |
| `yum-almalinux-9-x86_64-appstream` | https://repo.almalinux.org/almalinux/9/AppStream/x86_64/os/ |
| `yum-almalinux-10-x86_64-baseos` | https://repo.almalinux.org/almalinux/10/BaseOS/x86_64/os/ |
| `yum-almalinux-10-x86_64-appstream` | https://repo.almalinux.org/almalinux/10/AppStream/x86_64/os/ |

Каталоги **blob-apt** и **blob-yum** заданы в **`vars/blob_vars.yml`**.

### Клиенты: обновление ОС через Nexus (Debian 13 и AlmaLinux 10)

Локальный Nexus по **HTTP** (порт **8081**): в примерах ниже подставьте IP или имя хоста (**`nexus_public_hostname`**). Шаблон пути: **`http://<NEXUS>:8081/repository/<имя>/`**. Имена APT/YUM — в таблицах выше; для **bookworm** / **noble** замените префиксы репозиториев и **Suites**. YUM: **`yum-almalinux-10-x86_64-baseos`**, **`yum-almalinux-10-x86_64-appstream`**.

---

#### Debian 13 (trixie), APT

Отключите официальные зеркала в **`/etc/apt/sources.list`** и **`/etc/apt/sources.list.d/`**. После **`ansible-playbook install.yml`** в Nexus создаются **`apt-debian-13-trixie`**, **`...-updates`**, **`...-backports`**, **`...-security`** (см. **`group_vars/nexus/06-apt-debian-13-trixie-repos.yml`**).

Если **`nexus_anonymous_access: false`**, нужна учётка с **`repo-readers`** (например **`repo-dev`** в **`group_vars/nexus/13-users-rbac.yml`**); пароль в **`auth.conf`** замените на свой (в примере — **`CHANGE_ME`**). В **`machine`** для HTTP в Debian 12+ укажите префикс **`http://`**, иначе возможен **401** при **`apt update`**.

```text
debian@nexus:~$ sudo vim /etc/apt/sources.list.d/debian.sources
Types: deb
URIs: http://192.168.1.70:8081/repository/apt-debian-13-trixie
Suites: trixie
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://192.168.1.70:8081/repository/apt-debian-13-trixie-updates
Suites: trixie-updates
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://192.168.1.70:8081/repository/apt-debian-13-trixie-backports
Suites: trixie-backports
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://192.168.1.70:8081/repository/apt-debian-13-trixie-security
Suites: trixie-security
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
```

```text
debian@nexus:~$ sudo vim /etc/apt/auth.conf.d/90nexus.conf
machine http://192.168.1.70:8081
login repo-dev
password CHANGE_ME
```

```bash
sudo chmod 600 /etc/apt/auth.conf.d/90nexus.conf
sudo apt update
sudo apt full-upgrade
```

Дополнительные компоненты (**`contrib`**, **`non-free-firmware`**) — добавьте в **`Components`** через пробел при необходимости.

---

#### AlmaLinux 10, DNF / YUM

1. Сохраните копии репозиториев: **`/etc/yum.repos.d/`**.
2. Отключите штатные репозитории Alma (переименуйте или **`enabled=0`** в **`almalinux-*.repo`**), чтобы весь трафик шёл через Nexus.
3. Создайте **`/etc/yum.repos.d/nexus-alma10.repo`** (пример ниже — локальный Nexus по HTTP, порт **8081**):

```ini
[nexus-al10-baseos]
name=AlmaLinux 10 BaseOS via Nexus
baseurl=http://nexus.btnxlocal.ru:8081/repository/yum-almalinux-10-x86_64-baseos/
enabled=1
gpgcheck=1
countme=1
metadata_expire=86400
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-10

[nexus-al10-appstream]
name=AlmaLinux 10 AppStream via Nexus
baseurl=http://nexus.btnxlocal.ru:8081/repository/yum-almalinux-10-x86_64-appstream/
enabled=1
gpgcheck=1
countme=1
metadata_expire=86400
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-10
```

Если имя ключа другое — поправьте **`gpgkey`**. Для отладки без проверки подписи пакетов (не в бою) временно **`gpgcheck=0`**.

##### AlmaLinux 10: авторизация под пользователем Nexus (Basic Auth)

Учётка **`repo-readers`** (например **`repo-dev`**).

**Б) Поля `username=` и `password=` в секции** (пароль не в URL `baseurl`):

```ini
[nexus-al10-baseos]
name=AlmaLinux 10 BaseOS via Nexus (auth)
baseurl=http://192.168.1.70:8081/repository/yum-almalinux-10-x86_64-baseos/
username=repo-dev
password=CHANGE_ME
enabled=1
gpgcheck=1
countme=1
metadata_expire=86400
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-10

[nexus-al10-appstream]
name=AlmaLinux 10 AppStream via Nexus (auth)
baseurl=http://192.168.1.70:8081/repository/yum-almalinux-10-x86_64-appstream/
username=repo-dev
password=CHANGE_ME
enabled=1
gpgcheck=1
countme=1
metadata_expire=86400
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-10
```

**`chmod 600`** на **`/etc/yum.repos.d/nexus-alma10.repo`**. Для production удобнее шаблоны Ansible + **Vault**.

4. Обновление:

```bash
sudo dnf clean all
sudo dnf makecache
sudo dnf upgrade --refresh
```

**Замечание:** в **`group_vars`** сейчас только **BaseOS** и **AppStream**. Для **CRB**, **extras** и т.п. добавьте соответствующие **yum proxy** в Nexus и ещё один блок **`[nexus-...]`** с тем же шаблоном `baseurl`.

---

Кратко на английском и в таблице имён репозиториев см. также [**README.md**](README.md) (раздел про репозитории Linux).

### Docker hosted: очистка тегов `dev` / `test` / `main`

В **`group_vars/nexus/02-docker-repos.yml`** к репозиторию **`docker-hosted`** подключены три политики (имена в Nexus):

| Политика | Теги (regex) | Срок (дни), blob + не скачивали |
|----------|----------------|----------------------------------|
| `docker_cleanup_dev_tags` | `dev`, `*-dev`, пути `.../manifests/dev` и `.../manifests/*-dev` | 7 |
| `docker_cleanup_test_tags` | `test`, `*-test`, аналогично manifests | 21 |
| `docker_cleanup_main_tags` | `main`, `master`, `*-main`, `*-master` | 60 |

Условия **lastBlobUpdated** и **lastDownloaded** действуют **одновременно** (AND). После срабатывания политик имеет смысл цепочка: встроенная задача **Cleanup repositories using their associated policies** → ночной **Docker GC** (`12-scheduled-tasks.yml`) → **Compact blob store**.

Если раньше использовались политики `docker_*_aggressive_cleanup`, после деплоя старые записи можно удалить вручную в **Repository → Cleanup policies**, чтобы не путаться в списке.

**Остальные Docker-теги** (`v1.2.3`, `release`, `latest`, …) **ни одна из этих политик не описывает**, поэтому они **не участвуют в автоматической очистке** и могут лежать сколько угодно долго (пока вы не добавите ещё политики). Отдельная политика вида «всё, кроме dev/test/main, удалять через год» обычно **нежелательна**: через тот же срок начнут сниматься и **старые релизные** теги. Если нужен контроль мусора — лучше завести политику с **узким regex** (например только временные префиксы), а не `.*`.

**NPM, Maven, APT, YUM** в примере `group_vars` **без** привязанных cleanup policies — ими никто не ротирует, пока вы сами не настроите.

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

## Пароли (админ и локальные пользователи)

По умолчанию роль **не меняет** пароль `admin` в Nexus и **не перезаписывает** пароли уже существующих локальных пользователей из `nexus_local_users` при каждом запуске (роли, ФИО, email по-прежнему синхронизируются; новые пользователи создаются с паролем из списка).

- **`nexus_apply_admin_password`** (`false` по умолчанию) — включите (`true`) при первом деплое или разовой смене пароля админа, когда Ansible должен вызвать скрипт `update_admin_password`. Желаемый пароль — в **`nexus_admin_password`**. После того как вход по `nexus_admin_password` уже работает, повторные прогоны с `true` пароль снова не сбрасывают.
- Смена админа, когда текущий пароль другой: в **`nexus_admin_password`** — новый пароль, один запуск с **`-e nexus_default_admin_password=<текущий>`** и **`-e nexus_apply_admin_password=true`** (подробнее — [README.md](README.md), раздел *Change admin password after first install*).
- **`nexus_apply_local_user_passwords`** (`false` по умолчанию) — поставьте `true` или **`-e nexus_apply_local_user_passwords=true`**, когда нужно принудительно выставить пароли из списка (например ротация **gitlab-ci**).

## Безопасность

- Желаемый пароль администратора храните в **`group_vars/nexus/01-core.yml`** (**`nexus_admin_password`**) или в Vault; не коммитьте секреты в открытом виде.
- Пароли **`CHANGE_ME`** в **`group_vars/nexus/13-users-rbac.yml`** (в т.ч. **gitlab-ci** и read-only учётки) задайте через Vault; для принудительной смены паролей из плейбука — **`nexus_apply_local_user_passwords: true`**.

## Лицензия и авторы

См. [README.md](README.md) (GNU GPLv3, ссылки на авторов и форк).
