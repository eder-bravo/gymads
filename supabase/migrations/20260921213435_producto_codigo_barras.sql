-- =============================================
-- CÓDIGO DE BARRAS POR PRODUCTO
-- =============================================
-- Para ajustar el stock sin buscar el producto en una lista: se escanea el
-- código que ya trae el envase (una bebida, un bote de proteína) y la app
-- abre directamente el ajuste de ese producto.
--
-- Es el código del FABRICANTE (EAN/UPC), no uno generado por nosotros, así
-- que se guarda como texto libre: hay formatos de 8, 12, 13 y 14 dígitos, y
-- algunos productos traen códigos internos alfanuméricos.
--
-- Nota histórica: la tabla `products` tuvo columnas `sku` y `barcode` que se
-- eliminaron en `supabase/simplify_products_table.sql` (un script suelto,
-- fuera de migrations/). Esto NO revierte aquello: el `sku` sigue sin existir
-- y este `barcode` nace con un propósito concreto y su índice.
--
-- Idempotente.
-- =============================================

ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS barcode text;

-- La app convierte '' a NULL y recorta espacios antes de guardar. La base
-- repite esa garantía para que una escritura ajena a la app no cree códigos
-- imposibles de encontrar con el escáner ni "duplicados" hechos de espacios.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'products_barcode_not_blank'
          AND conrelid = 'public.products'::regclass
    ) THEN
        ALTER TABLE public.products
            ADD CONSTRAINT products_barcode_not_blank
            CHECK (barcode IS NULL OR (barcode = btrim(barcode) AND barcode <> ''));
    END IF;
END
$$;

COMMENT ON COLUMN public.products.barcode IS
    'Código de barras del fabricante (EAN/UPC). Opcional: los productos sin
     código se siguen buscando por nombre.';

-- Único POR SUCURSAL, no global: es el mismo criterio que ya usa el nombre
-- del producto (ver 004_update_unique_constraints.sql). Dos sucursales
-- pueden vender la misma bebida, cada una con su propia fila.
--
-- PARCIAL (`WHERE barcode IS NOT NULL`) porque la columna es opcional y así el
-- índice no guarda las filas sin código. PostgreSQL ya permite varios NULL en
-- un índice UNIQUE; la condición es por tamaño y claridad de intención.
DROP INDEX IF EXISTS idx_products_branch_barcode;
CREATE UNIQUE INDEX idx_products_branch_barcode
    ON public.products (branch_id, barcode)
    WHERE barcode IS NOT NULL;

-- No hacen falta políticas nuevas: la columna vive en `products` y hereda
-- las suyas. Escribirla exige `staff_puede('gestionar_productos')`, que es
-- justo el permiso de la pantalla donde se asigna el código. Quien solo
-- escanea para mover stock necesita SELECT (lo tiene) y la RPC
-- ajustar_stock_producto (también).
