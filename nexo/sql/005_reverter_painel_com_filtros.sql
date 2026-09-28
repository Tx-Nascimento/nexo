-- Usar junto com a restauração do frontend anterior. Sem exclusão de registros.
BEGIN;
REVOKE EXECUTE ON FUNCTION public.nexo_filtros_painel() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.nexo_painel_filtrado(integer,uuid,uuid) FROM authenticated;
COMMIT;
SELECT 'NOVAS RPCS DESATIVADAS; PAINEL ANTERIOR PRESERVADO' AS resultado;
