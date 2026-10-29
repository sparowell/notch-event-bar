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
- [ ] 5. В шторке без нулевых часов при остатке меньше часа (`39:38`, не `00:39:38`); подтверждено скриншотом
- [ ] 6. В шторке рядом со временем события длительность в скобках
- [ ] 7. Вложенные события. Подтверждено скриншотом: идущая встреча подменяет блок (блок уходит в «+1»). Нужно: блок остаётся основным, встреча накладывается на полосу капсулой (эскиз пользователя) и отсчёт до начала вложенной встречи
- [ ] 8. Баг: кнопка Join в шторке рисуется поверх строки «→ следующее событие» (`NotchPanelView.swift`, overlay `.bottom`, padding 16). Нужно другое место, варианты A/B/C в артефакте
- [ ] 9. Баг: обрезается верхняя часть подписи у текущего события в шторке. Не воспроизведён, нужен крупный скриншот и уточнение, какая именно подпись
- [ ] 10. Автозапуск (Launch at login) включить в приложении; заметку в волте обновить
