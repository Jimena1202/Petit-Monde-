CREATE SCHEMA inventario;
SET search_path TO inventario, public;

CREATE TABLE categorias (
    id_categoria  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre        VARCHAR(60) NOT NULL,
    CONSTRAINT uq_categorias_nombre UNIQUE (nombre)
);
COMMENT ON TABLE categorias IS 'Catalogo de categorias. Elimina redundancia A3 del Anexo 1.';

CREATE TABLE subcategorias (
    id_subcategoria INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_categoria    INT NOT NULL,
    nombre          VARCHAR(60) NOT NULL,
    CONSTRAINT fk_subcat_cat FOREIGN KEY (id_categoria)
        REFERENCES categorias(id_categoria) ON DELETE RESTRICT,
    CONSTRAINT uq_subcat_nombre UNIQUE (id_categoria, nombre)
);

--Provedores
CREATE TABLE proveedores (
    id_proveedor INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(120) NOT NULL,
    contacto     VARCHAR(120) NOT NULL,
    telefono     VARCHAR(30)  NOT NULL,
    pais         VARCHAR(60)  NOT NULL,
    CONSTRAINT uq_proveedores_nombre UNIQUE (nombre)
);
COMMENT ON TABLE proveedores IS 'Elimina A1, A4, A5 y A12. Un cambio de telefono es UN solo UPDATE.';

-- Almacenes
CREATE TABLE almacenes (
    id_almacen INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre     VARCHAR(80)  NOT NULL,
    ubicacion  VARCHAR(120) NOT NULL,
    CONSTRAINT uq_almacenes_nombre UNIQUE (nombre)
);
COMMENT ON TABLE almacenes IS 'Elimina A2, A6 y A11. Un almacen puede existir sin stock.';

-- Productos
CREATE TABLE productos (
    id_producto      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku              VARCHAR(20)   NOT NULL,
    nombre           VARCHAR(150)  NOT NULL,
    id_subcategoria  INT           NOT NULL,
    id_proveedor     INT           NOT NULL,
    costo_unitario   NUMERIC(12,2) NOT NULL,
    precio_venta     NUMERIC(12,2) NOT NULL,
    activo           BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_productos_sku UNIQUE (sku),
    CONSTRAINT fk_prod_subcat FOREIGN KEY (id_subcategoria)
        REFERENCES subcategorias(id_subcategoria) ON DELETE RESTRICT,
    CONSTRAINT fk_prod_prov FOREIGN KEY (id_proveedor)
        REFERENCES proveedores(id_proveedor) ON DELETE RESTRICT,
    CONSTRAINT ck_prod_costo_positivo CHECK (costo_unitario  >= 0),
    CONSTRAINT ck_prod_precio_positivo CHECK (precio_venta   >= 0),
    
    CONSTRAINT ck_prod_precio_ge_costo CHECK (precio_venta   >= costo_unitario)
);
COMMENT ON TABLE productos IS 'Elimina A8 y A9. Valor de stock y estado se calculan en vistas.';


-- STOCK
CREATE TABLE stock (
    id_almacen   INT NOT NULL,
    id_producto  INT NOT NULL,
    cantidad     INT NOT NULL DEFAULT 0,
    stock_minimo INT NOT NULL DEFAULT 0,
    pasillo      VARCHAR(10),
    estante      VARCHAR(10),
    CONSTRAINT pk_stock PRIMARY KEY (id_almacen, id_producto),
    CONSTRAINT fk_stock_almacen FOREIGN KEY (id_almacen)
        REFERENCES almacenes(id_almacen) ON DELETE RESTRICT,
    CONSTRAINT fk_stock_producto FOREIGN KEY (id_producto)
        REFERENCES productos(id_producto) ON DELETE RESTRICT,
    CONSTRAINT ck_stock_cantidad CHECK (cantidad     >= 0),
    CONSTRAINT ck_stock_minimo   CHECK (stock_minimo >= 0)
);
COMMENT ON TABLE stock IS 'Resuelve A13 (pasillo/estante dependen del par producto-almacen).';

--Movimiento de inventario 
CREATE TABLE movimientos_inventario (
    id_movimiento BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_producto   INT  NOT NULL,
    id_almacen    INT  NOT NULL,
    tipo          VARCHAR(15) NOT NULL,
    cantidad      INT  NOT NULL,
    fecha         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    referencia    VARCHAR(60),
    id_usuario    VARCHAR(60) NOT NULL DEFAULT current_user,
    CONSTRAINT fk_mov_producto FOREIGN KEY (id_producto)
        REFERENCES productos(id_producto) ON DELETE RESTRICT,
    CONSTRAINT fk_mov_almacen FOREIGN KEY (id_almacen)
        REFERENCES almacenes(id_almacen) ON DELETE RESTRICT,
    CONSTRAINT ck_mov_tipo CHECK (tipo IN ('ENTRADA','SALIDA','TRANSF_OUT','TRANSF_IN','AJUSTE')),
    CONSTRAINT ck_mov_cantidad CHECK (cantidad > 0)
);
COMMENT ON TABLE movimientos_inventario IS 'Resuelve A10 (trazabilidad historica completa).';


-- Ventas
CREATE TABLE ventas (
    id_venta   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_almacen INT  NOT NULL,
    fecha      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    id_usuario VARCHAR(60) NOT NULL DEFAULT current_user,
    total      NUMERIC(12,2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_venta_almacen FOREIGN KEY (id_almacen)
        REFERENCES almacenes(id_almacen) ON DELETE RESTRICT,
    CONSTRAINT ck_venta_total CHECK (total >= 0)
);

CREATE TABLE detalle_venta (
    id_venta         BIGINT NOT NULL,
    id_producto      INT    NOT NULL,
    cantidad         INT    NOT NULL,
    precio_unitario  NUMERIC(12,2) NOT NULL,
    CONSTRAINT pk_detalle_venta PRIMARY KEY (id_venta, id_producto),
    CONSTRAINT fk_dv_venta FOREIGN KEY (id_venta)
        REFERENCES ventas(id_venta) ON DELETE CASCADE,
    CONSTRAINT fk_dv_producto FOREIGN KEY (id_producto)
        REFERENCES productos(id_producto) ON DELETE RESTRICT,
    CONSTRAINT ck_dv_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_dv_precio CHECK (precio_unitario >= 0)
);


--Tranferencias 
CREATE TABLE transferencias (
    id_transferencia   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_almacen_origen  INT  NOT NULL,
    id_almacen_destino INT  NOT NULL,
    fecha              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    id_usuario         VARCHAR(60) NOT NULL DEFAULT current_user,
    estado             VARCHAR(15) NOT NULL DEFAULT 'EN_TRANSITO',
    CONSTRAINT fk_transf_origen FOREIGN KEY (id_almacen_origen)
        REFERENCES almacenes(id_almacen) ON DELETE RESTRICT,
    CONSTRAINT fk_transf_destino FOREIGN KEY (id_almacen_destino)
        REFERENCES almacenes(id_almacen) ON DELETE RESTRICT,
    CONSTRAINT ck_transf_estado CHECK (estado IN ('EN_TRANSITO','RECIBIDA')),
    CONSTRAINT ck_transf_origen_distinto CHECK (id_almacen_origen <> id_almacen_destino)
);
COMMENT ON TABLE transferencias IS 'Permite modelar el transito real Cartago<->San Jose (Pag. 12-13 del PDF).';

CREATE TABLE detalle_transferencia (
    id_transferencia BIGINT NOT NULL,
    id_producto      INT    NOT NULL,
    cantidad         INT    NOT NULL,
    CONSTRAINT pk_detalle_transf PRIMARY KEY (id_transferencia, id_producto),
    CONSTRAINT fk_dt_transf FOREIGN KEY (id_transferencia)
        REFERENCES transferencias(id_transferencia) ON DELETE CASCADE,
    CONSTRAINT fk_dt_producto FOREIGN KEY (id_producto)
        REFERENCES productos(id_producto) ON DELETE RESTRICT,
    CONSTRAINT ck_dt_cantidad CHECK (cantidad > 0)
);
COMMENT ON TABLE detalle_transferencia IS 'Necesaria para la Rutina 2: la cabecera sola no dice que productos mover.';

-- Bitacora de reportes 
CREATE TABLE bitacora_reportes (
    id_bitacora        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_sp          VARCHAR(80) NOT NULL,
    parametros         TEXT,
    fecha_ejecucion    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    id_usuario         VARCHAR(60) NOT NULL DEFAULT current_user,
    filas_retornadas   INT NOT NULL DEFAULT 0,
    CONSTRAINT ck_bitacora_filas CHECK (filas_retornadas >= 0)
);


-- Indices
CREATE INDEX ix_productos_subcat   ON productos(id_subcategoria);
CREATE INDEX ix_productos_prov     ON productos(id_proveedor);
CREATE INDEX ix_stock_producto     ON stock(id_producto);
CREATE INDEX ix_mov_prod_fecha     ON movimientos_inventario(id_producto, fecha);
CREATE INDEX ix_mov_almacen_fecha  ON movimientos_inventario(id_almacen, fecha);
CREATE INDEX ix_mov_tipo           ON movimientos_inventario(tipo);
CREATE INDEX ix_ventas_almacen_fec ON ventas(id_almacen, fecha);
CREATE INDEX ix_transf_origen      ON transferencias(id_almacen_origen);
CREATE INDEX ix_transf_destino     ON transferencias(id_almacen_destino);

-- Vistas
CREATE VIEW v_inventario_actual AS
SELECT
    p.id_producto,
    p.sku,
    p.nombre                        AS producto,
    c.nombre                        AS categoria,
    sc.nombre                       AS subcategoria,
    a.id_almacen,
    a.nombre                        AS almacen,
    a.ubicacion                     AS almacen_ubicacion,
    s.pasillo,
    s.estante,
    s.cantidad,
    s.stock_minimo,
    p.costo_unitario,
    p.precio_venta,
    (s.cantidad * p.costo_unitario)::NUMERIC(12,2) AS valor_total_stock,
    CASE
        WHEN s.cantidad = 0                       THEN 'Agotado'
        WHEN s.cantidad <= s.stock_minimo         THEN 'Reordenar'
        ELSE                                           'En Stock'
    END AS estado_stock
FROM stock s
JOIN productos     p  ON p.id_producto     = s.id_producto
JOIN subcategorias sc ON sc.id_subcategoria = p.id_subcategoria
JOIN categorias    c  ON c.id_categoria    = sc.id_categoria
JOIN almacenes     a  ON a.id_almacen      = s.id_almacen;
COMMENT ON VIEW v_inventario_actual IS 'Reemplaza las columnas derivadas Valor Total Stock y Estado Stock del Anexo 1.';

CREATE VIEW v_movimientos_resumen AS
SELECT
    m.id_movimiento,
    m.fecha,
    m.tipo,
    p.sku,
    p.nombre   AS producto,
    a.nombre   AS almacen,
    m.cantidad,
    m.referencia,
    m.id_usuario
FROM movimientos_inventario m
JOIN productos p ON p.id_producto = m.id_producto
JOIN almacenes a ON a.id_almacen  = m.id_almacen;
COMMENT ON VIEW v_movimientos_resumen IS 'Base de lectura para el rol auditor (Prueba 12).';


--DATOS DE PRUEBA
-- Categorias 
INSERT INTO categorias (id_categoria, nombre) OVERRIDING SYSTEM VALUE VALUES
    (1, 'Electronica'), (2, 'Muebles'), (3, 'Accesorios');

-- Subcategorias
INSERT INTO subcategorias (id_subcategoria, id_categoria, nombre) OVERRIDING SYSTEM VALUE VALUES
    (1, 1, 'Monitores'), (2, 1, 'Perifericos'), (3, 2, 'Oficina'),
    (4, 3, 'Perifericos'), (5, 3, 'Cables');

-- Proveedores
INSERT INTO proveedores (id_proveedor, nombre, contacto, telefono, pais) OVERRIDING SYSTEM VALUE VALUES
    (1, 'Tech Supplies Co.',  'Carlos Ruiz', '+506 8888-1111', 'Costa Rica'),
    (2, 'Muebles & Comfort',  'Ana Gomez',   '+506 8888-2222', 'Costa Rica'),
    (3, 'Importadora Global', 'Luis Mora',   '+506 8888-3333', 'Costa Rica');

-- Almacenes
INSERT INTO almacenes (id_almacen, nombre, ubicacion) OVERRIDING SYSTEM VALUE VALUES
    (1, 'Almacen Central', 'Cartago, Costa Rica'),
    (2, 'Bodega Norte',    'San Jose, Costa Rica');

-- Productos
INSERT INTO productos (id_producto, sku, nombre, id_subcategoria, id_proveedor, costo_unitario, precio_venta) OVERRIDING SYSTEM VALUE VALUES
    (1, 'ELE-101', 'Monitor Gamer 27" 144Hz',    1, 1, 180.00, 280.00),
    (2, 'ELE-102', 'Teclado Mecanico RGB',       2, 1,  35.00,  65.00),
    (3, 'OFF-201', 'Silla Ergonómica Ejecutiva', 3, 2, 110.00, 195.00),
    (4, 'OFF-202', 'Escritorio Ajustable',       3, 2, 210.00, 350.00),
    (5, 'ACC-301', 'Mousepad XL Antideslizante', 4, 3,   6.50,  15.00),
    (6, 'ACC-302', 'Cable HDMI 2.1 2m',          5, 3,   3.00,   8.00);

-- STOCK
INSERT INTO stock (id_almacen, id_producto, cantidad, stock_minimo, pasillo, estante) VALUES
    (1, 1, 15,  5, 'A', '01'), (1, 2,  4, 10, 'A', '02'), (1, 3,  8,  3, 'B', '05'), (1, 4,  0,  2, 'B', '06'),
    (2, 5, 45, 15, 'C', '01'), (2, 6,  8, 12, 'C', '03'),
    (2, 1,  3,  5, 'D', '01'), (1, 5, 10, 15, 'C', '04'), (2, 2, 20, 10, 'D', '02'), (2, 4,  5,  2, 'E', '01');

-- Movimientos
INSERT INTO movimientos_inventario (id_producto, id_almacen, tipo, cantidad, fecha, referencia, id_usuario) VALUES
    (1, 1, 'ENTRADA', 60, '2026-01-01 08:00', 'APERTURA',  'seed'), (1, 1, 'SALIDA',  15, '2026-01-15 12:30', 'VTA-0001',  'seed'),
    (1, 1, 'SALIDA',  15, '2026-02-10 13:00', 'VTA-0002',  'seed'), (1, 1, 'SALIDA',  15, '2026-03-15 17:45', 'VTA-0003',  'seed'),
    (1, 2, 'ENTRADA',  5, '2026-01-05 09:00', 'APERTURA',  'seed'), (1, 2, 'SALIDA',   1, '2026-02-15 12:30', 'VTA-0010',  'seed'),
    (1, 2, 'SALIDA',   1, '2026-03-10 18:00', 'VTA-0011',  'seed'), (2, 1, 'ENTRADA', 32, '2026-01-01 08:05', 'APERTURA',  'seed'),
    (2, 1, 'SALIDA',  10, '2026-01-20 12:30', 'VTA-0004',  'seed'), (2, 1, 'SALIDA',  10, '2026-02-20 13:00', 'VTA-0005',  'seed'),
    (2, 1, 'SALIDA',   8, '2026-03-20 17:30', 'VTA-0006',  'seed'), (2, 2, 'ENTRADA', 30, '2026-01-01 08:10', 'APERTURA',  'seed'),
    (2, 2, 'SALIDA',   5, '2026-01-25 12:30', 'VTA-0012',  'seed'), (2, 2, 'SALIDA',   3, '2026-02-25 13:00', 'VTA-0013',  'seed'),
    (2, 2, 'SALIDA',   2, '2026-03-25 18:15', 'VTA-0014',  'seed'), (3, 1, 'ENTRADA', 13, '2026-01-01 08:15', 'APERTURA',  'seed'),
    (3, 1, 'SALIDA',   3, '2026-02-01 12:30', 'VTA-0007',  'seed'), (3, 1, 'SALIDA',   2, '2026-03-01 17:30', 'VTA-0008',  'seed'),
    (4, 1, 'ENTRADA',  2, '2026-01-01 08:20', 'APERTURA',  'seed'), (4, 1, 'SALIDA',   2, '2026-02-15 17:30', 'VTA-0009',  'seed'),
    (4, 2, 'ENTRADA',  5, '2026-01-01 08:25', 'APERTURA',  'seed'), (5, 2, 'ENTRADA', 65, '2026-01-01 08:30', 'APERTURA',  'seed'),
    (5, 2, 'SALIDA',  10, '2026-02-10 12:30', 'VTA-0015',  'seed'), (5, 2, 'SALIDA',  10, '2026-03-05 17:30', 'VTA-0016',  'seed'),
    (5, 1, 'ENTRADA', 10, '2026-01-01 08:35', 'APERTURA',  'seed'), (6, 2, 'ENTRADA', 11, '2026-01-01 08:40', 'APERTURA',  'seed'),
    (6, 2, 'SALIDA',   3, '2026-03-05 12:30', 'VTA-0017',  'seed');

-- Verificacion
DO $$ BEGIN RAISE NOTICE '--- Conteos de Tablas ---'; END $$;
SELECT 'categorias' AS tabla, count(*) FROM categorias UNION ALL SELECT 'subcategorias', count(*) FROM subcategorias
UNION ALL SELECT 'proveedores', count(*) FROM proveedores UNION ALL SELECT 'almacenes', count(*) FROM almacenes
UNION ALL SELECT 'productos', count(*) FROM productos UNION ALL SELECT 'stock', count(*) FROM stock
UNION ALL SELECT 'movimientos', count(*) FROM movimientos_inventario;

--ROLES / PERMISOS

--Roles
CREATE ROLE db_admin          NOINHERIT CREATEROLE BYPASSRLS;
CREATE ROLE inventory_manager NOINHERIT;
CREATE ROLE auditor           NOINHERIT;

--Usuarios Prueba
CREATE ROLE u_admin     LOGIN PASSWORD 'Admin#2026'     IN ROLE db_admin;
CREATE ROLE u_manager_c LOGIN PASSWORD 'ManagerC#2026'  IN ROLE inventory_manager;
CREATE ROLE u_manager_n LOGIN PASSWORD 'ManagerN#2026'  IN ROLE inventory_manager;
CREATE ROLE u_auditor   LOGIN PASSWORD 'Auditor#2026'   IN ROLE auditor;

-- Permisos De Esquema
GRANT USAGE ON SCHEMA inventario TO db_admin, inventory_manager, auditor;

--db_admin (Todo)
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA inventario TO db_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA inventario TO db_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA inventario TO db_admin;

--inventory_manager (Operativo)
GRANT SELECT, INSERT, UPDATE ON ALL TABLES    IN SCHEMA inventario TO inventory_manager;
GRANT USAGE, SELECT           ON ALL SEQUENCES IN SCHEMA inventario TO inventory_manager;
REVOKE DELETE ON categorias, subcategorias, proveedores, almacenes, productos FROM inventory_manager;
REVOKE INSERT, UPDATE, DELETE ON bitacora_reportes FROM inventory_manager;

-- auditor (Solo lectura)
GRANT SELECT ON ALL TABLES    IN SCHEMA inventario TO auditor;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA inventario TO auditor;

-- Denegar a public
REVOKE ALL ON SCHEMA inventario FROM PUBLIC;
REVOKE ALL ON ALL TABLES    IN SCHEMA inventario FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA inventario FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA inventario FROM PUBLIC;

DO $$ BEGIN RAISE NOTICE '--- Verificando Privilegios de inventory_manager ---'; END $$;
SELECT privilege_type FROM information_schema.role_table_grants 
WHERE grantee = 'inventory_manager' AND table_name = 'productos' ORDER BY privilege_type;
-- Seguridad

--Función De Contexto
CREATE FUNCTION current_almacen_id() RETURNS INT LANGUAGE plpgsql STABLE AS $$
DECLARE v TEXT;
BEGIN
    v := current_setting('app.almacen_id', true);
    IF v IS NULL OR v = '' THEN RETURN NULL; END IF;
    RETURN v::INT;
EXCEPTION WHEN OTHERS THEN RETURN NULL; END;
$$;

--Habilitar RLS
ALTER TABLE stock ENABLE ROW LEVEL SECURITY; ALTER TABLE stock FORCE ROW LEVEL SECURITY;
ALTER TABLE movimientos_inventario ENABLE ROW LEVEL SECURITY; ALTER TABLE movimientos_inventario FORCE ROW LEVEL SECURITY;
ALTER TABLE ventas ENABLE ROW LEVEL SECURITY; ALTER TABLE ventas FORCE ROW LEVEL SECURITY;
ALTER TABLE detalle_venta ENABLE ROW LEVEL SECURITY; ALTER TABLE detalle_venta FORCE ROW LEVEL SECURITY;
ALTER TABLE transferencias ENABLE ROW LEVEL SECURITY; ALTER TABLE transferencias FORCE ROW LEVEL SECURITY;
ALTER TABLE detalle_transferencia ENABLE ROW LEVEL SECURITY; ALTER TABLE detalle_transferencia FORCE ROW LEVEL SECURITY;

--Políticas
CREATE POLICY pol_stock_almacen ON stock FOR ALL TO inventory_manager, auditor
USING (id_almacen = current_almacen_id()) WITH CHECK (id_almacen = current_almacen_id());

CREATE POLICY pol_mov_almacen ON movimientos_inventario FOR ALL TO inventory_manager, auditor
USING (id_almacen = current_almacen_id()) WITH CHECK (id_almacen = current_almacen_id());

CREATE POLICY pol_ventas_almacen ON ventas FOR ALL TO inventory_manager, auditor
USING (id_almacen = current_almacen_id()) WITH CHECK (id_almacen = current_almacen_id());

CREATE POLICY pol_dv_almacen ON detalle_venta FOR ALL TO inventory_manager, auditor
USING (EXISTS (SELECT 1 FROM ventas v WHERE v.id_venta = detalle_venta.id_venta))
WITH CHECK (EXISTS (SELECT 1 FROM ventas v WHERE v.id_venta = detalle_venta.id_venta));

CREATE POLICY pol_transf_almacen ON transferencias FOR ALL TO inventory_manager, auditor
USING (id_almacen_origen = current_almacen_id() OR id_almacen_destino = current_almacen_id())
WITH CHECK (id_almacen_origen = current_almacen_id() OR id_almacen_destino = current_almacen_id());

CREATE POLICY pol_dt_almacen ON detalle_transferencia FOR ALL TO inventory_manager, auditor
USING (EXISTS (SELECT 1 FROM transferencias t WHERE t.id_transferencia = detalle_transferencia.id_transferencia))
WITH CHECK (EXISTS (SELECT 1 FROM transferencias t WHERE t.id_transferencia = detalle_transferencia.id_transferencia));

SET ROLE u_manager_c;
SET app.almacen_id = '1';
SELECT count(*) AS filas_visibles, 'Manager Central (Almacén 1)' AS rol FROM stock;
RESET ROLE;

SET ROLE u_manager_n;
SET app.almacen_id = '2';
SELECT count(*) AS filas_visibles, 'Manager Norte (Almacén 2)' AS rol FROM stock;
RESET ROLE;

SET ROLE u_auditor;
RESET app.almacen_id;
SELECT count(*) AS filas_visibles, 'Auditor sin contexto' AS rol FROM stock;
RESET ROLE;

ALTER ROLE u_admin BYPASSRLS;

SET ROLE u_admin;
SELECT count(*) AS filas_visibles, 'Admin (Ve todo)' AS rol FROM stock;
RESET ROLE;

GRANT INSERT ON bitacora_reportes TO auditor;

CREATE OR REPLACE FUNCTION sp_reporte_rotacion_inventario(
    p_fecha_inicio DATE,
    p_fecha_fin DATE,
    p_categoria_id INT DEFAULT NULL
)
RETURNS TABLE (
    sku VARCHAR,
    producto VARCHAR,
    categoria VARCHAR,
    stock_promedio NUMERIC,
    total_salidas_unidades INT,
    valor_total_salidas_usd NUMERIC,
    promedio_diario_salidas NUMERIC,
    dias_inventario_restante NUMERIC,
    clasificacion_abc VARCHAR
)
LANGUAGE plpgsql
SECURITY INVOKER 
AS $BODY$
DECLARE
    v_total_global NUMERIC;
BEGIN
    IF p_fecha_inicio > p_fecha_fin THEN
        RAISE EXCEPTION 'La fecha de inicio (%) no puede ser posterior a la fecha fin (%). Operación cancelada.', 
            p_fecha_inicio, p_fecha_fin
            USING ERRCODE = '50001';
    END IF;

    --Insertar en bitácora de auditoría 
    INSERT INTO bitacora_reportes(nombre_sp, parametros, id_usuario)
    VALUES ('sp_reporte_rotacion_inventario', 
            'Inicio: ' || p_fecha_inicio || ', Fin: ' || p_fecha_fin || ', Cat: ' || COALESCE(p_categoria_id::text, 'NULL'), 
            current_user);

    -- Calcular el total global de ventas
    SELECT COALESCE(SUM(m.cantidad * p.precio_venta), 0) INTO v_total_global
    FROM movimientos_inventario m
    JOIN productos p ON p.id_producto = m.id_producto
    JOIN subcategorias sc ON sc.id_subcategoria = p.id_subcategoria
    WHERE m.tipo = 'SALIDA' 
      AND m.fecha::DATE BETWEEN p_fecha_inicio AND p_fecha_fin
      AND (p_categoria_id IS NULL OR sc.id_categoria = p_categoria_id);

    -- Retornar la tabla calculada
    RETURN QUERY
    WITH salidas AS (
        SELECT 
            p.id_producto,
            p.sku,
            p.nombre::VARCHAR AS producto,
            c.nombre::VARCHAR AS categoria,
            SUM(m.cantidad)::INT AS total_salidas,
            SUM(m.cantidad * p.precio_venta)::NUMERIC AS valor_salidas
        FROM movimientos_inventario m
        JOIN productos p ON p.id_producto = m.id_producto
        JOIN subcategorias sc ON sc.id_subcategoria = p.id_subcategoria
        JOIN categorias c ON c.id_categoria = sc.id_categoria
        WHERE m.tipo = 'SALIDA'
          AND m.fecha::DATE BETWEEN p_fecha_inicio AND p_fecha_fin
          AND (p_categoria_id IS NULL OR c.id_categoria = p_categoria_id)
        GROUP BY p.id_producto, p.sku, p.nombre, c.nombre
    ),
    acumulado AS (
        SELECT 
            s.*,
            SUM(s.valor_salidas) OVER (ORDER BY s.valor_salidas DESC) AS valor_acumulado
        FROM salidas s
    )
    SELECT 
        a.sku,
        a.producto,
        a.categoria,
        COALESCE(SUM(st.cantidad), 0)::NUMERIC AS stock_promedio, 
        a.total_salidas,
        a.valor_salidas,
        ROUND(a.total_salidas::NUMERIC / GREATEST((p_fecha_fin - p_fecha_inicio + 1), 1), 2) AS promedio_diario,
        CASE 
            WHEN a.total_salidas = 0 THEN 9999 
            ELSE ROUND(COALESCE(SUM(st.cantidad), 0)::NUMERIC / (a.total_salidas::NUMERIC / GREATEST((p_fecha_fin - p_fecha_inicio + 1), 1)), 0)
        END AS dias_restantes,
        CASE 
            WHEN v_total_global = 0 THEN 'Clase C (Baja Rotación)'
            WHEN (a.valor_acumulado / v_total_global) <= 0.80 THEN 'Clase A (Alta Rotación)'
            WHEN (a.valor_acumulado / v_total_global) <= 0.95 THEN 'Clase B (Rotación Media)'
            ELSE 'Clase C (Baja Rotación)'
        END::VARCHAR AS clasificacion_abc
    FROM acumulado a
    LEFT JOIN stock st ON st.id_producto = a.id_producto
    GROUP BY a.sku, a.producto, a.categoria, a.total_salidas, a.valor_salidas, a.valor_acumulado, v_total_global
    ORDER BY a.valor_salidas DESC;

END;
$BODY$;

--Asignar permisos de ejecución
GRANT EXECUTE ON FUNCTION sp_reporte_rotacion_inventario(DATE, DATE, INT) TO db_admin;
GRANT EXECUTE ON FUNCTION sp_reporte_rotacion_inventario(DATE, DATE, INT) TO auditor;
REVOKE EXECUTE ON FUNCTION sp_reporte_rotacion_inventario(DATE, DATE, INT) FROM inventory_manager;
REVOKE EXECUTE ON FUNCTION sp_reporte_rotacion_inventario(DATE, DATE, INT) FROM PUBLIC;
