// Puente entre la app y el modo sin internet (gavilan_sw.js). Nada se guarda ni se instala hasta que el dueño
// lo pide en Más → Esta computadora; desde entonces se recuerda en este navegador.
(function () {
  const FLAG = 'gavilan-offline';
  const SW = 'gavilan_sw.js';
  let installPrompt = null;

  const supported = 'serviceWorker' in navigator && 'caches' in window && window.isSecureContext;

  function flagOn() {
    try {
      return localStorage.getItem(FLAG) === '1';
    } catch (_) {
      return false;
    }
  }

  function setFlag(on) {
    try {
      if (on) localStorage.setItem(FLAG, '1');
      else localStorage.removeItem(FLAG);
    } catch (_) {}
  }

  // Ya activado antes: se vuelve a registrar para que el archivo se mantenga al día.
  if (supported && flagOn()) navigator.serviceWorker.register(SW).catch(() => {});

  // El navegador avisa que se puede instalar con ícono; se guarda para cuando el dueño toque el botón.
  window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    installPrompt = e;
  });
  window.addEventListener('appinstalled', () => {
    installPrompt = null;
  });

  // Lo que la página ya cargó (motor, código, fuentes) más la lista que manda la app.
  function filesToSave(extra) {
    const here = location.origin;
    const loaded = performance
      .getEntriesByType('resource')
      .map((e) => e.name)
      .filter((u) => u.startsWith(here))
      .map((u) => u.split('#')[0]);
    const core = [
      './',
      'index.html',
      'flutter_bootstrap.js',
      'flutter.js',
      'main.dart.js',
      'manifest.json',
      'atajos.js',
      'offline.js',
      'drift_worker.js',
      'sqlite3.wasm',
      'favicon.png',
      'icons/Icon-192.png',
      'icons/Icon-512.png',
      'version.json',
      'assets/FontManifest.json',
      'assets/AssetManifest.bin',
      'assets/AssetManifest.bin.json',
    ];
    return [...core, ...loaded, ...(extra || [])].map((u) => new URL(u, document.baseURI).href);
  }

  window.gavilanOffline = {
    supported: () => supported,

    /** Activado en este navegador y ya funcionando. */
    enabled: () => supported && flagOn(),

    /** Guarda la app en este navegador. Regresa cuántos archivos se guardaron y cuántos fallaron. */
    enable: async (extra) => {
      if (!supported) throw new Error('Este navegador no lo permite');
      setFlag(true);
      await navigator.serviceWorker.register(SW);
      const reg = await navigator.serviceWorker.ready;
      const worker = reg.active;
      return await new Promise((resolve, reject) => {
        const channel = new MessageChannel();
        const timer = setTimeout(() => reject(new Error('Tardó demasiado')), 180000);
        channel.port1.onmessage = (e) => {
          clearTimeout(timer);
          resolve(e.data);
        };
        worker.postMessage({ type: 'precache', urls: filesToSave(extra) }, [channel.port2]);
      });
    },

    /** Quita lo guardado y deja de funcionar sin internet en este navegador. */
    disable: async () => {
      setFlag(false);
      if (!supported) return;
      for (const reg of await navigator.serviceWorker.getRegistrations()) {
        if ((reg.active && reg.active.scriptURL.endsWith(SW)) || (reg.installing && reg.installing.scriptURL.endsWith(SW)))
          await reg.unregister();
      }
      for (const key of await caches.keys()) if (key.startsWith('gavilan')) await caches.delete(key);
    },

    /** El navegador ofrece instalar Gavilán con ícono (Chrome o Edge en la computadora). */
    canInstall: () => installPrompt !== null,

    /** Abierto como programa instalado (ventana propia, sin barra del navegador). */
    installed: () => window.matchMedia('(display-mode: standalone)').matches,

    /** Muestra la ventana del navegador "¿Instalar Gavilán?". true si la persona aceptó. */
    install: async () => {
      if (!installPrompt) return false;
      const prompt = installPrompt;
      installPrompt = null;
      await prompt.prompt();
      const choice = await prompt.userChoice;
      return choice.outcome === 'accepted';
    },
  };
})();
