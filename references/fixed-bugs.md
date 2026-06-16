# Реестр исправленных багов

## Принцип
Каждый исправленный баг заносится сюда с grep-шаблоном. Перед любым изменением — проверь, что ни один шаблон не совпал. Если совпал — это рецидив, исправь перед сдачей.

---

### PTS-STARTPRES (опечатка в константе ffmpeg)
**Grep-шаблон:** `STARTPRES`
**Файлы для проверки:** `lib/filter_graph_strategy.dart`
**Проверка:** `grep -r "STARTPRES" lib/` — 0 совпадений
**Дата исправления:** 2026-06-14
**Контекст:** В filter_graph_strategy использована несуществующая константа `PTS-STARTPRES` вместо `PTS-STARTPTS`.

---

### `-ss` перед `-i` + `-c:v copy` (keyframe desync)
**Grep-шаблон:** `-ss.*-i.*-c:v copy` или `-c:v copy.*-ss`
**Файлы для проверки:** любые экспортные стратегии
**Проверка:** `grep -r "\-ss" lib/ | grep -i "\-c:v copy"` — 0 совпадений
**Дата исправления:** 2026-06-14
**Контекст:** `-ss` перед `-i` с `-c:v copy` делает некадровую склейку.

---

### Extract-then-concat с temp-файлами (N+1 процессов)
**Grep-шаблон:** `tempDir` или `tempFiles` в контексте экспорта
**Файлы для проверки:** `lib/concat_strategy.dart`, `lib/transcode_strategy.dart`
**Проверка:** старые стратегии удалены
**Дата исправления:** 2026-06-14
**Контекст:** ConcatStrategy извлекала сегменты в temp-файлы, потом склеивала. N+1 ffmpeg процессов.

---

### `concat=n=1` crash
**Grep-шаблон:** `concat=n=1`
**Файлы для проверки:** `lib/filter_graph_strategy.dart`
**Проверка:** `grep -r "concat=n=1" lib/` — 0 совпадений
**Дата исправления:** 2026-06-14
**Контекст:** FFmpeg не поддерживает `concat=n=1`. При единственном клипе код пропускает concat.

---

### Hardcoded UI-текст (нелокализованная строка)
**Grep-шаблон:** `Text\(\s*['"][А-Яа-я]`
**Файлы для проверки:** все `.dart` файлы с виджетами
**Проверка:** при добавлении `Text('...')` убедись что строка не хардкожена
**Дата исправления:** ongoing
**Контекст:** Все тексты в UI должны быть через `AppLocalizations.t()`.

---

### Mix audio без enabled-треков (логическая ошибка)
**Grep-шаблон:** `mixAudio` в сочетании с `enabledPerType.length <= 1`
**Файлы для проверки:** `lib/filter_graph_strategy.dart`
**Проверка:** код проверяет `enabledPerType.length > 1` перед `amix`
**Дата исправления:** 2026-06-14
**Контекст:** Если включён только один аудиотрек, `amix` не нужен.

---

### Аудио выключено по умолчанию (нарушение принципа «вход = выход»)
**Grep-шаблон:** `_audioEnabled`
**Файлы для проверки:** `lib/home_screen.dart`, `lib/providers/audio_provider.dart`
**Проверка:** grep не находит `_audioEnabled` (заменено на `_muteAudio`)
**Дата исправления:** 2026-06-15
**Контекст:** `_audioEnabled` удалено. Вместо него `_muteAudio`. По умолчанию `false` — аудио всегда включено. Галка «Настроить аудио» заменена на «Без звука» в общих настройках.

---

### `ref.listen()` в `didChangeDependencies` (runtime crash)
**Grep-шаблон:** `didChangeDependencies.*ref\.listen`
**Файлы для проверки:** `lib/home_screen.dart`
**Проверка:** `grep -r "didChangeDependencies.*ref\.listen" lib/` — 0 совпадений
**Дата исправления:** 2026-06-15
**Контекст:** `ref.listen()` был помещён в `didChangeDependencies` вместо `build()`. Riverpod требует `ref.listen()` только внутри метода `build()` у `ConsumerStatefulWidget`/`ConsumerWidget`. Иначе — красный экран: "ref.listen can only be used within the build method". Перенесено в начало `build()`.
