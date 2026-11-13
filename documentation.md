# ThetaRush: архитектура и путеводитель по проекту

<a id="contents"></a>
## Как пользоваться документом

Это справочник по текущему рабочему дереву проекта на 13 ноября 2026 года, включая ещё не закоммиченные изменения. Он описывает устройство кода, а не доказывает, что все сервисы сейчас запущены. Планы могут отставать от реализации: если чекбокс и код расходятся, ниже описано поведение кода.

Чтобы узнать назначение файла, найдите его имя через Ctrl+F или откройте соответствующий раздел справочника. Чтобы понять функцию целиком, начните со сценариев: один экран обычно собирается из нескольких файлов.

- [Общая картина и словарь](#overview)
- [Данные и связи](#data)
- [Как реализованы функции](#features): [вход](#auth), [профиль](#profile), [задачи и импорт](#problems), [редактор и Run](#editor), [Submit и проверка](#judging), [турниры и рейтинг](#contests), [живая таблица](#live), [избранное и группы](#social), [администрирование](#admin), [оформление и переводы](#ui)
- [Справочник файлов](#files): [корень](#root), [контроллеры](#controllers), [модели](#models), [сервисы и задания](#services), [каналы](#channels), [шаблоны](#views), [JavaScript](#javascript), [стили и ресурсы](#assets), [конфигурация](#config), [база и миграции](#database), [команды](#bin), [тесты](#tests), [планы](#plans), [служебные каталоги](#support)
- [Майлстоуны M1-M7](#milestones)
- [Ответы на частые вопросы](#lookup)
- [Что пока не реализовано](#limitations)

Метки **M1-M7** связывают файл с учебными требованиями из [plan/milestones.md](plan/milestones.md). Это функциональная принадлежность, а не дата появления файла. **Основа** означает общую инфраструктуру. Один файл может относиться к нескольким этапам.

<a id="overview"></a>
## Общая картина: кто за что отвечает

ThetaRush позволяет решать задачи на Python и C++, отправлять решения на проверку, участвовать в турнирах и получать рейтинг. Основное приложение написано на Ruby on Rails. Пользовательские Python/C++ программы исполняются в отдельном Judge0 CE, а не процессом Rails и не редактором в браузере.

Представьте учебный центр: браузер является окном приёма, Rails принимает заявления, PostgreSQL хранит журнал, Sidekiq выполняет отложенную работу, а Judge0 является отдельной лабораторией для проверки программ.

- **Браузер** показывает HTML и CSS. JavaScript управляет редактором, кнопками и частичными обновлениями.
- **Puma** принимает HTTP-запросы и передаёт их Rails. HTTP - обмен сообщениями вида «открой страницу» или «сохрани решение».
- **Rails** проверяет права, читает и изменяет данные, собирает HTML. Большинство страниц создаёт сервер, а не отдельное приложение React.
- **PostgreSQL** хранит пользователей, задачи, турниры, отправки и результаты. Это постоянная память приложения.
- **Redis + Sidekiq** организуют очередь фоновых заданий. Redis хранит очередь, Sidekiq забирает из неё задания. Это список поручений и работник, который их выполняет.
- **Judge0 CE** получает код, входные данные и ограничения, запускает проверку в isolate и возвращает результаты. Его PostgreSQL и Redis отделены от хранилищ ThetaRush.
- **Action Cable + Solid Cable** доставляют обновления таблицы турнира подписанным браузерам. Solid Cable использует PostgreSQL для обмена сообщениями между процессами Rails и Sidekiq. Redis здесь нужен очереди Sidekiq, а не транспорту Action Cable.
- **Docker Compose** описывает локальные сервисы. Основной compose запускает PostgreSQL, Redis и Adminer; отдельный compose запускает Judge0. Rails и Sidekiq в описанном README локальном сценарии запускаются отдельно.

При открытии каталога задач запрос проходит через [routes.rb](config/routes.rb), затем [ProblemsController](app/controllers/problems_controller.rb). Контроллер получает записи через [Problem](app/models/problem.rb), передаёт их [шаблону каталога](app/views/problems/index.html.erb), а Rails вставляет страницу в [общую оболочку](app/views/layouts/application.html.erb). Браузер получает готовый HTML.

### Словарь на примерах

- **Маршрут, route**: запись в адресной книге. Связывает HTTP-метод и URL с действием контроллера. GET читает, POST обычно создаёт или запускает действие, PATCH изменяет, DELETE удаляет.
- **Контроллер, controller**: диспетчер запроса. Определяет, кто пришёл, что разрешено и какие данные нужны. Ruby-контроллеры сервера и Stimulus-контроллеры браузера являются разными слоями.
- **Модель, model**: представление сущности базы и её правил. Например, Submission знает допустимые языки и связь с задачей. Active Record переводит операции Ruby в SQL-запросы к базе.
- **Шаблон, view**: бланк страницы. Файл .html.erb содержит HTML и Ruby-вставки. Значения подставляются на сервере.
- **Partial**: многократно используемый фрагмент шаблона, например кнопка избранного. Имя начинается с подчёркивания; render вызывает его без этого подчёркивания.
- **Service object**: отдельный исполнитель сложной операции, например подсчёта штрафа. Это класс внутри Rails, а не обязательно отдельный сетевой сервер.
- **Job**: поручение, которое можно выполнить сейчас через perform_now или поставить в очередь через perform_later. Само наличие класса Job ещё не означает фоновое выполнение.
- **Валидация**: проверка данных перед сохранением. **Индекс** ускоряет поиск, а уникальный индекс дополнительно запрещает дубли на уровне базы.
- **Внешний ключ**: связь между строками таблиц, например submission.user_id указывает на users.id.
- **Транзакция**: несколько изменений как единая операция: либо сохраняются все, либо отменяются все. Блокировка записи помогает двум процессам не пересчитать её одновременно.
- **Миграция**: инструкция изменения структуры базы. **Schema**: снимок итоговой структуры. **Seeds**: начальные демонстрационные данные.
- **Session, сессия**: информация о текущем входе. Cookie в браузере позволяет узнавать пользователя между запросами. **localStorage** хранит локальные настройки интерфейса и не заменяет серверную учётную запись.
- **Polling**: периодический вопрос «результат уже готов?». **Webhook**: обратный HTTP-вызов, когда другой сервис сам сообщает о событии.
- **WebSocket**: длительное соединение, через которое сервер может отправить обновление без нового запроса пользователя.
- **Turbo Frame**: обновляемый участок страницы. **Turbo Stream**: инструкция изменить HTML, например заменить строки таблицы. Stream может прийти и обычным HTTP-ответом, и через WebSocket.
- **Stimulus**: JavaScript-поведение, подключаемое к HTML через data-controller, data-action и data-...-target. **Importmap**: список соответствий между именами JS-модулей и файлами.
- **API и JSON**: договорённость об обмене данными и текстовый формат этих данных. Judge0Client использует HTTP API Judge0.
- **Fixture, fake**: заранее подготовленные данные и подставной внешний сервис для теста. Они позволяют проверять Rails без настоящего исполнения пользовательского кода.
- **CI**: автоматические проверки изменений. **Deploy**: развёртывание приложения на сервере. Файлы для deploy не доказывают наличие работающего production-сайта.

[К оглавлению](#contents)

<a id="data"></a>
## Данные и связи

Источник структуры - [db/schema.rb](db/schema.rb), правил и связей - [модели](#models).

- **User** хранит email, хеш пароля, отображаемое имя, текущий/максимальный рейтинг, признак администратора и ссылку на закреплённый турнир. Email уникален, username в текущем коде может повторяться.
- **Problem** хранит условие, сложность, теги, примеры и лимиты. У одной задачи много **TestCase**. Тест содержит вход и ожидаемый ответ текстом либо вложением Active Storage. Методы модели сначала используют текст, затем вложенный файл.
- **Contest** хранит время и состояние турнира. **ContestProblem** связывает турнир с задачей и добавляет её букву и позицию. Одна задача может использоваться в нескольких турнирах.
- **ContestParticipation** связывает пользователя с турниром: время регистрации, количество решённых задач, штраф и место. Это одновременно факт участия и сохранённая строка таблицы результатов.
- **Submission** хранит автора, задачу, язык, исходный код, статус, вывод и ресурсы проверки. contest_id может отсутствовать: тогда это тренировочная отправка. judge0_token хранит JSON со списком идентификаторов проверок отдельных тестов.
- **RatingHistory** хранит старый и новый рейтинг пользователя за конкретный турнир. Она нужна, чтобы профиль показывал историю, а не только последнее число.
- **Favorite** связывает пользователя либо с Problem, либо с Contest. Такое универсальное указание через тип и id называется полиморфной связью: как закладка, которая помнит и вид документа, и его номер.
- **GroupMembership** связывает User с Group и хранит роль owner/member. Участие в группе само по себе не является участием в турнире.
- **Active Storage** использует собственные таблицы метаданных и связей вложений. Содержимое локальных вложений хранится в storage согласно config/storage.yml.
- Отдельные схемы **cable**, **cache**, **queue** относятся к библиотекам Rails. Наличие queue_schema.rb не меняет выбранный адаптер заданий: в development и production используется Sidekiq.

Связующие таблицы нужны потому, что одна запись может участвовать во многих отношениях. Например, у турнира много задач, и одна задача встречается в нескольких турнирах. ContestProblem хранит каждое отдельное включение задачи, не копируя её условие.

Ограничения существуют на двух уровнях: модели дают понятные ошибки, база защищает целостность данных. Например, участие пользователя в одном турнире не должно дублироваться. Для ряда сущностей модель запрещает удаление при наличии связанных результатов; точное поведение нужно смотреть в dependent и внешних ключах, а не предполагать каскадное удаление всего.

[К оглавлению](#contents)

<a id="features"></a>
## Как реализованы функции

<a id="auth"></a>
### Вход, регистрация и сессия [M2]

[routes.rb](config/routes.rb) подключает devise_for :users. Поэтому контроллер входа не обязан находиться в app/controllers: стандартные действия предоставляет библиотека Devise из Gemfile. [User](app/models/user.rb) включает вход по паролю, регистрацию, восстановление пароля, запоминание входа и проверку полей.

[Форма регистрации](app/views/devise/registrations/new.html.erb) отправляет email, пароль и необязательный username. [ApplicationController](app/controllers/application_controller.rb) разрешает Devise принять username. Если имя не задано, модель создаёт его из email. Имя обрезается по краям, имеет длину 3-20 символов и допускает Unicode-буквы, комбинируемые знаки, цифры, пробелы и подчёркивания. Совпадение отображаемых имён разрешено.

После входа Devise поддерживает сессию; обновление страницы её не сбрасывает. authenticate_user! защищает действия, а current_user предоставляет текущего пользователя. Sidebar меняет элементы для гостя и вошедшего пользователя. /dashboard служит простым подтверждением входа.

Шаблоны подтверждения email и разблокировки существуют, но модули confirmable и lockable в User не включены. Наличие таких файлов не означает работающий пользовательский сценарий. Отправка писем также зависит от настройки среды.

Проверки: [auth_session_test.rb](test/controllers/auth_session_test.rb), [user_test.rb](test/models/user_test.rb).

<a id="profile"></a>
### Профиль и изменение имени [M2, M5]

GET /profile вызывает [ProfilesController#show](app/controllers/profiles_controller.rb). Он берёт данные только текущего пользователя: последние 10 изменений рейтинга, последние 10 отправок, число участий и число уникальных решённых задач. [Шаблон](app/views/profiles/show.html.erb) показывает данные и форму имени.

PATCH /profile разрешает изменить только username, без повторного ввода пароля. При ошибке повторно загружает данные страницы и возвращает форму с сообщениями. Переданный чужой id или поле rating не превращает эту форму в редактор чужого аккаунта. Снятие уникальности username отражено в [миграции](db/migrate/20261113120000_allow_duplicate_usernames.rb) и текущей схеме.

Проверки: [profiles_controller_test.rb](test/controllers/profiles_controller_test.rb).

<a id="problems"></a>
### Каталог, условие и импорт задач [M4, M5]

GET /problems проходит через [ProblemsController#index](app/controllers/problems_controller.rb): фильтры по названию, диапазону сложности и тегу превращаются в запросы к Problem. Счётчик решивших считает разных пользователей с AC. GET /problems/:id собирает условие, языки, избранное и собственные отправки; при contest_id дополнительно проверяет принадлежность задачи турниру.

[import:problems](lib/tasks/import.rake) читает JSON из db/seeds/problems и вызывает [Problems::Importer](app/services/problems/importer.rb). Он находит или создаёт задачу по slug, обновляет её поля и синхронизирует тесты по position. Повторный импорт не создаёт второй экземпляр той же задачи. Важная деталь: тесты, отсутствующие в новом наборе позиций, удаляются; импорт не является простым добавлением в конец.

[db/seeds.rb](db/seeds.rb) также импортирует JSON, затем создаёт или обновляет демонстрационный турнир и включает в него до 26 задач. Повторный запуск меняет временное окно демотурнира. Это операция записи, а не команда просмотра.

В репозитории есть JSON для A + B и Hello Name. Автоматического конвейера загрузки внешних датасетов из исходной архитектурной схемы здесь нет.

Проверки: [importer_test.rb](test/services/problems/importer_test.rb), [ui_kit_placeholders_test.rb](test/controllers/ui_kit_placeholders_test.rb).

<a id="editor"></a>
### Редактор и кнопка Run [M3, M5]

[Страница задачи](app/views/problems/show.html.erb) соединяет условие, контекст турнира и [панели редактора](app/views/problems/_editor_chrome.html.erb). [editor_controller.js](app/javascript/controllers/editor_controller.js) загружает локальный Monaco, синхронизирует текст с полем формы, переключает язык и Vim-режим. При проблеме загрузки предусмотрено обычное текстовое поле.

[file_upload_controller.js](app/javascript/controllers/file_upload_controller.js) читает выбранный пользователем файл в редактор, а не исполняет его. [split_pane_controller.js](app/javascript/controllers/split_pane_controller.js) меняет размеры панелей. Настройки размеров, боковой панели и флаги редактора используют localStorage; это не серверное сохранение решения.

Run запускается через [custom_run_controller.js](app/javascript/controllers/custom_run_controller.js). Он отправляет код, язык и пользовательский stdin в POST /problems/:problem_id/custom_runs. [CustomRunsController](app/controllers/custom_runs_controller.rb) проверяет вход и поля, затем вызывает Judge0Client#create_run с лимитами задачи.

Judge0 получает одну проверку с wait=true, без expected_output и webhook. Rails возвращает JSON с выводом, ошибками и ресурсами. Браузер показывает результат и может сравнить его с примером. Такая проверка примера не является официальным прохождением всех тестов задачи. Run не создаёт Submission, не ставит JudgeSubmissionJob и не меняет рейтинг или зачёт турнира.

Проверки: [custom_runs_controller_test.rb](test/controllers/custom_runs_controller_test.rb), [judge0_client_test.rb](test/services/judge0_client_test.rb).

<a id="judging"></a>
### Submit: от кода до вердикта [M5, M6]

1. Форма отправляет POST /problems/:problem_id/submissions в [SubmissionsController#create](app/controllers/submissions_controller.rb). Требуется вход. Контроллер проверяет турнирный контекст и сохраняет Submission со статусом queued.
2. perform_later ставит [JudgeSubmissionJob](app/jobs/judge_submission_job.rb) в очередь Sidekiq через Redis. Браузер получает переход к отправке либо Turbo Stream с обновлением панели отправок в рабочем пространстве.
3. Sidekiq выполняет job, меняет статус на judging и вызывает [Judge0Client#create_batch](app/services/judge0_client.rb). Для каждого TestCase создаётся отдельная проверка одного и того же исходного кода с соответствующими stdin, expected_output и лимитами.
4. Judge0 исполняет программу в isolate. Список выданных токенов сохраняется в Submission, чтобы затем получить результаты и не отправлять тот же пакет повторно при продолжении задания.
5. Judge0 вызывает POST /judge0/webhook. [Judge0WebhookController](app/controllers/judge0_webhook_controller.rb) проверяет общий секрет и вызывает [ApplyJudge0Result](app/services/submissions/apply_judge0_result.rb). Обработчик не принимает присланный вердикт на веру: сервис заново запрашивает пакет по сохранённым токенам.
6. Пока хотя бы один полученный результат находится в очереди или обработке, агрегированный статус остаётся judging. Иначе выбирается первый не-AC результат, либо AC, если все успешны. Время и память берутся как максимумы по результатам.
7. Сервис сохраняет вердикт и, для турнирной отправки с участием пользователя, пересчитывает зачёт в транзакции. После успешного сохранения отправляет обновление таблицы турнира.

У webhook есть серверный запасной путь: JudgeSubmissionJob сам запрашивает результат через тот же сервис до 45 попыток с паузой 1 секунду между незавершёнными попытками. Это не строгий предел 45 секунд: сетевые запросы тоже занимают время. Ошибка или исчерпание попыток переводит отправку в ie. Этот аварийный путь job напрямую сохраняет ошибку и не вызывает сервис трансляции таблицы.

Статусы: queued - ожидает; judging - проверяется; ac - принято; wa - неверный ответ; tle - превышено время; mle - превышена память; re - ошибка исполнения; ce - ошибка компиляции; ie - внутренняя ошибка проверки.

Обновление панели в браузере является отдельным polling: [submission_status_controller.js](app/javascript/controllers/submission_status_controller.js) примерно раз в 1,5 секунды запрашивает GET /submissions/:id/status и заменяет HTML панели. Доступ к этому endpoint есть только у владельца. При конечном результате активный polling прекращается. Успешная замена незавершённой панели создаёт новый экземпляр контроллера, поэтому maxAttempts не следует считать общим пределом всех запросов за жизнь страницы.

GET /submissions показывает вошедшему пользователю его отправки, а при найденном contest_id - отправки турнира. GET /submissions/:id в текущем контроллере публичен; ограничение владельцем для /status не распространяется автоматически на страницу show. Она показывает в том числе исходный код.

Автоматический polling подключён к панели рабочего пространства задачи. Отдельная страница отправки show показывает кнопку ручного обновления, пока результат не готов; собственного автоматического обновления на ней сейчас нет.

Проверки: [интеграционный сценарий](test/integration/submission_judging_flow_test.rb), [job](test/jobs/judge_submission_job_test.rb), [обработка результатов](test/services/submissions/apply_judge0_result_test.rb).

<a id="contests"></a>
### Турниры, зачёт и рейтинг [M4, M5]

[ContestsController](app/controllers/contests_controller.rb) строит список по состояниям upcoming/running/finished/finalized, открывает турнир и его scoreboard. Регистрация создаёт ContestParticipation один раз. При первой обычной регистрации пересчитываются места. При отправке решения вошедший пользователь также может автоматически получить участие, если состояние турнира допускает это; отправка принимается только при running и попадании текущего времени в окно турнира.

[Contests::Scoring](app/services/contests/scoring.rb) считает только турнирные отправки внутри временного окна. Для каждой задачи учитывается первая AC: штраф равен целым минутам от старта до отправки AC плюс 20 минут за каждую предыдущую WA/TLE/MLE/RE. CE и IE не добавляют штрафа. Без AC задача не даёт ни решения, ни штрафа. Например, WA, затем AC на 12-й минуте дают 1 решение и 32 минуты штрафа.

Выше стоит участник с большим числом решений, затем с меньшим штрафом. Одинаковые результаты дают одинаковое место, например 1, 1, 3. Время регистрации и id стабилизируют порядок строк.

Финализацию после ends_at запускает администратор через POST /contests/:id/finalize. Контроллер вызывает [FinalizeContestJob](app/jobs/finalize_contest_job.rb) через perform_now, то есть в текущем запросе. Job пересчитывает зачёт, выставляет finished и синхронно вызывает [UpdateRatingsJob](app/jobs/update_ratings_job.rb).

[Ratings::Calculator](app/services/ratings/calculator.rb) сравнивает ожидаемый и фактический результат каждого участника относительно остальных. Это собственный Elo-подобный расчёт, вдохновлённый Codeforces, а не точное воспроизведение его рейтинга. Калькулятор не пишет в базу. UpdateRatingsJob сохраняет User.rating, max_rating и RatingHistory в транзакции и переводит турнир в finalized. Повторный вызов для finalized ничего не начисляет. При одном участнике рейтинг не меняется, но запись истории создаётся.

Автоматического переключения турниров по расписанию в текущем коде нет. Дата, сохранённый status и действие финализации являются отдельными вещами.

Проверки: [scoring_test.rb](test/services/contests/scoring_test.rb), [calculator_test.rb](test/services/ratings/calculator_test.rb), [finalize_contest_job_test.rb](test/jobs/finalize_contest_job_test.rb), [contest_submissions_controller_test.rb](test/controllers/contest_submissions_controller_test.rb).

<a id="live"></a>
### Живая таблица турнира [M7]

[scoreboard.html.erb](app/views/contests/scoreboard.html.erb) показывает таблицу всем, но создаёт подписку только для вошедших пользователей. [Connection](app/channels/application_cable/connection.rb) узнаёт пользователя через Devise/Warden и отвергает гостевое соединение. [ScoreboardChannel](app/channels/scoreboard_channel.rb) проверяет пользователя и наличие турнира, затем использует подписанный поток Turbo.

После сохранения конечного вердикта и пересчёта зачёта ApplyJudge0Result вызывает [ScoreboardBroadcaster](app/services/contests/scoreboard_broadcaster.rb). Он рендерит [_scoreboard_rows.html.erb](app/views/contests/_scoreboard_rows.html.erb) и отправляет replace для scoreboard_rows в поток конкретного турнира. Action Cable доставляет сообщение браузеру; Turbo меняет строки без перезагрузки всей страницы.

Отправка сообщения отложена до commit транзакции, чтобы браузер не увидел результат, который база затем отменит. Ошибка самой трансляции записывается в лог и не отменяет уже сохранённый вердикт.

Кнопка ручного обновления загружает Turbo Frame scoreboard. Подписка находится снаружи этого frame, поэтому обновление таблицы не создаёт её повторно. Без JavaScript ссылка открывает страницу обычным способом.

Ограничения: регистрация и финализация не транслируют таблицу; после них нужно обновить её вручную. После разрыва и восстановления соединения пропущенные изменения автоматически не восстанавливаются, также нужен refresh. Гость пользуется ручным обновлением. Здесь работает WebSocket, тогда как панель собственной отправки использует HTTP polling.

Проверки: [канал](test/channels/scoreboard_channel_test.rb), [соединение](test/channels/application_cable/connection_test.rb), [контроллер таблицы](test/controllers/contests_controller_test.rb), [транзакции и трансляция](test/services/submissions/apply_judge0_result_test.rb). Результаты прежней ручной проверки записаны в README; они не являются новой проверкой текущего запуска.

<a id="social"></a>
### Избранное, закрепление турнира и группы [M4, M5]

[FavoritesController](app/controllers/favorites_controller.rb) создаёт закладку Problem/Contest для current_user и удаляет только его запись. Общая кнопка находится в [shared/_favorite_button.html.erb](app/views/shared/_favorite_button.html.erb).

Закрепление является отдельной функцией: [PinnedContestsController](app/controllers/pinned_contests_controller.rb) меняет единственное поле User.pinned_contest. Ответ Turbo Stream заменяет кнопку и слот sidebar; это ответ на HTTP-запрос, а не WebSocket-трансляция. HTML-ветка возвращает пользователя на страницу.

[GroupsController](app/controllers/groups_controller.rb) показывает группы и участников, создаёт группу с владельцем, позволяет вступить и выйти. [Group](app/models/group.rb) создаёт уникальный slug для URL. Последний owner не может выйти. Блоки активности на странице группы пока содержат заглушки; создание группы не включает систему командных турниров или ленту событий.

Проверка закрепления: [pinned_contests_controller_test.rb](test/controllers/pinned_contests_controller_test.rb). Отдельных специализированных тестовых файлов для избранного и групп в текущем дереве нет.

<a id="admin"></a>
### Администрирование [M5]

/admin использует Administrate. [Admin::ApplicationController](app/controllers/admin/application_controller.rb) требует вход и admin?. Маршруты открыты для contests, contest_problems, problems и test_cases. Администратор может подготовить задачи и состав турнира для основного сценария.

Файлы app/dashboards описывают поля и представления административных экранов; это не пользовательская страница /dashboard. Контроллеры и dashboard-классы для пользователей, отправок, истории рейтинга и участия существуют, но соответствующих resources в текущем namespace :admin нет. Нельзя считать их доступными экранами только по имени файла.

Adminer из Docker Compose - другой инструмент: интерфейс к базе данных, а не административная панель Rails.

Проверка прав: [admin_access_test.rb](test/controllers/admin_access_test.rb).

<a id="ui"></a>
### Оформление, переводы и UI Kit [M2, M3, M5]

[application.html.erb](app/views/layouts/application.html.erb) подключает стили, importmap, иконку и внешние шрифты, показывает sidebar и сообщения, вставляет шаблон страницы через yield. [ApplicationHelper](app/helpers/application_helper.rb) создаёт навигацию, значки вердиктов, подписи рейтинга и времени.

Стили лежат в [application.css](app/assets/stylesheets/application.css) и [theme_dark.css](app/assets/stylesheets/theme_dark.css). [UI Kit](app/views/ui_kit/show.html.erb) демонстрирует элементы, а design хранит визуальные ориентиры, не исполняемый интерфейс.

[LocalesController](app/controllers/locales_controller.rb) сохраняет en/ru в cookie и сессии. ApplicationController выбирает cookie, затем сессию, затем язык по умолчанию en. Вызов t(...) берёт строку из config/locales. Отдельное правило выбирает русские формы «1 задача», «2 задачи», «5 задач».

[К оглавлению](#contents)

<a id="files"></a>
## Справочник папок и файлов

Запись содержит путь, назначение, момент использования и связи. Ссылки в заголовках разделов ведут к соответствующему сценарию. Общая механика Rails относится ко всем файлам раздела: контроллеры вызываются маршрутами, модели работают через Active Record, шаблоны рендерятся контроллерами или другими шаблонами. Ниже отдельно отмечены исключения и неподключённые заготовки.

<a id="root"></a>
### Корень проекта

Здесь собраны точки входа, зависимости и описание сервисов. Сценарий: [общая архитектура](#overview).

- [AGENTS.md](AGENTS.md) **[Основа]**: правила работы с проектом для ассистентов; читаются перед изменениями, дополняют планы.
- [README.md](README.md) **[Основа, M5-M7]**: краткий запуск, требования, команды и записанные результаты ручной проверки; помогает перейти от файлов конфигурации к работающему стеку.
- [documentation.md](documentation.md) **[M1-M7]**: этот подробный справочник; связывает код, сценарии и требования.
- [Gemfile](Gemfile) **[Основа]**: список Ruby-библиотек, включая Rails, Devise, Sidekiq и Administrate; Bundler использует его при установке.
- [Gemfile.lock](Gemfile.lock) **[Основа]**: зафиксированные разрешённые версии библиотек и их зависимостей; делает установку Gemfile воспроизводимой.
- [Rakefile](Rakefile) **[Основа]**: загружает Rails-задачи для bin/rake, включая lib/tasks/import.rake.
- [config.ru](config.ru) **[Основа]**: точка входа Rack для веб-сервера; загружает config/environment.rb и приложение Rails.
- [Dockerfile](Dockerfile) **[Основа]**: сборка контейнерного образа Rails с библиотеками и ресурсами; использует bin/docker-entrypoint, не является описанием Judge0.
- [docker-compose.yml](docker-compose.yml) **[Основа, M5]**: локальные PostgreSQL, Redis и Adminer, их сеть и тома; нужны Rails, Sidekiq и инструменту просмотра БД.
- [docker-compose.judge0.yml](docker-compose.judge0.yml) **[M5]**: отдельные API, workers, PostgreSQL и Redis Judge0; подключает judge0.conf и обеспечивает окружение внешней проверки.
- [judge0.conf](judge0.conf) **[M5]**: настройки Judge0 и ограничений запуска; используется его контейнерами, значения секретов здесь не воспроизводятся.
- [.ruby-version](.ruby-version) **[Основа]**: версия Ruby для инструментов разработки и CI; согласуется с окружением Gemfile.lock.
- [.rubocop.yml](.rubocop.yml) **[Основа]**: правила Ruby-стиля для bin/rubocop и CI; не меняют поведение сайта.
- [.gitignore](.gitignore) **[Основа]**: исключения Git для локальных и создаваемых файлов; влияет на состав изменений, не на маршруты Rails.
- [.gitattributes](.gitattributes) **[Основа]**: правила Git для обработки файлов, в том числе текстовых; используется при работе с репозиторием.
- [.dockerignore](.dockerignore) **[Основа]**: исключения контекста Docker-сборки; дополняет Dockerfile, а не .gitignore.
- [.env.example](.env.example) **[Основа, M5]**: образец имён настроек окружения для сервисов и Judge0; наличие примера само по себе не загружает .env в Ruby-процесс.
- [cookies.txt](cookies.txt) **[Локальный артефакт]**: имеющийся неотслеживаемый файл cookie; не является исходником или частью архитектуры приложения. Содержимое не читается и не публикуется.

[К справочнику](#files) · [К оглавлению](#contents)

<a id="controllers"></a>
### app/controllers: обработка запросов

Папка направляет действия пользователя к моделям и сервисам. См. [сценарии](#features).

- [app/controllers/application_controller.rb](app/controllers/application_controller.rb) **[Основа, M2]**: общий родитель контроллеров: выбор языка, современные браузеры и разрешение username при регистрации; вызывается вокруг запросов.
- [app/controllers/home_controller.rb](app/controllers/home_controller.rb) **[M3, M5]**: получает реальные счётчики задач, пользователей и активных/будущих турниров для главной страницы.
- [app/controllers/dashboard_controller.rb](app/controllers/dashboard_controller.rb) **[M2]**: защищает демонстрационную страницу сессии authenticate_user!; рендерит dashboard/show.
- [app/controllers/ui_kit_controller.rb](app/controllers/ui_kit_controller.rb) **[M3]**: открывает галерею компонентов ui_kit/show без проверки решений.
- [app/controllers/problems_controller.rb](app/controllers/problems_controller.rb) **[M3, M5]**: фильтрует Problem, готовит страницу задачи и турнирные вкладки; связывает каталог, модели и рабочее пространство.
- [app/controllers/submissions_controller.rb](app/controllers/submissions_controller.rb) **[M5]**: создаёт Submission и ставит JudgeSubmissionJob, показывает списки и детали; endpoint status отдаёт владельцу HTML панели.
- [app/controllers/custom_runs_controller.rb](app/controllers/custom_runs_controller.rb) **[M5]**: принимает Run, проверяет язык/код, вызывает Judge0Client и возвращает JSON; записи Submission не создаёт.
- [app/controllers/judge0_webhook_controller.rb](app/controllers/judge0_webhook_controller.rb) **[M5]**: принимает callback Judge0 с проверкой общего секрета; передаёт найденную отправку ApplyJudge0Result.
- [app/controllers/contests_controller.rb](app/controllers/contests_controller.rb) **[M5, M7]**: готовит список, карточку и таблицу турнира, регистрирует участника и разрешает администратору финализацию; использует Scoring и FinalizeContestJob.
- [app/controllers/profiles_controller.rb](app/controllers/profiles_controller.rb) **[M2, M5]**: показывает данные current_user и изменяет только username; ошибки возвращает в заполненный profiles/show.
- [app/controllers/locales_controller.rb](app/controllers/locales_controller.rb) **[M3]**: сохраняет выбранный en/ru в cookie и сессии; ApplicationController применяет его при следующих запросах.
- [app/controllers/favorites_controller.rb](app/controllers/favorites_controller.rb) **[M5]**: показывает и изменяет избранное текущего пользователя; принимает только Problem или Contest.
- [app/controllers/pinned_contests_controller.rb](app/controllers/pinned_contests_controller.rb) **[M5]**: меняет User.pinned_contest; рендерит Turbo Stream для кнопки/боковой панели либо HTML-переход.
- [app/controllers/groups_controller.rb](app/controllers/groups_controller.rb) **[M5]**: создаёт группы, загружает участников и обрабатывает вступление/выход через GroupMembership; защищает последнего владельца.
- [app/controllers/concerns/placeholder_data.rb](app/controllers/concerns/placeholder_data.rb) **[M3, заготовка]**: старые демонстрационные OpenStruct-данные для экранов; подключение этого concern в текущих контроллерах не найдено.
- [app/controllers/admin/application_controller.rb](app/controllers/admin/application_controller.rb) **[M5]**: общая проверка входа и admin? перед действиями Administrate; родитель всех admin-контроллеров.
- [app/controllers/admin/contests_controller.rb](app/controllers/admin/contests_controller.rb) **[M5]**: стандартные операции Administrate над Contest через contest_dashboard; доступен в /admin.
- [app/controllers/admin/contest_problems_controller.rb](app/controllers/admin/contest_problems_controller.rb) **[M5]**: управляет связями задач с турнирами через contest_problem_dashboard; доступен в /admin.
- [app/controllers/admin/problems_controller.rb](app/controllers/admin/problems_controller.rb) **[M5]**: управляет Problem и преобразует строку тегов в массив; использует problem_dashboard.
- [app/controllers/admin/test_cases_controller.rb](app/controllers/admin/test_cases_controller.rb) **[M5]**: управляет тестами задач через test_case_dashboard; доступен в /admin.
- [app/controllers/admin/users_controller.rb](app/controllers/admin/users_controller.rb) **[M5, заготовка]**: стандартный контроллер Administrate для User; маршрут ресурса сейчас не подключён.
- [app/controllers/admin/submissions_controller.rb](app/controllers/admin/submissions_controller.rb) **[M5, заготовка]**: контроллер Administrate для Submission; маршрут ресурса сейчас не подключён.
- [app/controllers/admin/rating_histories_controller.rb](app/controllers/admin/rating_histories_controller.rb) **[M5, заготовка]**: контроллер Administrate для RatingHistory; маршрут ресурса сейчас не подключён.
- [app/controllers/admin/contest_participations_controller.rb](app/controllers/admin/contest_participations_controller.rb) **[M5, заготовка]**: контроллер Administrate для ContestParticipation; маршрут ресурса сейчас не подключён.

[К справочнику](#files) · [К оглавлению](#contents)

<a id="models"></a>
### app/models: сущности и правила

Модели соответствуют таблицам db/schema.rb. См. [связи данных](#data).

- [app/models/application_record.rb](app/models/application_record.rb) **[Основа]**: общий абстрактный родитель моделей Active Record; собственной таблицы не имеет.
- [app/models/user.rb](app/models/user.rb) **[M2, M4, M5]**: учётная запись, Devise, правила имени, рейтинги и связи с результатами/группами; используется входом, профилем и турнирами.
- [app/models/problem.rb](app/models/problem.rb) **[M4]**: условие, лимиты, теги, slug и связи с тестами/отправками; проверяет и нормализует данные перед сохранением.
- [app/models/test_case.rb](app/models/test_case.rb) **[M4, M5]**: тест задачи; читает stdin и expected_output из текста или Active Storage для Judge0Client.
- [app/models/submission.rb](app/models/submission.rb) **[M4, M5]**: отправка программы, допустимые языки/статусы и время; проверяет, что турнир действительно включает задачу.
- [app/models/contest.rb](app/models/contest.rb) **[M4]**: турнир со временем и состоянием, связями с задачами и участниками; проверяет порядок дат.
- [app/models/contest_problem.rb](app/models/contest_problem.rb) **[M4]**: включение Problem в Contest с буквой и позицией; не допускает повторов внутри турнира.
- [app/models/contest_participation.rb](app/models/contest_participation.rb) **[M4, M5]**: регистрация и сохранённые solved_count, penalty, rank; используется Scoring и таблицей.
- [app/models/rating_history.rb](app/models/rating_history.rb) **[M4, M5]**: изменение рейтинга за турнир; ограничивает запись парой пользователь/турнир, используется UpdateRatingsJob и профилем.
- [app/models/favorite.rb](app/models/favorite.rb) **[M4, M5]**: закладка пользователя на задачу или турнир; проверяет тип и отсутствие дублей для FavoritesController.
- [app/models/group.rb](app/models/group.rb) **[M4, M5]**: имя, описание и уникальный slug группы; задаёт URL через to_param, связывает участников.
- [app/models/group_membership.rb](app/models/group_membership.rb) **[M4, M5]**: членство пользователя в группе с ролью owner/member; исключает повторное членство.

[К справочнику](#files) · [К оглавлению](#contents)

<a id="services"></a>
### app/services и app/jobs: операции и задания

Service выполняет расчёт или обмен с внешней системой. Job задаёт запуск операции сейчас или позже. См. [проверку](#judging), [зачёт](#contests) и [live](#live).

- [app/services/judge0_client.rb](app/services/judge0_client.rb) **[M5]**: HTTP-адаптер Judge0: языковые id, одиночный Run, пакет тестов, получение и объединение вердиктов; вызывается контроллером Run и заданиями проверки.
- [app/services/submissions/apply_judge0_result.rb](app/services/submissions/apply_judge0_result.rb) **[M5, M7]**: повторно получает результаты пакета, сохраняет вердикт и зачёт под блокировками; после commit вызывает ScoreboardBroadcaster.
- [app/services/contests/scoring.rb](app/services/contests/scoring.rb) **[M4, M5]**: рассчитывает решения, штраф и места по отправкам; вызывается при вердикте, регистрации и финализации.
- [app/services/contests/scoreboard_broadcaster.rb](app/services/contests/scoreboard_broadcaster.rb) **[M7]**: рендерит строки таблицы и отправляет Turbo replace в поток турнира; ошибки доставки пишет в лог.
- [app/services/ratings/calculator.rb](app/services/ratings/calculator.rb) **[M4]**: чистый Elo-подобный расчёт и подготовка полей истории без записи в БД; используется UpdateRatingsJob.
- [app/services/problems/importer.rb](app/services/problems/importer.rb) **[M5]**: создаёт/обновляет задачу по slug и синхронизирует тесты по позиции; вызывается seeds и import:problems.
- [app/jobs/application_job.rb](app/jobs/application_job.rb) **[Основа]**: родитель Active Job; сам не задаёт очередь Sidekiq, адаптер выбирается в окружениях.
- [app/jobs/judge_submission_job.rb](app/jobs/judge_submission_job.rb) **[M5]**: исполняется Sidekiq после Submit, отправляет пакет и опрашивает Judge0 через ApplyJudge0Result; при ошибках сохраняет ie.
- [app/jobs/finalize_contest_job.rb](app/jobs/finalize_contest_job.rb) **[M5]**: проверяет окончание турнира, пересчитывает результаты и вызывает UpdateRatingsJob; admin-контроллер запускает синхронно.
- [app/jobs/update_ratings_job.rb](app/jobs/update_ratings_job.rb) **[M5]**: под блокировками сохраняет расчёт рейтингов и RatingHistory, помечает турнир finalized; защищает от повторного начисления.

[К справочнику](#files) · [К оглавлению](#contents)

<a id="channels"></a>
### app/channels: соединение с живой таблицей

Каналы не проверяют код и не заменяют polling панели отправки. См. [live scoreboard](#live).

- [app/channels/application_cable/connection.rb](app/channels/application_cable/connection.rb) **[M7]**: получает current_user из Devise/Warden при WebSocket-подключении; отвергает гостей.
- [app/channels/scoreboard_channel.rb](app/channels/scoreboard_channel.rb) **[M7]**: допускает подписку вошедшего пользователя на существующий турнир, затем использует механизм подписанного Turbo-потока.

[К справочнику](#files) · [К оглавлению](#contents)

<a id="views"></a>
### app/views, app/helpers, app/mailers и app/dashboards

Шаблоны получают переменные контроллера, например @contest. Их Ruby-вставки выполняются на сервере. Dashboard-классы ниже являются описаниями административных форм. См. [оформление](#ui) и [администрирование](#admin).

- [app/views/layouts/application.html.erb](app/views/layouts/application.html.erb) **[M2, M3]**: общий HTML-каркас: метаданные, CSS/JS, sidebar, flash и yield для текущей страницы; умеет скрывать sidebar по content_for.
- [app/views/layouts/_sidebar.html.erb](app/views/layouts/_sidebar.html.erb) **[M2, M3, M5]**: основная навигация, профиль/вход/выход и закреплённый турнир; использует ApplicationHelper и sidebar_controller.
- [app/views/layouts/_sidebar_pin_slot.html.erb](app/views/layouts/_sidebar_pin_slot.html.erb) **[M5]**: фрагмент закреплённого турнира в sidebar; заменяется HTTP Turbo Stream после pin/unpin.
- [app/views/layouts/_flash.html.erb](app/views/layouts/_flash.html.erb) **[M2, M3]**: общий вывод уведомлений и ошибок flash после действий контроллеров.
- [app/views/layouts/_header.html.erb](app/views/layouts/_header.html.erb) **[M3, заготовка]**: сохранённый фрагмент верхней навигации; текущий application layout его не рендерит.
- [app/views/layouts/_footer.html.erb](app/views/layouts/_footer.html.erb) **[M3, заготовка]**: сохранённый подвал; текущий application layout его не рендерит.
- [app/views/layouts/mailer.html.erb](app/views/layouts/mailer.html.erb) **[Основа, M2]**: HTML-оболочка писем для почтовых шаблонов; отдельна от оболочки сайта.
- [app/views/layouts/mailer.text.erb](app/views/layouts/mailer.text.erb) **[Основа, M2]**: текстовая оболочка писем для клиентов без HTML; используется почтовым рендерингом.
- [app/views/home/index.html.erb](app/views/home/index.html.erb) **[M3, M5]**: главная страница со счётчиками HomeController и фоном matrix-rain.
- [app/views/dashboard/show.html.erb](app/views/dashboard/show.html.erb) **[M2]**: простая страница с email текущего пользователя; демонстрирует сохранение сессии.
- [app/views/ui_kit/show.html.erb](app/views/ui_kit/show.html.erb) **[M3]**: галерея форм, кнопок, таблиц и статусов; используется для просмотра общего оформления.
- [app/views/problems/index.html.erb](app/views/problems/index.html.erb) **[M3, M5]**: каталог с фильтрами, числом решивших и кнопками избранного; получает выборку ProblemsController.
- [app/views/problems/show.html.erb](app/views/problems/show.html.erb) **[M3, M5]**: условие и рабочее пространство; связывает editor, file-upload, custom-run и форму Submit с серверными маршрутами.
- [app/views/problems/_editor_chrome.html.erb](app/views/problems/_editor_chrome.html.erb) **[M3, M5]**: элементы вокруг редактора, панели ввода/вывода и отправок; включается в problems/show и подключает split-pane.
- [app/views/problems/_contest_strip.html.erb](app/views/problems/_contest_strip.html.erb) **[M5]**: турнирный контекст рабочей страницы, в том числе таймер; получает Contest и данные навигации страницы задачи.
- [app/views/submissions/index.html.erb](app/views/submissions/index.html.erb) **[M3, M5]**: список и фильтры отправок либо гостевое состояние; получает данные SubmissionsController#index.
- [app/views/submissions/show.html.erb](app/views/submissions/show.html.erb) **[M5]**: подробности отправки, исходник и результаты; clipboard помогает копировать код.
- [app/views/submissions/_workspace_panel.html.erb](app/views/submissions/_workspace_panel.html.erb) **[M5]**: панель последних/старых отправок в редакторе и статус последней; используется Submit и endpoint status, подключает polling для незавершённой отправки.
- [app/views/submissions/_status.html.erb](app/views/submissions/_status.html.erb) **[M3, M5, заготовка]**: отдельный старый фрагмент статуса с polling-атрибутами; текущий endpoint status рендерит workspace_panel, прямых render этого фрагмента не найдено.
- [app/views/contests/index.html.erb](app/views/contests/index.html.erb) **[M3, M5]**: список турниров по состоянию с избранным; получает данные ContestsController#index.
- [app/views/contests/show.html.erb](app/views/contests/show.html.erb) **[M3, M5]**: задачи турнира, действия участия, закрепления и финализации; учитывает пользователя и административные права.
- [app/views/contests/scoreboard.html.erb](app/views/contests/scoreboard.html.erb) **[M5, M7]**: публичная таблица с Turbo Frame и ручным refresh; подписка вошедшего пользователя находится снаружи frame.
- [app/views/contests/_scoreboard_rows.html.erb](app/views/contests/_scoreboard_rows.html.erb) **[M7]**: строки и контейнер scoreboard_rows; одинаково используется страницей и ScoreboardBroadcaster.
- [app/views/profiles/show.html.erb](app/views/profiles/show.html.erb) **[M2, M5]**: имя с формой изменения, статистика, рейтинг и история; получает только данные текущего пользователя.
- [app/views/favorites/index.html.erb](app/views/favorites/index.html.erb) **[M5]**: разделённые списки избранных задач и турниров; использует FavoritesController и общие кнопки.
- [app/views/groups/index.html.erb](app/views/groups/index.html.erb) **[M5]**: каталог групп и форма создания; получает Group и ошибки GroupsController.
- [app/views/groups/show.html.erb](app/views/groups/show.html.erb) **[M5]**: участники и действия группы; блоки активности пока являются заглушками.
- [app/views/shared/_favorite_button.html.erb](app/views/shared/_favorite_button.html.erb) **[M5]**: повторяемая кнопка добавления/удаления Favorite для Problem или Contest.
- [app/views/shared/_pin_button.html.erb](app/views/shared/_pin_button.html.erb) **[M5]**: кнопка закрепления/открепления Contest; используется карточкой турнира и Turbo Stream-ответами.
- [app/views/pinned_contests/create.turbo_stream.erb](app/views/pinned_contests/create.turbo_stream.erb) **[M5]**: HTTP-ответ на pin: заменяет кнопку и sidebar-pin-slot через общие partials.
- [app/views/pinned_contests/destroy.turbo_stream.erb](app/views/pinned_contests/destroy.turbo_stream.erb) **[M5]**: HTTP-ответ на unpin: заново рендерит те же участки после очистки закрепления.
- [app/views/devise/sessions/new.html.erb](app/views/devise/sessions/new.html.erb) **[M2, M3]**: форма входа для Devise; использует общие ссылки авторизации.
- [app/views/devise/registrations/new.html.erb](app/views/devise/registrations/new.html.erb) **[M2, M3]**: форма регистрации с необязательным username; показывает ошибки User.
- [app/views/devise/registrations/edit.html.erb](app/views/devise/registrations/edit.html.erb) **[M2]**: стандартная форма редактирования учётной записи Devise, отдельная от собственного /profile.
- [app/views/devise/passwords/new.html.erb](app/views/devise/passwords/new.html.erb) **[M2]**: запрос восстановления пароля; отправляет форму в Devise recoverable.
- [app/views/devise/passwords/edit.html.erb](app/views/devise/passwords/edit.html.erb) **[M2]**: установка нового пароля по токену восстановления; использует Devise и сообщения ошибок.
- [app/views/devise/confirmations/new.html.erb](app/views/devise/confirmations/new.html.erb) **[M2, заготовка]**: форма повторного подтверждения email; модуль confirmable у User не включён.
- [app/views/devise/unlocks/new.html.erb](app/views/devise/unlocks/new.html.erb) **[M2, заготовка]**: форма разблокировки аккаунта; модуль lockable у User не включён.
- [app/views/devise/shared/_links.html.erb](app/views/devise/shared/_links.html.erb) **[M2]**: ссылки входа, регистрации и восстановления в зависимости от доступных модулей Devise.
- [app/views/devise/shared/_error_messages.html.erb](app/views/devise/shared/_error_messages.html.erb) **[M2]**: общий вывод ошибок ресурса; используется также формой собственного профиля.
- [app/views/devise/mailer/reset_password_instructions.html.erb](app/views/devise/mailer/reset_password_instructions.html.erb) **[M2]**: текст HTML-письма с восстановлением пароля; рендерится Devise при соответствующем действии и настройке доставки.
- [app/views/devise/mailer/password_change.html.erb](app/views/devise/mailer/password_change.html.erb) **[M2]**: шаблон уведомления об изменении пароля; вызов зависит от настроек Devise.
- [app/views/devise/mailer/email_changed.html.erb](app/views/devise/mailer/email_changed.html.erb) **[M2]**: шаблон уведомления об изменении email; вызов зависит от настроек Devise.
- [app/views/devise/mailer/confirmation_instructions.html.erb](app/views/devise/mailer/confirmation_instructions.html.erb) **[M2, заготовка]**: письмо подтверждения для confirmable, который сейчас не включён.
- [app/views/devise/mailer/unlock_instructions.html.erb](app/views/devise/mailer/unlock_instructions.html.erb) **[M2, заготовка]**: письмо разблокировки для lockable, который сейчас не включён.
- [app/views/pwa/manifest.json.erb](app/views/pwa/manifest.json.erb) **[Основа, заготовка]**: описание устанавливаемого веб-приложения для браузера; PWA-маршруты в текущем routes.rb отсутствуют.
- [app/views/pwa/service-worker.js](app/views/pwa/service-worker.js) **[Основа, заготовка]**: заготовка фонового браузерного worker для PWA; подключённого PWA-сценария сейчас нет.
- [app/helpers/application_helper.rb](app/helpers/application_helper.rb) **[M3, M5]**: общие методы шаблонов: навигация, SVG-иконки, статусы, рейтинг, время и сведения о закреплённом турнире.
- [app/mailers/application_mailer.rb](app/mailers/application_mailer.rb) **[Основа]**: базовый класс почты Rails с layout mailer; собственных предметных mailer-классов в приложении нет, Devise предоставляет свой.
- [app/dashboards/contest_dashboard.rb](app/dashboards/contest_dashboard.rb) **[M5]**: поля и состав страниц Administrate для Contest; используется admin/contests.
- [app/dashboards/contest_problem_dashboard.rb](app/dashboards/contest_problem_dashboard.rb) **[M5]**: описание административной формы связи турнира и задачи; используется admin/contest_problems.
- [app/dashboards/problem_dashboard.rb](app/dashboards/problem_dashboard.rb) **[M5]**: поля задачи в административных списках/формах; работает с Admin::ProblemsController.
- [app/dashboards/test_case_dashboard.rb](app/dashboards/test_case_dashboard.rb) **[M5]**: поля теста задачи в Administrate; работает с admin/test_cases.
- [app/dashboards/user_dashboard.rb](app/dashboards/user_dashboard.rb) **[M5, заготовка]**: описание User для Administrate; соответствующего ресурса в admin-маршрутах нет.
- [app/dashboards/submission_dashboard.rb](app/dashboards/submission_dashboard.rb) **[M5, заготовка]**: описание Submission для Administrate; соответствующего ресурса в admin-маршрутах нет.
- [app/dashboards/rating_history_dashboard.rb](app/dashboards/rating_history_dashboard.rb) **[M5, заготовка]**: описание RatingHistory для Administrate; соответствующего ресурса в admin-маршрутах нет.
- [app/dashboards/contest_participation_dashboard.rb](app/dashboards/contest_participation_dashboard.rb) **[M5, заготовка]**: описание ContestParticipation для Administrate; соответствующего ресурса в admin-маршрутах нет.

[К справочнику](#files) · [К оглавлению](#contents)

<a id="javascript"></a>
### app/javascript: поведение браузера

Stimulus подключает класс только к элементу с соответствующим data-controller. Регистрация JS-класса не означает, что он используется на каждой странице. См. [редактор](#editor), [вердикт](#judging) и [оформление](#ui).

- [app/javascript/application.js](app/javascript/application.js) **[Основа, M3]**: JS-точка входа: импортирует Turbo и controllers через importmap; подключается layout.
- [app/javascript/controllers/application.js](app/javascript/controllers/application.js) **[Основа, M3]**: создаёт приложение Stimulus; остальные контроллеры регистрируются в нём.
- [app/javascript/controllers/index.js](app/javascript/controllers/index.js) **[Основа, M3]**: автоматически регистрирует controllers из importmap; связывает файлы с HTML data-controller.
- [app/javascript/controllers/editor_controller.js](app/javascript/controllers/editor_controller.js) **[M3, M5]**: загрузка/уничтожение Monaco, синхронизация textarea, язык, resize, Vim/Caps-настройки; работает на странице задачи.
- [app/javascript/controllers/custom_run_controller.js](app/javascript/controllers/custom_run_controller.js) **[M5]**: fetch для Run, индикатор занятости, вывод/ошибки и сравнение примеров; использует JSON CustomRunsController.
- [app/javascript/controllers/submission_status_controller.js](app/javascript/controllers/submission_status_controller.js) **[M5]**: HTTP polling HTML-панели отправок, остановка при конечном состоянии и confetti при AC; не подписка Action Cable.
- [app/javascript/controllers/file_upload_controller.js](app/javascript/controllers/file_upload_controller.js) **[M5]**: читает файл пользователя в редактор и выбирает язык по расширению; взаимодействует с editor_controller.
- [app/javascript/controllers/split_pane_controller.js](app/javascript/controllers/split_pane_controller.js) **[M3]**: перетаскивание и изменение пропорций панелей с сохранением localStorage; сообщает редактору об изменении размеров.
- [app/javascript/controllers/sidebar_controller.js](app/javascript/controllers/sidebar_controller.js) **[M3]**: открытие/сворачивание навигации, клавиатура, адаптация к размеру окна и сохранение состояния; управляет layout.
- [app/javascript/controllers/contest_countdown_controller.js](app/javascript/controllers/contest_countdown_controller.js) **[M5]**: обновляет таймер в браузере по времени турнира; не меняет Contest.status в базе.
- [app/javascript/controllers/clipboard_controller.js](app/javascript/controllers/clipboard_controller.js) **[M3, M5]**: копирует отображаемый исходник и показывает обратную связь; используется страницей Submission.
- [app/javascript/controllers/matrix_rain_controller.js](app/javascript/controllers/matrix_rain_controller.js) **[M3]**: рисует декоративный фон главной страницы; не участвует в проверке кода.
- [app/javascript/controllers/hello_controller.js](app/javascript/controllers/hello_controller.js) **[Основа, заготовка]**: стартовый пример Stimulus; привязки hello в текущих шаблонах не найдено.

[К справочнику](#files) · [К оглавлению](#contents)

<a id="assets"></a>
### app/assets, public, design и vendor: оформление и готовые ресурсы

Изображения и сторонние сборки сгруппированы. Их наличие не означает активное подключение. См. [оформление](#ui).

- [app/assets/stylesheets/application.css](app/assets/stylesheets/application.css) **[M3]**: общие стили и компоненты сайта; Propshaft отдаёт их layout и страницам.
- [app/assets/stylesheets/theme_dark.css](app/assets/stylesheets/theme_dark.css) **[M3]**: тёмная тема и оформление экранов; применяется вместе с общими стилями.
- [public/400.html](public/400.html) **[Основа]**: статическая страница некорректного запроса; доступна обработчику ошибок без обычного шаблона.
- [public/404.html](public/404.html) **[Основа]**: статическая страница отсутствующего адреса/ресурса; используется обработкой ошибок Rails.
- [public/406-unsupported-browser.html](public/406-unsupported-browser.html) **[Основа]**: сообщение для неподдерживаемого браузера; связано с allow_browser в ApplicationController.
- [public/422.html](public/422.html) **[Основа]**: статическая страница отклонённого изменения; используется общим обработчиком ошибок, не заменяет формы с валидациями.
- [public/500.html](public/500.html) **[Основа]**: статическая страница внутренней ошибки; работает независимо от основной разметки.
- [public/robots.txt](public/robots.txt) **[Основа]**: инструкции поисковым роботам при обращении к сайту; не механизм ограничения доступа.
- [vendor/monaco/README.md](vendor/monaco/README.md) **[M3, M5]**: инструкция получения локальной сборки Monaco и monaco-vim; объясняет происхождение public/monaco.
- [vendor/javascript/canvas-confetti.js](vendor/javascript/canvas-confetti.js) **[M5, сторонний код]**: готовый модуль эффекта AC; подключён importmap и вызывается submission_status_controller.

Группы ресурсов:

- [app/assets/images/](app/assets/images/) **[M3]**: logo.png, logo.svg и варианты logo_1.png, logo_2.png, logo_3png.png, logo_4png.png. Это графика бренда; layout использует logo.png для иконки, конкретное использование остальных определяется ссылками в шаблонах. Новые неотслеживаемые варианты включены в эту группу.
- [design/](design/) **[M1, M3]**: logo_green.png, logo_purple.png, logo_refined.jpg и все изображения [design/mockups/](design/mockups/), включая варианты workspace и лист обзора. Это эскизы экранов для сравнения с реализацией, Rails их автоматически не рендерит.
- [public/icon.png](public/icon.png) и [public/icon.svg](public/icon.svg) **[Основа]**: статические иконки-заготовки. Текущий layout ссылается на logo.png из assets.
- [public/monaco/](public/monaco/) **[M3, M5, сторонний код]**: monaco-vim.js даёт Vim-управление; vs/loader.js загружает модули; vs/editor/editor.main.js и .css содержат ядро/стили; vs/base содержит workers и шрифт codicon.ttf; vs/basic-languages содержит определения языков; vs/language содержит языковые службы и workers; vs/nls.messages.*.js содержит переводы редактора. Все файлы этих каталогов относятся к поставляемой библиотеке и используются загрузчиком Monaco по необходимости. Подсветка десятков языков не означает поддержку их отправки: сервер принимает только Python и C++.

[К справочнику](#files) · [К оглавлению](#contents)

<a id="config"></a>
### config: настройки Rails и библиотек

Конфигурация выбирает, как код работает в development, test и production. Значения секретов в справочник не включены. См. [общую архитектуру](#overview).

- [config/boot.rb](config/boot.rb) **[Основа]**: подключает Bundler и ускоритель загрузки Bootsnap перед Rails; вызывается точками запуска.
- [config/application.rb](config/application.rb) **[Основа]**: общие настройки Rails, загрузка библиотек и доступные en/ru с default en; база для настроек сред.
- [config/environment.rb](config/environment.rb) **[Основа]**: загружает application и инициализирует Rails; нужен серверу, командам и тестам.
- [config/routes.rb](config/routes.rb) **[M2-M7]**: адресная книга HTTP: Devise, каталог, отправки, Run, webhook, турниры, профиль и admin; Sidekiq Web подключён только в development.
- [config/environments/development.rb](config/environments/development.rb) **[Основа, M5]**: настройки локальной разработки, памяти-кеша и адаптера Sidekiq; переопределяют общие параметры.
- [config/environments/test.rb](config/environments/test.rb) **[Основа, M6]**: изолированные настройки тестов: тестовый Active Job и null cache; не требует настоящего Sidekiq для проверок.
- [config/environments/production.rb](config/environments/production.rb) **[Основа, M5]**: настройки рабочего сервера, Solid Cache и Sidekiq; не доказательство уже выполненного deploy.
- [config/database.yml](config/database.yml) **[Основа, M4, M7]**: подключения PostgreSQL, включая служебные базы/схемы конфигурации; используется Active Record и Solid Cable.
- [config/storage.yml](config/storage.yml) **[Основа, M4]**: места хранения Active Storage для файлов тестов; TestCase читает вложения через эту библиотеку.
- [config/cable.yml](config/cable.yml) **[M7]**: Solid Cable в development/production и тестовый адаптер в test; определяет хранение/обмен сообщениями для Action Cable.
- [config/cache.yml](config/cache.yml) **[Основа]**: настройки Solid Cache; используются там, где среда включает этот кеш.
- [config/queue.yml](config/queue.yml) **[Основа, заготовка]**: параметры Solid Queue для bin/jobs; основной поток Submit использует Sidekiq, не эту очередь.
- [config/recurring.yml](config/recurring.yml) **[Основа, заготовка]**: пример периодических заданий и очистка Solid Queue для production; не расписание создания или финализации турниров.
- [config/sidekiq.yml](config/sidekiq.yml) **[M5]**: параметры процесса Sidekiq и очередей; читаются при его запуске для Active Job.
- [config/puma.rb](config/puma.rb) **[Основа]**: порт и потоки веб-сервера, PID и условное включение Solid Queue по переменной; запускается вместе с Puma.
- [config/importmap.rb](config/importmap.rb) **[M3, M5]**: соответствия JS-модулей для Turbo, Stimulus и canvas-confetti; используется layout и application.js.
- [config/deploy.yml](config/deploy.yml) **[Основа]**: описание развёртывания через Kamal; связано с Dockerfile и bin/kamal, не с локальной проверкой задачи.
- [config/credentials.yml.enc](config/credentials.yml.enc) **[Основа]**: зашифрованные настройки Rails; приложение может читать их с ключом, содержимое здесь не раскрывается.
- [config/ci.rb](config/ci.rb) **[Основа, M6]**: последовательность bin/ci: setup, стиль, аудит и тесты; включает изменяющий тестовую БД seed:replant.
- [config/bundler-audit.yml](config/bundler-audit.yml) **[Основа]**: настройки проверки уязвимостей зависимостей; используются bin/bundler-audit.
- [config/initializers/assets.rb](config/initializers/assets.rb) **[Основа, M3]**: настройки ресурсов при загрузке Rails; связаны с Propshaft и app/assets.
- [config/initializers/content_security_policy.rb](config/initializers/content_security_policy.rb) **[Основа]**: заготовка настройки политики загрузки браузерных ресурсов; закомментированные примеры не являются включёнными ограничениями.
- [config/initializers/devise.rb](config/initializers/devise.rb) **[M2]**: настройки Devise, включая поведение входа и паролей; дополняют модули в User.
- [config/initializers/filter_parameter_logging.rb](config/initializers/filter_parameter_logging.rb) **[Основа, M2]**: список чувствительных параметров для фильтрации Rails-логов; применяется к журналированию запросов.
- [config/initializers/i18n_pluralization.rb](config/initializers/i18n_pluralization.rb) **[M3]**: подключает механизм множественных форм I18n; работает с ru_pluralization.rb.
- [config/initializers/inflections.rb](config/initializers/inflections.rb) **[Основа]**: место правил преобразования имён единственного/множественного числа Rails; используется соглашениями об именах.
- [config/initializers/sidekiq.rb](config/initializers/sidekiq.rb) **[M5]**: задаёт Redis-подключение клиента и сервера Sidekiq; связывает постановку job и worker.
- [config/locales/en.yml](config/locales/en.yml) **[M3, M5, M7]**: английские строки интерфейса, статусов и ошибок; используются t(...) в шаблонах и контроллерах.
- [config/locales/ru.yml](config/locales/ru.yml) **[M3, M5, M7]**: русские строки тех же интерфейсов; выбираются через locale.
- [config/locales/devise.en.yml](config/locales/devise.en.yml) **[M2]**: английские сообщения Devise для входа, регистрации и восстановления.
- [config/locales/devise.ru.yml](config/locales/devise.ru.yml) **[M2]**: русские сообщения Devise; дополняют общий словарь ru.yml.
- [config/locales/ru_pluralization.rb](config/locales/ru_pluralization.rb) **[M3]**: Ruby-правило one/few/many для русского языка; применяется I18n при строках с count.

[К справочнику](#files) · [К оглавлению](#contents)

<a id="database"></a>
### db: структура, история изменений и начальные данные

Миграции выполняются при обновлении базы и затем определяют структуру, с которой работают модели. Они не выполняются заново при каждом открытии страницы. См. [данные](#data) и [импорт](#problems).

- [db/schema.rb](db/schema.rb) **[M4]**: снимок текущей структуры предметных таблиц, индексов и внешних ключей; сверяется с моделями и историей миграций.
- [db/cable_schema.rb](db/cable_schema.rb) **[M7]**: таблицы Solid Cable для доставки сообщений между процессами; используется конфигурацией cable.
- [db/cache_schema.rb](db/cache_schema.rb) **[Основа]**: таблицы Solid Cache; относятся к кешированию, не к решениям пользователей.
- [db/queue_schema.rb](db/queue_schema.rb) **[Основа, заготовка]**: таблицы Solid Queue; не хранилище основной очереди Sidekiq.
- [db/seeds.rb](db/seeds.rb) **[M5]**: импортирует примеры, создаёт/обновляет демотурнир и его задачи; повторный запуск меняет его время.
- [db/seeds/problems/a_plus_b.json](db/seeds/problems/a_plus_b.json) **[M5]**: условие, лимиты и тесты A + B для Importer; пример формата данных задачи.
- [db/seeds/problems/hello_name.json](db/seeds/problems/hello_name.json) **[M5]**: условие, лимиты и тесты Hello Name для того же импортера.
- [db/migrate/20261015190109_devise_create_users.rb](db/migrate/20261015190109_devise_create_users.rb) **[M2]**: создаёт users с полями Devise; основа входа и регистрации.
- [db/migrate/20261015202232_create_active_storage_tables.active_storage.rb](db/migrate/20261015202232_create_active_storage_tables.active_storage.rb) **[M4]**: создаёт служебные таблицы вложений; обеспечивает файловые входы/ответы TestCase.
- [db/migrate/20261015232201_add_profile_fields_to_users.rb](db/migrate/20261015232201_add_profile_fields_to_users.rb) **[M4]**: добавляет имя и рейтинг к User; более поздняя миграция меняет уникальность имени.
- [db/migrate/20261015232202_create_problems.rb](db/migrate/20261015232202_create_problems.rb) **[M4]**: создаёт таблицу задач с условием, тегами и лимитами для Problem.
- [db/migrate/20261015232203_create_test_cases.rb](db/migrate/20261015232203_create_test_cases.rb) **[M4]**: создаёт тесты и связь с задачами для TestCase.
- [db/migrate/20261015232204_create_contests.rb](db/migrate/20261015232204_create_contests.rb) **[M4]**: создаёт турниры со временем и состоянием для Contest.
- [db/migrate/20261015232205_create_contest_problems.rb](db/migrate/20261015232205_create_contest_problems.rb) **[M4]**: создаёт связь турниров/задач, буквы, порядок и ограничения повторов.
- [db/migrate/20261015232206_create_contest_participations.rb](db/migrate/20261015232206_create_contest_participations.rb) **[M4]**: создаёт участие с результатами и ограничением одного участия на пользователя/турнир.
- [db/migrate/20261015232207_create_submissions.rb](db/migrate/20261015232207_create_submissions.rb) **[M4]**: создаёт сохранённые отправки и поля проверки для Submission и Judge0.
- [db/migrate/20261015232208_create_rating_histories.rb](db/migrate/20261015232208_create_rating_histories.rb) **[M4]**: создаёт историю рейтинга с привязкой к пользователю и турниру.
- [db/migrate/20261022214500_add_admin_to_users.rb](db/migrate/20261022214500_add_admin_to_users.rb) **[M5]**: добавляет признак администратора; используется защитой /admin и финализации.
- [db/migrate/20261023010000_create_favorites.rb](db/migrate/20261023010000_create_favorites.rb) **[M4, M5]**: создаёт полиморфные закладки пользователя для Favorite.
- [db/migrate/20261023010001_create_groups.rb](db/migrate/20261023010001_create_groups.rb) **[M4, M5]**: создаёт группы с именем и slug; используется Group.
- [db/migrate/20261023010002_create_group_memberships.rb](db/migrate/20261023010002_create_group_memberships.rb) **[M4, M5]**: создаёт связь пользователя/группы с ролью для GroupMembership.
- [db/migrate/20261023104917_add_pinned_contest_to_users.rb](db/migrate/20261023104917_add_pinned_contest_to_users.rb) **[M5]**: добавляет ссылку на единственный закреплённый турнир пользователя.
- [db/migrate/20261023140100_nullify_pinned_contest_on_delete.rb](db/migrate/20261023140100_nullify_pinned_contest_on_delete.rb) **[M5]**: меняет внешний ключ закрепления на очистку ссылки при удалении турнира; дополняет предыдущую миграцию.
- [db/migrate/20261113120000_allow_duplicate_usernames.rb](db/migrate/20261113120000_allow_duplicate_usernames.rb) **[M2, M4]**: заменяет уникальный индекс username обычным; обратный переход отказывается восстанавливать уникальность при наличии дублей.

[К справочнику](#files) · [К оглавлению](#contents)

<a id="bin"></a>
### bin и lib/tasks: команды обслуживания

Это запускаемые помощники, а не страницы сайта. Некоторые меняют данные или очищают файлы: здесь описано их назначение, а не дана команда выполнить их. См. [импорт](#problems) и [проверки](#tests).

- [bin/rails](bin/rails) **[Основа]**: вход в CLI Rails для server, console, routes, test и задач БД; загружает приложение.
- [bin/rake](bin/rake) **[Основа]**: запуск задач Rake, включая lib/tasks/import.rake; использует Rakefile.
- [bin/dev](bin/dev) **[Основа]**: запускает Rails server; сам не запускает Sidekiq или контейнеры Judge0.
- [bin/server](bin/server) **[Основа]**: локальное управление фоновым Rails: start/stop/restart/status; использует PID в tmp/pids и log/server.log.
- [bin/server.cmd](bin/server.cmd) **[Основа]**: Windows-обёртка, передающая аргументы Ruby-скрипту bin/server.
- [bin/setup](bin/setup) **[Основа]**: проверяет/устанавливает зависимости, готовит БД, очищает логи/tmp и может запустить сервер; --reset сбрасывает БД.
- [bin/docker-entrypoint](bin/docker-entrypoint) **[Основа]**: перед контейнерным запуском Rails server выполняет db:prepare, затем передаёт управление команде Dockerfile.
- [bin/jobs](bin/jobs) **[Основа, заготовка]**: запускает Solid Queue CLI; это не команда запуска используемого для Submit Sidekiq.
- [bin/importmap](bin/importmap) **[M3]**: управляет JS-зависимостями importmap и их аудитом; связан с config/importmap.rb.
- [bin/ci](bin/ci) **[Основа, M6]**: выполняет последовательность config/ci.rb; это более широкая и изменяющая окружение проверка, чем чтение документации.
- [bin/rubocop](bin/rubocop) **[Основа]**: запускает проверку Ruby-стиля по .rubocop.yml; используется CI.
- [bin/brakeman](bin/brakeman) **[Основа]**: запускает статический анализ безопасности Rails; читает код без исполнения пользовательских решений.
- [bin/bundler-audit](bin/bundler-audit) **[Основа]**: проверяет зависимости Gemfile.lock на известные уязвимости с настройками config/bundler-audit.yml.
- [bin/kamal](bin/kamal) **[Основа]**: вход в инструмент развёртывания Kamal; использует config/deploy.yml.
- [bin/kamal.cmd](bin/kamal.cmd) **[Основа]**: Windows-обёртка запуска Kamal; относится к развёртыванию, а не проверке задач.
- [bin/thrust](bin/thrust) **[Основа]**: запуск Thruster для обслуживания HTTP перед Rails в контейнерном сценарии; связан с Dockerfile.
- [lib/tasks/import.rake](lib/tasks/import.rake) **[M5]**: команда import:problems: находит JSON задач и вызывает Problems::Importer; без демотурнира из seeds.rb.

[К справочнику](#files) · [К оглавлению](#contents)

<a id="tests"></a>
### test: что проверяют автоматические тесты

Тесты Rails используют тестовую PostgreSQL и адаптер Active Job :test. Настоящие Redis, Sidekiq и Judge0 для штатного набора не нужны. Fake Judge0 подменяет транспорт, но не запускает пользовательский код на хосте. Сценарии: [Submit](#judging), [рейтинг](#contests), [live](#live).

Не путайте два значения слова «тест»: app/models/test_case.rb описывает вход и ожидаемый ответ для программы участника, а файлы test/*_test.rb и вложенных каталогов проверяют сам сайт. Первые использует Judge0, вторые запускает разработчик через Rails.

- [test/test_helper.rb](test/test_helper.rb) **[Основа, M6]**: общая загрузка Rails/test, fixtures и помощников; подключается тестовыми файлами.
- [test/fixtures/users.yml](test/fixtures/users.yml) **[M2, M6]**: начальные пользователи для тестов; не production-аккаунты и не источник паролей для документации.
- [test/models/user_test.rb](test/models/user_test.rb) **[M2, M4]**: повторяющиеся Unicode-имена, нормализация, генерация имени и локализованные ошибки User.
- [test/models/submission_test.rb](test/models/submission_test.rb) **[M4]**: языки/статусы, связь задачи с турниром и время отправки; проверяет Submission без Judge0.
- [test/controllers/auth_session_test.rb](test/controllers/auth_session_test.rb) **[M2, M6]**: регистрация, имя, вход, обновление страницы, выход и ограничения гостя; связывает Devise с UI.
- [test/controllers/profiles_controller_test.rb](test/controllers/profiles_controller_test.rb) **[M2, M5, M6]**: изменение имени current_user, повторяющиеся имена, ошибки/права и реальные рейтинги в профиле.
- [test/controllers/admin_access_test.rb](test/controllers/admin_access_test.rb) **[M5, M6]**: запрет гостю/обычному пользователю и создание задачи администратором.
- [test/controllers/ui_kit_placeholders_test.rb](test/controllers/ui_kit_placeholders_test.rb) **[M3, M5, M6]**: отрисовка UI Kit, каталога и основных экранов, доступ гостя/вошедшего; старое имя файла не означает, что все данные ещё фиктивны.
- [test/controllers/contest_submissions_controller_test.rb](test/controllers/contest_submissions_controller_test.rb) **[M5, M6]**: турнирный Submit, автоматическое участие, закрытый турнир, панель отправок и навигация задач.
- [test/controllers/contests_controller_test.rb](test/controllers/contests_controller_test.rb) **[M5-M7]**: страницы турнира, однократная регистрация, порядок результатов, гостевой доступ и ручное восстановление Turbo Frame с переводами.
- [test/controllers/custom_runs_controller_test.rb](test/controllers/custom_runs_controller_test.rb) **[M5, M6]**: защита Run и JSON-ответ подставного Judge0Client; проверяет отдельный путь без Submission.
- [test/controllers/pinned_contests_controller_test.rb](test/controllers/pinned_contests_controller_test.rb) **[M5, M6]**: защита закрепления, замена предыдущего pin и Turbo-обновление кнопки/sidebar.
- [test/integration/submission_judging_flow_test.rb](test/integration/submission_judging_flow_test.rb) **[M6, M7]**: сквозной путь Python/C++ через настоящий Rails job и fake HTTP Judge0, сохранение вердиктов, турнирный зачёт, polling и ветки отказов.
- [test/jobs/judge_submission_job_test.rb](test/jobs/judge_submission_job_test.rb) **[M5, M6]**: возобновление по токенам, ошибка внешнего сервиса и исчерпание polling.
- [test/jobs/finalize_contest_job_test.rb](test/jobs/finalize_contest_job_test.rb) **[M5, M6]**: финальный зачёт/рейтинг, повторная финализация и запрет финализации активного турнира.
- [test/services/judge0_client_test.rb](test/services/judge0_client_test.rb) **[M5, M6]**: id языков, агрегация статусов, превышение памяти и формат одиночного Run.
- [test/services/problems/importer_test.rb](test/services/problems/importer_test.rb) **[M5, M6]**: повторный импорт задачи и тестов без дублирования; проверяет Importer на тестовых данных.
- [test/services/contests/scoring_test.rb](test/services/contests/scoring_test.rb) **[M4, M6]**: штраф WA/AC, исключение CE, нерешённые задачи, временное окно, первая AC и одинаковые места.
- [test/services/ratings/calculator_test.rb](test/services/ratings/calculator_test.rb) **[M4, M6]**: ожидаемые изменения рейтинга, ничья, один участник, нижняя граница и формат результата без записи.
- [test/services/submissions/apply_judge0_result_test.rb](test/services/submissions/apply_judge0_result_test.rb) **[M5-M7]**: вердикт/зачёт, повторные callback, устаревший pending, изоляция потоков, commit/rollback и ошибка трансляции.
- [test/channels/application_cable/connection_test.rb](test/channels/application_cable/connection_test.rb) **[M7]**: вход через Devise-сессию в WebSocket и отказ гостю.
- [test/channels/scoreboard_channel_test.rb](test/channels/scoreboard_channel_test.rb) **[M7]**: подписка вошедшего пользователя на турнир и отказ для гостя/неизвестного турнира.

[К справочнику](#files) · [К оглавлению](#contents)

<a id="plans"></a>
### plan: требования и дальнейшие предложения

Эти документы читают разработчики. Rails не исполняет их. См. [карту майлстоунов](#milestones).

- [plan/architecture.md](plan/architecture.md) **[M1]**: исходная общая схема компонентов, включая ещё не реализованные генератор и импорт внешних датасетов; сверять с текущими сценариями этого справочника.
- [plan/milestones.md](plan/milestones.md) **[M1-M7]**: учебные этапы, сроки и общие чекбоксы готовности; источник названий M1-M7.
- [plan/implementation.md](plan/implementation.md) **[M1-M7]**: пошаговый план реализации, порядок работ и критерии проверки; уточняет исходные требования.
- [plan/spec.md](plan/spec.md) **[M1]**: описание продукта, экранов, стека и рисков; связывает задачи пользователя с архитектурой.
- [plan/ui_refactoring.md](plan/ui_refactoring.md) **[M3, M6, M7, план]**: предложение переработки интерфейса и замены некоторых механизмов; не описание уже установленной библиотеки UI.
- [plan/completion_and_frontend_simplification.md](plan/completion_and_frontend_simplification.md) **[M2, M3, M7, план]**: план завершения проверки live, редактирования имени и упрощения frontend; часть текущего кода уже опережает его незакрытые пункты.

[К справочнику](#files) · [К оглавлению](#contents)

<a id="support"></a>
### Служебные и скрытые каталоги

Включены файлы репозитория и известные локальные артефакты. Генерируемые данные и установленные библиотеки не перечисляются по экземплярам. Сценарий: [запуск и проверки](#overview).

- [.github/workflows/ci.yml](.github/workflows/ci.yml) **[Основа, M6]**: GitHub Actions: Ruby/JS-аудит, стиль, Rails-тесты и system-test job с PostgreSQL; запускается на push/PR.
- [.github/dependabot.yml](.github/dependabot.yml) **[Основа]**: расписание проверки обновлений зависимостей для GitHub Dependabot; не часть обработки запросов.
- [.adminer/adminer-dark.css](.adminer/adminer-dark.css) **[Основа]**: тёмное оформление отдельного Adminer; монтируется docker-compose.yml.
- [.cursor/rules/ask-ru.mdc](.cursor/rules/ask-ru.mdc) **[Основа]**: локальное правило общения с ассистентом; не выполняется Rails и не переводит сайт.
- [.kamal/secrets](.kamal/secrets) **[Основа]**: файл предоставления секретов инструменту Kamal; относится к deploy, содержимое не публикуется.

Группы служебных файлов:

- [log/](log/) **[Основа]**: журналы Rails и локальных процессов; создаются при работе, помогают найти ошибки запросов и Judge0. Не являются исходниками.
- [tmp/](tmp/) и [tmp/pids/](tmp/pids/) **[Основа]**: временные данные, кеши и идентификаторы процессов; bin/server использует PID для управления сервером. Конкретные временные файлы не часть стабильной архитектуры.
- [storage/](storage/) **[M4, M5]**: локальные вложения Active Storage; связаны с TestCase и storage.yml, это данные, а не тестовые классы.
- [script/](script/) **[Основа, заготовка]**: место дополнительных скриптов; в отслеживаемой части сейчас только .keep.
- [vendor/](vendor/) **[Основа]**: локально поставляемые сторонние ресурсы; JS-библиотеки описаны в разделе ресурсов, установленные зависимости не документируются как собственный код.
- Все **.keep** в app/assets/images, app/controllers/concerns, app/models/concerns, lib/tasks, log, script, storage, tmp, tmp/pids, vendor, vendor/javascript, test/controllers, test/fixtures/files, test/helpers, test/integration, test/mailers и test/models сохраняют каталоги в Git. Они не исполняются.
- **.git/** хранит историю и служебное состояние Git. Локальные **.bundle/**, если присутствуют, относятся к настройкам установки зависимостей. **.env** и ключи, если присутствуют, являются локальными настройками/секретами; этот справочник не раскрывает их и не утверждает автоматическую загрузку .env.

[К справочнику](#files) · [К оглавлению](#contents)

<a id="milestones"></a>
## Карта майлстоунов и порядок чтения

Все семь общих этапов отмечены выполненными в [milestones.md](plan/milestones.md). Это состояние плана, а не результат повторного запуска тестов при написании документации. Позднейшие улучшения имени и интерфейса привязаны ниже к близким по смыслу требованиям, не выделены в выдуманный M8.

<a id="m1"></a>
### M1. Спецификация проекта

Цель: понять продукт, экраны, технологии и сложности до реализации. Читать [spec.md](plan/spec.md), затем [architecture.md](plan/architecture.md), затем [implementation.md](plan/implementation.md). Эскизы лежат в [design/mockups](design/mockups/). Проверка этого этапа является содержательной проверкой документов, а не отдельным Ruby-тестом.

<a id="m2"></a>
### M2. Регистрация и авторизация

Цель: зарегистрироваться, войти, обновить страницу без потери сессии и выйти. Читать [маршруты](config/routes.rb), [User](app/models/user.rb), [настройки Devise](config/initializers/devise.rb), [форму регистрации](app/views/devise/registrations/new.html.erb), [sidebar](app/views/layouts/_sidebar.html.erb). Затем [auth_session_test.rb](test/controllers/auth_session_test.rb). Позднее редактирование имени связано с [ProfilesController](app/controllers/profiles_controller.rb) и [его тестом](test/controllers/profiles_controller_test.rb).

<a id="m3"></a>
### M3. UI Kit и видимые экраны

Цель: показать основные элементы и структуру интерфейса. Читать [application layout](app/views/layouts/application.html.erb), [CSS](app/assets/stylesheets/application.css), [тёмную тему](app/assets/stylesheets/theme_dark.css), [UI Kit](app/views/ui_kit/show.html.erb), затем нужную страницу из [справочника views](#views). Проверка отрисовки: [ui_kit_placeholders_test.rb](test/controllers/ui_kit_placeholders_test.rb). Исторические заглушки не означают, что нынешний каталог использует фиктивные данные.

<a id="m4"></a>
### M4. Модели и тесты бизнес-правил

Цель: определить структуру и правила хранения, расчёта зачёта и рейтинга. Читать [schema.rb](db/schema.rb), [связи](#data), [модели](#models), [Scoring](app/services/contests/scoring.rb) и [Calculator](app/services/ratings/calculator.rb). Затем [Submission test](test/models/submission_test.rb), [Scoring test](test/services/contests/scoring_test.rb), [Calculator test](test/services/ratings/calculator_test.rb). «Бизнес-правила» здесь означают правила предметной области: например, сколько штрафа даёт неправильная попытка.

<a id="m5"></a>
### M5. Основной пользовательский сценарий

Цель: пройти от задачи и отправки до реального вердикта, турнирного результата и профиля. Читать [seeds](db/seeds.rb), [SubmissionsController](app/controllers/submissions_controller.rb), [JudgeSubmissionJob](app/jobs/judge_submission_job.rb), [Judge0Client](app/services/judge0_client.rb), [ApplyJudge0Result](app/services/submissions/apply_judge0_result.rb), затем [финализацию и рейтинг](#contests). Здесь же относятся импорт, минимальный admin, Run и вспомогательные страницы. Проверки: [contest_submissions_controller_test.rb](test/controllers/contest_submissions_controller_test.rb), [finalize_contest_job_test.rb](test/jobs/finalize_contest_job_test.rb); ручной сценарий с настоящим Judge0 описан в [README](README.md).

<a id="m6"></a>
### M6. Интеграционные тесты

Цель: проверить цепочку компонентов и отклонения от успешного пути. Читать [test_helper](test/test_helper.rb), [submission_judging_flow_test.rb](test/integration/submission_judging_flow_test.rb), затем [справочник проверок](#tests). Важно различать проверку Rails с fake HTTP-транспортом и ручной запуск реального Judge0: первая не подтверждает исправность Docker-сети или доступность компилятора.

Штатная команда из корня проекта: `ruby bin/rails test`. Для цепочки judging: `ruby bin/rails test test/integration/submission_judging_flow_test.rb`. Нужна подготовленная тестовая PostgreSQL. CI описан в [.github/workflows/ci.yml](.github/workflows/ci.yml); отдельной папки test/system в текущем дереве нет, несмотря на наличие system-test job.

<a id="m7"></a>
### M7. Живые и частичные обновления

Цель: таблица турнира обновляется через WebSocket, а её ручная загрузка использует Turbo Frame. Читать [scoreboard view](app/views/contests/scoreboard.html.erb), [Connection](app/channels/application_cable/connection.rb), [ScoreboardChannel](app/channels/scoreboard_channel.rb), [ApplyJudge0Result](app/services/submissions/apply_judge0_result.rb), [ScoreboardBroadcaster](app/services/contests/scoreboard_broadcaster.rb), [cable.yml](config/cable.yml). Проверки: [канал](test/channels/scoreboard_channel_test.rb), [таблица](test/controllers/contests_controller_test.rb), [транзакции и доставка](test/services/submissions/apply_judge0_result_test.rb). HTTP Turbo Stream-ответы pin/Submit и polling отправки сами по себе не заменяют WebSocket-требование M7.

[К оглавлению](#contents)

<a id="lookup"></a>
## Ответы на частые вопросы

### «Для чего нужен файл X?»

Найдите полный путь через Ctrl+F в [справочнике](#files). Сначала прочитайте назначение его папки, затем запись файла и связанный сценарий. Если это файл из public/monaco, изображения или .keep, смотрите описание группы. Если имя заканчивается на _test.rb, это проверка поведения, а не код обработки обычного запроса.

### «Как найти файлы конкретной страницы?»

Начните с [routes.rb](config/routes.rb): URL ведёт к controller#action. В контроллере найдите действие, затем соответствующий app/views/имя_контроллера/действие.html.erb. Вызовы render ведут к partials; data-controller ведёт в app/javascript/controllers. Общие рамки страницы задаёт application.html.erb.

Например, /contests/:id/scoreboard связывает ContestsController#scoreboard, ContestParticipation, scoreboard.html.erb и _scoreboard_rows.html.erb. Для автоматического обновления дополнительно нужны файлы [M7](#m7).

### «Где изменить внешний вид, подпись или кнопку?»

Разметка находится в [views](#views), общие цвета и размеры в [assets/stylesheets](#assets), надписи в [config/locales](#config). Для общей навигации проверьте ApplicationHelper и layouts/_sidebar. Если кнопка имеет data-action, её поведение находится в Stimulus-контроллере. Если это форма, её url/method ведут к серверному маршруту.

### «Где добавлены Python и C++?»

[Submission::LANGUAGES](app/models/submission.rb) проверяет допустимые значения, [ProblemsController](app/controllers/problems_controller.rb) готовит варианты интерфейса, [Judge0Client::LANGUAGE_IDS](app/services/judge0_client.rb) переводит их в id Judge0. Редактор и загрузка файла также знают соответствия языков. Определения подсветки Monaco не дают серверу возможность проверять другие языки автоматически.

### «Где меняется штраф или рейтинг?»

Штраф и места находятся в [Scoring](app/services/contests/scoring.rb), формула рейтинга в [Calculator](app/services/ratings/calculator.rb), запись рейтинга и истории в [UpdateRatingsJob](app/jobs/update_ratings_job.rb). Это разные задачи: AC сначала меняет зачёт, а рейтинг сохраняется при финализации турнира.

### «Почему Run работает, а Submit остаётся queued?»

Run обращается к Judge0 из веб-запроса, Submit требует отдельного Sidekiq и Redis. Смотреть [путь проверки](#judging), настройки среды и логи соответствующего процесса. Если статус judging, дополнительно важны Judge0, сохранённые токены, callback и серверный polling. Не проверяйте проблему запуском пользовательской программы на Rails-хосте.

### «Почему таблица или вердикт не обновились?»

Это разные механизмы. Панель отправки спрашивает endpoint /status по HTTP, таблица получает WebSocket через Solid Cable. Для таблицы важны вход, подписка, конкретный турнир и факт пересчёта зачёта. После reconnect, регистрации и финализации требуется ручное обновление. См. [ограничения live](#live).

### «Почему файл есть, а функция не открывается?»

Нужны и маршрут, и вызов/подключение файла. Например, дополнительные admin-контроллеры, PWA-шаблоны и Devise confirmations не подключены к полноценным сценариям. Подробности помечены «заготовка» в справочнике.

### «Как добавить новую функцию, не потеряв связи?»

Определите её пользовательское действие и соответствующий этап плана. Для нового экрана обычно нужны маршрут, контроллер и view; для новых данных - миграция, модель и тест правил; для сложного расчёта - service; для фоновой работы - job и способ запуска. Переводы и подходящие тесты являются частью той же функции. Не все изменения требуют каждого слоя: новая подпись обычно не требует миграции.

### «Какая проверка доказывает работу функции?»

В [справочнике тестов](#tests) найдите поведение, затем читайте соответствующий тест вместе с реализацией. Наличие тестового файла не является отчётом о его последнем успешном запуске. Для внешнего Judge0 отдельно требуется ручной сценарий из README.

[К оглавлению](#contents)

<a id="limitations"></a>
## Границы текущей реализации

- Исходная схема предусматривает Contests::Generator, GenerateDailyContestsJob, sidekiq-cron и внешний Python-конвейер датасетов. Их реализации в текущем проекте нет. Имеется импорт локальных JSON и демотурнир.
- Основная очередь использует Sidekiq. Solid Queue остаётся в зависимостях, схемах, bin/jobs и отдельных настройках, но это не механизм текущего Submit.
- Живой WebSocket-сценарий реализован для scoreboard. Приватные трансляции вердиктов вместо polling и переход Run на серверные HTML-ответы пока описаны в планах, а текущий код использует polling и JSON.
- Monaco и собственные CSS/Stimulus-контроллеры остаются текущей реализацией. Предложенные изменения UI-библиотек в планах нельзя считать выполненными.
- Часть административных классов, PWA и Devise-шаблонов является заготовками; блоки активности групп остаются демонстрационными.
- Никнеймы уже редактируются и могут повторяться в текущем рабочем дереве, даже если соответствующие пункты отдельного плана ещё не отмечены.
- Judge0 запускается отдельно в Docker с isolate и ресурсными лимитами. Это описание архитектуры, а не утверждение о полной безопасности любого развёртывания. Обработчик webhook рассчитан на общий секрет локальной интеграции; секреты и содержимое cookie здесь не приведены.

При изменении функции обновляйте её сценарий, записи затронутых файлов и ссылки на проверки. Так документ останется ответом и на вопрос о конкретном файле, и на вопрос о работе всей цепочки.

[К оглавлению](#contents)
