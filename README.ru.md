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
- **APT:** `apt-ubuntu-24.04-noble`, `apt-ubuntu-24.04-noble-security`, `apt-debian-12-bookworm`, `apt-debian-12-bookworm-security`, `apt-debian-13-trixie`, `apt-debian-13-trixie-security`
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

Подставьте свой хост и схему доступа к Nexus (в примере ниже — из **`nexus_public_hostname`** и типичный прямой порт **8081**). Если перед Nexus стоит reverse proxy на **443**, используйте `https://<хост>/repository/...` **без** `:8081`.

**Базовый шаблон URL в Nexus 3:**

- APT: `http(s)://<NEXUS>/repository/<имя_репозитория>/`
- YUM: `http(s)://<NEXUS>/repository/<имя_репозитория>/` (в конце слэш желателен)

Имена APT-репозиториев в **`group_vars`** (в т.ч. `*-security`): см. таблицу выше; для клиентов **suite `*-security`** всегда указывайте **отдельный** `URIs` с суффиксом **`-security`** в имени репозитория Nexus. Далее в примере — только Debian 13; для **bookworm** / **noble** замените имена на **`apt-debian-12-bookworm-security`** / **`apt-ubuntu-24.04-noble-security`** и соответствующие **Suites**. YUM: **`yum-almalinux-10-x86_64-baseos`**, **`yum-almalinux-10-x86_64-appstream`**.

---

#### Debian 13 (trixie), APT

1. Отключите или закомментируйте официальные зеркала в **`/etc/apt/sources.list`** и **`/etc/apt/sources.list.d/*.sources`** / **`*.list`**, чтобы не смешивать поток с Nexus.

2. **По умолчанию для HTTPS к Nexus** (частый случай — свой TLS без корпоративного CA на клиенте): создайте **`/etc/apt/apt.conf.d/80nexus-https.conf`**:

```text
Acquire::https::Verify-Peer "false";
Acquire::https::Verify-Host "false";
```

Первая директива — то, что обычно требуется при самоподписанном или внутреннем сертификате; вторая — если не совпадает имя в сертификате. Если корневой CA Nexus установлен в системе как доверенный, этот файл можно **не** создавать (предпочтительнее для production).

3. Создайте **`/etc/apt/sources.list.d/nexus-trixie.sources`** (deb822). Важно: **`trixie`** и **`trixie-security`** — это **разные** upstream-зеркала; в Nexus у них **разные** имена репозиториев, на клиенте — **два** блока **`Types: deb`** (или две строки **`deb`**).

**HTTPS** (подставьте хост Nexus, ниже для примера — прямой IP):

```ini
Types: deb
URIs: https://192.168.1.70:8081/repository/apt-debian-13-trixie
Suites: trixie
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://192.168.1.70:8081/repository/apt-debian-13-trixie-security
Suites: trixie-security
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
```

**HTTP :8081** (без TLS — шаг 2 с **`Acquire::https::...`** не нужен):

```ini
Types: deb
URIs: http://192.168.1.70:8081/repository/apt-debian-13-trixie
Suites: trixie
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://192.168.1.70:8081/repository/apt-debian-13-trixie-security
Suites: trixie-security
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
```

Ошибка **`... trixie-security InRelease' is not signed`** чаще всего из‑за строки вида **`deb .../apt-debian-13-trixie trixie-security main`**: репозиторий **`apt-debian-13-trixie`** в Nexus привязан только к **`distribution: trixie`**, не к security. Тогда Nexus отдаёт не тот индекс — APT считает репозиторий неподписанным. После **`ansible-playbook install.yml`** в Nexus создаются пары основной + security: **`apt-debian-13-trixie-security`**, **`apt-debian-12-bookworm-security`**, **`apt-ubuntu-24.04-noble-security`**. Для suite **`*-security`** в **`URIs`** указывайте именно их, а не репозиторий с «обычным» distribution.

Сообщение **`Unauthorized` / `401`** при **`apt update`**: для чтения репозиториев без логина в Nexus включите анонимный доступ (**`nexus_anonymous_access: true`** в vars и повторный прогон роли) либо настройте аутентификацию APT к Nexus (см. документацию Sonatype).

Классические строки **`sources.list`** (эквивалент двум блокам выше, HTTP):

```text
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] http://192.168.1.70:8081/repository/apt-debian-13-trixie trixie main
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] http://192.168.1.70:8081/repository/apt-debian-13-trixie-security trixie-security main
```

4. Обновление индекса и системы:

```bash
sudo apt update
sudo apt full-upgrade
```

Для **`trixie-updates`** добавьте ещё один APT proxy в Nexus (**`distribution: trixie-updates`**, **`remote_url`**: тот же **`https://deb.debian.org/debian`**) и ещё один блок в **`*.sources`**. **`trixie-security`** уже покрыт репозиторием **`apt-debian-13-trixie-security`** в **`group_vars/nexus/06-apt-debian-13-trixie-repos.yml`**.

---

#### AlmaLinux 10, DNF / YUM

1. Сохраните копии репозиториев: **`/etc/yum.repos.d/`**.
2. Отключите штатные репозитории Alma (переименуйте или **`enabled=0`** в **`almalinux-*.repo`**), чтобы весь трафик шёл через Nexus.
3. Создайте **`/etc/yum.repos.d/nexus-alma10.repo`**.

Вариант **HTTP :8081** (проверка TLS к Nexus не используется):

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

Вариант **HTTPS** к Nexus — **по умолчанию отключите проверку TLS** (аналог apt), если нет доверенного CA на клиенте: в **каждой** секции добавьте **`sslverify=0`**:

```ini
[nexus-al10-baseos]
name=AlmaLinux 10 BaseOS via Nexus (HTTPS)
baseurl=https://nexus.btnxlocal.ru/repository/yum-almalinux-10-x86_64-baseos/
enabled=1
sslverify=0
gpgcheck=1
countme=1
metadata_expire=86400
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-10

[nexus-al10-appstream]
name=AlmaLinux 10 AppStream via Nexus (HTTPS)
baseurl=https://nexus.btnxlocal.ru/repository/yum-almalinux-10-x86_64-appstream/
enabled=1
sslverify=0
gpgcheck=1
countme=1
metadata_expire=86400
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-10
```

Если RPM-GPG-KEY с другим именем на хосте — поправьте путь (**`rpm -qa gpg-pubkey*`** / каталог **`/etc/pki/rpm-gpg/`**). Для отладки без проверки подписи пакетов (нежелательно в бою) временно **`gpgcheck=0`**.

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
