-- Ajuste atómico de stock.
--
-- Hasta ahora la aritmética de stock vivía en Dart, en dos rutas con reglas
-- distintas: SaleRepository._updateProductStock (leer, sumar, escribir) y
-- ProductRepository.recordTransaction (igual, pero con tope en 0). Dos cajas
-- vendiendo a la vez leían el mismo valor y una pisaba a la otra.
--
-- Esta función deja el cálculo en la base, en un solo UPDATE. El resultado
-- puede quedar NEGATIVO a propósito: es el faltante, las unidades vendidas
-- sin existencias. Se salda solo al reponer, porque el delta se suma sobre el
-- negativo (-3 + 10 = 7). Por eso NO hay CHECK (stock >= 0).

CREATE OR REPLACE FUNCTION public.ajustar_stock_producto(
  p_product_id uuid,
  p_delta int
)
RETURNS int
LANGUAGE plpgsql
-- INVOKER a propósito: conserva las políticas RLS de products, que ya acotan
-- por branch_id. Con DEFINER cualquiera podría mover el stock de otra sucursal.
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_stock int;
BEGIN
  UPDATE public.products
     SET stock = stock + p_delta,
         updated_at = now()
   WHERE id = p_product_id
  RETURNING stock INTO v_stock;

  -- Sin fila: el producto no existe o RLS lo dejó fuera de alcance. Lanzar es
  -- importante, porque el llamador reporta la venta como exitosa si esto
  -- devuelve en silencio.
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Producto no encontrado o sin permiso: %', p_product_id
      USING ERRCODE = 'no_data_found';
  END IF;

  RETURN v_stock;
END;
$$;

COMMENT ON FUNCTION public.ajustar_stock_producto(uuid, int) IS
  'Suma p_delta al stock del producto y devuelve el resultado. Admite negativos (faltante).';

GRANT EXECUTE ON FUNCTION public.ajustar_stock_producto(uuid, int) TO authenticated;
