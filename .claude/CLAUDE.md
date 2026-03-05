# PeaceEnd — AI Instructions

## Kanban Board: docs/KANBAN.md

**ОБЯЗАТЕЛЬНО:** Перед любой работой прочитай `docs/KANBAN.md`. После завершения — обнови.

### Работа с доской

1. **Начало задачи:**
   - Прочитай `docs/KANBAN.md`
   - Найди задачу или создай новую карточку с новым ID (`[P-NNN]`)
   - Перемести карточку из `## Plan` в `## In Progress`, поменяй `**Статус:** progress`

2. **Завершение задачи:**
   - Перемести карточку из `## In Progress` в `## Done`, поменяй `**Статус:** done`
   - Если задача не завершена полностью — оставь в `In Progress` и добавь примечание

3. **Новая задача:**
   - Добавь карточку в `## Plan` с новым ID (следующий по порядку)
   - Формат:
     ```
     ### [P-NNN] Название
     - **Статус:** plan
     - **Приоритет:** high | medium | low
     - **Категория:** gameplay | ui | art | audio | infra | polish
     - **Описание:** Краткое описание
     ```

4. **ID схема:** `P-001`, `P-002`, ... (P = PeaceEnd, монотонно возрастающий номер)

5. **Правила:**
   - Только ОДНА задача `in progress` за раз (на одного агента)
   - Не удалять завершённые задачи — они остаются в `## Done` как история
   - Приоритет `high` = блокирует геймплей, `medium` = улучшение, `low` = nice-to-have
   - Категории: `gameplay` (механики), `ui` (интерфейс), `art` (графика), `audio` (звук), `infra` (сборка/экспорт), `polish` (доработки)

### Красные флаги

| Мысль | Реальность |
|-------|-----------|
| "Задача слишком мелкая для доски" | Добавь. Доска — это история проекта |
| "Обновлю потом" | Обновляй сейчас, пока контекст свеж |
| "Начал писать код" | Сначала проверь доску |
| "Это просто баг-фикс" | Всё равно занеси в доску |

---

## Parallel Agents: MAXIMIZE Usage

**CRITICAL:** Always prefer parallel agent execution over sequential work. This is a top-priority workflow rule.

### When to use parallel agents (Task tool):
- **2+ independent file edits** — launch separate agents for each file/module
- **Research + implementation** — one agent explores codebase while another starts implementation of known parts
- **Multiple search queries** — run Explore agents in parallel instead of sequential Grep/Glob
- **Testing + fixing** — one agent runs tests, another already works on the next task
- **Code review + new work** — review completed work in parallel with starting next step
- **Plan execution** — when a plan has independent steps, dispatch agents for all independent steps simultaneously
- **Sprite generation + code** — generate assets in parallel with writing game logic

### Rules:
1. Before starting any multi-step task, identify which steps are independent and can run in parallel
2. Use `subagent_type: "general-purpose"` for implementation tasks, `subagent_type: "Explore"` for research
3. Launch ALL independent agents in a single message (multiple Task tool calls)
4. Only sequence agents when there is a true data dependency (output of one feeds into another)
5. When in doubt, parallelize — the cost of a wasted agent is far lower than the cost of sequential execution
6. For plans with 3+ steps, always use the `superpowers:dispatching-parallel-agents` or `superpowers:subagent-driven-development` skill

### Anti-patterns to AVOID:
- Reading files one by one when you could dispatch agents to read multiple areas simultaneously
- Waiting for research to complete before starting implementation of parts you already understand
- Running a single Explore agent when multiple independent searches would be faster
- Doing sequential edits to unrelated files

### Examples:
- "Implement explosion + infantry" → 2 parallel agents (one per feature)
- "Fix bug in A.gd and add feature to B.gd" → 2 parallel agents
- "Research how X works and implement Y" → 2 parallel agents (Explore + general-purpose)
- "Run tests and write docs" → 2 parallel agents
