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
