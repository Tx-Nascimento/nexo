-- Reversão da etapa 2A: restaura as regras do diagnóstico de 25/09/2026.
-- Reintroduz as limitações anteriores; usar somente para recuperar acesso.
BEGIN;
SET LOCAL lock_timeout = '5s';

DROP POLICY IF EXISTS nexo_002_limite ON public.empresas;

DROP POLICY IF EXISTS nexo_002_limite ON public.pessoas;

DROP POLICY IF EXISTS nexo_002_limite ON public.usuarios;

DROP POLICY IF EXISTS nexo_002_limite ON public.setores;

DROP POLICY IF EXISTS nexo_002_limite ON public.cargos;

DROP POLICY IF EXISTS nexo_002_limite ON public.processos;

DROP POLICY IF EXISTS nexo_002_limite ON public.operacoes;

DROP POLICY IF EXISTS nexo_002_limite ON public.demandas;

DROP POLICY IF EXISTS nexo_002_limite ON public.documentos;

DROP POLICY IF EXISTS nexo_002_limite ON public.objetivos;

DROP POLICY IF EXISTS nexo_002_limite ON public.indicadores;

DROP POLICY IF EXISTS nexo_002_limite ON public.execucoes;

DROP POLICY IF EXISTS nexo_002_limite ON public.aprovacoes;

DROP POLICY IF EXISTS nexo_002_limite ON public.bloqueios;

DROP POLICY IF EXISTS nexo_002_limite ON public.conferencias;

DROP POLICY IF EXISTS nexo_002_limite ON public.dependencias;

DROP POLICY IF EXISTS nexo_002_limite ON public.evidencias;

DROP POLICY IF EXISTS nexo_002_limite ON public.execucao_participantes;

DROP POLICY IF EXISTS nexo_002_limite ON public.execucao_status_historico;

DROP POLICY IF EXISTS nexo_002_limite ON public.retrabalhos;

DROP POLICY IF EXISTS nexo_002_limite ON public.escalonamentos;

DROP POLICY IF EXISTS nexo_002_limite ON public.operacao_recorrencias;

DROP POLICY IF EXISTS nexo_002_limite ON public.operacao_responsaveis;

DROP POLICY IF EXISTS nexo_002_limite ON public.procedimentos;

DROP POLICY IF EXISTS nexo_002_limite ON public.demanda_status_historico;

DROP POLICY IF EXISTS nexo_002_limite ON public.documento_vinculos;

DROP POLICY IF EXISTS nexo_002_limite ON public.procedimento_versoes;

DROP POLICY IF EXISTS nexo_002_limite ON public.procedimento_etapas;

DROP POLICY IF EXISTS nexo_002_limite ON public.carga_trabalho;

DROP POLICY IF EXISTS nexo_002_limite ON public.auditoria;

DROP POLICY IF EXISTS nexo_002_limite ON public.alertas;

DROP POLICY IF EXISTS nexo_002_limite ON public.perfis;

DROP POLICY IF EXISTS nexo_002_limite ON public.permissoes;

DROP POLICY IF EXISTS nexo_002_limite ON public.perfil_permissoes;

DROP POLICY IF EXISTS nexo_002_leitura ON public.pessoas;

DROP POLICY IF EXISTS nexo_002_leitura ON public.empresas;

DROP POLICY IF EXISTS nexo_002_leitura ON public.setores;

DROP POLICY IF EXISTS nexo_002_leitura ON public.cargos;

DROP POLICY IF EXISTS nexo_002_leitura ON public.processos;

DROP POLICY IF EXISTS nexo_002_leitura ON public.operacoes;

DROP POLICY IF EXISTS nexo_002_leitura ON public.operacao_recorrencias;

DROP POLICY IF EXISTS nexo_002_leitura ON public.operacao_responsaveis;

DROP POLICY IF EXISTS nexo_002_admin_select ON public.usuarios;

DROP POLICY IF EXISTS nexo_002_admin_update ON public.usuarios;

DROP POLICY IF EXISTS nexo_002_pessoa_insert ON public.pessoas;
DROP POLICY IF EXISTS nexo_002_pessoa_update ON public.pessoas;
DROP POLICY IF EXISTS nexo_002_pessoa_delete ON public.pessoas;
DROP TRIGGER IF EXISTS trg_nexo_002_proteger_pessoa ON public.pessoas;
DROP FUNCTION IF EXISTS public.nexo_002_proteger_pessoa();
DROP FUNCTION IF EXISTS public.nexo_identidade_pessoa_id();

CREATE OR REPLACE FUNCTION public.nexo_usuario_pessoa_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select u.pessoa_id
  from public.usuarios u
  where u.id = auth.uid()
    and u.ativo = true
  limit 1
$function$
;

CREATE OR REPLACE FUNCTION public.nexo_usuario_empresa_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.empresa_id
  from public.usuarios u
  join public.pessoas p on p.id = u.pessoa_id
  where u.id = auth.uid()
    and u.ativo = true
  limit 1
$function$
;

CREATE OR REPLACE FUNCTION public.nexo_usuario_setor_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.setor_id
  from public.usuarios u
  join public.pessoas p on p.id = u.pessoa_id
  where u.id = auth.uid()
    and u.ativo = true
  limit 1
$function$
;

CREATE OR REPLACE FUNCTION public.nexo_usuario_perfil()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select pf.nome
  from public.usuarios u
  join public.perfis pf on pf.id = u.perfil_id
  where u.id = auth.uid()
    and u.ativo = true
  limit 1
$function$
;

CREATE OR REPLACE FUNCTION public.usuario_e_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
    select exists (
        select 1
        from usuarios u
        join perfis p on p.id = u.perfil_id
        where u.id = auth.uid()
          and u.ativo = true
          and p.nome = 'ADMIN'
    );
$function$
;

CREATE OR REPLACE FUNCTION public.nexo_proteger_ultimo_admin()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_admin_id uuid;
  v_qtd integer;
begin
  select id into v_admin_id from public.perfis where nome = 'ADMIN' limit 1;

  if old.perfil_id = v_admin_id
     and old.ativo = true
     and (new.perfil_id is distinct from v_admin_id or new.ativo = false) then

    select count(*) into v_qtd
    from public.usuarios
    where perfil_id = v_admin_id
      and ativo = true
      and id <> old.id;

    if v_qtd = 0 then
      raise exception 'Não é permitido remover ou desativar o último ADMIN.';
    end if;
  end if;

  return new;
end
$function$
;

REVOKE UPDATE (perfil_id, ativo, updated_at) ON public.usuarios FROM authenticated;

GRANT UPDATE ON public.usuarios TO anon;

GRANT UPDATE ON public.usuarios TO authenticated;

COMMIT;
