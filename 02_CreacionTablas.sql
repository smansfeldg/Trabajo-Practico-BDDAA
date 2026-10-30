-- =====================================================================
-- Universidad : Universidad Nacional de La Matanza
-- Materia     : Bases de Datos Aplicadas
-- Comision    : 01-2900   Grupo: 11
-- Integrantes : Santiago Ariel Mansfeld, Agustin Pes Gabriel, Camilo Santiago Manzi.
-- Fecha       : 30/10/2026
-- Objetivo    : Crear todas las tablas y restricciones del Sistema de
--               Registro y Gestion del Mundial de Futbol. Requiere haber
--               ejecutado 01_CreacionBaseYEsquemas.sql. Puede reejecutarse:
--               las tablas existentes no se modifican ni pierden datos.
--
-- Nomenclatura: tablas y columnas en snake_case y singular; clave primaria
--               <tabla>_id. Restricciones: pk_ primaria, fk_ foranea,
--               uq_ unica, ck_ check, df_ default; ux_ indice unico filtrado.
--
-- Tipos       : NVARCHAR para nombres y textos libres de fuentes externas
--               (ej. Dzeko con z caron); VARCHAR para codigos y valores
--               de dominio cerrado.
--
-- Husos       : huso_horario guarda el nombre de Windows que acepta
--               AT TIME ZONE (ej. 'Eastern Standard Time'), ver
--               sys.time_zone_info. Las importaciones deben convertir los
--               nombres IANA (ej. 'America/New_York').
--
-- Desnormalizaciones controladas:
--   competencia.partido.fecha_hora_local_oficial: se pide junto con UTC y
--     es el dato oficial publicado; no se recalcula para no depender de
--     las reglas de huso vigentes.
--   competencia.partido_seleccion.goles y penales: el resultado oficial
--     puede importarse sin el detalle de eventos. Los SP deben mantenerlo
--     coherente con competencia.gol.
-- =====================================================================

USE MundialFutbol;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- 1. MAESTROS: DATOS GEOGRAFICOS, TORNEO Y SEDES
-- =====================================================================

IF OBJECT_ID(N'maestro.confederacion', N'U') IS NULL
CREATE TABLE maestro.confederacion (
    confederacion_id        INT IDENTITY(1,1) NOT NULL,
    codigo                  VARCHAR(10) NOT NULL,
    nombre                  NVARCHAR(100) NOT NULL,

    CONSTRAINT pk_confederacion PRIMARY KEY (confederacion_id),
    CONSTRAINT uq_confederacion_codigo UNIQUE (codigo),
    CONSTRAINT uq_confederacion_nombre UNIQUE (nombre)
);
GO

-- Las selecciones sin codigo ISO 3166-1 propio (ej. Inglaterra, Escocia)
-- se cargan con codigos de uso privado: XA-XZ para ISO2 y su sigla FIFA
-- para ISO3. Las importaciones por ISO deben mapearlas a GB/GBR.
IF OBJECT_ID(N'maestro.pais', N'U') IS NULL
CREATE TABLE maestro.pais (
    pais_id                 INT IDENTITY(1,1) NOT NULL,
    confederacion_id        INT,
    nombre                  NVARCHAR(100) NOT NULL,
    codigo_iso2             CHAR(2) NOT NULL,
    codigo_iso3             CHAR(3) NOT NULL,

    CONSTRAINT pk_pais PRIMARY KEY (pais_id),
    CONSTRAINT uq_pais_nombre UNIQUE (nombre),
    CONSTRAINT uq_pais_iso2 UNIQUE (codigo_iso2),
    CONSTRAINT uq_pais_iso3 UNIQUE (codigo_iso3),

    CONSTRAINT fk_pais_confederacion
        FOREIGN KEY (confederacion_id)
        REFERENCES maestro.confederacion (confederacion_id)
);
GO

IF OBJECT_ID(N'maestro.torneo', N'U') IS NULL
CREATE TABLE maestro.torneo (
    torneo_id                       INT IDENTITY(1,1) NOT NULL,
    nombre                          NVARCHAR(150) NOT NULL,
    anio                            SMALLINT NOT NULL,
    fecha_inicio                    DATE NOT NULL,
    fecha_fin                       DATE NOT NULL,

    -- Parametros reglamentarios del torneo.
    min_jugadores_convocados        SMALLINT NOT NULL,
    max_jugadores_convocados        SMALLINT NOT NULL,
    max_cambios                     SMALLINT NOT NULL,
    max_ventanas_cambio             SMALLINT NOT NULL,
    cambio_extra_alargue            BIT NOT NULL
        CONSTRAINT df_torneo_cambio_extra DEFAULT 0,
    ventana_extra_alargue           BIT NOT NULL
        CONSTRAINT df_torneo_ventana_extra DEFAULT 0,

    -- Criterios de suspension parametrizables.
    amarillas_para_suspension       SMALLINT NOT NULL,
    partidos_susp_amarillas         SMALLINT NOT NULL
        CONSTRAINT df_torneo_susp_amarillas DEFAULT 1,
    partidos_susp_doble_amarilla    SMALLINT NOT NULL
        CONSTRAINT df_torneo_susp_doble_amarilla DEFAULT 1,
    partidos_susp_roja_directa      SMALLINT NOT NULL
        CONSTRAINT df_torneo_susp_roja_directa DEFAULT 1,

    CONSTRAINT pk_torneo PRIMARY KEY (torneo_id),
    CONSTRAINT uq_torneo UNIQUE (nombre, anio),

    CONSTRAINT ck_torneo_fechas
        CHECK (fecha_fin >= fecha_inicio),

    CONSTRAINT ck_torneo_convocados
        CHECK (
            min_jugadores_convocados > 0
            AND max_jugadores_convocados >= min_jugadores_convocados
        ),

    CONSTRAINT ck_torneo_cambios
        CHECK (
            max_cambios >= 0
            AND max_ventanas_cambio >= 0
        ),

    CONSTRAINT ck_torneo_amarillas
        CHECK (amarillas_para_suspension > 0),

    CONSTRAINT ck_torneo_partidos_suspension
        CHECK (
            partidos_susp_amarillas > 0
            AND partidos_susp_doble_amarilla > 0
            AND partidos_susp_roja_directa > 0
        )
);
GO

IF OBJECT_ID(N'maestro.fase', N'U') IS NULL
CREATE TABLE maestro.fase (
    fase_id                 INT IDENTITY(1,1) NOT NULL,
    torneo_id               INT NOT NULL,
    nombre                  NVARCHAR(80) NOT NULL,
    orden                   SMALLINT NOT NULL,
    es_eliminatoria         BIT NOT NULL
        CONSTRAINT df_fase_eliminatoria DEFAULT 0,

    -- Al terminar esta fase las amarillas acumuladas vuelven a cero.
    limpia_amarillas        BIT NOT NULL
        CONSTRAINT df_fase_limpia_amarillas DEFAULT 0,

    CONSTRAINT pk_fase PRIMARY KEY (fase_id),
    CONSTRAINT uq_fase_nombre UNIQUE (torneo_id, nombre),
    CONSTRAINT uq_fase_orden UNIQUE (torneo_id, orden),
    CONSTRAINT ck_fase_orden CHECK (orden > 0),

    CONSTRAINT fk_fase_torneo
        FOREIGN KEY (torneo_id)
        REFERENCES maestro.torneo (torneo_id)
);
GO

IF OBJECT_ID(N'maestro.sede', N'U') IS NULL
CREATE TABLE maestro.sede (
    sede_id                 INT IDENTITY(1,1) NOT NULL,
    nombre_estadio          NVARCHAR(150) NOT NULL,
    ciudad                  NVARCHAR(120) NOT NULL,
    pais_id                 INT NOT NULL,
    capacidad               INT NOT NULL,
    huso_horario            VARCHAR(80) NOT NULL,
    latitud                 DECIMAL(9,6),
    longitud                DECIMAL(9,6),

    CONSTRAINT pk_sede PRIMARY KEY (sede_id),

    CONSTRAINT uq_sede
        UNIQUE (nombre_estadio, ciudad, pais_id),

    CONSTRAINT ck_sede_capacidad
        CHECK (capacidad > 0),

    CONSTRAINT ck_sede_latitud
        CHECK (latitud IS NULL OR latitud BETWEEN -90 AND 90),

    CONSTRAINT ck_sede_longitud
        CHECK (longitud IS NULL OR longitud BETWEEN -180 AND 180),

    CONSTRAINT fk_sede_pais
        FOREIGN KEY (pais_id)
        REFERENCES maestro.pais (pais_id)
);
GO

-- =====================================================================
-- 2. SELECCIONES, JUGADORES Y CONVOCATORIAS
-- =====================================================================

IF OBJECT_ID(N'plantel.seleccion', N'U') IS NULL
CREATE TABLE plantel.seleccion (
    seleccion_id            INT IDENTITY(1,1) NOT NULL,
    torneo_id               INT NOT NULL,
    pais_id                 INT NOT NULL,
    grupo                   VARCHAR(10),

    CONSTRAINT pk_seleccion PRIMARY KEY (seleccion_id),

    CONSTRAINT uq_seleccion_torneo_pais
        UNIQUE (torneo_id, pais_id),

    CONSTRAINT fk_seleccion_torneo
        FOREIGN KEY (torneo_id)
        REFERENCES maestro.torneo (torneo_id),

    CONSTRAINT fk_seleccion_pais
        FOREIGN KEY (pais_id)
        REFERENCES maestro.pais (pais_id)
);
GO

IF OBJECT_ID(N'plantel.jugador', N'U') IS NULL
CREATE TABLE plantel.jugador (
    jugador_id              INT IDENTITY(1,1) NOT NULL,
    nombres                 NVARCHAR(120) NOT NULL,
    apellidos               NVARCHAR(120) NOT NULL,
    fecha_nacimiento        DATE,
    pais_nacionalidad_id    INT,

    CONSTRAINT pk_jugador PRIMARY KEY (jugador_id),

    CONSTRAINT fk_jugador_nacionalidad
        FOREIGN KEY (pais_nacionalidad_id)
        REFERENCES maestro.pais (pais_id)
);
GO

-- Clave natural para el upsert de importaciones. Es filtrada porque
-- fecha_nacimiento es opcional y dos homonimos sin fecha no son duplicados.
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'ux_jugador_identidad'
      AND object_id = OBJECT_ID(N'plantel.jugador')
)
CREATE UNIQUE INDEX ux_jugador_identidad
    ON plantel.jugador (apellidos, nombres, fecha_nacimiento)
    WHERE fecha_nacimiento IS NOT NULL;
GO

-- convocatoria_jugador no duplica a jugador:
-- jugador contiene la identidad estable de la persona.
-- convocatoria_jugador contiene datos dependientes de su participacion
-- en una seleccion y torneo concretos.
IF OBJECT_ID(N'plantel.convocatoria_jugador', N'U') IS NULL
CREATE TABLE plantel.convocatoria_jugador (
    convocatoria_jugador_id INT IDENTITY(1,1) NOT NULL,
    seleccion_id            INT NOT NULL,
    jugador_id              INT NOT NULL,
    club_origen             NVARCHAR(150) NOT NULL,
    posicion_habitual       NVARCHAR(50) NOT NULL,
    dorsal                  SMALLINT NOT NULL,
    fecha_alta              DATE NOT NULL,
    fecha_baja              DATE,
    motivo_baja             NVARCHAR(300),

    CONSTRAINT pk_convocatoria_jugador PRIMARY KEY (convocatoria_jugador_id),

    CONSTRAINT uq_convocatoria_jugador
        UNIQUE (seleccion_id, jugador_id),

    CONSTRAINT ck_convocatoria_dorsal
        CHECK (dorsal > 0),

    CONSTRAINT ck_convocatoria_fechas
        CHECK (fecha_baja IS NULL OR fecha_baja >= fecha_alta),

    -- Toda baja debe indicar fecha y motivo.
    CONSTRAINT ck_convocatoria_baja
        CHECK (
            (fecha_baja IS NULL AND motivo_baja IS NULL)
            OR (fecha_baja IS NOT NULL AND motivo_baja IS NOT NULL)
        ),

    CONSTRAINT fk_convocatoria_seleccion
        FOREIGN KEY (seleccion_id)
        REFERENCES plantel.seleccion (seleccion_id),

    CONSTRAINT fk_convocatoria_jugador
        FOREIGN KEY (jugador_id)
        REFERENCES plantel.jugador (jugador_id)
);
GO

-- Es filtrado porque el reemplazo puede heredar el dorsal de quien fue baja.
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'ux_convocatoria_dorsal_activo'
      AND object_id = OBJECT_ID(N'plantel.convocatoria_jugador')
)
CREATE UNIQUE INDEX ux_convocatoria_dorsal_activo
    ON plantel.convocatoria_jugador (seleccion_id, dorsal)
    WHERE fecha_baja IS NULL;
GO

IF OBJECT_ID(N'plantel.cambio_convocatoria', N'U') IS NULL
CREATE TABLE plantel.cambio_convocatoria (
    cambio_convocatoria_id      INT IDENTITY(1,1) NOT NULL,
    convocatoria_saliente_id    INT NOT NULL,
    convocatoria_entrante_id    INT NOT NULL,
    fecha_cambio                DATE NOT NULL,
    motivo                      NVARCHAR(300) NOT NULL,

    CONSTRAINT pk_cambio_convocatoria PRIMARY KEY (cambio_convocatoria_id),

    CONSTRAINT uq_cambio_convocatoria_saliente
        UNIQUE (convocatoria_saliente_id),

    CONSTRAINT ck_cambio_convocatoria_jugadores
        CHECK (convocatoria_saliente_id <> convocatoria_entrante_id),

    CONSTRAINT fk_cambio_convocatoria_saliente
        FOREIGN KEY (convocatoria_saliente_id)
        REFERENCES plantel.convocatoria_jugador (convocatoria_jugador_id),

    CONSTRAINT fk_cambio_convocatoria_entrante
        FOREIGN KEY (convocatoria_entrante_id)
        REFERENCES plantel.convocatoria_jugador (convocatoria_jugador_id)
);
GO

IF OBJECT_ID(N'plantel.cuerpo_tecnico', N'U') IS NULL
CREATE TABLE plantel.cuerpo_tecnico (
    cuerpo_tecnico_id       INT IDENTITY(1,1) NOT NULL,
    seleccion_id            INT NOT NULL,
    nombres                 NVARCHAR(120) NOT NULL,
    apellidos               NVARCHAR(120) NOT NULL,
    fecha_nacimiento        DATE,
    pais_nacionalidad_id    INT,
    rol                     NVARCHAR(50) NOT NULL,

    CONSTRAINT pk_cuerpo_tecnico PRIMARY KEY (cuerpo_tecnico_id),

    CONSTRAINT fk_cuerpo_tecnico_seleccion
        FOREIGN KEY (seleccion_id)
        REFERENCES plantel.seleccion (seleccion_id),

    CONSTRAINT fk_cuerpo_tecnico_nacionalidad
        FOREIGN KEY (pais_nacionalidad_id)
        REFERENCES maestro.pais (pais_id)
);
GO

-- =====================================================================
-- 3. PARTIDOS Y CUADRO DEL TORNEO
-- =====================================================================

IF OBJECT_ID(N'competencia.partido', N'U') IS NULL
CREATE TABLE competencia.partido (
    partido_id                  INT IDENTITY(1,1) NOT NULL,
    fase_id                     INT NOT NULL,
    sede_id                     INT NOT NULL,

    -- Numero oficial del partido: clave natural para el upsert del fixture.
    numero_partido              SMALLINT NOT NULL,
    fecha_hora_utc              DATETIME2(0) NOT NULL,

    -- Desnormalizacion controlada explicada en el encabezado.
    fecha_hora_local_oficial    DATETIME2(0) NOT NULL,

    asistencia_publico          INT,

    CONSTRAINT pk_partido PRIMARY KEY (partido_id),

    CONSTRAINT uq_partido_numero
        UNIQUE (fase_id, numero_partido),

    CONSTRAINT uq_partido_sede_horario
        UNIQUE (sede_id, fecha_hora_utc),

    CONSTRAINT ck_partido_numero
        CHECK (numero_partido > 0),

    CONSTRAINT ck_partido_asistencia
        CHECK (asistencia_publico IS NULL OR asistencia_publico >= 0),

    CONSTRAINT fk_partido_fase
        FOREIGN KEY (fase_id)
        REFERENCES maestro.fase (fase_id),

    CONSTRAINT fk_partido_sede
        FOREIGN KEY (sede_id)
        REFERENCES maestro.sede (sede_id)
);
GO

-- Entidad asociativa entre partido y seleccion.
-- Permite representar LOCAL/VISITANTE sin repetir columnas
-- seleccion_local_id y seleccion_visitante_id en partido.
IF OBJECT_ID(N'competencia.partido_seleccion', N'U') IS NULL
CREATE TABLE competencia.partido_seleccion (
    partido_seleccion_id     INT IDENTITY(1,1) NOT NULL,
    partido_id               INT NOT NULL,
    seleccion_id             INT NOT NULL,
    condicion                VARCHAR(10) NOT NULL,

    -- Resultado oficial: desnormalizacion controlada.
    goles                    SMALLINT,
    penales                  SMALLINT,

    CONSTRAINT pk_partido_seleccion PRIMARY KEY (partido_seleccion_id),

    CONSTRAINT uq_partido_seleccion
        UNIQUE (partido_id, seleccion_id),

    CONSTRAINT uq_partido_condicion
        UNIQUE (partido_id, condicion),

    CONSTRAINT ck_partido_condicion
        CHECK (condicion IN ('LOCAL', 'VISITANTE')),

    CONSTRAINT ck_partido_goles
        CHECK (goles IS NULL OR goles >= 0),

    CONSTRAINT ck_partido_penales
        CHECK (penales IS NULL OR penales >= 0),

    CONSTRAINT fk_partido_seleccion_partido
        FOREIGN KEY (partido_id)
        REFERENCES competencia.partido (partido_id),

    CONSTRAINT fk_partido_seleccion_seleccion
        FOREIGN KEY (seleccion_id)
        REFERENCES plantel.seleccion (seleccion_id)
);
GO

-- Relacion que representa el avance en el cuadro eliminatorio.
-- Permite determinar cruces futuros para las advertencias de arbitraje.
IF OBJECT_ID(N'competencia.avance_partido', N'U') IS NULL
CREATE TABLE competencia.avance_partido (
    partido_origen_id        INT NOT NULL,
    partido_destino_id       INT NOT NULL,
    clasificado              VARCHAR(10) NOT NULL,
    condicion_destino        VARCHAR(10) NOT NULL,

    CONSTRAINT pk_avance_partido
        PRIMARY KEY (partido_origen_id, clasificado),

    CONSTRAINT ck_avance_partido_distinto
        CHECK (partido_origen_id <> partido_destino_id),

    CONSTRAINT ck_avance_clasificado
        CHECK (clasificado IN ('GANADOR', 'PERDEDOR')),

    CONSTRAINT ck_avance_condicion
        CHECK (condicion_destino IN ('LOCAL', 'VISITANTE')),

    CONSTRAINT uq_avance_destino_condicion
        UNIQUE (partido_destino_id, condicion_destino),

    CONSTRAINT fk_avance_origen
        FOREIGN KEY (partido_origen_id)
        REFERENCES competencia.partido (partido_id),

    CONSTRAINT fk_avance_destino
        FOREIGN KEY (partido_destino_id)
        REFERENCES competencia.partido (partido_id)
);
GO

-- =====================================================================
-- 4. ALINEACIONES
-- =====================================================================

IF OBJECT_ID(N'competencia.alineacion', N'U') IS NULL
CREATE TABLE competencia.alineacion (
    alineacion_id            INT IDENTITY(1,1) NOT NULL,
    partido_seleccion_id     INT NOT NULL,
    esquema_tactico          VARCHAR(30),

    CONSTRAINT pk_alineacion PRIMARY KEY (alineacion_id),

    CONSTRAINT uq_alineacion_partido_seleccion
        UNIQUE (partido_seleccion_id),

    CONSTRAINT fk_alineacion_partido_seleccion
        FOREIGN KEY (partido_seleccion_id)
        REFERENCES competencia.partido_seleccion (partido_seleccion_id)
);
GO

-- El dorsal NO se repite aqui: pertenece a convocatoria_jugador y puede
-- obtenerse mediante la FK. Repetirlo generaria una dependencia redundante.
IF OBJECT_ID(N'competencia.alineacion_jugador', N'U') IS NULL
CREATE TABLE competencia.alineacion_jugador (
    alineacion_jugador_id     INT IDENTITY(1,1) NOT NULL,
    alineacion_id             INT NOT NULL,
    convocatoria_jugador_id   INT NOT NULL,
    tipo                      VARCHAR(10) NOT NULL,
    posicion_en_cancha        NVARCHAR(50),
    es_capitan                BIT NOT NULL
        CONSTRAINT df_alineacion_jugador_capitan DEFAULT 0,

    CONSTRAINT pk_alineacion_jugador PRIMARY KEY (alineacion_jugador_id),

    CONSTRAINT uq_alineacion_jugador
        UNIQUE (alineacion_id, convocatoria_jugador_id),

    CONSTRAINT ck_alineacion_tipo
        CHECK (tipo IN ('TITULAR', 'SUPLENTE')),

    CONSTRAINT fk_alineacion_jugador_alineacion
        FOREIGN KEY (alineacion_id)
        REFERENCES competencia.alineacion (alineacion_id),

    CONSTRAINT fk_alineacion_jugador_convocatoria
        FOREIGN KEY (convocatoria_jugador_id)
        REFERENCES plantel.convocatoria_jugador (convocatoria_jugador_id)
);
GO

-- =====================================================================
-- 5. EVENTOS DEL PARTIDO
-- =====================================================================

-- Superentidad comun para no repetir partido/minuto/periodo en gol,
-- tarjeta y sustitucion. Los adicionales de cada tiempo se registran
-- en minuto_adicional, no como un periodo aparte.
IF OBJECT_ID(N'competencia.evento_partido', N'U') IS NULL
CREATE TABLE competencia.evento_partido (
    evento_id                INT IDENTITY(1,1) NOT NULL,
    partido_id               INT NOT NULL,
    periodo                  VARCHAR(20) NOT NULL,
    minuto                   SMALLINT NOT NULL,
    minuto_adicional         SMALLINT NOT NULL
        CONSTRAINT df_evento_minuto_adicional DEFAULT 0,
    secuencia                SMALLINT NOT NULL
        CONSTRAINT df_evento_secuencia DEFAULT 1,

    CONSTRAINT pk_evento_partido PRIMARY KEY (evento_id),

    CONSTRAINT uq_evento_orden
        UNIQUE (
            partido_id,
            periodo,
            minuto,
            minuto_adicional,
            secuencia
        ),

    CONSTRAINT ck_evento_periodo
        CHECK (
            periodo IN (
                'PRIMER_TIEMPO',
                'SEGUNDO_TIEMPO',
                'ALARGUE_1',
                'ALARGUE_2',
                'PENALES'
            )
        ),

    CONSTRAINT ck_evento_minuto
        CHECK (minuto >= 0 AND minuto_adicional >= 0),

    CONSTRAINT ck_evento_secuencia
        CHECK (secuencia > 0),

    CONSTRAINT fk_evento_partido
        FOREIGN KEY (partido_id)
        REFERENCES competencia.partido (partido_id)
);
GO

IF OBJECT_ID(N'competencia.gol', N'U') IS NULL
CREATE TABLE competencia.gol (
    evento_id                    INT NOT NULL,
    autor_convocatoria_id        INT NOT NULL,
    asistencia_convocatoria_id   INT,
    beneficiario_id              INT NOT NULL,
    tipo                         VARCHAR(30) NOT NULL,

    CONSTRAINT pk_gol PRIMARY KEY (evento_id),

    CONSTRAINT ck_gol_asistencia
        CHECK (
            asistencia_convocatoria_id IS NULL
            OR asistencia_convocatoria_id <> autor_convocatoria_id
        ),

    CONSTRAINT ck_gol_tipo
        CHECK (
            tipo IN (
                'JUGADA',
                'PENAL',
                'TIRO_LIBRE',
                'EN_CONTRA',
                'CABEZAZO',
                'OTRO'
            )
        ),

    CONSTRAINT fk_gol_evento
        FOREIGN KEY (evento_id)
        REFERENCES competencia.evento_partido (evento_id),

    CONSTRAINT fk_gol_autor
        FOREIGN KEY (autor_convocatoria_id)
        REFERENCES plantel.convocatoria_jugador (convocatoria_jugador_id),

    CONSTRAINT fk_gol_asistencia
        FOREIGN KEY (asistencia_convocatoria_id)
        REFERENCES plantel.convocatoria_jugador (convocatoria_jugador_id),

    CONSTRAINT fk_gol_beneficiario
        FOREIGN KEY (beneficiario_id)
        REFERENCES competencia.partido_seleccion (partido_seleccion_id)
);
GO

IF OBJECT_ID(N'competencia.tarjeta', N'U') IS NULL
CREATE TABLE competencia.tarjeta (
    evento_id                    INT NOT NULL,
    convocatoria_jugador_id      INT NOT NULL,
    tipo                         VARCHAR(10) NOT NULL,
    tipo_expulsion               VARCHAR(20),
    motivo                       NVARCHAR(300),

    CONSTRAINT pk_tarjeta PRIMARY KEY (evento_id),

    CONSTRAINT ck_tarjeta_tipo
        CHECK (tipo IN ('AMARILLA', 'ROJA')),

    CONSTRAINT ck_tarjeta_expulsion
        CHECK (
            (tipo = 'AMARILLA' AND tipo_expulsion IS NULL)
            OR
            (
                tipo = 'ROJA'
                AND tipo_expulsion IN ('DIRECTA', 'DOBLE_AMARILLA')
            )
        ),

    CONSTRAINT fk_tarjeta_evento
        FOREIGN KEY (evento_id)
        REFERENCES competencia.evento_partido (evento_id),

    CONSTRAINT fk_tarjeta_convocatoria
        FOREIGN KEY (convocatoria_jugador_id)
        REFERENCES plantel.convocatoria_jugador (convocatoria_jugador_id)
);
GO

IF OBJECT_ID(N'competencia.sustitucion', N'U') IS NULL
CREATE TABLE competencia.sustitucion (
    evento_id                    INT NOT NULL,
    jugador_sale_id              INT NOT NULL,
    jugador_entra_id             INT NOT NULL,
    numero_ventana               SMALLINT,
    motivo                       VARCHAR(20) NOT NULL,

    CONSTRAINT pk_sustitucion PRIMARY KEY (evento_id),

    CONSTRAINT ck_sustitucion_jugadores
        CHECK (jugador_sale_id <> jugador_entra_id),

    CONSTRAINT ck_sustitucion_ventana
        CHECK (numero_ventana IS NULL OR numero_ventana > 0),

    CONSTRAINT ck_sustitucion_motivo
        CHECK (motivo IN ('TACTICO', 'LESION', 'PRECAUCION', 'OTRO')),

    CONSTRAINT fk_sustitucion_evento
        FOREIGN KEY (evento_id)
        REFERENCES competencia.evento_partido (evento_id),

    CONSTRAINT fk_sustitucion_sale
        FOREIGN KEY (jugador_sale_id)
        REFERENCES competencia.alineacion_jugador (alineacion_jugador_id),

    CONSTRAINT fk_sustitucion_entra
        FOREIGN KEY (jugador_entra_id)
        REFERENCES competencia.alineacion_jugador (alineacion_jugador_id)
);
GO

-- =====================================================================
-- 6. SUSPENSIONES
-- =====================================================================

IF OBJECT_ID(N'competencia.suspension', N'U') IS NULL
CREATE TABLE competencia.suspension (
    suspension_id              INT IDENTITY(1,1) NOT NULL,
    convocatoria_jugador_id    INT NOT NULL,
    partido_origen_id          INT NOT NULL,
    tipo                       VARCHAR(30) NOT NULL,
    motivo                     NVARCHAR(300) NOT NULL,
    anulada                    BIT NOT NULL
        CONSTRAINT df_suspension_anulada DEFAULT 0,

    CONSTRAINT pk_suspension PRIMARY KEY (suspension_id),

    -- Evita duplicar la suspension si el calculo se reejecuta.
    CONSTRAINT uq_suspension
        UNIQUE (convocatoria_jugador_id, partido_origen_id, tipo),

    CONSTRAINT ck_suspension_tipo
        CHECK (
            tipo IN (
                'ACUMULACION_AMARILLAS',
                'ROJA_DIRECTA',
                'DOBLE_AMARILLA',
                'DISCIPLINARIA'
            )
        ),

    CONSTRAINT fk_suspension_convocatoria
        FOREIGN KEY (convocatoria_jugador_id)
        REFERENCES plantel.convocatoria_jugador (convocatoria_jugador_id),

    CONSTRAINT fk_suspension_origen
        FOREIGN KEY (partido_origen_id)
        REFERENCES competencia.partido (partido_id)
);
GO

IF OBJECT_ID(N'competencia.suspension_partido', N'U') IS NULL
CREATE TABLE competencia.suspension_partido (
    suspension_id              INT NOT NULL,
    partido_id                 INT NOT NULL,
    cumplida                   BIT NOT NULL
        CONSTRAINT df_suspension_partido_cumplida DEFAULT 0,

    CONSTRAINT pk_suspension_partido
        PRIMARY KEY (suspension_id, partido_id),

    CONSTRAINT fk_suspension_partido_suspension
        FOREIGN KEY (suspension_id)
        REFERENCES competencia.suspension (suspension_id),

    CONSTRAINT fk_suspension_partido_partido
        FOREIGN KEY (partido_id)
        REFERENCES competencia.partido (partido_id)
);
GO

-- =====================================================================
-- 7. ARBITROS
-- =====================================================================

IF OBJECT_ID(N'arbitraje.arbitro', N'U') IS NULL
CREATE TABLE arbitraje.arbitro (
    arbitro_id                INT IDENTITY(1,1) NOT NULL,
    nombres                   NVARCHAR(120) NOT NULL,
    apellidos                 NVARCHAR(120) NOT NULL,
    fecha_nacimiento          DATE,
    pais_id                   INT NOT NULL,
    categoria                 VARCHAR(50) NOT NULL,

    CONSTRAINT pk_arbitro PRIMARY KEY (arbitro_id),

    -- Clave natural para el upsert: las nominas publicas no traen
    -- fecha de nacimiento.
    CONSTRAINT uq_arbitro_identidad
        UNIQUE (apellidos, nombres, pais_id),

    CONSTRAINT fk_arbitro_pais
        FOREIGN KEY (pais_id)
        REFERENCES maestro.pais (pais_id)
);
GO

IF OBJECT_ID(N'arbitraje.arbitro_idioma', N'U') IS NULL
CREATE TABLE arbitraje.arbitro_idioma (
    arbitro_id                INT NOT NULL,
    idioma                    NVARCHAR(80) NOT NULL,

    CONSTRAINT pk_arbitro_idioma PRIMARY KEY (arbitro_id, idioma),

    CONSTRAINT fk_arbitro_idioma_arbitro
        FOREIGN KEY (arbitro_id)
        REFERENCES arbitraje.arbitro (arbitro_id)
);
GO

IF OBJECT_ID(N'arbitraje.designacion_arbitral', N'U') IS NULL
CREATE TABLE arbitraje.designacion_arbitral (
    designacion_id            INT IDENTITY(1,1) NOT NULL,
    partido_id                INT NOT NULL,
    arbitro_id                INT NOT NULL,
    rol                       VARCHAR(30) NOT NULL,

    CONSTRAINT pk_designacion_arbitral PRIMARY KEY (designacion_id),

    CONSTRAINT uq_designacion_arbitro
        UNIQUE (partido_id, arbitro_id),

    CONSTRAINT uq_designacion_rol
        UNIQUE (partido_id, rol),

    CONSTRAINT ck_designacion_rol
        CHECK (
            rol IN (
                'PRINCIPAL',
                'ASISTENTE_1',
                'ASISTENTE_2',
                'CUARTO_ARBITRO',
                'VAR'
            )
        ),

    CONSTRAINT fk_designacion_partido
        FOREIGN KEY (partido_id)
        REFERENCES competencia.partido (partido_id),

    CONSTRAINT fk_designacion_arbitro
        FOREIGN KEY (arbitro_id)
        REFERENCES arbitraje.arbitro (arbitro_id)
);
GO

IF OBJECT_ID(N'arbitraje.antecedente_arbitral', N'U') IS NULL
CREATE TABLE arbitraje.antecedente_arbitral (
    antecedente_id            INT IDENTITY(1,1) NOT NULL,
    arbitro_id                INT NOT NULL,
    partido_id                INT NOT NULL,
    fecha                     DATE NOT NULL,
    tipo                      VARCHAR(15) NOT NULL,
    detalle                   NVARCHAR(2000) NOT NULL,

    CONSTRAINT pk_antecedente_arbitral PRIMARY KEY (antecedente_id),

    CONSTRAINT ck_antecedente_tipo
        CHECK (tipo IN ('INFORME', 'SANCION')),

    CONSTRAINT fk_antecedente_arbitro
        FOREIGN KEY (arbitro_id)
        REFERENCES arbitraje.arbitro (arbitro_id),

    CONSTRAINT fk_antecedente_partido
        FOREIGN KEY (partido_id)
        REFERENCES competencia.partido (partido_id)
);
GO

-- =====================================================================
-- 8. PUBLICIDAD
-- =====================================================================

-- El prime time puede cruzar la medianoche (ej. 22:00 a 01:00), por eso
-- solo se exige que desde y hasta sean distintos.
IF OBJECT_ID(N'publicidad.mercado', N'U') IS NULL
CREATE TABLE publicidad.mercado (
    mercado_id              INT IDENTITY(1,1) NOT NULL,
    pais_id                 INT NOT NULL,
    nombre                  NVARCHAR(120) NOT NULL,
    huso_horario            VARCHAR(80) NOT NULL,
    prime_time_desde        TIME(0) NOT NULL
        CONSTRAINT df_mercado_prime_time_desde DEFAULT '19:00',
    prime_time_hasta        TIME(0) NOT NULL
        CONSTRAINT df_mercado_prime_time_hasta DEFAULT '23:00',

    CONSTRAINT pk_mercado PRIMARY KEY (mercado_id),

    CONSTRAINT uq_mercado UNIQUE (pais_id, nombre, huso_horario),

    CONSTRAINT ck_mercado_prime_time
        CHECK (prime_time_desde <> prime_time_hasta),

    CONSTRAINT fk_mercado_pais
        FOREIGN KEY (pais_id)
        REFERENCES maestro.pais (pais_id)
);
GO

-- Tarifa vigente de cada franja horaria, expresada en hora local del
-- mercado. Igual que el prime time, una franja puede cruzar la medianoche.
IF OBJECT_ID(N'publicidad.tarifa_franja', N'U') IS NULL
CREATE TABLE publicidad.tarifa_franja (
    tarifa_franja_id          INT IDENTITY(1,1) NOT NULL,
    mercado_id                INT NOT NULL,
    nombre                    NVARCHAR(80) NOT NULL,
    hora_desde                TIME(0) NOT NULL,
    hora_hasta                TIME(0) NOT NULL,
    importe                   DECIMAL(18,2) NOT NULL,
    moneda                    CHAR(3) NOT NULL,

    CONSTRAINT pk_tarifa_franja PRIMARY KEY (tarifa_franja_id),

    CONSTRAINT uq_tarifa_franja_nombre UNIQUE (mercado_id, nombre),
    CONSTRAINT uq_tarifa_franja_inicio UNIQUE (mercado_id, hora_desde),

    CONSTRAINT ck_tarifa_franja_horario
        CHECK (hora_desde <> hora_hasta),

    CONSTRAINT ck_tarifa_franja_importe
        CHECK (importe >= 0),

    CONSTRAINT fk_tarifa_franja_mercado
        FOREIGN KEY (mercado_id)
        REFERENCES publicidad.mercado (mercado_id)
);
GO

IF OBJECT_ID(N'publicidad.anunciante', N'U') IS NULL
CREATE TABLE publicidad.anunciante (
    anunciante_id             INT IDENTITY(1,1) NOT NULL,
    nombre                    NVARCHAR(180) NOT NULL,
    pais_id                   INT,

    CONSTRAINT pk_anunciante PRIMARY KEY (anunciante_id),

    CONSTRAINT uq_anunciante_nombre UNIQUE (nombre),

    CONSTRAINT fk_anunciante_pais
        FOREIGN KEY (pais_id)
        REFERENCES maestro.pais (pais_id)
);
GO

IF OBJECT_ID(N'publicidad.campania', N'U') IS NULL
CREATE TABLE publicidad.campania (
    campania_id               INT IDENTITY(1,1) NOT NULL,
    anunciante_id             INT NOT NULL,
    nombre                    NVARCHAR(180) NOT NULL,
    fecha_inicio              DATE NOT NULL,
    fecha_fin                 DATE NOT NULL,

    CONSTRAINT pk_campania PRIMARY KEY (campania_id),

    CONSTRAINT uq_campania
        UNIQUE (anunciante_id, nombre, fecha_inicio),

    CONSTRAINT ck_campania_fechas
        CHECK (fecha_fin >= fecha_inicio),

    CONSTRAINT fk_campania_anunciante
        FOREIGN KEY (anunciante_id)
        REFERENCES publicidad.anunciante (anunciante_id)
);
GO

IF OBJECT_ID(N'publicidad.campania_mercado', N'U') IS NULL
CREATE TABLE publicidad.campania_mercado (
    campania_id               INT NOT NULL,
    mercado_id                INT NOT NULL,
    prioridad                 SMALLINT,

    CONSTRAINT pk_campania_mercado PRIMARY KEY (campania_id, mercado_id),

    CONSTRAINT ck_campania_mercado_prioridad
        CHECK (prioridad IS NULL OR prioridad > 0),

    CONSTRAINT fk_campania_mercado_campania
        FOREIGN KEY (campania_id)
        REFERENCES publicidad.campania (campania_id),

    CONSTRAINT fk_campania_mercado_mercado
        FOREIGN KEY (mercado_id)
        REFERENCES publicidad.mercado (mercado_id)
);
GO

IF OBJECT_ID(N'publicidad.pieza_publicitaria', N'U') IS NULL
CREATE TABLE publicidad.pieza_publicitaria (
    pieza_id                  INT IDENTITY(1,1) NOT NULL,
    campania_id               INT NOT NULL,
    nombre                    NVARCHAR(180) NOT NULL,
    idioma                    NVARCHAR(80) NOT NULL,
    contenido_uri             VARCHAR(1000),
    activa                    BIT NOT NULL
        CONSTRAINT df_pieza_activa DEFAULT 1,

    CONSTRAINT pk_pieza_publicitaria PRIMARY KEY (pieza_id),

    CONSTRAINT uq_pieza
        UNIQUE (campania_id, nombre, idioma),

    CONSTRAINT fk_pieza_campania
        FOREIGN KEY (campania_id)
        REFERENCES publicidad.campania (campania_id)
);
GO

IF OBJECT_ID(N'publicidad.pieza_mercado', N'U') IS NULL
CREATE TABLE publicidad.pieza_mercado (
    pieza_id                  INT NOT NULL,
    mercado_id                INT NOT NULL,

    CONSTRAINT pk_pieza_mercado PRIMARY KEY (pieza_id, mercado_id),

    CONSTRAINT fk_pieza_mercado_pieza
        FOREIGN KEY (pieza_id)
        REFERENCES publicidad.pieza_publicitaria (pieza_id),

    CONSTRAINT fk_pieza_mercado_mercado
        FOREIGN KEY (mercado_id)
        REFERENCES publicidad.mercado (mercado_id)
);
GO

-- No se crea una entidad "espacio_publicitario" porque el enunciado no
-- le asigna atributos propios: los cuatro espacios se identifican por su
-- numero dentro de cada partido.
--
-- El importe y la moneda se copian de tarifa_franja al asignar: son
-- atributos de la pauta de ese partido y espacio, y un cambio posterior
-- de tarifa no debe alterar lo facturado. tarifa_franja_id admite NULL
-- para pautas pactadas fuera de tarifa.
--
-- estado distingue la propuesta del sistema de lo efectivamente exhibido,
-- que es lo que se factura.
IF OBJECT_ID(N'publicidad.publicidad_partido', N'U') IS NULL
CREATE TABLE publicidad.publicidad_partido (
    publicidad_partido_id     INT IDENTITY(1,1) NOT NULL,
    partido_id                INT NOT NULL,
    numero_espacio            SMALLINT NOT NULL,
    pieza_id                  INT NOT NULL,
    tarifa_franja_id          INT,
    importe                   DECIMAL(18,2) NOT NULL,
    moneda                    CHAR(3) NOT NULL,
    estado                    VARCHAR(10) NOT NULL
        CONSTRAINT df_publicidad_partido_estado DEFAULT 'PROPUESTA',

    CONSTRAINT pk_publicidad_partido PRIMARY KEY (publicidad_partido_id),

    CONSTRAINT uq_publicidad_partido_espacio
        UNIQUE (partido_id, numero_espacio),

    CONSTRAINT ck_publicidad_partido_espacio
        CHECK (numero_espacio BETWEEN 1 AND 4),

    CONSTRAINT ck_publicidad_partido_importe
        CHECK (importe >= 0),

    CONSTRAINT ck_publicidad_partido_estado
        CHECK (estado IN ('PROPUESTA', 'EXHIBIDA')),

    CONSTRAINT fk_publicidad_partido_partido
        FOREIGN KEY (partido_id)
        REFERENCES competencia.partido (partido_id),

    CONSTRAINT fk_publicidad_partido_pieza
        FOREIGN KEY (pieza_id)
        REFERENCES publicidad.pieza_publicitaria (pieza_id),

    CONSTRAINT fk_publicidad_partido_tarifa
        FOREIGN KEY (tarifa_franja_id)
        REFERENCES publicidad.tarifa_franja (tarifa_franja_id)
);
GO

-- =====================================================================
-- 9. DATOS EXTERNOS NECESARIOS PARA ANALISIS
-- =====================================================================

IF OBJECT_ID(N'externo.pbi_pais', N'U') IS NULL
CREATE TABLE externo.pbi_pais (
    pais_id                   INT NOT NULL,
    anio                      SMALLINT NOT NULL,
    pbi_per_capita_usd        DECIMAL(18,2) NOT NULL,

    CONSTRAINT pk_pbi_pais PRIMARY KEY (pais_id, anio),

    CONSTRAINT ck_pbi_valor
        CHECK (pbi_per_capita_usd >= 0),

    CONSTRAINT fk_pbi_pais
        FOREIGN KEY (pais_id)
        REFERENCES maestro.pais (pais_id)
);
GO

IF OBJECT_ID(N'externo.tipo_cambio', N'U') IS NULL
CREATE TABLE externo.tipo_cambio (
    moneda_origen             CHAR(3) NOT NULL,
    moneda_destino            CHAR(3) NOT NULL,
    fecha                     DATE NOT NULL,
    tasa                      DECIMAL(24,10) NOT NULL,

    CONSTRAINT pk_tipo_cambio
        PRIMARY KEY (moneda_origen, moneda_destino, fecha),

    CONSTRAINT ck_tipo_cambio_monedas
        CHECK (moneda_origen <> moneda_destino),

    CONSTRAINT ck_tipo_cambio_tasa
        CHECK (tasa > 0)
);
GO

IF OBJECT_ID(N'externo.feriado', N'U') IS NULL
CREATE TABLE externo.feriado (
    feriado_id                INT IDENTITY(1,1) NOT NULL,
    pais_id                   INT NOT NULL,
    fecha                     DATE NOT NULL,
    nombre                    NVARCHAR(180) NOT NULL,

    CONSTRAINT pk_feriado PRIMARY KEY (feriado_id),

    CONSTRAINT uq_feriado
        UNIQUE (pais_id, fecha, nombre),

    CONSTRAINT fk_feriado_pais
        FOREIGN KEY (pais_id)
        REFERENCES maestro.pais (pais_id)
);
GO

-- =====================================================================
-- FIN DEL MODELO
-- =====================================================================
