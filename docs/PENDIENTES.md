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
- [x] **Alta** · Primera prueba real: cuenta creada y confirmada desde el celular; negocio, producto, venta, corte y existencia llegaron a Supabase. *31/10/2026*
- [ ] **Alta** · Correo propio (SMTP con Resend o Brevo) para los correos de confirmación: el de Supabase solo manda unos cuantos por hora y puede caer en spam.
- [x] **Media** · El enlace del correo de confirmación abre la app con la cuenta lista y enlaza el teléfono (`mx.gavilan.gavilan://auth/confirmado`). *01/11/2026*
- [x] **Media** · "Olvidé mi contraseña": correo con enlace que abre la app para elegir la contraseña nueva. *01/11/2026*
- [x] **Alta** · `mx.gavilan.gavilan://**` agregado en Supabase → Authentication → URL Configuration → Redirect URLs. El usuario probó "Olvidé mi contraseña" en su celular y funcionó. *09/11/2026*
- [ ] **Baja** · Traducir al español las plantillas de correo de Supabase (Authentication → Emails).
- [ ] **Media** · Decidir si el respaldo en la nube es solo de los planes de pago: el PDF lo pone en Emprendedor. Hoy está abierto para todos.
- [ ] **Baja** · Pagos mixtos (`sale_payments`) y devoluciones en la sincronización.
- [x] **Alta** · Primer arranque: bienvenida con el nombre del negocio, o probar con la tiendita de ejemplo. En Más se puede borrar todo y empezar de nuevo. *26/10/2026*
- [ ] **Media** · Guía para dar de alta el primer producto cuando el negocio está vacío.
- [ ] **Media** · En el navegador (vista previa) los datos no se guardan. Si hace falta, agregar `sqlite3.wasm` y `drift_worker.js` a `web/`.
- [x] **Alta** · Indicador real en el encabezado: Sin internet, Sin respaldo, Por subir, Respaldado o Revisar respaldo. *26/10/2026*
- [x] **Media** · Folios que no chocan entre teléfonos: cada uno tiene su clave ("K7-0043") y su propia numeración. *09/11/2026*
- [ ] **Media** · Probar que un cajero del negocio A no vea nada del negocio B (RLS con usuarios reales). Las funciones del equipo ya se probaron en el servidor con un usuario simulado.

## Etapa 2 · Completar el mostrador
- [x] **Alta** · Cámara como escáner de códigos (`mobile_scanner`), modo "¿Cuánto cuesta?", alta de producto desde un código desconocido y lector en la ficha de producto. *31/10/2026*
- [x] **Alta** · Escáner probado en el celular del usuario con un código real: alta, cobro y "¿Cuánto cuesta?" funcionan. *31/10/2026*
- [ ] **Media** · Error de Flutter 3.47 en el emulador al cargar su efecto de estiramiento de listas (`shaders/stretch_effect.frag ... manifest could not be decoded`). No es código de la app y no la detiene; revisar en un celular real y, si sigue, actualizar Flutter.
- [x] **Alta** · Permiso de internet en la versión final de Android: faltaba y la app compilada para entregar no habría podido respaldar. *31/10/2026*
- [x] **Alta** · Probar la app en Android: probada en el emulador; guarda, cierra a la fuerza, reabre y actualiza sin perder datos. *26/10/2026*
- [x] **Alta** · Probada en el celular Android del usuario: fluida, conserva los datos al salir y el ticket llega bien por WhatsApp. *31/10/2026*
- [ ] **Media** · Probarla en un celular de gama baja (2 o 3 GB de RAM), como los de muchos comerciantes.
- [x] **Media** · Pantalla de carga en color papel en Android e iPhone; en Android 12 o más sale el icono de Gavilán. *01/11/2026*
- [x] **Media** · Ticket como imagen PNG para WhatsApp (`RepaintBoundary` + `share_plus`), con la opción de mandarlo como texto. *31/10/2026*
- [ ] **Media** · Logo del negocio en el ticket para los planes de pago.
- [ ] **Media** · Tarjeta para Estados de WhatsApp: foto del producto, precio y sello "Disponible".
- [ ] **Media** · Fotos de producto en planes de pago: reducir a 600×600 WebP en el teléfono y subir a Supabase Storage.
- [ ] **Media** · Políticas de Supabase Storage para fotos de productos y apartados.
- [x] **Media** · Fuentes Archivo y Space Mono dentro de la app (`assets/google_fonts/`, licencia OFL): se ven bien sin internet desde el primer arranque. *01/11/2026*
- [ ] **Baja** · Celular como escáner inalámbrico de la laptop (Supabase Realtime).
- [ ] **Baja** · Generador de etiquetas con código de barras en PDF.
- [ ] **Baja** · Descuentos por venta y devoluciones.

## Etapa 3 · Módulos por giro
- [x] **Media** · Apartados: anticipo, abonos, fecha límite con aviso de vencido, liquidación automática, cancelación y comprobante por WhatsApp. *31/10/2026*
- [ ] **Media** · Foto del artículo apartado (cámara + Supabase Storage).
- [x] **Media** · Pacas y lotes: inversión, ventas rápidas, barra de recuperación y ganancia; entra al corte. El plan gratis permite 1 paca activa. *31/10/2026*
- [x] **Media** · Pedidos por tanda: entrega y pago en dos toques, insumos, ganancia y aviso por WhatsApp. *31/10/2026*
- [ ] **Baja** · Decidir si lo cobrado de las tandas entra al corte de caja (hoy no entra: muchas tandas se cobran fuera del mostrador).
- [x] **Media** · Restaurante: mesas, comandas, pantalla de cocina al instante (Realtime), para llevar y cobro por mesa. Meseros y cocina se invitan al equipo y la app les abre directo en mesas o cocina. *09/11/2026*
- [ ] **Media** · Probar el restaurante con dos celulares reales (mesero y cocina) para medir cuánto tarda en llegar la comanda.
- [ ] **Baja** · Restaurante: dividir la cuenta, pasar una cuenta a otra mesa, imprimir la comanda en cocina y poner la mesa en el ticket.
- [ ] **Baja** · Platillos que no se venden en mostrador (que solo salgan en el restaurante) y modificadores con precio (extra queso).
- [x] **Media** · Equipo y roles: el dueño invita cajeros y administradores con un código; el cajero no cambia el catálogo. *09/11/2026*
- [ ] **Media** · Probar el equipo con dos cuentas reales: el dueño invita desde su celular y alguien se une desde otro.
- [x] **Media** · Invitar meseros y cocina. *09/11/2026*
- [ ] **Baja** · Validar en la base que solo el plan Negocio pueda invitar (hoy solo lo limita la app, con la vista previa).
- [ ] **Baja** · Impresora térmica Bluetooth o USB.
- [ ] **Baja** · Límite de crédito por cliente y alertas de vencimiento (plan Negocio).
- [ ] **Baja** · Reportes de margen de ganancia y costos de proveedores.

## Etapa 4 · Planes y cobro
- [ ] **Media** · Confirmar los límites exactos de cada plan contra el PDF (la tabla salió desordenada al leerla).
- [ ] **Media** · Validar los límites también en la base de datos (triggers), no solo en la app.
- [ ] **Media** · Cobro real de suscripciones y quitar el selector de "vista previa" de planes.
- [ ] **Alta** · Pasar proyecto-Gavilan a plan Pro de Supabase antes de tener clientes: el gratis se pausa tras 7 días sin actividad. Ya pasó una vez (09/11/2026) y se reactivó a mano; mientras está pausado, ningún teléfono respalda.

## Etapa 5 · Panel web (Next.js)
- [ ] **Baja** · Definir el alcance mínimo: reportes, catálogo tipo Excel y cobro con lector USB.
- [ ] **Baja** · Crear el proyecto conectado al mismo Supabase.

## Seguridad y ajustes de base de datos
- [ ] **Media** · Activar en Supabase Auth la protección contra contraseñas filtradas (Authentication → Policies). Es un ajuste de seguridad del panel; lo hace el dueño del proyecto.
- [ ] **Media** · Que los meseros no vean el costo de los productos (vista sin `cost`).
- [ ] **Media** · Que el rol cocina solo pueda cambiar el estado de los pedidos, no otros campos.
- [ ] **Baja** · Revisar los 3 avisos "WARN" de Supabase cuando cambie el esquema. Hoy son intencionales; ver [BASE_DE_DATOS.md](BASE_DE_DATOS.md).

## Diseño
- [x] **Baja** · Gavilán nuevo (ilustración de Flow) en el inicio, la bienvenida y el encabezado. *01/11/2026*
- [x] **Baja** · Icono de la app: la cabeza del gavilán sobre óxido, en Android (adaptable) e iPhone. *01/11/2026*
- [ ] **Baja** · Tema oscuro.
- [x] **Baja** · Diseñar comandera y pantalla de cocina. *09/11/2026*

## Proyecto 1 · Directorio (otro repositorio)
Mejoras acordadas en el PDF, pendientes en el repositorio del Directorio:
- [ ] Portada: quitar el doble buscador, tipografía sans-serif y tarjetas flotantes.
- [ ] Carrusel publicitario con arte para escritorio (1440×450) y móvil (1080×1080 o 1080×1350).
- [ ] SMTP propio (Resend o Brevo) en Supabase Auth.
- [ ] Monitor (UptimeRobot) para evitar el arranque en frío de Render.
- [ ] Reglas del piloto de repartidores: cuota $0, mensaje por WhatsApp y tope de $100 en efectivo.
