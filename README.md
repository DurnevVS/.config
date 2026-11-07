# Настройки терминала для Windows

Конфигурация PowerShell 7, Starship, Yazi, LazyGit, LazyDocker, GitHub CLI, micro, Glow и Posting в теме Catppuccin Mocha. Скрипт `install.ps1` устанавливает выбранные программы и зависимости, копирует настройки в `%USERPROFILE%\.config` и подключает профиль PowerShell.

## Установка

Понадобятся Windows 11 x64, доступ к интернету и возможность подтвердить запросы UAC от установщиков отдельных программ. Запускайте скрипт под своей обычной учётной записью. Для Docker Desktop также нужны аппаратная виртуализация и настроенный WSL 2; актуальные требования приведены в [документации Docker](https://docs.docker.com/desktop/setup/install/windows-install/).

1. Скачайте репозиторий через **Code → Download ZIP**, распакуйте архив и откройте PowerShell в распакованной папке с `install.ps1`. PowerShell 7, Git и WinGet заранее устанавливать не требуется: достаточно встроенного Windows PowerShell 5.1.
2. Посмотрите список доступных компонентов. Эта команда выводит полный план без вопросов, загрузок, установки, изменения `PATH` и записи файлов:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -WhatIf
   ```

3. Запустите установку:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
   ```

   Перед установкой каждой недостающей программы скрипт задаст вопрос. Ответьте `Y` / `Yes`, чтобы установить, или `N` / `No` / Enter, чтобы пропустить. Также принимаются `Д` / `Да` и `Н` / `Нет`. Например, для пропуска Posting:

   ```text
   Install Posting? [y/N]: n
   Skipped Posting.
   ```

   Уже установленные программы пропускаются автоматически. WinGet, если он отсутствует, и шрифт JetBrainsMono Nerd Font тоже устанавливаются после отдельного подтверждения.

4. Если PowerShell 7 и Windows Terminal установлены, после завершения полностью закройте и снова откройте Windows Terminal. Выберите профиль **PowerShell 7 (dotfiles)**. В нём указан JetBrainsMono Nerd Font, если этот шрифт установлен; иначе используется шрифт Terminal по умолчанию. При желании сделайте этот профиль профилем по умолчанию в настройках Terminal.
5. Если скрипт сообщил о необходимости перезагрузки, перезагрузите Windows и повторите команду установки.

Если Git уже установлен, вместо скачивания ZIP можно клонировать репозиторий:

```powershell
git clone https://github.com/DurnevVS/.config.git "$env:USERPROFILE\dotfiles"
Set-Location "$env:USERPROFILE\dotfiles"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

Для установки всего набора без отдельных вопросов используйте `-Yes`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Yes
```

### Что делает установщик

- Восстанавливает или устанавливает WinGet из официального релиза Microsoft, если он отсутствует.
- Предлагает программы и зависимости из таблиц ниже по одной и устанавливает выбранные через WinGet, кроме Posting, шрифта и плагинов. Для .NET выбран **SDK 10 LTS**; [сроки поддержки .NET](https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core).
- Устанавливает Posting через `uv tool install --python 3.13 posting`; uv самостоятельно загружает Python, если нужно. [Инструкция для Python-версии Posting](https://pypi.org/project/posting/).
- Устанавливает JetBrainsMono Nerd Font для текущего пользователя. PSReadLine входит в PowerShell 7.
- Копирует только разрешённые файлы настроек, темы и плагины. Плагины Yazi и тема включены в репозиторий вместе с лицензиями; отдельно запускать `ya pkg add` не требуется.
- Если PowerShell 7 установлен, добавляет загрузку `powershell/init.ps1` в его профиль для текущего пользователя и всех хостов (`$PROFILE.CurrentUserAllHosts`). В этом профиле задаются пути к конфигурациям приложений, редактор и алиасы.
- Если PowerShell 7 и Windows Terminal установлены, создаёт профиль Terminal через [JSON-фрагмент](https://learn.microsoft.com/en-us/windows/terminal/json-fragment-extensions) в `%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\dotfiles\profile.json`.

Выбор влияет на установку программ; файлы настроек копируются в полном составе. Позже можно снова запустить установщик и установить пропущенные приложения.

Если отказаться от отсутствующего WinGet, установка программ через него будет пропущена. Posting требует uv: если uv отсутствует и его установка пропущена, скрипт объяснит причину пропуска Posting и продолжит работу. Если не установлены PowerShell 7 или Windows Terminal, соответствующие шаги настройки профиля тоже пропускаются. Отдельные зависимости Yazi и LazyGit можно пропустить, но функции, которые их используют, будут недоступны до установки этих зависимостей.

Существующие программы пропускаются, кроме проверки наличия нужной ветки .NET SDK и PowerShell 7. Установщик не обновляет автоматически весь установленный набор программ. Перед заменой отличающегося файла настроек, профиля или JSON-фрагмента сохраняется копия с датой и расширением `.bak`. Повторный запуск не создаёт копии неизменившихся файлов и не дублирует строку подключения профиля.

При ошибке скрипт останавливается и показывает причину. Исправьте её и повторите запуск: уже выполненные шаги будут пропущены. Если команда после установки пакета ещё не найдена, откройте новое окно PowerShell и запустите скрипт снова.

### Параметры

| Параметр | Назначение |
| --- | --- |
| `-WhatIf` | Показать план без изменений системы |
| `-Yes` | Установить все недостающие программы, зависимости и шрифт без отдельных вопросов |
| `-ConfigRoot 'D:\terminal-config'` | Установить настройки в другую папку и подключить её в профиле |
| `-SkipProfile` | Установить программы и файлы без изменения профиля PowerShell |

С `-SkipProfile` подключите конфигурацию самостоятельно в PowerShell 7, указав выбранную папку:

```powershell
. "$env:USERPROFILE\.config\powershell\init.ps1"
```

### После установки

Авторизация GitHub CLI и Codex выполняется отдельно при использовании этих приложений. Запустите Docker Desktop и завершите первый запуск; при необходимости настройте WSL 2 по инструкции Docker выше. Установщик устанавливает Docker Desktop, а настройка виртуализации и компонентов Windows выполняется отдельно.

В новом профиле PowerShell доступны `ls` (eza), `e` / `y` (Yazi с переходом в выбранную папку), `ed` (micro), `lg` (LazyGit), `lzd` (LazyDocker). `cd` автоматически подключает `.venv` в каталоге проекта.

Для быстрой проверки выполните команды для выбранных программ:

```powershell
pwsh --version
starship --version
yazi --version
uv --version
posting --version
dotnet --list-sdks
```

## Что публикуется в Git

`.gitignore` разрешает только конкретные файлы конфигурации, установщик, тесты, документацию и необходимые файлы тем и плагинов. Любые новые файлы и каталоги по умолчанию игнорируются. Если добавляете новую настройку, внесите её путь в `.gitignore` и в `Get-DotfilesConfigurationPaths` в `powershell/installer-functions.ps1`.

Локальными остаются весь `codex/` (включая настройки, авторизацию, сессии, базы данных и навыки), `cagent/`, авторизация `gh/hosts.yml`, история PowerShell, состояния LazyGit, закладки Yazi, буферы и резервные копии micro, коллекции и история Posting, `.env`, кэши, логи и сведения об установке uv. Настройки Codex и пользовательские коллекции установщик не переносит.

Перед публикацией просмотрите набор файлов:

```powershell
git status --short --untracked-files=all
git ls-files --cached --others --exclude-standard
```

`.gitignore` не удаляет ранее закоммиченные файлы из истории и не проверяет содержимое разрешённых конфигураций. Не записывайте токены и пароли в публикуемые настройки и не добавляйте личные файлы через `git add -f`.

## Проверки

Для проверок нужны Git, Python 3.11+ и соответствующий PowerShell. Установка программ не запускается; проверки используют временную папку, проверяют правила Git, копирование, резервные копии, повторный запуск, подключение профиля и отсутствие вопросов и изменений при `-WhatIf`. Также проверяются выбор отдельных программ, пропуск Posting и зависимостей, отказ от шрифта, PowerShell и Terminal, а также режим `-Yes`.

```powershell
python tests/run.py --shell powershell
python tests/run.py --shell pwsh
```

Полная установка на чистой Windows пока не проверена. Проверки в репозитории подтверждают работу отдельных шагов и предварительного просмотра, но не заменяют такой прогон.

## Программы

| Программа | Скачать |
| --- | --- |
| Windows Terminal | [GitHub](https://github.com/microsoft/terminal/releases/latest) |
| PowerShell 7 | [GitHub](https://github.com/PowerShell/PowerShell/releases/latest) |
| Starship | [GitHub](https://github.com/starship/starship/releases/latest) |
| Git for Windows | [GitHub](https://github.com/git-for-windows/git/releases/latest) |
| GitHub CLI | [GitHub](https://github.com/cli/cli/releases/latest) |
| LazyGit | [GitHub](https://github.com/jesseduffield/lazygit/releases/latest) |
| eza | [GitHub](https://github.com/eza-community/eza/releases/latest) |
| Yazi | [GitHub](https://github.com/sxyazi/yazi/releases/latest) |
| micro | [GitHub](https://github.com/micro-editor/micro/releases/latest) |
| Glow | [GitHub](https://github.com/charmbracelet/glow/releases/latest) |
| uv / uvx | [GitHub](https://github.com/astral-sh/uv/releases/latest) |
| Posting | [GitHub](https://github.com/darrenburns/posting/releases/latest) |
| LazyDocker | [GitHub](https://github.com/jesseduffield/lazydocker/releases/latest) |
| Docker Desktop | [Сайт](https://www.docker.com/products/docker-desktop/) |
| Codex CLI | [GitHub](https://github.com/openai/codex/releases/latest) |
| .NET SDK | [Сайт](https://dotnet.microsoft.com/download) |
| WinGet | [GitHub](https://github.com/microsoft/winget-cli/releases/latest) |

## Зависимости

| Зависимость | Скачать |
| --- | --- |
| delta | [GitHub](https://github.com/dandavison/delta/releases/latest) |
| FFmpeg — Windows-сборки Gyan | [GitHub](https://github.com/GyanD/codexffmpeg/releases/latest) |
| 7-Zip | [GitHub](https://github.com/ip7z/7zip/releases/latest) |
| jq | [GitHub](https://github.com/jqlang/jq/releases/latest) |
| fd | [GitHub](https://github.com/sharkdp/fd/releases/latest) |
| ripgrep | [GitHub](https://github.com/BurntSushi/ripgrep/releases/latest) |
| fzf | [GitHub](https://github.com/junegunn/fzf/releases/latest) |
| zoxide | [GitHub](https://github.com/ajeetdsouza/zoxide/releases/latest) |
| ImageMagick | [Сайт](https://imagemagick.org/download/) |
| Poppler — сборки для Windows | [GitHub](https://github.com/oschwartz10612/poppler-windows/releases/latest) |
| resvg | [GitHub](https://github.com/linebender/resvg/releases/latest) |
| PSReadLine | [GitHub](https://github.com/PowerShell/PSReadLine) |
| JetBrainsMono Nerd Font | [ZIP](https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip) |
| yamb (Yazi) | [GitHub](https://github.com/h-hg/yamb.yazi) |
| piper (Yazi) | [GitHub](https://github.com/yazi-rs/plugins) |
| toggle-pane (Yazi) | [GitHub](https://github.com/yazi-rs/plugins) |
| preview-arrow (Yazi) | [В репозитории](yazi/plugins/preview-arrow.yazi/main.lua) |
| Catppuccin Mocha (Yazi) | [GitHub](https://github.com/yazi-rs/flavors) |
