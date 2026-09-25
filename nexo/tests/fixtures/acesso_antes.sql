-- Estrutura reproduzida do diagnóstico de 25/09/2026; sem dados reais.

create role anon; create role authenticated;

create schema auth;

create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;

grant usage on schema public, auth to anon, authenticated;

create table public.alertas ("id" uuid, "execucao_id" uuid, "pessoa_id" uuid, "tipo" text, "titulo" text, "mensagem" text, "prioridade" text, "lido" bool, "created_at" timestamptz, "lido_em" timestamptz);

alter table public.alertas enable row level security;

create table public.aprovacoes ("id" uuid, "execucao_id" uuid, "aprovador_id" uuid, "status" text, "observacao" text, "solicitado_em" timestamptz, "respondido_em" timestamptz, "created_at" timestamptz, "updated_at" timestamptz);

alter table public.aprovacoes enable row level security;

create table public.auditoria ("id" uuid, "tabela" text, "registro_id" uuid, "acao" text, "pessoa_id" uuid, "campo" text, "valor_anterior" text, "valor_novo" text, "motivo" text, "created_at" timestamptz);

alter table public.auditoria enable row level security;

create table public.bloqueios ("id" uuid, "execucao_id" uuid, "dependencia_id" uuid, "motivo" text, "descricao" text, "criado_por" uuid, "iniciado_em" timestamptz, "finalizado_em" timestamptz, "resolucao" text, "ativo" bool, "created_at" timestamptz, "updated_at" timestamptz);

alter table public.bloqueios enable row level security;

create table public.carga_trabalho ("id" uuid, "pessoa_id" uuid, "execucao_id" uuid, "complexidade" int4, "peso" numeric, "tempo_estimado_minutos" int4, "percentual_carga" numeric, "created_at" timestamptz, "updated_at" timestamptz);

alter table public.carga_trabalho enable row level security;

create table public.cargos ("id" uuid, "empresa_id" uuid, "nome" text, "descricao" text, "ativo" bool, "created_at" timestamptz, "updated_at" timestamptz);

alter table public.cargos enable row level security;

create table public.conferencias ("id" uuid, "execucao_id" uuid, "conferente_id" uuid, "resultado" text, "observacao" text, "iniciado_em" timestamptz, "finalizado_em" timestamptz, "created_at" timestamptz, "updated_at" timestamptz);

alter table public.conferencias enable row level security;

create table public.demanda_status_historico ("id" uuid, "demanda_id" uuid, "status_anterior" text, "status_novo" text, "alterado_por" uuid, "motivo" text, "created_at" timestamptz);

alter table public.demanda_status_historico enable row level security;

create table public.demandas ("id" uuid, "empresa_id" uuid, "solicitante_id" uuid, "responsavel_id" uuid, "setor_id" uuid, "processo_id" uuid, "operacao_id" uuid, "execucao_id" uuid, "titulo" text, "descricao" text, "prioridade" text, "status" text, "data_prevista" timestamptz, "data_inicio" timestamptz, "data_conclusao" timestamptz, "percentual_conclusao" int4, "created_at" timestamptz, "updated_at" timestamptz);

alter table public.demandas enable row level security;

create table public.dependencias ("id" uuid, "execucao_id" uuid, "tipo_dependencia" text, "pessoa_id" uuid, "setor_id" uuid, "entidade_externa" text, "motivo" text, "descricao" text, "impacto" text, "previsao_retorno" timestamptz, "proxima_acao" text, "iniciado_em" timestamptz, "finalizado_em" timestamptz, "ativo" bool, "created_at" timestamptz, "updated_at" timestamptz);

alter table public.dependencias enable row level security;

create table public.documento_vinculos ("id" uuid, "documento_id" uuid, "processo_id" uuid, "operacao_id" uuid, "execucao_id" uuid, "created_at" timestamptz);

alter table public.documento_vinculos enable row level security;

create table public.documentos ("id" uuid, "empresa_id" uuid, "setor_id" uuid, "pessoa_id" uuid, "titulo" text, "descricao" text, "tipo" text, "arquivo_url" text, "link_externo" text, "ativo" bool, "created_at" timestamptz, "updated_at" timestamptz);

alter table public.documentos enable row level security;

create table public.empresas ("id" uuid, "nome" text, "nome_fantasia" text, "cnpj" text, "ativo" bool, "created_at" timestamptz, "updated_at" timestamptz);

alter table public.empresas enable row level security;

create table public.escalonamentos ("id" uuid, "execucao_id" uuid, "nivel" int4, "pessoa_id" uuid, "setor_id" uuid, "motivo" text, "escalonado_em" timestamptz, "resolvido_em" timestamptz, "ativo" bool, "created_at" timestamptz);

alter table public.escalonamentos enable row level security;

create table public.evidencias ("id" uuid, "execucao_id" uuid, "pessoa_id" uuid, "tipo" text, "titulo" text, "descricao" text, "valor_texto" text, "arquivo_url" text, "obrigatoria" bool, "created_at" timestamptz);

alter table public.evidencias enable row level security;

create table public.execucao_participantes ("id" uuid, "execucao_id" uuid, "pessoa_id" uuid, "papel" text, "ativo" bool, "entrou_em" timestamptz, "saiu_em" timestamptz, "created_at" timestamptz);

alter table public.execucao_participantes enable row level security;

create table public.execucao_status_historico ("id" uuid, "execucao_id" uuid, "status_anterior" text, "status_novo" text, "alterado_por" uuid, "motivo" text, "observacao" text, "created_at" timestamptz);

alter table public.execucao_status_historico enable row level security;

create table public.execucoes ("id" uuid, "operacao_id" uuid, "responsavel_id" uuid, "titulo" text, "descricao" text, "status" text, "prioridade" text, "data_prevista" timestamptz, "data_inicio" timestamptz, "data_conclusao" timestamptz, "prazo_minutos" int4, "sla_minutos" int4, "percentual_conclusao" int4, "created_at" timestamptz, "updated_at" timestamptz, "recorrencia_id" uuid, "data_referencia" date);

alter table public.execucoes enable row level security;

create table public.indicadores ("id" uuid, "empresa_id" uuid, "setor_id" uuid, "processo_id" uuid, "operacao_id" uuid, "nome" text, "descricao" text, "tipo" text, "unidade" text, "meta" numeric, "ativo" bool, "created_at" timestamptz, "updated_at" timestamptz);

alter table public.indicadores enable row level security;

create table public.objetivos ("id" uuid, "empresa_id" uuid, "setor_id" uuid, "pessoa_id" uuid, "titulo" text, "descricao" text, "tipo" text, "valor_meta" numeric, "unidade" text, "data_inicio" date, "data_fim" date, "ativo" bool, "created_at" timestamptz, "updated_at" timestamptz);

alter table public.objetivos enable row level security;

create table public.operacao_recorrencias ("id" uuid, "operacao_id" uuid, "tipo_recorrencia" text, "dia_semana" int4, "dia_mes" int4, "data_especifica" date, "hora_prevista" time, "prazo_minutos" int4, "sla_minutos" int4, "ativo" bool, "created_at" timestamptz, "updated_at" timestamptz);

alter table public.operacao_recorrencias enable row level security;

create table public.operacao_responsaveis ("id" uuid, "operacao_id" uuid, "pessoa_id" uuid, "papel" text, "principal" bool, "ativo" bool, "created_at" timestamptz, "updated_at" timestamptz);

alter table public.operacao_responsaveis enable row level security;

create table public.operacoes ("id" uuid, "empresa_id" uuid, "setor_id" uuid, "processo_id" uuid, "nome" text, "descricao" text, "tipo" text, "prioridade" text, "tempo_estimado_minutos" int4, "exige_conferencia" bool, "exige_aprovacao" bool, "exige_evidencia" bool, "ativo" bool, "created_at" timestamptz, "updated_at" timestamptz, "peso_complexidade" numeric);

alter table public.operacoes enable row level security;

create table public.perfil_permissoes ("id" uuid, "perfil_id" uuid, "permissao_id" uuid, "created_at" timestamptz);

alter table public.perfil_permissoes enable row level security;

create table public.perfis ("id" uuid, "nome" text, "descricao" text, "created_at" timestamptz);

alter table public.perfis enable row level security;

create table public.permissoes ("id" uuid, "codigo" text, "nome" text, "descricao" text, "created_at" timestamptz);

alter table public.permissoes enable row level security;

create table public.pessoas ("id" uuid, "empresa_id" uuid, "setor_id" uuid, "cargo_id" uuid, "nome" text, "email" text, "ativo" bool, "created_at" timestamptz, "updated_at" timestamptz, "gestor_id" uuid);

alter table public.pessoas enable row level security;

create table public.procedimento_etapas ("id" uuid, "procedimento_versao_id" uuid, "ordem" int4, "titulo" text, "descricao" text, "obrigatoria" bool, "created_at" timestamptz);

alter table public.procedimento_etapas enable row level security;

create table public.procedimento_versoes ("id" uuid, "procedimento_id" uuid, "versao" int4, "descricao_alteracao" text, "criado_por" uuid, "created_at" timestamptz);

alter table public.procedimento_versoes enable row level security;

create table public.procedimentos ("id" uuid, "operacao_id" uuid, "titulo" text, "descricao" text, "versao_atual" int4, "ativo" bool, "created_at" timestamptz, "updated_at" timestamptz);

alter table public.procedimentos enable row level security;

create table public.processos ("id" uuid, "empresa_id" uuid, "setor_id" uuid, "nome" text, "descricao" text, "ativo" bool, "created_at" timestamptz, "updated_at" timestamptz);

alter table public.processos enable row level security;

create table public.retrabalhos ("id" uuid, "execucao_id" uuid, "conferencia_id" uuid, "identificado_por" uuid, "pessoa_origem_id" uuid, "setor_origem_id" uuid, "responsavel_correcao_id" uuid, "categoria" text, "motivo" text, "descricao" text, "prazo_correcao" timestamptz, "iniciado_em" timestamptz, "corrigido_em" timestamptz, "status" text, "numero_retorno" int4, "created_at" timestamptz, "updated_at" timestamptz);

alter table public.retrabalhos enable row level security;

create table public.setores ("id" uuid, "empresa_id" uuid, "nome" text, "descricao" text, "ativo" bool, "created_at" timestamptz, "updated_at" timestamptz);

alter table public.setores enable row level security;

create table public.usuarios ("id" uuid, "pessoa_id" uuid, "perfil_id" uuid, "ativo" bool, "created_at" timestamptz, "updated_at" timestamptz);

alter table public.usuarios enable row level security;

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

CREATE OR REPLACE FUNCTION public.nexo_perfil_empresa()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(public.nexo_usuario_perfil() in ('ADMIN','DIRETORIA','AUDITOR'), false)
$function$
;

CREATE OR REPLACE FUNCTION public.nexo_perfil_setor()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(public.nexo_usuario_perfil() in ('LIDER','GESTOR','GERENTE'), false)
$function$
;

CREATE OR REPLACE FUNCTION public.nexo_pode_ver_pessoa(p_pessoa_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.pessoas alvo
    where alvo.id = p_pessoa_id
      and alvo.empresa_id = public.nexo_usuario_empresa_id()
      and (
        public.nexo_perfil_empresa()
        or alvo.id = public.nexo_usuario_pessoa_id()
        or (
          public.nexo_perfil_setor()
          and alvo.setor_id is not distinct from public.nexo_usuario_setor_id()
        )
        or alvo.gestor_id = public.nexo_usuario_pessoa_id()
      )
  )
$function$
;

CREATE OR REPLACE FUNCTION public.nexo_pode_ver_execucao(p_execucao_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.execucoes e
    join public.operacoes o on o.id = e.operacao_id
    where e.id = p_execucao_id
      and o.empresa_id = public.nexo_usuario_empresa_id()
      and (
        public.nexo_perfil_empresa()
        or e.responsavel_id = public.nexo_usuario_pessoa_id()
        or exists (
          select 1
          from public.execucao_participantes ep
          where ep.execucao_id = e.id
            and ep.pessoa_id = public.nexo_usuario_pessoa_id()
            and ep.ativo = true
        )
        or (
          public.nexo_perfil_setor()
          and o.setor_id is not distinct from public.nexo_usuario_setor_id()
        )
      )
  )
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

create policy "admin_total_alertas" on public.alertas as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "admin_total_aprovacoes" on public.aprovacoes as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "nexo_final_aprovacoes_all" on public.aprovacoes as PERMISSIVE for ALL to authenticated using (nexo_pode_ver_execucao(execucao_id)) with check (nexo_pode_ver_execucao(execucao_id));

create policy "admin_total_auditoria" on public.auditoria as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "admin_total_bloqueios" on public.bloqueios as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "nexo_final_bloqueios_all" on public.bloqueios as PERMISSIVE for ALL to authenticated using (nexo_pode_ver_execucao(execucao_id)) with check (nexo_pode_ver_execucao(execucao_id));

create policy "admin_total_carga_trabalho" on public.carga_trabalho as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "admin_total_cargos" on public.cargos as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "admin_total_conferencias" on public.conferencias as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "nexo_final_conferencias_all" on public.conferencias as PERMISSIVE for ALL to authenticated using (nexo_pode_ver_execucao(execucao_id)) with check (nexo_pode_ver_execucao(execucao_id));

create policy "admin_gerencia_historico_demandas" on public.demanda_status_historico as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "admin_gerencia_demandas" on public.demandas as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "admin_total_dependencias" on public.dependencias as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "nexo_final_dependencias_all" on public.dependencias as PERMISSIVE for ALL to authenticated using (nexo_pode_ver_execucao(execucao_id)) with check (nexo_pode_ver_execucao(execucao_id));

create policy "admin_total_documento_vinculos" on public.documento_vinculos as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "admin_total_documentos" on public.documentos as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "admin_total_empresas" on public.empresas as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "admin_total_escalonamentos" on public.escalonamentos as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "admin_total_evidencias" on public.evidencias as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "nexo_final_evidencias_all" on public.evidencias as PERMISSIVE for ALL to authenticated using (nexo_pode_ver_execucao(execucao_id)) with check (nexo_pode_ver_execucao(execucao_id));

create policy "admin_total_execucao_participantes" on public.execucao_participantes as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "nexo_final_participantes_all" on public.execucao_participantes as PERMISSIVE for ALL to authenticated using (nexo_pode_ver_execucao(execucao_id)) with check (nexo_pode_ver_execucao(execucao_id));

create policy "admin_total_execucao_status_historico" on public.execucao_status_historico as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "nexo_final_historico_insert" on public.execucao_status_historico as PERMISSIVE for INSERT to authenticated with check ((nexo_pode_ver_execucao(execucao_id) AND (alterado_por = nexo_usuario_pessoa_id())));

create policy "nexo_final_historico_select" on public.execucao_status_historico as PERMISSIVE for SELECT to authenticated using (nexo_pode_ver_execucao(execucao_id));

create policy "admin_total_execucoes" on public.execucoes as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "nexo_final_execucoes_select" on public.execucoes as PERMISSIVE for SELECT to authenticated using (nexo_pode_ver_execucao(id));

create policy "nexo_final_execucoes_update" on public.execucoes as PERMISSIVE for UPDATE to authenticated using (nexo_pode_ver_execucao(id)) with check (nexo_pode_ver_execucao(id));

create policy "admin_total_indicadores" on public.indicadores as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "admin_total_objetivos" on public.objetivos as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "admin_total_operacao_recorrencias" on public.operacao_recorrencias as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "admin_total_operacao_responsaveis" on public.operacao_responsaveis as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "admin_total_operacoes" on public.operacoes as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "perfil_permissoes_visualizacao" on public.perfil_permissoes as PERMISSIVE for SELECT to authenticated using (true);

create policy "perfis_visualizacao" on public.perfis as PERMISSIVE for SELECT to authenticated using (true);

create policy "permissoes_visualizacao" on public.permissoes as PERMISSIVE for SELECT to authenticated using (true);

create policy "admin_total_pessoas" on public.pessoas as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "admin_total_procedimento_etapas" on public.procedimento_etapas as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "admin_total_procedimento_versoes" on public.procedimento_versoes as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "admin_total_procedimentos" on public.procedimentos as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "admin_total_processos" on public.processos as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "admin_total_retrabalhos" on public.retrabalhos as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "nexo_final_retrabalhos_all" on public.retrabalhos as PERMISSIVE for ALL to authenticated using (nexo_pode_ver_execucao(execucao_id)) with check (nexo_pode_ver_execucao(execucao_id));

create policy "admin_total_setores" on public.setores as PERMISSIVE for ALL to authenticated using (usuario_e_admin()) with check (usuario_e_admin());

create policy "usuario_visualiza_proprio_cadastro" on public.usuarios as PERMISSIVE for SELECT to authenticated using ((id = auth.uid()));

CREATE TRIGGER trg_nexo_proteger_ultimo_admin BEFORE UPDATE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION nexo_proteger_ultimo_admin();

grant all on all tables in schema public to anon, authenticated;
