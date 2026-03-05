#!/usr/bin/env python3
"""
PeaceEnd Kanban Board — Local web UI for docs/KANBAN.md
Usage: python tools/kanban_server.py [--port 8080]
"""

import http.server
import json
import os
import re
import sys
import webbrowser
from urllib.parse import urlparse, parse_qs

KANBAN_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs", "KANBAN.md")
DEFAULT_PORT = 8080


def parse_kanban_md(path: str) -> list[dict]:
    """Parse KANBAN.md into a list of card dicts."""
    if not os.path.exists(path):
        return []

    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    cards = []
    current_section = None  # plan, progress, done
    card_lines = []
    current_id = None
    current_title = None

    section_map = {
        "plan": "plan",
        "in progress": "progress",
        "done": "done",
    }

    for line in content.split("\n"):
        # Detect section headers (## Plan, ## In Progress, ## Done)
        section_match = re.match(r"^## (.+)$", line.strip())
        if section_match:
            # Save previous card if any
            if current_id:
                cards.append(_parse_card_block(current_id, current_title, card_lines, current_section))
                card_lines = []
                current_id = None

            section_name = section_match.group(1).strip().lower()
            current_section = section_map.get(section_name)
            continue

        # Detect card headers (### [P-NNN] Title)
        card_match = re.match(r"^### \[([A-Z]-\d+)\]\s+(.+)$", line.strip())
        if card_match:
            # Save previous card if any
            if current_id:
                cards.append(_parse_card_block(current_id, current_title, card_lines, current_section))
                card_lines = []

            current_id = card_match.group(1)
            current_title = card_match.group(2).strip()
            continue

        if current_id:
            card_lines.append(line)

    # Save last card
    if current_id:
        cards.append(_parse_card_block(current_id, current_title, card_lines, current_section))

    return cards


def _parse_card_block(card_id: str, title: str, lines: list[str], section_status: str) -> dict:
    """Parse a card's property lines into a dict."""
    card = {
        "id": card_id,
        "title": title,
        "status": section_status or "plan",
        "priority": "medium",
        "category": "other",
        "description": "",
    }

    for line in lines:
        line = line.strip()
        if not line or line.startswith("---"):
            continue

        status_match = re.match(r"^-\s+\*\*Статус:\*\*\s+(.+)$", line)
        if status_match:
            val = status_match.group(1).strip().lower()
            if val in ("plan", "progress", "done"):
                card["status"] = val
            continue

        priority_match = re.match(r"^-\s+\*\*Приоритет:\*\*\s+(.+)$", line)
        if priority_match:
            val = priority_match.group(1).strip().lower()
            if val in ("high", "medium", "low"):
                card["priority"] = val
            continue

        category_match = re.match(r"^-\s+\*\*Категория:\*\*\s+(.+)$", line)
        if category_match:
            card["category"] = category_match.group(1).strip().lower()
            continue

        desc_match = re.match(r"^-\s+\*\*Описание:\*\*\s+(.+)$", line)
        if desc_match:
            card["description"] = desc_match.group(1).strip()
            continue

    return card


def write_kanban_md(path: str, cards: list[dict]):
    """Write cards back to KANBAN.md preserving the format."""
    plan_cards = [c for c in cards if c["status"] == "plan"]
    progress_cards = [c for c in cards if c["status"] == "progress"]
    done_cards = [c for c in cards if c["status"] == "done"]

    # Sort: by numeric ID within each section
    def sort_key(c):
        m = re.match(r"[A-Z]-(\d+)", c["id"])
        return int(m.group(1)) if m else 0

    plan_cards.sort(key=sort_key)
    progress_cards.sort(key=sort_key)
    done_cards.sort(key=sort_key)

    lines = []
    lines.append("# PeaceEnd — Kanban Board")
    lines.append("")
    lines.append("> **Формат:** Локальная markdown-доска задач, аналог AR_DB roadmap board.")
    lines.append("> Единственный источник правды по текущему состоянию разработки.")
    lines.append("")
    lines.append("## Легенда")
    lines.append("")
    lines.append("**Статусы:** `plan` | `progress` | `done`")
    lines.append("**Приоритет:** `high` | `medium` | `low`")
    lines.append("**Категории:** `gameplay` | `ui` | `art` | `audio` | `infra` | `polish`")
    lines.append("")
    lines.append("**Формат карточки:**")
    lines.append("```")
    lines.append("### [ID] Название")
    lines.append("- **Статус:** plan | progress | done")
    lines.append("- **Приоритет:** high | medium | low")
    lines.append("- **Категория:** gameplay | ui | art | audio | infra | polish")
    lines.append("- **Описание:** Краткое описание задачи")
    lines.append("```")
    lines.append("")
    lines.append("---")
    lines.append("")

    def write_section(title, section_cards):
        lines.append(f"## {title}")
        lines.append("")
        if not section_cards:
            lines.append("*(нет задач)*")
            lines.append("")
        for card in section_cards:
            lines.append(f"### [{card['id']}] {card['title']}")
            lines.append(f"- **Статус:** {card['status']}")
            lines.append(f"- **Приоритет:** {card['priority']}")
            lines.append(f"- **Категория:** {card['category']}")
            lines.append(f"- **Описание:** {card['description']}")
            lines.append("")

    write_section("Plan", plan_cards)
    lines.append("---")
    lines.append("")
    write_section("In Progress", progress_cards)
    lines.append("---")
    lines.append("")
    write_section("Done", done_cards)

    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def get_next_id(cards: list[dict]) -> str:
    """Get next available P-NNN id."""
    max_num = 0
    for c in cards:
        m = re.match(r"P-(\d+)", c["id"])
        if m:
            max_num = max(max_num, int(m.group(1)))
    return f"P-{max_num + 1:03d}"


HTML_PAGE = r"""<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>PeaceEnd — Kanban Board</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #1a1a2e;
    color: #e0e0e0;
    min-height: 100vh;
}

header {
    background: #16213e;
    border-bottom: 2px solid #0f3460;
    padding: 16px 24px;
    display: flex;
    align-items: center;
    justify-content: space-between;
}

header h1 {
    font-size: 20px;
    color: #e94560;
    letter-spacing: 1px;
}

header .subtitle {
    color: #888;
    font-size: 13px;
}

.toolbar {
    display: flex;
    gap: 10px;
    align-items: center;
}

.btn {
    padding: 8px 16px;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 600;
    transition: all 0.2s;
}

.btn-primary {
    background: #e94560;
    color: white;
}
.btn-primary:hover { background: #c73e54; }

.btn-secondary {
    background: #2a2a4a;
    color: #ccc;
    border: 1px solid #444;
}
.btn-secondary:hover { background: #3a3a5a; }

.board {
    display: flex;
    gap: 16px;
    padding: 20px 24px;
    min-height: calc(100vh - 70px);
    overflow-x: auto;
}

.column {
    flex: 1;
    min-width: 300px;
    max-width: 450px;
    background: #16213e;
    border-radius: 10px;
    display: flex;
    flex-direction: column;
}

.column-header {
    padding: 14px 16px;
    font-weight: 700;
    font-size: 14px;
    text-transform: uppercase;
    letter-spacing: 1px;
    border-bottom: 2px solid transparent;
    display: flex;
    align-items: center;
    justify-content: space-between;
    border-radius: 10px 10px 0 0;
}

.column-header .count {
    background: #2a2a4a;
    padding: 2px 8px;
    border-radius: 10px;
    font-size: 12px;
    color: #aaa;
}

.col-plan .column-header { border-bottom-color: #533483; color: #b388ff; }
.col-progress .column-header { border-bottom-color: #e94560; color: #ff6b81; }
.col-done .column-header { border-bottom-color: #0f9b58; color: #69db7c; }

.column-body {
    padding: 10px;
    flex: 1;
    overflow-y: auto;
    min-height: 100px;
}

.column-body.drag-over {
    background: rgba(233, 69, 96, 0.08);
    border-radius: 0 0 10px 10px;
}

.card {
    background: #1a1a2e;
    border: 1px solid #2a2a4a;
    border-radius: 8px;
    padding: 12px;
    margin-bottom: 8px;
    cursor: grab;
    transition: all 0.2s;
    border-left: 4px solid transparent;
}

.card:hover {
    border-color: #444;
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(0,0,0,0.3);
}

.card.dragging {
    opacity: 0.5;
    transform: rotate(2deg);
}

.card.priority-high { border-left-color: #e94560; }
.card.priority-medium { border-left-color: #f59e0b; }
.card.priority-low { border-left-color: #0f9b58; }

.card-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 8px;
    margin-bottom: 6px;
}

.card-id {
    font-size: 11px;
    color: #666;
    font-family: monospace;
    flex-shrink: 0;
}

.card-title {
    font-size: 14px;
    font-weight: 600;
    color: #e0e0e0;
    flex: 1;
}

.card-desc {
    font-size: 12px;
    color: #888;
    margin-top: 6px;
    line-height: 1.4;
}

.card-footer {
    display: flex;
    gap: 6px;
    margin-top: 8px;
    flex-wrap: wrap;
    align-items: center;
}

.badge {
    font-size: 10px;
    padding: 2px 8px;
    border-radius: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

.badge-gameplay { background: #1e3a5f; color: #5dade2; }
.badge-ui { background: #3b1f5e; color: #bb86fc; }
.badge-art { background: #4a2c1a; color: #f4a261; }
.badge-audio { background: #1a3a2a; color: #52c41a; }
.badge-infra { background: #3a3a1a; color: #d4b106; }
.badge-polish { background: #3a1a2a; color: #eb2f96; }
.badge-other { background: #2a2a2a; color: #999; }

.priority-badge {
    font-size: 10px;
    padding: 2px 6px;
    border-radius: 3px;
    font-weight: 700;
}
.priority-badge.high { background: rgba(233,69,96,0.2); color: #e94560; }
.priority-badge.medium { background: rgba(245,158,11,0.2); color: #f59e0b; }
.priority-badge.low { background: rgba(15,155,88,0.2); color: #0f9b58; }

.card-actions {
    opacity: 0;
    transition: opacity 0.2s;
    display: flex;
    gap: 4px;
}
.card:hover .card-actions { opacity: 1; }

.card-actions button {
    background: none;
    border: none;
    cursor: pointer;
    color: #666;
    font-size: 14px;
    padding: 2px 4px;
    border-radius: 4px;
}
.card-actions button:hover { color: #e94560; background: rgba(233,69,96,0.1); }

/* Modal */
.modal-overlay {
    display: none;
    position: fixed;
    top: 0; left: 0; right: 0; bottom: 0;
    background: rgba(0,0,0,0.6);
    z-index: 1000;
    justify-content: center;
    align-items: center;
}
.modal-overlay.active { display: flex; }

.modal {
    background: #16213e;
    border: 1px solid #2a2a4a;
    border-radius: 12px;
    padding: 24px;
    width: 480px;
    max-width: 90vw;
    box-shadow: 0 20px 60px rgba(0,0,0,0.5);
}

.modal h2 {
    color: #e94560;
    margin-bottom: 16px;
    font-size: 18px;
}

.form-group {
    margin-bottom: 14px;
}

.form-group label {
    display: block;
    font-size: 12px;
    color: #888;
    margin-bottom: 4px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

.form-group input,
.form-group select,
.form-group textarea {
    width: 100%;
    padding: 10px 12px;
    background: #1a1a2e;
    border: 1px solid #2a2a4a;
    border-radius: 6px;
    color: #e0e0e0;
    font-size: 14px;
    font-family: inherit;
}

.form-group input:focus,
.form-group select:focus,
.form-group textarea:focus {
    outline: none;
    border-color: #e94560;
}

.form-group textarea { resize: vertical; min-height: 60px; }

.modal-actions {
    display: flex;
    gap: 8px;
    justify-content: flex-end;
    margin-top: 20px;
}

.stats {
    display: flex;
    gap: 16px;
    align-items: center;
}

.stat {
    font-size: 12px;
    color: #666;
}
.stat strong { color: #aaa; }

/* Filter bar */
.filter-bar {
    padding: 10px 24px;
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
    align-items: center;
}

.filter-bar label {
    font-size: 12px;
    color: #666;
    margin-right: 4px;
}

.filter-btn {
    padding: 4px 10px;
    border: 1px solid #333;
    background: transparent;
    color: #888;
    border-radius: 14px;
    font-size: 11px;
    cursor: pointer;
    transition: all 0.15s;
}
.filter-btn:hover { border-color: #555; color: #ccc; }
.filter-btn.active { border-color: #e94560; color: #e94560; background: rgba(233,69,96,0.1); }

/* Empty state */
.empty-state {
    text-align: center;
    padding: 30px 16px;
    color: #555;
    font-size: 13px;
    font-style: italic;
}
</style>
</head>
<body>

<header>
    <div>
        <h1>PEACEEND</h1>
        <span class="subtitle">Kanban Board &mdash; docs/KANBAN.md</span>
    </div>
    <div class="toolbar">
        <div class="stats" id="stats"></div>
        <button class="btn btn-primary" onclick="openCreateModal()">+ New Card</button>
    </div>
</header>

<div class="filter-bar" id="filterBar">
    <label>Filter:</label>
    <button class="filter-btn active" data-filter="all" onclick="setFilter('all', this)">All</button>
    <button class="filter-btn" data-filter="gameplay" onclick="setFilter('gameplay', this)">Gameplay</button>
    <button class="filter-btn" data-filter="ui" onclick="setFilter('ui', this)">UI</button>
    <button class="filter-btn" data-filter="art" onclick="setFilter('art', this)">Art</button>
    <button class="filter-btn" data-filter="audio" onclick="setFilter('audio', this)">Audio</button>
    <button class="filter-btn" data-filter="infra" onclick="setFilter('infra', this)">Infra</button>
    <button class="filter-btn" data-filter="polish" onclick="setFilter('polish', this)">Polish</button>
    <span style="margin-left: auto"></span>
    <label>Priority:</label>
    <button class="filter-btn active" data-pfilter="all" onclick="setPriorityFilter('all', this)">All</button>
    <button class="filter-btn" data-pfilter="high" onclick="setPriorityFilter('high', this)">High</button>
    <button class="filter-btn" data-pfilter="medium" onclick="setPriorityFilter('medium', this)">Medium</button>
    <button class="filter-btn" data-pfilter="low" onclick="setPriorityFilter('low', this)">Low</button>
</div>

<div class="board">
    <div class="column col-plan" data-status="plan">
        <div class="column-header">
            <span>Plan</span>
            <span class="count" id="count-plan">0</span>
        </div>
        <div class="column-body" id="col-plan"
             ondragover="onDragOver(event)" ondrop="onDrop(event, 'plan')"
             ondragenter="onDragEnter(event)" ondragleave="onDragLeave(event)"></div>
    </div>
    <div class="column col-progress" data-status="progress">
        <div class="column-header">
            <span>In Progress</span>
            <span class="count" id="count-progress">0</span>
        </div>
        <div class="column-body" id="col-progress"
             ondragover="onDragOver(event)" ondrop="onDrop(event, 'progress')"
             ondragenter="onDragEnter(event)" ondragleave="onDragLeave(event)"></div>
    </div>
    <div class="column col-done" data-status="done">
        <div class="column-header">
            <span>Done</span>
            <span class="count" id="count-done">0</span>
        </div>
        <div class="column-body" id="col-done"
             ondragover="onDragOver(event)" ondrop="onDrop(event, 'done')"
             ondragenter="onDragEnter(event)" ondragleave="onDragLeave(event)"></div>
    </div>
</div>

<!-- Modal -->
<div class="modal-overlay" id="modal">
    <div class="modal">
        <h2 id="modalTitle">New Card</h2>
        <input type="hidden" id="editId">
        <div class="form-group">
            <label>Title</label>
            <input type="text" id="fieldTitle" placeholder="Task title...">
        </div>
        <div class="form-group">
            <label>Description</label>
            <textarea id="fieldDesc" placeholder="What needs to be done..."></textarea>
        </div>
        <div style="display: flex; gap: 12px;">
            <div class="form-group" style="flex:1">
                <label>Priority</label>
                <select id="fieldPriority">
                    <option value="high">High</option>
                    <option value="medium" selected>Medium</option>
                    <option value="low">Low</option>
                </select>
            </div>
            <div class="form-group" style="flex:1">
                <label>Category</label>
                <select id="fieldCategory">
                    <option value="gameplay">Gameplay</option>
                    <option value="ui">UI</option>
                    <option value="art">Art</option>
                    <option value="audio">Audio</option>
                    <option value="infra">Infra</option>
                    <option value="polish">Polish</option>
                </select>
            </div>
            <div class="form-group" style="flex:1">
                <label>Status</label>
                <select id="fieldStatus">
                    <option value="plan">Plan</option>
                    <option value="progress">In Progress</option>
                    <option value="done">Done</option>
                </select>
            </div>
        </div>
        <div class="modal-actions">
            <button class="btn btn-secondary" onclick="closeModal()">Cancel</button>
            <button class="btn btn-primary" id="btnDelete" style="display:none; background:#c0392b" onclick="deleteCard()">Delete</button>
            <button class="btn btn-primary" onclick="saveCard()">Save</button>
        </div>
    </div>
</div>

<script>
let cards = [];
let currentFilter = 'all';
let currentPriorityFilter = 'all';
let draggedId = null;

async function loadCards() {
    const resp = await fetch('/api/items');
    cards = await resp.json();
    render();
}

function render() {
    const filtered = cards.filter(c => {
        if (currentFilter !== 'all' && c.category !== currentFilter) return false;
        if (currentPriorityFilter !== 'all' && c.priority !== currentPriorityFilter) return false;
        return true;
    });

    const plan = filtered.filter(c => c.status === 'plan');
    const progress = filtered.filter(c => c.status === 'progress');
    const done = filtered.filter(c => c.status === 'done');

    document.getElementById('col-plan').innerHTML = plan.length
        ? plan.map(renderCard).join('')
        : '<div class="empty-state">No planned tasks</div>';
    document.getElementById('col-progress').innerHTML = progress.length
        ? progress.map(renderCard).join('')
        : '<div class="empty-state">Nothing in progress</div>';
    document.getElementById('col-done').innerHTML = done.length
        ? done.map(renderCard).join('')
        : '<div class="empty-state">Nothing completed yet</div>';

    document.getElementById('count-plan').textContent = plan.length;
    document.getElementById('count-progress').textContent = progress.length;
    document.getElementById('count-done').textContent = done.length;

    const total = cards.length;
    const doneCount = cards.filter(c => c.status === 'done').length;
    document.getElementById('stats').innerHTML =
        `<span class="stat"><strong>${total}</strong> total</span>` +
        `<span class="stat"><strong>${doneCount}</strong> done</span>` +
        `<span class="stat"><strong>${total > 0 ? Math.round(doneCount/total*100) : 0}%</strong> complete</span>`;
}

function renderCard(card) {
    return `<div class="card priority-${card.priority}" draggable="true"
                 ondragstart="onDragStart(event, '${card.id}')"
                 ondragend="onDragEnd(event)"
                 ondblclick="openEditModal('${card.id}')">
        <div class="card-header">
            <span class="card-id">${card.id}</span>
            <span class="card-title">${escHtml(card.title)}</span>
            <div class="card-actions">
                <button onclick="openEditModal('${card.id}')" title="Edit">&#9998;</button>
            </div>
        </div>
        ${card.description ? `<div class="card-desc">${escHtml(card.description)}</div>` : ''}
        <div class="card-footer">
            <span class="badge badge-${card.category}">${card.category}</span>
            <span class="priority-badge ${card.priority}">${card.priority}</span>
        </div>
    </div>`;
}

function escHtml(s) {
    return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

// Drag & drop
function onDragStart(e, id) {
    draggedId = id;
    e.target.classList.add('dragging');
    e.dataTransfer.effectAllowed = 'move';
}

function onDragEnd(e) {
    e.target.classList.remove('dragging');
    draggedId = null;
    document.querySelectorAll('.column-body').forEach(el => el.classList.remove('drag-over'));
}

function onDragOver(e) { e.preventDefault(); e.dataTransfer.dropEffect = 'move'; }
function onDragEnter(e) { e.preventDefault(); e.currentTarget.classList.add('drag-over'); }
function onDragLeave(e) { e.currentTarget.classList.remove('drag-over'); }

async function onDrop(e, newStatus) {
    e.preventDefault();
    e.currentTarget.classList.remove('drag-over');
    if (!draggedId) return;

    const card = cards.find(c => c.id === draggedId);
    if (!card || card.status === newStatus) return;

    card.status = newStatus;
    render();

    await fetch(`/api/items/${draggedId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(card)
    });
}

// Modal
function openCreateModal() {
    document.getElementById('modalTitle').textContent = 'New Card';
    document.getElementById('editId').value = '';
    document.getElementById('fieldTitle').value = '';
    document.getElementById('fieldDesc').value = '';
    document.getElementById('fieldPriority').value = 'medium';
    document.getElementById('fieldCategory').value = 'gameplay';
    document.getElementById('fieldStatus').value = 'plan';
    document.getElementById('btnDelete').style.display = 'none';
    document.getElementById('modal').classList.add('active');
    setTimeout(() => document.getElementById('fieldTitle').focus(), 100);
}

function openEditModal(id) {
    const card = cards.find(c => c.id === id);
    if (!card) return;
    document.getElementById('modalTitle').textContent = `Edit [${card.id}]`;
    document.getElementById('editId').value = card.id;
    document.getElementById('fieldTitle').value = card.title;
    document.getElementById('fieldDesc').value = card.description;
    document.getElementById('fieldPriority').value = card.priority;
    document.getElementById('fieldCategory').value = card.category;
    document.getElementById('fieldStatus').value = card.status;
    document.getElementById('btnDelete').style.display = 'inline-block';
    document.getElementById('modal').classList.add('active');
    setTimeout(() => document.getElementById('fieldTitle').focus(), 100);
}

function closeModal() {
    document.getElementById('modal').classList.remove('active');
}

async function saveCard() {
    const id = document.getElementById('editId').value;
    const data = {
        title: document.getElementById('fieldTitle').value.trim(),
        description: document.getElementById('fieldDesc').value.trim(),
        priority: document.getElementById('fieldPriority').value,
        category: document.getElementById('fieldCategory').value,
        status: document.getElementById('fieldStatus').value,
    };

    if (!data.title) { alert('Title is required'); return; }

    if (id) {
        // Update
        data.id = id;
        await fetch(`/api/items/${id}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
    } else {
        // Create
        await fetch('/api/items', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
    }

    closeModal();
    await loadCards();
}

async function deleteCard() {
    const id = document.getElementById('editId').value;
    if (!id) return;
    if (!confirm(`Delete [${id}]?`)) return;

    await fetch(`/api/items/${id}`, { method: 'DELETE' });
    closeModal();
    await loadCards();
}

// Filters
function setFilter(filter, btn) {
    currentFilter = filter;
    document.querySelectorAll('[data-filter]').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    render();
}

function setPriorityFilter(filter, btn) {
    currentPriorityFilter = filter;
    document.querySelectorAll('[data-pfilter]').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    render();
}

// Keyboard shortcuts
document.addEventListener('keydown', e => {
    if (e.key === 'Escape') closeModal();
    if (e.key === 'n' && !document.querySelector('.modal-overlay.active') && e.target === document.body) {
        e.preventDefault();
        openCreateModal();
    }
});

// Click outside modal to close
document.getElementById('modal').addEventListener('click', e => {
    if (e.target === document.getElementById('modal')) closeModal();
});

loadCards();
</script>
</body>
</html>"""


class KanbanHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        print(f"[kanban] {args[0]}")

    def _json_response(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

    def _html_response(self, html):
        body = html.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        return json.loads(self.rfile.read(length)) if length else {}

    def do_GET(self):
        path = urlparse(self.path).path

        if path == "/" or path == "":
            self._html_response(HTML_PAGE)
        elif path == "/api/items":
            cards = parse_kanban_md(KANBAN_PATH)
            self._json_response(cards)
        else:
            self.send_error(404)

    def do_POST(self):
        path = urlparse(self.path).path

        if path == "/api/items":
            data = self._read_body()
            cards = parse_kanban_md(KANBAN_PATH)
            new_id = get_next_id(cards)
            card = {
                "id": new_id,
                "title": data.get("title", "Untitled"),
                "description": data.get("description", ""),
                "priority": data.get("priority", "medium"),
                "category": data.get("category", "other"),
                "status": data.get("status", "plan"),
            }
            cards.append(card)
            write_kanban_md(KANBAN_PATH, cards)
            self._json_response(card, 201)
        else:
            self.send_error(404)

    def do_PUT(self):
        path = urlparse(self.path).path
        match = re.match(r"^/api/items/([A-Z]-\d+)$", path)

        if match:
            item_id = match.group(1)
            data = self._read_body()
            cards = parse_kanban_md(KANBAN_PATH)
            card = next((c for c in cards if c["id"] == item_id), None)
            if not card:
                self.send_error(404)
                return

            for key in ("title", "description", "priority", "category", "status"):
                if key in data:
                    card[key] = data[key]

            write_kanban_md(KANBAN_PATH, cards)
            self._json_response(card)
        else:
            self.send_error(404)

    def do_DELETE(self):
        path = urlparse(self.path).path
        match = re.match(r"^/api/items/([A-Z]-\d+)$", path)

        if match:
            item_id = match.group(1)
            cards = parse_kanban_md(KANBAN_PATH)
            cards = [c for c in cards if c["id"] != item_id]
            write_kanban_md(KANBAN_PATH, cards)
            self._json_response({"ok": True})
        else:
            self.send_error(404)


def main():
    port = DEFAULT_PORT
    if "--port" in sys.argv:
        idx = sys.argv.index("--port")
        if idx + 1 < len(sys.argv):
            port = int(sys.argv[idx + 1])

    server = http.server.HTTPServer(("127.0.0.1", port), KanbanHandler)
    url = f"http://127.0.0.1:{port}"
    print(f"Kanban board: {url}")
    print(f"Data file:    {KANBAN_PATH}")
    print("Press Ctrl+C to stop\n")

    webbrowser.open(url)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
        server.server_close()


if __name__ == "__main__":
    main()
