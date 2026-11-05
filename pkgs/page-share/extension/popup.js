/* global chrome, navigator */

// --- Phosphor 图标 (regular, viewBox 0 0 256 256) ---
const icons = {
  shareNetwork: (s) => svg(s, '<path d="M176,164a28,28,0,0,0-21.94,10.59l-46.69-29.18A28,28,0,0,0,108,128a28,28,0,0,0-.63-5.41l46.69-29.18A28,28,0,1,0,148,76a28,28,0,0,0,.63,5.41L101.94,110.59a28,28,0,1,0,0,36.82l46.69,29.18A28,28,0,1,0,176,164Z"/>'),
  clipboardText: (s) => svg(s, '<path d="M168,152a8,8,0,0,1-8,8H96a8,8,0,0,1,0-16h64A8,8,0,0,1,168,152Zm-8-40H96a8,8,0,0,0,0,16h64a8,8,0,0,0,0-16Zm56-64V216a16,16,0,0,1-16,16H56a16,16,0,0,1-16-16V48A16,16,0,0,1,56,32H92.26a47.92,47.92,0,0,1,71.48,0H200A16,16,0,0,1,216,48ZM128,32a32,32,0,0,0-32,32h64A32,32,0,0,0,128,32Zm72,16H173.25A47.93,47.93,0,0,1,176,64v8a8,8,0,0,1-8,8H88a8,8,0,0,1-8-8V64a47.93,47.93,0,0,1,2.75-16H56V216H200Z"/>'),
  x: (s) => svg(s, '<path d="M205.66,194.34a8,8,0,0,1-11.32,11.32L128,139.31,61.66,205.66a8,8,0,0,1-11.32-11.32L116.69,128,50.34,61.66A8,8,0,0,1,61.66,50.34L128,116.69l66.34-66.35a8,8,0,0,1,11.32,11.32L139.31,128Z"/>'),
  plus: (s) => svg(s, '<path d="M224,128a8,8,0,0,1-8,8H136v80a8,8,0,0,1-16,0V136H40a8,8,0,0,1,0-16h80V40a8,8,0,0,1,16,0v80h80A8,8,0,0,1,224,128Z"/>'),
  check: (s) => svg(s, '<path d="M229.66,77.66l-128,128a8,8,0,0,1-11.32,0l-56-56a8,8,0,0,1,11.32-11.32L96,188.69,218.34,66.34a8,8,0,0,1,11.32,11.32Z"/>'),
  trash: (s) => svg(s, '<path d="M216,48H176V40a24,24,0,0,0-24-24H104A24,24,0,0,0,80,40v8H40a8,8,0,0,0,0,16h8V208a16,16,0,0,0,16,16H192a16,16,0,0,0,16-16V64h8a8,8,0,0,0,0-16ZM96,40a8,8,0,0,1,8-8h48a8,8,0,0,1,8,8v8H96Zm96,168H64V64H192ZM112,104v64a8,8,0,0,1-16,0V104a8,8,0,0,1,16,0Zm48,0v64a8,8,0,0,1-16,0V104a8,8,0,0,1,16,0Z"/>'),
};

function svg(size, inner) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" fill="currentColor" width="${size}" height="${size}">${inner}</svg>`;
}

// --- State ---
let sharesList = [];

// --- Prompt ---

function pagePrompt(title, url, tabId) {
  return `[Chrome DevTools MCP] 操作页面 tabId=${tabId}「${title}」${url}`;
}

// --- Clipboard ---
async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    const ta = document.createElement('textarea');
    ta.value = text;
    ta.style.cssText = 'position:fixed;left:-9999px';
    document.body.appendChild(ta);
    ta.select();
    document.execCommand('copy');
    ta.remove();
    return true;
  }
}

// --- Chrome messaging ---
function sendMessage(msg) {
  return new Promise((resolve) => chrome.runtime.sendMessage(msg, resolve));
}

// --- DOM helper ---
function el(tag, cls) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  return e;
}

// --- Toast ---
function showToast(text) {
  const existing = document.querySelector('.ps-toast');
  if (existing) existing.remove();
  const toast = el('div', 'ps-toast fixed bottom-16 left-1/2 -translate-x-1/2 bg-zinc-800 dark:bg-zinc-200 text-white dark:text-zinc-900 text-xs font-medium px-3 py-1.5 rounded-full shadow-lg transition-opacity');
  toast.textContent = text;
  document.body.appendChild(toast);
  setTimeout(() => {
    toast.style.opacity = '0';
    setTimeout(() => toast.remove(), 200);
  }, 1800);
}

// --- Render ---

function render() {
  const app = document.getElementById('app');
  app.innerHTML = '';

  // Header
  const header = el('div', 'flex items-center gap-2 px-4 py-3 border-b border-zinc-200 dark:border-zinc-700');
  header.innerHTML = `
    <span class="text-blue-600 dark:text-blue-400">${icons.shareNetwork(22)}</span>
    <span class="font-semibold text-base flex-1">Page Share</span>
  `;
  if (sharesList.length > 0) {
    const clearBtn = el('button', 'ml-1 p-1.5 rounded-md text-zinc-400 hover:text-red-500 hover:bg-zinc-100 dark:hover:bg-zinc-700 dark:hover:text-red-400 transition-colors');
    clearBtn.innerHTML = icons.trash(16);
    clearBtn.title = '全部停止';
    clearBtn.addEventListener('click', handleRemoveAll);
    header.appendChild(clearBtn);
  }
  app.appendChild(header);

  // Share list
  if (sharesList.length === 0) {
    const empty = el('div', 'px-4 py-8 text-center text-zinc-400 dark:text-zinc-500 text-sm');
    empty.textContent = '没有分享中的页面';
    app.appendChild(empty);
  } else {
    const list = el('div', 'max-h-[300px] overflow-y-auto');
    for (const share of sharesList) {
      list.appendChild(renderShareItem(share));
    }
    app.appendChild(list);
  }

  // Footer
  const footer = el('div', 'p-3 border-t border-zinc-200 dark:border-zinc-700');
  const btn = el('button', 'w-full flex items-center justify-center gap-2 px-4 py-2.5 bg-blue-600 hover:bg-blue-700 active:bg-blue-800 text-white text-sm font-medium rounded-lg transition-colors');
  btn.innerHTML = `${icons.plus(16)} 分享当前页面`;
  btn.addEventListener('click', handleAddPage);
  footer.appendChild(btn);
  app.appendChild(footer);
}

function renderShareItem(share) {
  const row = el('div', 'flex items-center gap-3 px-4 py-2.5 hover:bg-zinc-50 dark:hover:bg-zinc-800/50 transition-colors');

  // Favicon
  const fav = document.createElement('img');
  fav.src = share.favicon || '';
  fav.width = 16;
  fav.height = 16;
  fav.className = 'shrink-0 rounded-sm';
  fav.onerror = function () { this.style.display = 'none'; };
  row.appendChild(fav);

  // Info
  const info = el('div', 'flex-1 min-w-0');
  const title = el('div', 'text-sm font-medium truncate');
  title.textContent = share.title || '(无标题)';
  const url = el('div', 'text-xs text-zinc-400 dark:text-zinc-500 truncate');
  url.textContent = share.url || '';
  info.appendChild(title);
  info.appendChild(url);
  row.appendChild(info);

  // Copy
  const copyBtn = el('button', 'shrink-0 p-1.5 rounded-md text-zinc-400 hover:text-blue-600 hover:bg-zinc-100 dark:hover:bg-zinc-700 dark:hover:text-blue-400 transition-colors');
  copyBtn.innerHTML = icons.clipboardText(16);
  copyBtn.title = '复制提示';
  copyBtn.addEventListener('click', async (e) => {
    e.stopPropagation();
    const prompt = pagePrompt(share.title, share.url, share.tabId);
    await copyText(prompt);
    copyBtn.innerHTML = icons.check(16);
    copyBtn.classList.add('text-emerald-500');
    setTimeout(() => {
      copyBtn.innerHTML = icons.clipboardText(16);
      copyBtn.classList.remove('text-emerald-500');
    }, 1500);
  });
  row.appendChild(copyBtn);

  // Remove
  const removeBtn = el('button', 'shrink-0 p-1.5 rounded-md text-zinc-400 hover:text-red-500 hover:bg-zinc-100 dark:hover:bg-zinc-700 dark:hover:text-red-400 transition-colors');
  removeBtn.innerHTML = icons.x(16);
  removeBtn.title = '停止分享';
  removeBtn.addEventListener('click', async (e) => {
    e.stopPropagation();
    await sendMessage({ action: 'removeShare', shareId: share.shareId });
    await loadShares();
  });
  row.appendChild(removeBtn);

  return row;
}

// --- Actions ---

async function handleAddPage() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab) return;

  const result = await sendMessage({ action: 'addPage', tab });
  if (result?.shareId) {
    await copyText(pagePrompt(result.title, tab.url, tab.id));
    showToast('已复制提示到剪贴板');
  }
  await loadShares();
}


async function handleRemoveAll() {
  await sendMessage({ action: 'removeAll' });
  await loadShares();
}

async function loadShares() {
  sharesList = (await sendMessage({ action: 'getShares' })) || [];
  render();
}

// --- Init ---
loadShares();
