# Pendientes

Lista de control. Marca con `[x]` lo que se termine y agrega la fecha. Lo ya hecho está en [BITACORA.md](BITACORA.md).

Prioridad: **Alta** = sin esto no se puede usar con un negocio real · **Media** = necesario antes de cobrar suscripciones · **Baja** = mejora.

---

## Etapa 0 · Orden del proyecto
- [x] **Alta** · Poner la carpeta bajo control de versiones y subirla a GitHub: [almeida-crypto/Conect-Tzuca](https://github.com/almeida-crypto/Conect-Tzuca) (público). *26/10/2026*
- [x] **Media** · Agregar `.gitignore` para `gavilan_app/build/`, archivos locales, llaves y el PDF maestro. *26/10/2026*
- [ ] **Media** · Cuando haya llaves reales (Supabase, PowerSync, firma de Android), guardarlas fuera del repositorio: es público.

## Etapa 1 · Que la app guarde y sincronice
- [x] **Alta** · Guardar los datos en el teléfono con Drift (SQLite): cada venta, abono, gasto y producto se guarda al momento y se carga al abrir. *26/10/2026*
- [x] **Alta** · Sincronizar con Supabase sin servicios externos: fila de pendientes que sube sola y descarga de cambios por `synced_at`. *26/10/2026*
- [x] **Alta** · Inicio de sesión con correo y contraseña (Supabase Auth) y enlace del negocio con `create_business`. *26/10/2026*
- [ ] **Alta** · Primera prueba real: el usuario crea su cuenta desde la app, confirma el correo y revisamos en Supabase que suban las ventas.
- [ ] **Alta** · Correo propio (SMTP con Resend o Brevo) para los correos de confirmación: el de Supabase solo manda unos cuantos por hora y puede caer en spam.
- [ ] **Media** · En Supabase Auth, poner una página de "correo confirmado" como URL de redirección. Hoy el enlace del correo confirma la cuenta pero abre una página que no carga.
- [ ] **Media** · "Olvidé mi contraseña".
- [ ] **Media** · Decidir si el respaldo en la nube es solo de los planes de pago: el PDF lo pone en Emprendedor. Hoy está abierto para todos.
- [ ] **Baja** · Pagos mixtos (`sale_payments`) y devoluciones en la sincronización.
- [x] **Alta** · Primer arranque: bienvenida con el nombre del negocio, o probar con la tiendita de ejemplo. En Más se puede borrar todo y empezar de nuevo. *26/10/2026*
- [ ] **Media** · Guía para dar de alta el primer producto cuando el negocio está vacío.
- [ ] **Media** · En el navegador (vista previa) los datos no se guardan. Si hace falta, agregar `sqlite3.wasm` y `drift_worker.js` a `web/`.
- [x] **Alta** · Indicador real en el encabezado: Sin internet, Sin respaldo, Por subir, Respaldado o Revisar respaldo. *26/10/2026*
- [ ] **Media** · Folios de venta que no choquen entre dos dispositivos sin internet (prefijo por dispositivo).
- [ ] **Media** · Probar que un cajero del negocio A no vea nada del negocio B (RLS con usuarios reales).

## Etapa 2 · Completar el mostrador
- [ ] **Alta** · Cámara como escáner de códigos (`mobile_scanner`) y modo "¿Cuánto cuesta?".
- [x] **Alta** · Probar la app en Android: probada en el emulador; guarda, cierra a la fuerza, reabre y actualiza sin perder datos. *26/10/2026*
- [ ] **Alta** · Probarla en un celular Android real de gama baja.
- [ ] **Media** · Pantalla de carga de Android con los colores de Gavilán: hoy sale un instante blanca con el logo de Flutter.
- [ ] **Media** · Ticket como imagen PNG para WhatsApp (`RepaintBoundary` + `share_plus`), con logo en planes de pago.
- [ ] **Media** · Tarjeta para Estados de WhatsApp: foto del producto, precio y sello "Disponible".
- [ ] **Media** · Fotos de producto en planes de pago: reducir a 600×600 WebP en el teléfono y subir a Supabase Storage.
- [ ] **Media** · Políticas de Supabase Storage para fotos de productos y apartados.
- [ ] **Media** · Incluir las fuentes Archivo y Space Mono dentro de la app. Hoy se descargan la primera vez y necesitan internet.
- [ ] **Baja** · Celular como escáner inalámbrico de la laptop (Supabase Realtime).
- [ ] **Baja** · Generador de etiquetas con código de barras en PDF.
- [ ] **Baja** · Descuentos por venta y devoluciones.

## Etapa 3 · Módulos por giro
- [ ] **Media** · Apartados: foto, anticipo, fecha límite, abonos y comprobante por WhatsApp. Las tablas `layaways` y `layaway_payments` ya existen.
- [ ] **Media** · Pacas y lotes: inversión, ventas y barra de recuperación. Las tablas `lots` y `lot_sales` ya existen. El plan gratis permite 1 lote.
- [ ] **Media** · Pedidos por tanda: entrega y pago en dos toques, y ganancia restando insumos. Las tablas `batches` y `batch_orders` ya existen.
- [ ] **Media** · Restaurante:
  - Mesas y comandera para meseros.
  - Pantalla de cocina en tiempo real.
  - Cobro por mesa.

  Las tablas `restaurant_tables`, `orders` y `order_items` ya existen, con Realtime activado.
- [ ] **Media** · Equipo y roles: invitar cajeros, meseros y cocina.
- [ ] **Baja** · Impresora térmica Bluetooth o USB.
- [ ] **Baja** · Límite de crédito por cliente y alertas de vencimiento (plan Negocio).
- [ ] **Baja** · Reportes de margen de ganancia y costos de proveedores.

## Etapa 4 · Planes y cobro
- [ ] **Media** · Confirmar los límites exactos de cada plan contra el PDF (la tabla salió desordenada al leerla).
- [ ] **Media** · Validar los límites también en la base de datos (triggers), no solo en la app.
- [ ] **Media** · Cobro real de suscripciones y quitar el selector de "vista previa" de planes.
- [ ] **Media** · Pasar proyecto-Gavilan a plan Pro de Supabase antes de tener clientes: el gratis se pausa tras 7 días sin actividad.

## Etapa 5 · Panel web (Next.js)
- [ ] **Baja** · Definir el alcance mínimo: reportes, catálogo tipo Excel y cobro con lector USB.
- [ ] **Baja** · Crear el proyecto conectado al mismo Supabase.

## Seguridad y ajustes de base de datos
- [ ] **Media** · Que los meseros no vean el costo de los productos (vista sin `cost`).
- [ ] **Media** · Que el rol cocina solo pueda cambiar el estado de los pedidos, no otros campos.
- [ ] **Baja** · Revisar los 3 avisos "WARN" de Supabase cuando cambie el esquema. Hoy son intencionales; ver [BASE_DE_DATOS.md](BASE_DE_DATOS.md).

## Diseño
- [ ] **Baja** · Ajustes futuros del gavilán, si el usuario los pide. Por ejemplo, acercar el pecho al de la foto: barrado café y blanco en lugar del crema con óxido.
- [ ] **Baja** · Icono de la app (launcher) a partir del gavilán.
- [ ] **Baja** · Tema oscuro.
- [ ] **Baja** · Diseñar comandera y pantalla de cocina.

## Proyecto 1 · Directorio (otro repositorio)
Mejoras acordadas en el PDF, pendientes en el repositorio del Directorio:
- [ ] Portada: quitar el doble buscador, tipografía sans-serif y tarjetas flotantes.
- [ ] Carrusel publicitario con arte para escritorio (1440×450) y móvil (1080×1080 o 1080×1350).
- [ ] SMTP propio (Resend o Brevo) en Supabase Auth.
- [ ] Monitor (UptimeRobot) para evitar el arranque en frío de Render.
- [ ] Reglas del piloto de repartidores: cuota $0, mensaje por WhatsApp y tope de $100 en efectivo.
