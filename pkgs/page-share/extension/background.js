/* global chrome */

// 分享列表：shareId → {tabId, title, url, favicon, type}
const shares = new Map();

// --- Tab lifecycle ---

chrome.tabs.onRemoved.addListener((tabId) => {
  for (const [shareId, info] of shares) {
    if (info.tabId === tabId) shares.delete(shareId);
  }
});

chrome.tabs.onUpdated.addListener((tabId, changeInfo) => {
  for (const [, info] of shares) {
    if (info.tabId === tabId) {
      if (changeInfo.url) info.url = changeInfo.url;
      if (changeInfo.title) info.title = changeInfo.title;
    }
  }
});

// --- ID 生成 ---

function generateShareId() {
  return Array.from(crypto.getRandomValues(new Uint8Array(4)))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

// --- Popup 通信 ---

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  const { action } = message;

  if (action === 'getShares') {
    sendResponse([...shares.entries()].map(([shareId, info]) => ({ shareId, ...info })));
    return false;
  }

  if (action === 'addPage') {
    const { tab } = message;
    const shareId = generateShareId();
    shares.set(shareId, {
      tabId: tab.id,
      title: tab.title || '',
      url: tab.url || '',
      favicon: tab.favIconUrl || '',
    });
    sendResponse({ shareId, title: tab.title });
    return false;
  }


  if (action === 'removeShare') {
    shares.delete(message.shareId);
    sendResponse({ ok: true });
    return false;
  }

  if (action === 'removeAll') {
    shares.clear();
    sendResponse({ ok: true });
    return false;
  }

  return false;
});
