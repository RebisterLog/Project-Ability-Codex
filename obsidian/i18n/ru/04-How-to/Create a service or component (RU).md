# Создание сервиса или компонента

## Сервис

```luau
local Service = Crane:CreateService({ Name = "MyService" })

function Service:onInit() end
function Service:onStart() end

return Service
```

- Серверные сервисы — в `src/server/services/<Name>.luau` или `src/server/services/<Name>/init.luau`; клиентские — в `src/client/services/`.
- Зависимости получаются через `Crane:GetService("Name")`, а не передаются в конструктор.
- Пакеты регистрируются через `Crane:GetPacket("Name")`, сигналы — через `Signal()`.
- Таймеры, соединения и инстансы отслеживаются в `Crane.Janitor` / `Crane.Buttler`.
- Порядок: `onInit` всех сервисов выполняется до `onStart`; сервис, нужный другому в `onStart`, должен быть готов заранее.

## Компонент

```luau
local Component = Crane:CreateComponent({ Name = "MyComponent" })
-- self.instance — привязанный инстанс
```

- Компоненты — в `src/server/components/` или `src/client/components/`.
- Компонент привязан к инстансу; получайте его через `Crane:GetComponent`.
- После респавнов не предполагайте ровно один компонент на модель. См. [[Gotchas (RU)]].

## Шаблоны

В `tools/templates/` есть `Service.luau.tmpl`, `Component.luau.tmpl`, `Spec.luau.tmpl` и `Hook.luau.tmpl`. Замените все `{{...}}`, затем следуйте нужному гайду. См. [[Templates and generators (RU)]].

## Проверка

- Колбэки жизненного цикла срабатывают в ожидаемом порядке.
- Все ресурсы освобождаются при удалении компонента/сервиса.
- Отформатируйте код: `lune run tools/format.luau --fix --src`.

Связанные: [[Services and dependencies (RU)]], [[Player modules (RU)]], [[Player and character lifecycle (RU)]]. Оригинал: [[Create a service or component]].
