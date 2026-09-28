-- SOMENTE LEITURA. Executar no SQL Editor. Envie o JSON para identificar os testes.
-- Palavras no título são candidatas, nunca autorização de exclusão.
SELECT coalesce(jsonb_agg(x),'[]'::jsonb) AS candidatos_a_revisar FROM (
 SELECT 'execucoes' entidade,e.id,o.empresa_id,e.titulo nome,e.status,e.created_at
 FROM public.execucoes e JOIN public.operacoes o ON o.id=e.operacao_id
 WHERE e.titulo ~* '(^|[^[:alnum:]])(teste|testes|demo|simulacao|simulação)([^[:alnum:]]|$)'
 UNION ALL SELECT 'demandas',d.id,d.empresa_id,d.titulo,d.status,d.created_at FROM public.demandas d
 WHERE d.titulo ~* '(^|[^[:alnum:]])(teste|testes|demo|simulacao|simulação)([^[:alnum:]]|$)'
 UNION ALL SELECT 'operacoes',o.id,o.empresa_id,o.nome,CASE WHEN o.ativo THEN 'ATIVA' ELSE 'INATIVA' END,o.created_at FROM public.operacoes o
 WHERE o.nome ~* '(^|[^[:alnum:]])(teste|testes|demo|simulacao|simulação)([^[:alnum:]]|$)'
 UNION ALL SELECT 'documentos',d.id,d.empresa_id,d.titulo,CASE WHEN d.ativo THEN 'ATIVO' ELSE 'INATIVO' END,d.created_at FROM public.documentos d
 WHERE d.titulo ~* '(^|[^[:alnum:]])(teste|testes|demo|simulacao|simulação)([^[:alnum:]]|$)'
) x;
