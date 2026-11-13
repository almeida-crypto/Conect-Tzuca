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
- [x] **Media** · Primer uso: con el negocio vacío, Cobrar e Inventario muestran "Agrega tus primeros productos": elegir de una lista de ~65 productos comunes de tiendita (se marca y se pone precio), agregar uno por uno o pegar desde Excel (computadora). *12/11/2026*
- [x] **Media** · Un código de barras desconocido (lector USB o tecleado) ofrece "Darlo de alta" y lo agrega a la cuenta al guardarlo. *12/11/2026*
- [ ] **Baja** · Listas de inicio para otros giros (fonda, papelería, ferretería, farmacia).
- [x] **Media** · En el navegador los datos se guardan (`sqlite3.wasm` y `drift_worker.js` en `web/`) y se respaldan en Supabase igual que en el celular. *11/11/2026*
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
- [x] **Alta** · Ventas del turno (lista con cada ticket) y cancelar una venta del turno abierto: regresa al inventario, deja de contar en la caja y la ganancia, y si fue fiada le quita la deuda al cliente. Solo dueño y administradores. *12/11/2026*
- [x] **Media** · Devolver solo una parte de una venta: se cancela la original y queda una venta nueva con lo que se quedó el cliente. *12/11/2026*
- [x] **Media** · Descuento a la cuenta al cobrar (porcentaje o pesos), en el ticket y repartido en la ganancia. *12/11/2026*
- [ ] **Baja** · Cancelar o devolver ventas de turnos ya cerrados (con su ajuste en el siguiente corte).

## Etapa 3 · Módulos por giro
- [x] **Media** · Apartados: anticipo, abonos, fecha límite con aviso de vencido, liquidación automática, cancelación y comprobante por WhatsApp. *31/10/2026*
- [ ] **Media** · Foto del artículo apartado (cámara + Supabase Storage).
- [x] **Media** · Pacas y lotes: inversión, ventas rápidas, barra de recuperación y ganancia; entra al corte. El plan gratis permite 1 paca activa. *31/10/2026*
- [x] **Media** · Pedidos por tanda: entrega y pago en dos toques, insumos, ganancia y aviso por WhatsApp. *31/10/2026*
- [ ] **Baja** · Decidir si lo cobrado de las tandas entra al corte de caja (hoy no entra: muchas tandas se cobran fuera del mostrador).
- [x] **Media** · Restaurante: mesas, comandas, pantalla de cocina al instante (Realtime), para llevar y cobro por mesa. Meseros y cocina se invitan al equipo y la app les abre directo en mesas o cocina. *09/11/2026*
- [ ] **Media** · Probar el restaurante con dos celulares reales (mesero y cocina) para medir cuánto tarda en llegar la comanda.
- [x] **Media** · Zonas de mesas (Planta baja, Segunda planta, Terraza): cada zona con su numeración, mesas agrupadas y nombre completo en cocina. *11/11/2026*
- [x] **Baja** · Restaurante: pasar una cuenta a otra mesa libre y poner la mesa en el ticket. *12/11/2026*
- [ ] **Baja** · Restaurante: dividir la cuenta e imprimir la comanda en cocina.
- [x] **Media** · Extras con precio (extra queso +\$10): el dueño los da de alta, el mesero los elige en cada platillo, salen en cocina y se cobran. *13/11/2026*
- [ ] **Baja** · Platillos que no se venden en mostrador (que solo salgan en el restaurante).
- [x] **Media** · Equipo y roles: el dueño invita cajeros y administradores con un código; el cajero no cambia el catálogo. *09/11/2026*
- [ ] **Media** · Probar el equipo con dos cuentas reales: el dueño invita desde su celular y alguien se une desde otro.
- [x] **Media** · Invitar meseros y cocina. *09/11/2026*
- [ ] **Baja** · Validar en la base que solo el plan Negocio pueda invitar (hoy solo lo limita la app, con la vista previa).
- [ ] **Baja** · Impresora térmica Bluetooth o USB.
- [ ] **Baja** · Límite de crédito por cliente y alertas de vencimiento (plan Negocio).
- [x] **Media** · Ganancia por producto en el corte (vendido, precio, costo, ganancia y margen), para dueño y administradores. También en los cortes anteriores. *12/11/2026*
- [ ] **Baja** · Ganancia por producto en el panel web y por rango de fechas; costos por proveedor.

## Etapa 4 · Planes y cobro
- [ ] **Media** · Confirmar los límites exactos de cada plan contra el PDF (la tabla salió desordenada al leerla).
- [ ] **Media** · Validar los límites también en la base de datos (triggers), no solo en la app. Se hace junto con el cobro real: hoy la vista previa deja probar Negocio y en la base todos son plan gratis, así que los triggers trabarían el respaldo de quien prueba.
- [ ] **Media** · Cobro real de suscripciones y quitar el selector de "vista previa" de planes.
- [ ] **Alta** · Pasar proyecto-Gavilan a plan Pro de Supabase antes de tener clientes: el gratis se pausa tras 7 días sin actividad. Ya pasó una vez (09/11/2026) y se reactivó a mano; mientras está pausado, ningún teléfono respalda.

## Etapa 5 · Panel web (Next.js)
- [x] **Media** · Panel web (`panel-web/`, Next.js 16) conectado al mismo Supabase, con reportes de ventas: cifras con comparación, ventas por día y por hora, formas de pago, lo más vendido, cortes, quién debe y por acabarse. Tiene datos de ejemplo. *11/11/2026*
- [ ] **Media** · Que el usuario entre al panel con su cuenta y revise sus números reales.
- [ ] **Media** · Publicar el panel en Vercel. Necesita que el usuario cree una cuenta gratuita.
- [x] **Media** · Catálogo tipo Excel: "Editar en tabla" en Inventario (computadora). Cambia nombre, código, precio, costo, existencia y mínimo de muchos productos; da de alta renglones nuevos y se puede pegar desde Excel. *12/11/2026*
- [ ] **Baja** · Panel: descargar los reportes en Excel o PDF, elegir un rango de fechas libre y reportes por cajero o por teléfono.
- [x] **Media** · Mostrador en la computadora: la misma app abierta en el navegador cobra, fía, lleva inventario, caja, mesas y equipo. Menú a la izquierda, la cuenta siempre a la derecha y lector láser USB sin tocar nada. *11/11/2026*
- [ ] **Media** · Publicar el mostrador web (la app compilada con `flutter build web`) junto al panel, por ejemplo en `/mostrador`.
- [x] **Media** · Mostrador web: atajos de teclado (F2, Esc, + y −, F3, F1, escribir sin dar clic) y cobrar escribiendo el monto con Enter. *12/11/2026*
- [x] **Media** · Imprimir el ticket desde el navegador (botón, P o Ctrl+P), con la impresora de tickets o cualquiera instalada. *12/11/2026*
- [ ] **Media** · Probar la impresión con una impresora térmica real (58 y 80 mm) y ajustar márgenes si hace falta.
- [ ] **Baja** · Opción "imprimir siempre al cobrar" en la computadora.
- [ ] **Baja** · Tabla del catálogo: elegir el icono y ocultar productos desde la tabla.

## Seguridad y ajustes de base de datos
- [ ] **Media** · Activar en Supabase Auth la protección contra contraseñas filtradas (Authentication → Policies). Es un ajuste de seguridad del panel; lo hace el dueño del proyecto.
- [x] **Media** · Que meseros y cocina no vean el costo de compra (migración 0008, `pull_products`). Se probó en la base con un dueño y un mesero simulados. *12/11/2026*
- [ ] **Media** · Los meseros con una versión vieja de la app (antes del 12/11/2026) ya no bajan productos: hay que actualizarles la app.
- [x] **Media** · La cocina solo cambia el estado de los platillos: no abre ni cambia cuentas ni agrega platillos (migración 0009). Probado en la base con mesero y cocina simulados. *12/11/2026*
- [ ] **Baja** · Revisar los 3 avisos "WARN" de Supabase cuando cambie el esquema. Hoy son intencionales; ver [BASE_DE_DATOS.md](BASE_DE_DATOS.md).

## Diseño
- [x] **Baja** · Gavilán nuevo (ilustración de Flow) en el inicio, la bienvenida y el encabezado. *01/11/2026*
- [x] **Baja** · Icono de la app: la cabeza del gavilán sobre óxido, en Android (adaptable) e iPhone. *01/11/2026*
- [x] **Alta** · Límites de números reales en todos los campos (dinero hasta \$999,999.99 con 2 decimales, cantidades hasta 99,999 con 3, nombres y códigos con largo máximo) y también en la base (migración 0011). *12/11/2026*
- [x] **Media** · Letra Manrope en la app y el panel; pantalla de planes rediseñada con tarjetas redondeadas y sin prometer lo que aún no existe. *12/11/2026*
- [ ] **Baja** · Tema oscuro.
- [x] **Baja** · Diseñar comandera y pantalla de cocina. *09/11/2026*

## Proyecto 1 · Directorio (otro repositorio)
Mejoras acordadas en el PDF, pendientes en el repositorio del Directorio:
- [ ] Portada: quitar el doble buscador, tipografía sans-serif y tarjetas flotantes.
- [ ] Carrusel publicitario con arte para escritorio (1440×450) y móvil (1080×1080 o 1080×1350).
- [ ] SMTP propio (Resend o Brevo) en Supabase Auth.
- [ ] Monitor (UptimeRobot) para evitar el arranque en frío de Render.
- [ ] Reglas del piloto de repartidores: cuota $0, mensaje por WhatsApp y tope de $100 en efectivo.
