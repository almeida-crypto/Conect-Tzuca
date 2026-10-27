# PROYEC-INVEN · Ecosistema comercial Tzucacab

Carpeta de trabajo del **Proyecto 2: Gavilán**, el sistema POS y de administración para negocios locales. La idea base está en el PDF *Ecosistema Comercial y Sistema POS Local - Documentación Maestra*, que se guarda solo en la copia local (no se sube porque el repositorio es público).

Repositorio: https://github.com/almeida-crypto/Conect-Tzuca

El **Proyecto 1 (Directorio Tzucacab)** vive en otro repositorio y en otro proyecto de Supabase. Esta carpeta no lo toca.

## Estado al 20 de octubre de 2026

| Pieza | Estado |
|---|---|
| Base de datos en Supabase (proyecto-Gavilan) | Aplicada: 21 tablas con RLS, 2 migraciones |
| Identidad visual (gavilán, paleta, inicio animado) | Aprobada por ahora; se puede ajustar después |
| App Flutter: Cobrar, Fiados, Inventario, Caja, Más | Funciona con datos de ejemplo en memoria |
| Guardar datos en el teléfono y sincronizar | Pendiente |
| Inicio de sesión y alta de negocio | Pendiente |
| Módulos extra (apartados, lotes, tandas, restaurante) | Pendiente |
| Panel web (Next.js) | Pendiente, no iniciado |

## Documentación

| Archivo | Para qué sirve |
|---|---|
| [docs/BITACORA.md](docs/BITACORA.md) | Qué se hizo, en orden, y por qué |
| [docs/PENDIENTES.md](docs/PENDIENTES.md) | Lista de control de lo que falta, por etapas |
| [docs/DECISIONES.md](docs/DECISIONES.md) | Decisiones técnicas y de producto ya tomadas |
| [docs/BASE_DE_DATOS.md](docs/BASE_DE_DATOS.md) | Esquema de Supabase, roles y seguridad |
| [docs/DISENO.md](docs/DISENO.md) | Paleta, tipografía, el gavilán y el inicio animado |
| [gavilan_app/README.md](gavilan_app/README.md) | Cómo correr, probar y organizar la app Flutter |

## Carpetas

| Carpeta | Contenido |
|---|---|
| `gavilan_app/` | App Flutter (Android, iOS y web) |
| `pos-backend/supabase/migrations/` | Migraciones SQL aplicadas en proyecto-Gavilan |
| `design-lab/` | Laboratorio de diseño: maqueta HTML, generador del gavilán y servidor local |
| `docs/` | Esta documentación |

## Comandos frecuentes

Correr la app (desde `gavilan_app/`):

```bash
flutter run
```

Pruebas de la app (desde `gavilan_app/`):

```bash
flutter test
```

Regenerar el gavilán después de editar `design-lab/hawk-build.js` (desde la raíz):

```bash
node design-lab/export-hawk.js
```

Ver la maqueta HTML en `http://localhost:4173/mockup.html` (desde la raíz):

```bash
node design-lab/server.js
```
