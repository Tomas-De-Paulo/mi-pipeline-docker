# 🚀 Pipeline ETL con Docker Compose

Pipeline **Extract → Transform → Load** totalmente contenedorizado: lee un CSV "sucio",
valida y normaliza cada registro, carga el resultado en PostgreSQL y genera un reporte
JSON con KPIs de negocio.

El objetivo no es el volumen de datos (son 8 filas), sino **replicar la estructura, los
flujos y las prácticas de un proyecto real**: orquestación declarativa, base de datos
con inicialización automática, dependencias sanas entre servicios y manejo de datos sucios.

---

## 🏗 Arquitectura

```
┌──────────────────────┐
│       pgAdmin 4      │  UI de administración
│   localhost:8080     │
└──────────┬───────────┘
           │
┌──────────▼───────────┐     ┌──────────────────────────┐
│     PostgreSQL 16    │◄────│      ETL (Python)        │
│   localhost:5432     │     │  extract → transform     │
│                      │     │      → load → report     │
│  init automático:    │     └──────────┬───────────────┘
│  init-db/schema.sql  │                │
└──────────────────────┘     ┌──────────▼───────────────┐
                             │  data/ventas_raw.csv     │
                             │  output/reporte.json     │
                             └──────────────────────────┘

depends_on: condition: service_healthy  →  el ETL nunca arranca antes
 de que PostgreSQL acepte conexiones
```

---

## 🛠 Stack

| Componente       | Tecnología |
|------------------|-----------------------------------------|
| Orquestación     | Docker Compose (3 servicios)           |
| Base de datos    | PostgreSQL 16                          |
| Administración   | pgAdmin 4                              |
| Motor ETL        | Python 3.12 + `psycopg2`               |
| Persistencia     | Volumen nombrado (`pgdata`)            |
| Intercambio      | CSV → JSON                             |

---

## 🚀 Inicio rápido

**Prerrequisitos:** Docker Desktop (o Docker Engine + Compose plugin). No necesitas Python
ni PostgreSQL instalados en tu máquina.

```bash
git clone https://github.com/Tomas-De-Paulo/mi-pipeline-docker.git
cd mi-pipeline-docker

# 1. Levantar la infraestructura
docker compose up -d

# 2. Ejecutar el pipeline
docker compose run --rm etl
```

Salida esperada:

```
==================================================
Pipeline ETL iniciado
==================================================
[OK] PostgreSQL listo (intento 1)

Extrayendo datos del CSV...
   Filas leidas: 8

Limpiando y transformando datos...
  [AVISO] Fila 2: cantidad vacia o no numerica
  [AVISO] Fila 6: cantidad invalida (-1)
  Filas validas: 6

Cargando en PostgreSQL...
  Filas insertadas: 6

Generando reporte...
Reporte generado: {...}

[OK] Pipeline completo exitosamente!
==================================================
```

### Accesos

| Servicio | URL / Host | Credenciales |
|----------|------------|--------------|
| pgAdmin  | http://localhost:8080 | `admin@datos.com` / `admin123` |
| PostgreSQL | `localhost:5432` | `etl_user` / `etl_secreto` / db `ventas` |

### Detener / limpiar

```bash
docker compose down      # detiene los contenedores, conserva los datos
docker compose down -v   # detiene y borra el volumen (empezar de cero)
```

---

## 📁 Estructura

```
mi-pipeline-docker/
├── docker-compose.yml       # Orquestación de los 3 servicios
├── Dockerfile               # Imagen del ETL (python:3.12-slim)
├── requirements.txt         # psycopg2-binary
├── etl/
│   └── pipeline.py          # Extract → Transform → Load → Report
├── init-db/
│   └── schema.sql           # Se ejecuta solo en el primer arranque
├── data/
│   └── ventas_raw.csv       # Origen (8 filas, 2 inválidas)
└── output/
    └── reporte.json         # KPIs generados
```

---

## 🔄 Etapas del pipeline

| Etapa | Función | Qué hace |
|-------|---------|----------|
| **Extract** | `leer_csv()` | Lee el CSV crudo a memoria |
| **Transform** | `limpiar_fila()` | Valida, normaliza y descarta registros |
| **Load** | `cargar_en_postgres()` | Inserta en una sola transacción (`commit`) |
| **Report** | `generar_reporte()` | Agrega KPIs y escribe `reporte.json` |

Además, `esperar_postgres()` actúa como **retry con backoff**: intenta conectar hasta
10 veces (2 s entre intentos) antes de rendirse.

---

## 🧹 Calidad de datos

El CSV de entrada incluye errores intencionales para ejercitar las validaciones:

| Regla | Ejemplo inválido | Resultado |
|-------|------------------|-----------|
| `cantidad` numérica y > 0 | `""`, `-1` | Fila descartada |
| `precio_unitario` ≥ 0 | `"N/A"` | Fila descartada |
| `fecha` parseable | `"32/13/2024"` | Fila descartada |
| Formato de fecha mixto | `15/01/2024` | Normalizado a `2024-01-15` |
| `cliente` no vacío | `""` | Default → `"Desconocido"` |

**De 8 filas crudas se aceptan 6.** Además, la base de datos refuerza las reglas con
constraints (`NOT NULL`, `CHECK (cantidad > 0)`, `DECIMAL(10,2)`).

---

## 📊 Reporte generado

```json
{
    "total_filas": 6,
    "total_ventas": 7847.43,
    "top_ciudad": {
        "nombre": "Madrid",
        "total": 6659.93
    }
}
```

---

## ⚙️ Configuración

Variables de entorno del servicio `etl` (definidas en `docker-compose.yml`):

| Variable | Default | Descripción |
|----------|---------|-------------|
| `DB_HOST` | `postgres` | Host de PostgreSQL (nombre del servicio en la red de Docker) |
| `DB_PORT` | `5432` | Puerto |
| `DB_USER` | `etl_user` | Usuario |
| `DB_PASS` | `etl_secreto` | Contraseña |
| `DB_NAME` | `ventas` | Base de datos |

---

## 🐛 Troubleshooting

### pgAdmin: `Connection refused` en `127.0.0.1:5432`

Es el error más común al trabajar con pgAdmin en Docker. pgAdmin corre **dentro** de un
contenedor, así que `localhost` para él es su propio contenedor, no tu máquina.

✅ **Solución:** en *Add New Server* usa como **Host name/address → `postgres`**
(el nombre del servicio, que Docker resuelve por DNS en la red compartida).

Si usas la app de pgAdmin instalada en tu escritorio, entonces sí `localhost` es correcto.

### El CSV no se actualiza tras editarlo

Está montado como volumen. En Windows, si no ves el cambio:

```bash
docker compose down -v && docker compose up -d
```

### `schema.sql` no se ejecuta

Los scripts de `init-db/` **solo corren cuando el volumen está vacío**. Tras modificarlo,
usa `docker compose down -v`.

---

## ⚠️ Limitaciones conocidas

Este es un proyecto de aprendizaje. Puntos que en un entorno real habría que resolver:

- **No es idempotente**: cada ejecución vuelve a insertar las filas. Se resolvería con `TRUNCATE`, clave natural `UNIQUE` o tabla de staging.
- **Credenciales en el código**: deberían venir de un `.env` o un secret manager.
- **Una sola ejecución**: sin reintento por lote ni checkpointing ante fallos parciales.
- **Logging con `print()`**: en producción se usaría logging estructurado (JSON).

---

## 📚 Aprendizajes

1. **Healthchecks + `depends_on: condition: service_healthy`** — el orden de arranque no es
   un `sleep`, es una garantía.
2. **Inicialización declarativa de la BD** — montar `schema.sql` en
   `/docker-entrypoint-initdb.d` elimina pasos manuales.
3. **Configuración por red, no por localhost** — dentro de Docker los servicios se hablan
   por nombre.
4. **La calidad de datos empieza antes de la base de datos** — validar en el `Transform`
   desperdicia menos trabajo que insertar y luego limpiar.

---

## 📄 Licencia

MIT

---

<div align="center">
  <sub>Hecho con 🧉 como parte de mi camino a Data Engineering</sub>
</div>