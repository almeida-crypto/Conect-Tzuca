# Respuestas para los formularios de Play Console (Contenido de la app)

## Política de privacidad
URL pública de `web/privacidad.html`.

## Acceso a la app
"Toda la funcionalidad está disponible sin acceso especial" **no** aplica del todo, porque el respaldo en la nube y el
equipo piden cuenta. Elige **"Toda o parte de la funcionalidad está restringida"** y escribe:

> La app funciona completa sin cuenta: en la primera pantalla toque "Probar con una tiendita de ejemplo" para ver un
> negocio con productos, ventas, fiados y caja. El respaldo en la nube y el equipo necesitan una cuenta: use el
> usuario de prueba indicado (correo y contraseña).

Crea tú una cuenta de prueba para los revisores (un correo tuyo de pruebas) y pon el correo y la contraseña en el
formulario. Deja ese negocio en plan Negocio desde Supabase para que vean todo.

## Anuncios
**No**, la app no tiene anuncios.

## Clasificación del contenido
- Categoría: **Utilidad, productividad, comunicación u otra**.
- Violencia, sexo, lenguaje, drogas, apuestas: **No** a todo.
- ¿Los usuarios pueden interactuar o compartir contenido entre sí? **No** (el equipo comparte solo los datos de su
  propio negocio; no hay chat ni contenido público).
- ¿Comparte la ubicación? **No**. ¿Compras digitales? **No**.
- Resultado esperado: **Para todos (IARC 3+)**.

## Público objetivo
- Edad: **18 años o más** únicamente. No está dirigida a niños.

## Apps de noticias / gobierno / salud / préstamos
- Noticias: **No**. Gobierno: **No**. Salud: **No**.
- Funciones financieras: **la app no ofrece funciones financieras** (registra ventas y fiados del propio negocio; no
  presta dinero, no hace pagos, no es banco).

## Eliminación de cuentas
- ¿La app permite crear cuentas? **Sí**.
- Enlace para pedir la eliminación: URL pública de `web/borrar-cuenta.html`.
- Dentro de la app: Más → Cuenta y respaldo → Borrar mi cuenta.

## Seguridad de los datos
**¿Recopila o comparte datos?** Sí, recopila. **No** los comparte con terceros (Supabase es proveedor de servicio que
guarda los datos por nosotros; eso no cuenta como "compartir").

- ¿Los datos están cifrados en tránsito? **Sí**.
- ¿Los usuarios pueden pedir que se borren? **Sí**.

| Tipo de dato | ¿Se recopila? | ¿Obligatorio? | Para qué |
|---|---|---|---|
| Información personal → **Dirección de correo** | Sí | Opcional (solo con cuenta) | Funcionalidad de la app, administración de la cuenta |
| Información personal → **Nombre** | Sí | Opcional | Funcionalidad de la app (clientes de fiado y apartados, nombre del equipo) |
| Información personal → **Número de teléfono** | Sí | Opcional | Funcionalidad de la app (teléfono de clientes y proveedores) |
| Información financiera → **Otra información financiera** | Sí | Opcional | Funcionalidad de la app (ventas, fiados y caja del negocio) |
| Fotos y videos → **Fotos** | Sí | Opcional | Funcionalidad de la app (fotos de productos, apartados y logo) |

No recopila: ubicación, contactos, mensajes, audio, archivos, calendario, salud, historial web, identificadores de
publicidad, diagnósticos ni actividad en la app.

Para cada dato: **no** se procesa de forma efímera; **no** se comparte; se usa solo para la funcionalidad de la app.

## Permisos
- **Cámara**: leer códigos de barras y tomar fotos de productos (solo cuando el usuario la abre).
- **Internet**: respaldo en la nube.
