// ============================================================
// Editor de Orçamento — vanilla JS (sem Turbo, sem Stimulus)
// ============================================================

(function () {
  "use strict";

  // ── Helpers ─────────────────────────────────────────────────

  function editorEl() {
    return document.getElementById("orcamento-editor");
  }

  function csrf() {
    return editorEl()?.dataset.csrf ||
      document.querySelector('meta[name="csrf-token"]')?.content;
  }

  function itensUrl() { return editorEl()?.dataset.itensUrl; }
  function reordenarUrl() { return editorEl()?.dataset.reordenarUrl; }
  function autoSaveUrl() { return editorEl()?.dataset.autoSaveUrl; }
  function trocarTemaUrl() { return editorEl()?.dataset.trocarTemaUrl; }

  function marcandoSalvando() {
    const el = document.getElementById("save-indicator");
    if (el) el.innerHTML = '<i class="fa fa-clock me-1"></i>Salvando...';
    if (el) el.className = "text-muted small";
  }

  function marcandoSalvo() {
    const el = document.getElementById("save-indicator");
    if (el) el.innerHTML = '<i class="fa fa-check-circle me-1"></i>Salvo';
    if (el) el.className = "text-success small";
  }

  function marcandoErro() {
    const el = document.getElementById("save-indicator");
    if (el) el.innerHTML = '<i class="fa fa-exclamation-circle me-1"></i>Erro';
    if (el) el.className = "text-danger small";
  }

  function parseBrMoeda(valor) {
    if (!valor) return "0";
    return valor.replace(/\./g, "").replace(",", ".");
  }

  // ── Auto-save dos campos da proposta ────────────────────────

  let autoSaveTimer = null;

  window.editorAutoSave = function () {
    marcandoSalvando();
    clearTimeout(autoSaveTimer);
    autoSaveTimer = setTimeout(_doAutoSave, 800);
  };

  function _doAutoSave() {
    const fd = new FormData();
    const titulo = document.getElementById("campo-titulo");
    const validade = document.getElementById("campo-validade");
    const desconto = document.getElementById("campo-desconto");
    const obs = document.getElementById("campo-observacoes");

    if (titulo) fd.append("orcamento[titulo]", titulo.value);
    if (validade) fd.append("orcamento[data_validade]", validade.value);
    if (desconto) fd.append("orcamento[desconto]", parseBrMoeda(desconto.value));
    if (obs) fd.append("orcamento[observacoes]", obs.value);
    fd.append("_method", "patch");

    fetch(autoSaveUrl(), {
      method: "POST",
      headers: { "X-CSRF-Token": csrf() },
      body: fd
    }).then(r => r.ok ? marcandoSalvo() : marcandoErro())
      .catch(marcandoErro);
  }

  // ── Adicionar item ───────────────────────────────────────────

  window.editorAdicionarItem = function () {
    const fd = new FormData();
    fd.append("_method", "post");

    fetch(itensUrl(), {
      method: "POST",
      headers: { "X-CSRF-Token": csrf(), "Accept": "application/json" },
      body: fd
    }).then(r => r.json()).then(data => {
      if (!data.success) return;

      const lista = document.getElementById("itens-lista");
      const vazio = document.getElementById("itens-vazio");
      if (vazio) vazio.remove();

      lista.insertAdjacentHTML("beforeend", data.item_html);
      _setupDrag(lista.querySelector(`#item-card-${data.item_id}`));
      _atualizarTotais(data.totais_html);
      // Aplicar máscara money2 nos novos inputs
      if (typeof $ !== "undefined") $(".money2").mask("000000000,00", { reverse: true });
    });
  };

  // ── Salvar campo de texto (com debounce) ─────────────────────

  const _debounceTimers = {};

  window.editorSalvarCampo = function (itemId, campo, valor, url, comDebounce) {
    marcandoSalvando();
    if (comDebounce) {
      clearTimeout(_debounceTimers[`${itemId}_${campo}`]);
      _debounceTimers[`${itemId}_${campo}`] = setTimeout(() => {
        _patchItem(url, { [`item[${campo}]`]: valor }, itemId, true);
      }, 600);
    } else {
      _patchItem(url, { [`item[${campo}]`]: valor }, itemId, false);
    }
  };

  window.editorSalvarPreco = function (itemId, valor, url) {
    marcandoSalvando();
    _patchItem(url, { "item[valorunitario]": parseBrMoeda(valor) }, itemId, false);
  };

  function _patchItem(url, dados, itemId, skipCard) {
    const fd = new FormData();
    Object.entries(dados).forEach(([k, v]) => fd.append(k, v));
    fd.append("_method", "patch");
    if (skipCard) fd.append("skip_card", "true");

    fetch(url, {
      method: "POST",
      headers: { "X-CSRF-Token": csrf(), "Accept": "application/json" },
      body: fd
    }).then(r => r.json()).then(data => {
      if (!data.success) return marcandoErro();
      if (!skipCard) _substituirCard(itemId, data.item_html);
      _atualizarTotais(data.totais_html);
      marcandoSalvo();
    }).catch(marcandoErro);
  }

  // ── Remover item ─────────────────────────────────────────────

  window.editorRemoverItem = function (itemId, url) {
    if (!confirm("Remover este produto?")) return;

    fetch(url, {
      method: "POST",
      headers: { "X-CSRF-Token": csrf(), "Accept": "application/json" },
      body: (() => { const fd = new FormData(); fd.append("_method", "delete"); return fd; })()
    }).then(r => r.json()).then(data => {
      if (!data.success) return;
      document.getElementById(`item-card-${itemId}`)?.remove();
      _atualizarTotais(data.totais_html);
    });
  };

  // ── Toggle posição foto ──────────────────────────────────────

  window.editorToggleFoto = function (itemId, url) {
    const fd = new FormData();
    fd.append("_method", "patch");
    fetch(url, {
      method: "POST",
      headers: { "X-CSRF-Token": csrf(), "Accept": "application/json" },
      body: fd
    }).then(r => r.json()).then(data => {
      if (data.success) _substituirCard(itemId, data.item_html);
    });
  };

  // ── Trocar tamanho foto ──────────────────────────────────────

  window.editorTrocarTamanho = function (itemId, url) {
    const fd = new FormData();
    fd.append("_method", "patch");
    fetch(url, {
      method: "POST",
      headers: { "X-CSRF-Token": csrf(), "Accept": "application/json" },
      body: fd
    }).then(r => r.json()).then(data => {
      if (data.success) _substituirCard(itemId, data.item_html);
    });
  };

  // ── Foto picker ──────────────────────────────────────────────

  let _fotoItemAtivo = null;
  let _fotoUrlAtiva = null;

  window.editorAbrirMenuFoto = function (itemId) {
    // Fecha outros menus abertos
    document.querySelectorAll(".foto-overlay").forEach(m => m.style.display = "none");
    const menu = document.getElementById(`foto-menu-${itemId}`);
    if (menu) menu.style.display = "flex";
    _fotoItemAtivo = itemId;
  };

  window.editorUploadFoto = function (itemId) {
    document.getElementById(`foto-menu-${itemId}`).style.display = "none";
    document.getElementById(`file-foto-${itemId}`).click();
  };

  window.editorSubmitFoto = function (itemId, url) {
    const input = document.getElementById(`file-foto-${itemId}`);
    if (!input.files[0]) return;

    const fd = new FormData();
    fd.append("item[foto]", input.files[0]);
    fd.append("_method", "patch");

    fetch(url, {
      method: "POST",
      headers: { "X-CSRF-Token": csrf(), "Accept": "application/json" },
      body: fd
    }).then(r => r.json()).then(data => {
      if (data.success) _substituirCard(itemId, data.item_html);
    });
  };

  window.editorAbrirBiblioteca = function (itemId, url) {
    document.getElementById(`foto-menu-${itemId}`).style.display = "none";
    _fotoItemAtivo = itemId;
    _fotoUrlAtiva = url;

    const body = document.getElementById("modal-biblioteca-body");
    body.innerHTML = '<p class="text-center text-muted">Carregando...</p>';

    const modalEl = document.getElementById("modalBiblioteca");
    const modal = bootstrap.Modal.getOrCreateInstance(modalEl);
    modal.show();

    fetch("/collaborators_backoffice/produto_imagens/biblioteca", {
      headers: { "Accept": "text/html" }
    }).then(r => r.text()).then(html => { body.innerHTML = html; });
  };

  window.editorSelecionarDaBiblioteca = function (produtoImagemId) {
    if (!_fotoItemAtivo || !_fotoUrlAtiva) return;

    const modal = bootstrap.Modal.getInstance(document.getElementById("modalBiblioteca"));
    modal?.hide();

    const fd = new FormData();
    fd.append("produto_imagem_id", produtoImagemId);
    fd.append("_method", "patch");

    fetch(_fotoUrlAtiva, {
      method: "POST",
      headers: { "X-CSRF-Token": csrf(), "Accept": "application/json" },
      body: fd
    }).then(r => r.json()).then(data => {
      if (data.success) _substituirCard(_fotoItemAtivo, data.item_html);
    });
  };

  // ── Trocar tema ──────────────────────────────────────────────

  window.editorTrocarTema = function (tema) {
    const fd = new FormData();
    fd.append("tema", tema);
    fd.append("_method", "patch");

    fetch(trocarTemaUrl(), {
      method: "POST",
      headers: { "X-CSRF-Token": csrf(), "Accept": "text/html" },
      body: fd
    }).then(r => r.text()).then(html => {
      document.getElementById("preview-documento").innerHTML = html;
      _setupDragAll();
      if (typeof $ !== "undefined") $(".money2").mask("000000000,00", { reverse: true });
    });
  };

  // ── Toggle desktop/mobile ────────────────────────────────────

  window.editorToggleDevice = function (device) {
    const frame = document.getElementById("preview-frame");
    if (!frame) return;
    frame.className = device === "mobile" ? "preview-mobile" : "preview-desktop";
    document.getElementById("btn-desktop").classList.toggle("active", device === "desktop");
    document.getElementById("btn-mobile").classList.toggle("active", device === "mobile");
  };

  // ── Drag and drop para reordenar ─────────────────────────────

  function _setupDrag(el) {
    if (!el) return;
    el.setAttribute("draggable", "true");

    el.addEventListener("dragstart", e => {
      el.classList.add("dragging");
      e.dataTransfer.effectAllowed = "move";
      e.dataTransfer.setData("text/plain", el.dataset.itemId);
    });

    el.addEventListener("dragend", () => {
      el.classList.remove("dragging");
      _salvarOrdem();
    });

    el.addEventListener("dragover", e => {
      e.preventDefault();
      const dragging = document.querySelector(".dragging");
      if (!dragging || dragging === el) return;
      const rect = el.getBoundingClientRect();
      if (e.clientY < rect.top + rect.height / 2) {
        el.parentNode.insertBefore(dragging, el);
      } else {
        el.parentNode.insertBefore(dragging, el.nextSibling);
      }
    });
  }

  function _setupDragAll() {
    document.querySelectorAll(".item-editavel").forEach(_setupDrag);
  }

  function _salvarOrdem() {
    const posicoes = Array.from(document.querySelectorAll(".item-editavel"))
      .map(el => el.dataset.itemId);

    fetch(reordenarUrl(), {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": csrf(),
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: JSON.stringify({ posicoes: posicoes })
    });
  }

  // ── Helpers internos ─────────────────────────────────────────

  function _substituirCard(itemId, html) {
    const card = document.getElementById(`item-card-${itemId}`);
    if (!card) return;
    card.outerHTML = html;
    _setupDrag(document.getElementById(`item-card-${itemId}`));
    if (typeof $ !== "undefined") $(".money2").mask("000000000,00", { reverse: true });
  }

  function _atualizarTotais(html) {
    const el = document.getElementById("editor-totais");
    if (el && html) el.innerHTML = html;
    const preview = document.getElementById("preview-totais");
    if (preview && html) preview.innerHTML = html;
  }

  // ── Fechar menu de foto ao clicar fora ───────────────────────

  document.addEventListener("click", function (e) {
    if (!e.target.closest(".foto-wrapper")) {
      document.querySelectorAll(".foto-overlay").forEach(m => m.style.display = "none");
    }
  });

  // ── Init ─────────────────────────────────────────────────────

  document.addEventListener("DOMContentLoaded", function () {
    _setupDragAll();
  });

})();
