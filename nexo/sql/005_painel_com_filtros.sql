-- Supabase > SQL Editor > New query. Executar inteiro. Pré-requisito: 004.
-- Não altera nem exclui registros. Mantém a RPC antiga para compatibilidade.
BEGIN;
SET LOCAL lock_timeout='5s';
CREATE OR REPLACE FUNCTION public.nexo_painel_filtrado(p_dias integer DEFAULT 30, p_setor uuid DEFAULT NULL, p_operacao uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE v jsonb; v_modo text; v_score boolean; v_inicio timestamptz;
BEGIN
 IF nexo_usuario_empresa_id() IS NULL THEN RAISE EXCEPTION 'Acesso inativo'; END IF;
 IF p_dias IS NULL OR p_dias NOT IN (7,30,90) THEN RAISE EXCEPTION 'Período inválido'; END IF;
 IF p_setor IS NOT NULL AND NOT EXISTS(SELECT 1 FROM setores WHERE id=p_setor AND empresa_id=nexo_usuario_empresa_id()) THEN RAISE EXCEPTION 'Filtro indisponível'; END IF;
 IF p_operacao IS NOT NULL AND NOT EXISTS(SELECT 1 FROM operacoes WHERE id=p_operacao AND empresa_id=nexo_usuario_empresa_id() AND (p_setor IS NULL OR setor_id=p_setor)) THEN RAISE EXCEPTION 'Filtro indisponível'; END IF;
 v_inicio:=date_trunc('day',now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC' - (p_dias-1)*interval '1 day';
 SELECT pontuacao INTO v_modo FROM nexo_governanca WHERE empresa_id=nexo_usuario_empresa_id();
 v_modo:=coalesce(v_modo,'TODOS');
 v_score:=v_modo='TODOS' OR (v_modo='GESTAO' AND nexo_usuario_perfil() IN ('ADMIN','DIRETORIA','LIDER','GESTOR','GERENTE'));
 WITH e AS MATERIALIZED (
 SELECT e.*,o.nome operacao,s.nome setor,
 EXISTS(SELECT 1 FROM bloqueios b WHERE b.execucao_id=e.id AND b.ativo) bloqueada,
 EXISTS(SELECT 1 FROM dependencias d WHERE d.execucao_id=e.id AND d.ativo) dependente,
 EXISTS(SELECT 1 FROM retrabalhos r WHERE r.execucao_id=e.id) retrabalho
 FROM execucoes e JOIN operacoes o ON o.id=e.operacao_id LEFT JOIN setores s ON s.id=o.setor_id
 WHERE o.empresa_id=nexo_usuario_empresa_id() AND nexo_pode_ver_execucao(e.id) AND (p_setor IS NULL OR o.setor_id=p_setor) AND (p_operacao IS NULL OR o.id=p_operacao)),
 abertas AS (SELECT * FROM e WHERE status NOT IN ('CONCLUIDA','CANCELADA')),
 feitas AS (SELECT * FROM e WHERE status='CONCLUIDA' AND data_conclusao>=v_inicio AND data_conclusao<=now()),
 equipe AS (SELECT p.id,p.nome,
 (SELECT count(*) FROM abertas a WHERE a.responsavel_id=p.id) abertas,
 (SELECT count(*) FROM abertas a WHERE a.responsavel_id=p.id AND a.data_prevista<now()) atrasadas,
 count(f.id) entregues,count(f.id) FILTER(WHERE f.data_prevista IS NOT NULL) amostra,
 CASE WHEN v_score THEN round(100.0*count(f.id) FILTER(WHERE f.data_conclusao<=f.data_prevista)/nullif(count(f.id) FILTER(WHERE f.data_prevista IS NOT NULL),0),1) END pontuacao
 FROM pessoas p LEFT JOIN feitas f ON f.responsavel_id=p.id
 WHERE p.empresa_id=nexo_usuario_empresa_id() AND p.ativo AND nexo_pessoa_no_escopo(p.id) AND ((p_setor IS NULL AND p_operacao IS NULL) OR EXISTS(SELECT 1 FROM e WHERE e.responsavel_id=p.id)) GROUP BY p.id,p.nome)
 SELECT jsonb_build_object(
 'gerado_em',now(),'inicio',v_inicio,'modo',v_modo,'pontuacao_visivel',v_score,
 'abertas',(SELECT count(*) FROM abertas),
 'atrasadas',(SELECT count(*) FROM abertas WHERE data_prevista<now()),
 'sem_prazo',(SELECT count(*) FROM abertas WHERE data_prevista IS NULL),
 'bloqueadas',(SELECT count(*) FROM abertas WHERE bloqueada),
 'dependencias',(SELECT count(*) FROM abertas WHERE dependente),
 'entregues',(SELECT count(*) FROM feitas),
 'amostra_prazo',(SELECT count(*) FROM feitas WHERE data_prevista IS NOT NULL),
 'no_prazo',(SELECT round(100.0*count(*) FILTER(WHERE data_conclusao<=data_prevista)/nullif(count(*) FILTER(WHERE data_prevista IS NOT NULL),0),1) FROM feitas),
 'retrabalho',(SELECT round(100.0*count(*) FILTER(WHERE retrabalho)/nullif(count(*),0),1) FROM feitas),
 'ciclo_horas',(SELECT round(avg(extract(epoch FROM (data_conclusao-data_inicio))/3600)::numeric,1) FROM feitas WHERE data_inicio IS NOT NULL AND data_conclusao>=data_inicio),
 'sla', (SELECT round(100.0*count(*) FILTER(WHERE data_conclusao<=data_inicio+sla_minutos*interval '1 minute')/nullif(count(*),0),1) FROM feitas WHERE data_inicio IS NOT NULL AND sla_minutos>0 AND data_conclusao>=data_inicio),
 'idade',coalesce((SELECT jsonb_agg(x ORDER BY x.ordem) FROM (SELECT CASE WHEN created_at IS NULL THEN 'Sem data' WHEN created_at>=now()-interval '2 days' THEN 'Até 2 dias' WHEN created_at>=now()-interval '7 days' THEN '3 a 7 dias' WHEN created_at>=now()-interval '14 days' THEN '8 a 14 dias' ELSE 'Mais de 14 dias' END nome, CASE WHEN created_at IS NULL THEN 5 WHEN created_at>=now()-interval '2 days' THEN 1 WHEN created_at>=now()-interval '7 days' THEN 2 WHEN created_at>=now()-interval '14 days' THEN 3 ELSE 4 END ordem,count(*) valor FROM abertas GROUP BY 1,2) x),'[]'::jsonb),
 'causas',coalesce((SELECT jsonb_agg(x) FROM (SELECT coalesce(nullif(trim(b.motivo),''),'Sem motivo') nome,count(*) valor FROM bloqueios b JOIN abertas a ON a.id=b.execucao_id WHERE b.ativo GROUP BY 1 ORDER BY count(*) DESC LIMIT 10) x),'[]'::jsonb),
 'demandas_abertas',(SELECT count(*) FROM demandas d WHERE (p_setor IS NULL OR d.setor_id=p_setor OR EXISTS(SELECT 1 FROM operacoes o WHERE o.id=d.operacao_id AND o.setor_id=p_setor)) AND (p_operacao IS NULL OR d.operacao_id=p_operacao) AND nexo_pode_ver_demanda(d.id) AND status NOT IN ('CONCLUIDA','CANCELADA') AND execucao_id IS NULL),
 'status',coalesce((SELECT jsonb_agg(x) FROM (SELECT status nome,count(*) valor FROM abertas GROUP BY status ORDER BY count(*) DESC) x),'[]'::jsonb),
 'gargalos',coalesce((SELECT jsonb_agg(x) FROM (SELECT coalesce(setor,'Sem setor') nome,count(*) valor,count(*) FILTER(WHERE data_prevista<now()) atrasadas FROM abertas GROUP BY setor ORDER BY count(*) DESC) x),'[]'::jsonb),
 'fluxo',coalesce((SELECT jsonb_agg(x ORDER BY x.dia) FROM (SELECT to_char(d,'DD/MM') nome,to_char(d,'YYYY-MM-DD') dia,
 (SELECT count(*) FROM e WHERE created_at>=d AND created_at<d+interval '1 day') entradas,
 (SELECT count(*) FROM feitas WHERE data_conclusao>=d AND data_conclusao<d+interval '1 day') valor
 FROM generate_series(v_inicio,date_trunc('day',now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC',interval '1 day') d) x),'[]'::jsonb),
 'equipe',coalesce((SELECT jsonb_agg(equipe ORDER BY atrasadas DESC,abertas DESC,nome) FROM equipe),'[]'::jsonb),
 'fila',coalesce((SELECT jsonb_agg(x) FROM (SELECT id,titulo,operacao,status,data_prevista,bloqueada,dependente FROM abertas ORDER BY (data_prevista<now()) DESC NULLS LAST,bloqueada DESC,data_prevista ASC NULLS LAST,id LIMIT 50) x),'[]'::jsonb),
 'decisoes',coalesce((SELECT jsonb_agg(x) FROM (
 SELECT c.execucao_id,e.titulo,'Conferência' etapa FROM conferencias c JOIN e ON e.id=c.execucao_id WHERE c.resultado='PENDENTE' AND c.conferente_id=nexo_usuario_pessoa_id()
 UNION ALL SELECT a.execucao_id,e.titulo,'Aprovação' FROM aprovacoes a JOIN e ON e.id=a.execucao_id WHERE a.status='PENDENTE' AND a.aprovador_id=nexo_usuario_pessoa_id()) x),'[]'::jsonb)
 ) INTO v;
 RETURN v;
END $$;

CREATE OR REPLACE FUNCTION public.nexo_filtros_painel()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 WITH ops AS MATERIALIZED (
 SELECT o.id,o.nome,o.setor_id FROM operacoes o WHERE o.empresa_id=nexo_usuario_empresa_id()
 AND (nexo_perfil_empresa() OR (nexo_perfil_setor() AND o.setor_id=nexo_usuario_setor_id())
 OR EXISTS(SELECT 1 FROM execucoes e WHERE e.operacao_id=o.id AND nexo_pode_ver_execucao(e.id))
 OR EXISTS(SELECT 1 FROM demandas d WHERE d.operacao_id=o.id AND nexo_pode_ver_demanda(d.id))
 OR EXISTS(SELECT 1 FROM operacao_responsaveis r WHERE r.operacao_id=o.id AND r.ativo AND r.pessoa_id=nexo_usuario_pessoa_id())))
 SELECT jsonb_build_object('operacoes',coalesce((SELECT jsonb_agg(ops ORDER BY nome,id) FROM ops),'[]'::jsonb),
 'setores',coalesce((SELECT jsonb_agg(x ORDER BY x.nome,x.id) FROM (SELECT s.id,s.nome FROM setores s WHERE s.empresa_id=nexo_usuario_empresa_id()
 AND (nexo_perfil_empresa() OR (nexo_perfil_setor() AND s.id=nexo_usuario_setor_id()) OR s.id IN (SELECT setor_id FROM ops)
 OR EXISTS(SELECT 1 FROM demandas d WHERE d.setor_id=s.id AND nexo_pode_ver_demanda(d.id)))) x),'[]'::jsonb))
$$;
REVOKE ALL ON FUNCTION public.nexo_filtros_painel(),public.nexo_painel_filtrado(integer,uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.nexo_filtros_painel(),public.nexo_painel_filtrado(integer,uuid,uuid) TO authenticated;
COMMIT;
SELECT 'PAINEL COM FILTROS APLICADO' AS resultado;
