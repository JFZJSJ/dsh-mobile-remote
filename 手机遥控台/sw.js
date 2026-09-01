/* DSH 遥控台 Service Worker：仅保证可安装性，不缓存业务数据。
   API 与实时流一律透传；导航请求强制不走缓存（no-store），
   确保升级后的页面立刻生效，绝不显示旧版。 */
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  if (e.request.mode === 'navigate') {
    e.respondWith(fetch(e.request, { cache: 'no-store' }));
    return;
  }
  e.respondWith(fetch(e.request));
});
