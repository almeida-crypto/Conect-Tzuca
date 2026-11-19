// Gavilán sin internet: guarda los archivos de la app en este navegador para que abra aunque no haya conexión
// (por ejemplo, cuando regresa la luz y el módem todavía no). Solo se registra si el dueño lo activa en
// Más → Esta computadora. Los datos del negocio no pasan por aquí: viven en la base del navegador.
//
// Con internet siempre pide la versión nueva (y la guarda); si no contesta en unos segundos, usa la guardada.
// Solo atiende archivos de este mismo sitio; lo de Supabase va directo a la red.

const CACHE = 'gavilan-app';
const WAIT_MS = 4000;

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      // Cachés viejas de otras versiones de este archivo.
      for (const key of await caches.keys()) if (key !== CACHE) await caches.delete(key);
      await self.clients.claim();
    })(),
  );
});

// La página manda la lista de archivos para guardarlos todos de una vez.
self.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.type !== 'precache' || !Array.isArray(data.urls)) return;
  const port = event.ports && event.ports[0];
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE);
      let saved = 0;
      let failed = 0;
      // De 6 en 6 para no saturar la conexión.
      const urls = [...new Set(data.urls)];
      for (let i = 0; i < urls.length; i += 6) {
        await Promise.all(
          urls.slice(i, i + 6).map(async (url) => {
            try {
              const res = await fetch(url, { cache: 'no-cache' });
              if (!res.ok) throw new Error(String(res.status));
              await cache.put(url, res);
              saved++;
            } catch (_) {
              failed++;
            }
          }),
        );
      }
      if (port) port.postMessage({ saved, failed });
    })(),
  );
});

function sameOrigin(url) {
  return new URL(url).origin === self.location.origin;
}

async function fromNetwork(request) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), WAIT_MS);
  try {
    const res = await fetch(request, { signal: controller.signal });
    if (res.ok && res.type === 'basic') {
      const copy = res.clone();
      caches.open(CACHE).then((c) => c.put(request, copy));
    }
    return res;
  } finally {
    clearTimeout(timer);
  }
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || !sameOrigin(request.url)) return;
  event.respondWith(
    (async () => {
      try {
        return await fromNetwork(request);
      } catch (error) {
        const cache = await caches.open(CACHE);
        const hit = await cache.match(request, { ignoreSearch: true });
        if (hit) return hit;
        // Al abrir la página sin internet: la página principal guardada.
        if (request.mode === 'navigate') {
          const page = (await cache.match('./')) || (await cache.match('index.html'));
          if (page) return page;
        }
        throw error;
      }
    })(),
  );
});
