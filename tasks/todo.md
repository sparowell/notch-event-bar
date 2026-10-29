# Personal build: NotchBar

- [x] Fork, branch `personal`, baseline build + 163 tests green
- [x] Shared: `NextEvent.startDate`
- [x] Track A: menu-bar text (remaining + next event title/countdown)
- [x] Track B: mini progress bar in menu bar
- [x] Track C: windows from day start, no 2h cap
- [x] Merge C -> A -> B, full tests
- [ ] Package, install to /Applications, launch at login

## Review
190 tests green on `personal`. Installed to /Applications. Text in menu bar verified on screenshot; mini bar and launch-at-login still to confirm by hand.

## Backlog 2026-10-30 (обсуждается, реализация не начата)

- [ ] 1. Метки внутри длинного блока (части = длина / 30 мин, не больше 4; 1 ч: 50%, 1 ч 30: 33/67%, 2 ч+: 25/50/75%). Стиль выбирается по артефакту с 5 вариантами
- [ ] 2. Мини-полоса в строке меню: толще/шире, отступ от «чёлки». Уточнить, это она или тонкая линия под «чёлкой»
- [ ] 3. Баг: в настройках из иконки в строке меню список календарей пуст (в шторке виден). Гипотеза: ScrollView с `.frame(maxHeight: 220)` схлопывается в MenuBarExtra (`SettingsView.swift:57`)
- [ ] 4. Check for Updates: смотрит релизы upstream Periicles/Notchapp, для форка бесполезна. Решение: убрать
- [ ] 5. В шторке при остатке меньше часа не показывать часы (`MM:SS` вместо `00:MM:SS`)
- [ ] 6. В шторке рядом со временем события показывать длительность в скобках
- [ ] 7. Вложенные события: наложение на полосе блока (5 вариантов в артефакте) и отсчёт до начала вложенной встречи. Сейчас «главным» выбирается событие, которое кончается раньше, то есть встреча подменяет блок
- [ ] 8. Автозапуск (Launch at login) включить в приложении; заметку в волте обновить
