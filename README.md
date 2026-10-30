# Sistema de Registro y Gestión del Mundial de Fútbol

Trabajo práctico de Bases de Datos Aplicadas, Universidad Nacional de La Matanza. Comisión 01-2900, Grupo 11.

Este documento explica cómo crear la base de datos `MundialFutbol` en SQL Server.

## Requisitos

- SQL Server. Los scripts se probaron en SQL Server 2022 Developer.
- SQL Server Management Studio (SSMS) o la herramienta de línea de comandos `sqlcmd`.
- Un usuario con permiso para crear bases de datos.

## Archivos

| Archivo | Contenido |
|---|---|
| `01_CreacionBaseYEsquemas.sql` | Crea la base `MundialFutbol` y sus 6 esquemas. |
| `02_CreacionTablas.sql` | Crea las 36 tablas con sus restricciones e índices. |
| `DER.sql` | Versión simplificada para generar el DER. **No se ejecuta en SQL Server.** |
| `schema.png` | Imagen del diagrama entidad-relación. |

Los scripts se ejecutan en el orden que indica su número.

## Crear la base de datos

### Con SSMS

1. Conectate a tu instancia de SQL Server.
2. Abrí `01_CreacionBaseYEsquemas.sql` y ejecutalo con **F5**.
3. Abrí `02_CreacionTablas.sql` y ejecutalo con **F5**.

Cada script selecciona la base por su cuenta, así que no hace falta elegirla en el desplegable.

### Con sqlcmd

Abrí una terminal en la carpeta del repositorio y ejecutá:

```powershell
sqlcmd -S . -E -C -b -i 01_CreacionBaseYEsquemas.sql
sqlcmd -S . -E -C -b -i 02_CreacionTablas.sql
```

- `-S .` usa la instancia predeterminada del equipo. Para una instancia con nombre, cambiala, por ejemplo por `-S .\SQLEXPRESS`.
- `-E` entra con tu usuario de Windows. Para usar un login de SQL Server, reemplazalo por `-U usuario -P contraseña`.
- `-C` confía en el certificado del servidor.
- `-b` detiene el script ante el primer error.

## Verificar la instalación

Ejecutá esta consulta:

```sql
USE MundialFutbol;

SELECT s.name AS esquema, COUNT(*) AS tablas
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
GROUP BY s.name
ORDER BY s.name;
```

Si todo salió bien, el resultado suma 36 tablas:

| esquema | tablas |
|---|---|
| arbitraje | 4 |
| competencia | 11 |
| externo | 3 |
| maestro | 5 |
| plantel | 5 |
| publicidad | 8 |

## Volver a ejecutar los scripts

Los dos scripts se pueden ejecutar más de una vez: lo que ya existe se saltea y los datos cargados no se pierden.

Por eso, **un cambio en la definición de una tabla existente no se aplica al reejecutar**. Para aplicarlo hay que recrear la base.

> **Atención:** esto borra la base y todos sus datos.

```sql
USE master;

ALTER DATABASE MundialFutbol SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE MundialFutbol;
```

Después, ejecutá de nuevo los scripts en orden.

## Problemas frecuentes

| Mensaje | Causa | Solución |
|---|---|---|
| `Database 'MundialFutbol' does not exist` | Se ejecutó `02` antes que `01`. | Ejecutá primero `01_CreacionBaseYEsquemas.sql`. |
| `'sqlcmd' is not recognized` | `sqlcmd` no está instalado o no está en el `PATH`. | Instalalo o usá SSMS. |
| `A network-related or instance-specific error` | El nombre de la instancia es incorrecto o el servicio está detenido. | Revisá el valor de `-S` y que el servicio de SQL Server esté iniciado. |
