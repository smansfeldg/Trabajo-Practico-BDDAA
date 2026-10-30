-- =====================================================================
-- Universidad : Universidad Nacional de La Matanza
-- Materia     : Bases de Datos Aplicadas
-- Comision    : 01-2900   Grupo: 11
-- Integrantes : Santiago Ariel Mansfeld, Agustin Pes Gabriel, Camilo Santiago Manzi.
-- Fecha       : 30/10/2026
-- Objetivo    : Crear la base de datos del Sistema de Registro y Gestion
--               del Mundial de Futbol y sus esquemas. Ejecutar antes que
--               02_CreacionTablas.sql. Puede reejecutarse sin perder datos.
-- =====================================================================

IF DB_ID(N'MundialFutbol') IS NULL
    CREATE DATABASE MundialFutbol;
GO

USE MundialFutbol;
GO

-- CREATE SCHEMA debe ser la primera instruccion de su lote y no admite IF.
-- SET NOEXEC saltea el lote cuando el esquema ya existe, sin SQL dinamico.

-- Catalogos generales: confederaciones, paises, torneos, fases y sedes.
IF SCHEMA_ID(N'maestro') IS NOT NULL SET NOEXEC ON;
GO
CREATE SCHEMA maestro;
GO
SET NOEXEC OFF;
GO

-- Selecciones, jugadores, convocatorias y cuerpos tecnicos.
IF SCHEMA_ID(N'plantel') IS NOT NULL SET NOEXEC ON;
GO
CREATE SCHEMA plantel;
GO
SET NOEXEC OFF;
GO

-- Partidos, alineaciones, eventos y suspensiones.
IF SCHEMA_ID(N'competencia') IS NOT NULL SET NOEXEC ON;
GO
CREATE SCHEMA competencia;
GO
SET NOEXEC OFF;
GO

-- Arbitros, designaciones y antecedentes.
IF SCHEMA_ID(N'arbitraje') IS NOT NULL SET NOEXEC ON;
GO
CREATE SCHEMA arbitraje;
GO
SET NOEXEC OFF;
GO

-- Mercados, anunciantes, campanias, piezas y pauta por partido.
IF SCHEMA_ID(N'publicidad') IS NOT NULL SET NOEXEC ON;
GO
CREATE SCHEMA publicidad;
GO
SET NOEXEC OFF;
GO

-- Indicadores obtenidos de fuentes externas.
IF SCHEMA_ID(N'externo') IS NOT NULL SET NOEXEC ON;
GO
CREATE SCHEMA externo;
GO
SET NOEXEC OFF;
GO
