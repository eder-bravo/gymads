-- Eliminar la restricción actual que impide borrar productos con transacciones
ALTER TABLE public.product_transactions 
DROP CONSTRAINT IF EXISTS product_transactions_product_id_fkey;

-- Crear nueva restricción con CASCADE
-- Ahora cuando se elimine un producto, también se eliminarán automáticamente sus transacciones
ALTER TABLE public.product_transactions
ADD CONSTRAINT product_transactions_product_id_fkey 
FOREIGN KEY (product_id) 
REFERENCES public.products(id) 
ON DELETE CASCADE;

-- Comentario explicativo
COMMENT ON CONSTRAINT product_transactions_product_id_fkey ON public.product_transactions IS 
'Foreign key con CASCADE - Al eliminar un producto se eliminan automáticamente todas sus transacciones relacionadas';
