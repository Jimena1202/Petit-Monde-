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

