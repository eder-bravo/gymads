-- =============================================
-- MIGRATION 013: DELETE USER
-- Remove user cfaba34f-8662-46e3-bc8d-932309179bf7
-- =============================================

-- Delete related records first to avoid FK violations
DELETE FROM public.access_logs WHERE user_id = 'cfaba34f-8662-46e3-bc8d-932309179bf7';
DELETE FROM public.payments WHERE user_id = 'cfaba34f-8662-46e3-bc8d-932309179bf7';
DELETE FROM public.ingresos WHERE cliente_id = 'cfaba34f-8662-46e3-bc8d-932309179bf7';
DELETE FROM public.users WHERE id = 'cfaba34f-8662-46e3-bc8d-932309179bf7';
