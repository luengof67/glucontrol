# GluControl 10

Control de diabetes para **Android y Windows** (Flutter), con los datos
sincronizados entre dispositivos mediante Firebase.

Sustituye a las versiones HTML (v4 de este repo y v9.2 del repo `Glucosa`), que
quedan guardadas en `legacy/` como referencia.

## Qué hace

| Pantalla | Contenido |
|---|---|
| Inicio | Última medida, huecos del día por momento, media de hoy, tiempo en rango, HbA1c, peso, gráfica 7/30 días, observaciones, medicación del día con casillas, comidas y próximas citas. Avisos de bajada/subida y de "llevas X h sin medir". |
| Glucemia | Historial agrupado por día, filtro por momento, alta y **edición**. Al apuntar una bajada muestra la regla del 15. |
| Estadísticas | 7/14/28/90 días: media, tiempo en rango en 5 bandas (consenso internacional), variabilidad (CV), HbA1c estimada (GMI), perfil del día, media por momento, evolución diaria y semanal, observaciones automáticas. |
| HbA1c | Resultados, evolución, comparación con la estimada. |
| Alimentación | Diario con hidratos, calorías e IG. **Foto del plato analizada por IA**. Al lado de cada comida, la glucosa de después. |
| Comida y glucosa | Cruza comidas y glucemias (antes / 1-3 h después): subida media por IG y por comida del día, y las comidas que más te suben. |
| Peso y tensión | Registros, IMC, peso objetivo con progreso, gráficas. |
| Medicación | Stock con días restantes, tomas de hoy por horario (casillas), reponer, deshacer toma, **aviso a cada hora de toma**. |
| Recordatorios | Por días de la semana; notificaciones en Android y en Windows. |
| Citas, Informes, Emergencias | Citas próximas/pasadas; informes con foto y buscador; contactos con llamada y WhatsApp con tus datos, botón 112. |
| Asistente IA | Análisis rápidos y chat con Claude sobre tus datos (clave propia de Anthropic). |
| Ajustes | Perfil y objetivos, **informe PDF para el médico**, copia JSON, CSV para Excel, importar copias antiguas, clave de la IA. |

## Puesta en marcha (una sola vez)

### 1. Reglas de Firebase

GluControl usa el mismo proyecto Firebase que ComparaPrecios
(`comparaprecio-a1191`) y la misma cuenta, pero guarda sus datos aparte, en
`glucontrol/{uid}/…`. Para que **solo tú** puedas leerlos, añade esto dentro
de `match /databases/{database}/documents { … }` en *Firestore → Reglas* de la
consola de Firebase, y publica:

```
match /glucontrol/{uid}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
```

(Las reglas tienen que empezar por `rules_version = '2';`, que es lo normal.)
Si falta la regla, la app avisa arriba con "Sin sincronizar".

### 2. Firma del APK

En *Settings → Secrets and variables → Actions* de este repo, copia los 4
Secrets de ComparaPrecios: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`,
`KEY_PASSWORD`, `KEY_ALIAS`. Sin ellos el APK sale con firma de depuración y
cada versión nueva obliga a desinstalar la anterior.

### 3. Traer los datos de la versión HTML

En el navegador donde usabas GluControl: *Ajustes / Copia de seguridad →
Exportar* (v4) o *Backup* (v9). Luego en la app nueva: *Ajustes → Importar
copia*. Se puede importar más de una vez sin duplicar.

## Compilar

Pestaña **Actions** de GitHub:

- **Build Android (APK)** → artefacto `glucontrol-apk` (`GluControl.apk`).
- **Build (Windows escritorio)** → artefacto `glucontrol-windows`
  (`GluControl-windows.zip`: descomprimir y abrir `glucontrol.exe`).

También se lanzan al crear un tag `v*` (APK) o `win-v*` (Windows).

## Notas técnicas

- Datos en Firestore, escuchados en tiempo real; copia local en un archivo para
  abrir sin conexión. En Windows la app usa una instancia de Firebase con nombre
  propio y sin persistencia de Firestore (mismo arreglo que ConsultaPrecios,
  incluido el parche del plugin en el workflow).
- Notificaciones con `flutter_local_notifications`: en Android se repiten solas;
  en Windows se programan los 7 días siguientes cada vez que se abre la app.
- La clave de Anthropic se guarda cifrada en cada dispositivo
  (`flutter_secure_storage`), nunca en Firebase.
- Las fotos (informes) se reducen a JPEG y van dentro del propio registro.
- Las observaciones automáticas y el asistente son orientativos; no sustituyen
  al médico.
