# Guía: de aquí a Google Play con la prueba cerrada

Google pide a las cuentas de desarrollador **personales** nuevas una **prueba cerrada con al menos 12 personas que
se queden inscritas 14 días seguidos** antes de dejar publicar en producción. Invita a **15 o 20** por si alguien se
sale. (Una cuenta de **organización**, con número D-U-N-S, no tiene este requisito.)

---

## Antes de invitar a nadie (lo que te toca a ti)

1. **Supabase de pago (Pro).** El plan gratis se pausa a los 7 días sin uso; si pasa durante la prueba, nadie
   respalda ni puede crear cuenta. Es lo más importante.
2. **Correo propio para las confirmaciones (Resend o Brevo).** El correo de Supabase solo manda unos pocos por hora:
   con 15 personas creando cuenta el mismo día, a varias no les llegará. Crea la cuenta y yo lo conecto.
3. **Un correo de contacto** para el aviso de privacidad y la página de borrar cuenta (cambia `CORREO_DE_CONTACTO`
   en los dos archivos de `web/`, o dime cuál y lo pongo).
4. **Publicar las dos páginas** (`web/privacidad.html` y `web/borrar-cuenta.html`) en una dirección pública. Lo más
   rápido: GitHub Pages del repositorio (te ayudo si me das el visto bueno), o Vercel cuando publiques la web.
5. **Decidir el plan de los probadores.** En la nube, un negocio nuevo empieza en Semilla (gratis): no verían
   apartados, mesas, compras ni equipo. Puedes subirles el plan a mano en Supabase (Table editor → businesses →
   plan = business) o pedirme que, mientras dure la prueba, los negocios nuevos empiecen en Negocio.

## 1. Cuenta de desarrollador
- En https://play.google.com/console regístrate como **personal**, paga los **25 USD** y verifica tu identidad
  (INE y, a veces, tu celular). La verificación puede tardar unos días.

## 2. Crear la app
- **Crear app** → Nombre "Gavilán · Punto de venta", idioma **Español (Latinoamérica)**, **App**, **Gratis**.
- **Firma de la app (importante):** cuando te pregunte por la clave de firma, elige **usar tu propia clave**
  ("Exportar y subir una clave desde un almacén de claves Java") y sigue sus pasos con `gavilan-upload.jks`.
  Así los amigos que ya instalaron los APK que te he mandado podrán actualizar desde Play sin desinstalar.
  Si dejas que Google genere una clave nueva, ellos tendrán que **desinstalar** primero; antes de hacerlo deben
  iniciar sesión y respaldar, o perderán lo que tengan solo en el celular.
- La contraseña del almacén de claves la escribes tú; no la pongas en ningún archivo del repositorio.

## 3. Contenido de la app y ficha
- Llena todo con lo que está en `formularios.md` (privacidad, acceso, anuncios, clasificación, público, seguridad
  de datos, eliminación de cuentas).
- **Ficha principal de Play Store:** textos de `ficha.md` y gráficos de `graficos/`.
- **Detalles de la app:** categoría Empresa y tu correo de contacto.

## 4. Prueba cerrada
1. **Pruebas → Prueba cerrada → Crear pista** (puede llamarse "Beta").
2. **Probadores:** crea una lista de correos (los correos de Gmail con los que tus probadores usan Play) o un Grupo
   de Google y agrégalo.
3. **Crear versión** → sube `Gavilan-1.14.0.aab` (está en esta carpeta) → notas de `ficha.md` → **Revisar y
   lanzar**. La primera revisión puede tardar de horas a unos días.
4. Cuando esté aprobada, copia el **enlace para unirse** y mándalo a tus probadores. Cada uno debe:
   - abrir el enlace con su cuenta de Gmail y tocar **"Quiero participar"**,
   - instalar Gavilán desde Play con ese enlace,
   - **no salirse** de la prueba durante los 14 días, y usarla de verdad (Google pregunta cómo la usaron).
5. Pídeles comentarios por un grupo de WhatsApp o en Play (sección de comentarios privados para probadores).

## 5. Durante los 14 días
- Si arreglamos algo, yo subo la versión (`versionCode` siempre mayor) y tú la subes a la misma pista; no se
  reinician los 14 días.
- Cuenta cuántos siguen inscritos en **Prueba cerrada → Probadores**; deben ser al menos 12 todo el tiempo.

## 6. Pedir producción
- Después de 14 días con 12 o más, aparece **"Solicitar acceso a producción"**. Contesta las preguntas (quiénes
  probaron, qué comentaron, qué cambiaste). Con la aprobación ya puedes publicar para todos.

## Para después (antes de cobrar los planes)
- Si los planes se van a pagar **dentro de la app**, Google exige su sistema de cobro (Google Play Billing), con su
  comisión. Hay que decidir cómo cobrar antes de activar pagos; mientras la app no tenga botón de pago, no aplica.
